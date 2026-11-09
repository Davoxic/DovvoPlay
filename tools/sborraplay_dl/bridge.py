"""Il ponte: un piccolo server sul computer che presta yt-dlp al telefono.

Su iOS yt-dlp non può girare, quindi ricerca e risoluzione dei link YouTube
avvengono qui. Lo streaming però non passa da qui: al telefono restituiamo
l'URL audio diretto, e i byte se li scarica lui dai server di Google.
"""
from __future__ import annotations

import json
import socket
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from . import __version__
from .util import info, ok, warn, err

DEFAULT_PORT = 8077
_state = {"outdir": Path.cwd() / "SborraPlay" / "YouTube", "phone": None, "quiet": False}


# ------------------------------------------------------------------ rete

def local_ip(target: str | None = None) -> str:
    """Indirizzo di questa macchina sulla rete locale."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((target or "8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


# ------------------------------------------------------------------ yt-dlp

def _ydl(extra: dict | None = None):
    import yt_dlp
    opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "noplaylist": True,
        "socket_timeout": 20,
    }
    if extra:
        opts.update(extra)
    return yt_dlp.YoutubeDL(opts)


def search_youtube(query: str, limit: int = 20) -> list[dict]:
    with _ydl({"extract_flat": "in_playlist"}) as ydl:
        data = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)
    out = []
    for e in (data or {}).get("entries") or []:
        if not e or not e.get("id"):
            continue
        thumb = ""
        thumbs = e.get("thumbnails") or []
        if thumbs:
            thumb = thumbs[-1].get("url", "")
        elif e.get("id"):
            thumb = f"https://i.ytimg.com/vi/{e['id']}/mqdefault.jpg"
        out.append({
            "id": e["id"],
            "title": e.get("title") or "",
            "artist": e.get("channel") or e.get("uploader") or "",
            "duration": float(e.get("duration") or 0),
            "artwork": thumb,
            "url": f"https://www.youtube.com/watch?v={e['id']}",
        })
    return out


def audio_url(video_id: str) -> str:
    with _ydl({"format": "bestaudio[ext=m4a]/bestaudio/best"}) as ydl:
        inf = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
    url = (inf or {}).get("url")
    if not url:
        formats = (inf or {}).get("formats") or []
        audio = [f for f in formats if f.get("acodec") not in (None, "none") and f.get("vcodec") in (None, "none")]
        if audio:
            url = sorted(audio, key=lambda f: f.get("abr") or 0)[-1].get("url")
    if not url:
        raise RuntimeError("audio non trovato")
    return url


def grab(video_id: str, title: str, artist: str, callback: str | None) -> dict:
    """Scarica in mp3, scrive i tag e, se il telefono è raggiungibile, glielo manda."""
    from .spotify import SpotifyTrack
    from .matcher import Candidate
    from .downloader import fetch_and_tag
    from . import pusher

    outdir = Path(_state["outdir"])
    outdir.mkdir(parents=True, exist_ok=True)

    track = SpotifyTrack(title=title or video_id, artist=artist or "")
    cand = Candidate(video_id=video_id, title=title or "", channel=artist or "", duration=0)
    path = fetch_and_tag(track, cand, outdir, "mp3", "320", archive=None)

    sent = False
    device = None
    if callback:
        try:
            device = pusher.normalize_host(callback)
        except ValueError:
            device = None
    if device is None:
        device = _state.get("phone")
    if device is not None:
        try:
            pusher.upload_file(device, path)
            sent = True
        except Exception as exc:
            warn(f"Scaricato ma non inviato: {exc}")

    return {"ok": True, "file": path.name, "sent": sent, "path": str(path)}


# ------------------------------------------------------------------ server

class Handler(BaseHTTPRequestHandler):
    server_version = f"SborraPlayBridge/{__version__}"

    def log_message(self, *args):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/health":
            return self._json({"ok": True, "app": "sborraplay-bridge", "version": __version__})

        if parsed.path == "/search":
            q = (query.get("q") or [""])[0].strip()
            if not q:
                return self._json({"error": "manca q"}, 400)
            limit = int((query.get("limit") or ["20"])[0])
            try:
                results = search_youtube(q, max(1, min(limit, 40)))
            except Exception as exc:
                return self._json({"error": f"ricerca fallita: {exc}"}, 500)
            if not _state["quiet"]:
                info(f"ricerca \"{q}\" → {len(results)} risultati")
            return self._json({"results": results})

        if parsed.path == "/stream":
            vid = (query.get("id") or [""])[0].strip()
            if not vid:
                return self._json({"error": "manca id"}, 400)
            try:
                return self._json({"url": audio_url(vid)})
            except Exception as exc:
                return self._json({"error": str(exc)}, 500)

        self._json({"error": "endpoint sconosciuto"}, 404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw or b"{}")
        except Exception:
            return self._json({"error": "JSON non valido"}, 400)

        if parsed.path == "/grab":
            vid = (payload.get("id") or "").strip()
            if not vid:
                return self._json({"error": "manca id"}, 400)
            if not _state["quiet"]:
                info(f"scarico {payload.get('title') or vid}…")
            try:
                result = grab(vid, payload.get("title", ""), payload.get("artist", ""),
                              payload.get("callback"))
            except Exception as exc:
                err(f"download fallito: {exc}")
                return self._json({"error": str(exc)}, 500)
            if not _state["quiet"]:
                ok(f"{result['file']}" + (" → telefono" if result["sent"] else " (resta sul PC)"))
            return self._json(result)

        self._json({"error": "endpoint sconosciuto"}, 404)


def announce(device, port: int, tries: int = 40) -> bool:
    """Dice al telefono dove siamo, così nell'app non si configura niente."""
    from . import pusher
    ip = local_ip(device.host if device else None)
    url = f"http://{ip}:{port}"
    for attempt in range(tries):
        target = device
        if target is None:
            found = pusher.discover(timeout=3.0)
            target = found[0] if found else None
        if target is not None:
            try:
                pusher._request(f"{target.base}/api/bridge", method="POST",
                                data=json.dumps({"url": url}).encode(),
                                headers={"Content-Type": "application/json"}, timeout=8)
                _state["phone"] = target
                ok(f"Telefono collegato: {target.host} ← ponte su {url}")
                return True
            except Exception:
                pass
        if attempt == 0:
            warn("Telefono non ancora raggiungibile: apri SborraPlay e accendi il Server Wi-Fi.")
            info("Resto in ascolto e riprovo da solo ogni 15 secondi.")
        time.sleep(15)
    return False


def serve(port: int = DEFAULT_PORT, outdir: Path | None = None, device=None) -> int:
    if outdir:
        _state["outdir"] = Path(outdir)
    _state["phone"] = device

    httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    ip = local_ip(device.host if device else None)

    print()
    ok(f"Ponte acceso su http://{ip}:{port}")
    info(f"I brani scaricati finiscono in {_state['outdir']}")
    info("Lascia questa finestra aperta mentre usi YouTube dall'iPhone. Ctrl+C per chiudere.")
    print()

    threading.Thread(target=announce, args=(device, port), daemon=True).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print()
        info("Ponte spento.")
    finally:
        httpd.server_close()
    return 0
