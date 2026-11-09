from __future__ import annotations

import argparse
import shutil
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from . import __version__
from .util import (info, ok, warn, err, step, human_time, safe_filename,
                   load_config, save_config)

PRINT_LOCK = threading.Lock()


def say(msg: str) -> None:
    with PRINT_LOCK:
        print(msg)


# ------------------------------------------------------------------ comandi

def cmd_playlist(args) -> int:
    from .spotify import load_playlist
    from .matcher import find_best
    from .downloader import fetch_and_tag, DownloadResult, target_name, AUDIO_FORMATS
    from . import pusher

    if args.format not in AUDIO_FORMATS:
        err(f"Formato non supportato: {args.format}. iOS riproduce {', '.join(AUDIO_FORMATS)}.")
        return 2
    if shutil.which("ffmpeg") is None:
        err("ffmpeg non trovato nel PATH: yt-dlp non può convertire l'audio.\n"
            "  macOS: brew install ffmpeg · Windows: winget install Gyan.FFmpeg · Linux: apt install ffmpeg")
        return 2

    step("1 · Leggo la playlist")
    try:
        playlist = load_playlist(args.reference)
    except Exception as exc:
        err(str(exc))
        return 1
    if not playlist.tracks:
        err("La playlist è vuota.")
        return 1

    tracks = playlist.tracks[:args.limit] if args.limit else playlist.tracks
    ok(f"{playlist.name} — {len(tracks)} brani")

    outdir = Path(args.out).expanduser() if args.out else Path.cwd() / "SborraPlay" / safe_filename(playlist.name)
    outdir.mkdir(parents=True, exist_ok=True)
    archive = outdir / ".yt-archive.txt" if args.archive else None

    if args.dry_run:
        step("2 · Anteprima (nessun download)")
        for i, t in enumerate(tracks, 1):
            say(f"  {i:3d}. {t.label}  [{human_time(t.duration)}]  → {target_name(t, args.format)}")
        return 0

    step(f"2 · Cerco e scarico in {outdir}")
    results: list[DownloadResult] = []
    counter = {"n": 0}

    def work(index_track):
        index, track = index_track
        existing = outdir / target_name(track, args.format)
        if existing.exists() and not args.overwrite:
            return DownloadResult(track=track, ok=True, path=existing, skipped=True,
                                  reason="già scaricato")
        try:
            cand, sc, _ = find_best(track, per_query=args.candidates,
                                    min_score=args.min_score)
        except Exception as exc:
            return DownloadResult(track=track, ok=False, reason=f"ricerca fallita: {exc}")
        if cand is None:
            return DownloadResult(track=track, ok=False, match_score=sc,
                                  reason="nessun risultato abbastanza affidabile")
        try:
            path = fetch_and_tag(track, cand, outdir, args.format, args.quality,
                                 archive, args.overwrite, args.cookies_from_browser)
            return DownloadResult(track=track, ok=True, path=path, candidate=cand, match_score=sc)
        except Exception as exc:
            return DownloadResult(track=track, ok=False, candidate=cand, match_score=sc,
                                  reason=str(exc).strip().splitlines()[0][:160] if str(exc) else "errore")

    total = len(tracks)
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = {pool.submit(work, (i, t)): t for i, t in enumerate(tracks)}
        for fut in as_completed(futures):
            res = fut.result()
            results.append(res)
            counter["n"] += 1
            n = counter["n"]
            if res.skipped:
                say(f"  [{n:3d}/{total}] ↷ {res.track.label}  (già presente)")
            elif res.ok:
                extra = f"  ·  {res.candidate.title[:46]}" if res.candidate else ""
                say(f"  [{n:3d}/{total}] ✓ {res.track.label}{extra}")
            else:
                say(f"  [{n:3d}/{total}] ✗ {res.track.label}  → {res.reason}")

    # rimettiamo i risultati nell'ordine della playlist
    order = {t.label: i for i, t in enumerate(tracks)}
    results.sort(key=lambda r: order.get(r.track.label, 0))

    good = [r for r in results if r.ok and r.path]
    bad = [r for r in results if not r.ok]
    step("3 · Riepilogo")
    ok(f"{len(good)}/{total} brani pronti in {outdir}")
    if bad:
        warn(f"{len(bad)} non scaricati:")
        for r in bad:
            say(f"    · {r.track.label} — {r.reason}")
        failed_file = outdir / "_non_scaricati.txt"
        failed_file.write_text("\n".join(r.track.label for r in bad), encoding="utf-8")
        info(f"Elenco salvato in {failed_file.name}")

    if args.m3u and good:
        m3u = outdir / (safe_filename(playlist.name) + ".m3u")
        lines = ["#EXTM3U"]
        for r in good:
            lines.append(f"#EXTINF:{int(r.track.duration)},{r.track.label}")
            lines.append(r.path.name)
        m3u.write_text("\n".join(lines) + "\n", encoding="utf-8")
        info(f"Playlist locale: {m3u.name}")

    if args.no_push or not good:
        if not args.no_push:
            info("Niente da inviare al telefono.")
        return 0 if not bad else 1

    step("4 · Invio al telefono")
    device = resolve_device(args.host)
    if device is None:
        warn("Nessun telefono raggiungibile: i file restano nella cartella, "
             "puoi inviarli dopo con  sborraplay-dl push \"" + str(outdir) + "\"")
        return 0 if not bad else 1

    sent, names = pusher.push_many(device, [r.path for r in good], skip_existing=not args.overwrite)
    ok(f"{sent} file sul telefono ({device.host})")
    if names:
        try:
            pusher.create_playlist(device, playlist.name, names)
            ok(f"Playlist \"{playlist.name}\" creata nell'app")
        except Exception as exc:
            warn(f"File caricati ma playlist non creata: {exc}")
    return 0 if not bad else 1


def cmd_push(args) -> int:
    from . import pusher
    paths: list[Path] = []
    for raw in args.paths:
        p = Path(raw).expanduser()
        if p.is_dir():
            for f in sorted(p.rglob("*")):
                if f.suffix.lower().lstrip(".") in {"mp3", "m4a", "flac", "wav", "aiff", "aif", "alac", "m4b"}:
                    paths.append(f)
        elif p.exists():
            paths.append(p)
        else:
            warn(f"non trovo {p}")
    if not paths:
        err("Nessun file audio da inviare.")
        return 1

    device = resolve_device(args.host)
    if device is None:
        return 1
    step(f"Invio di {len(paths)} file a {device.host}:{device.port}")
    sent, names = pusher.push_many(device, paths, skip_existing=not args.overwrite)
    ok(f"{sent}/{len(paths)} file caricati")
    if args.playlist and names:
        pusher.create_playlist(device, args.playlist, names)
        ok(f"Playlist \"{args.playlist}\" creata nell'app")
    return 0


def cmd_discover(args) -> int:
    from . import pusher
    info("Cerco SborraPlay sulla rete locale…")
    devices = pusher.discover(timeout=args.timeout)
    if not devices:
        warn("Nessun dispositivo trovato. Controlla che l'app sia aperta con il server acceso, "
             "e che PC e iPhone siano sulla stessa rete.")
        return 1
    for d in devices:
        data = pusher.ping(d) or {}
        ok(f"{d.host}:{d.port}  —  {data.get('device', d.name)}  ·  {data.get('tracks', '?')} brani")
    save_config({"host": f"{devices[0].host}:{devices[0].port}"})
    info(f"Salvato come predefinito: {devices[0].host}:{devices[0].port}")
    return 0


def cmd_library(args) -> int:
    from . import pusher
    device = resolve_device(args.host)
    if device is None:
        return 1
    data = pusher.library(device)
    tracks = data.get("tracks", [])
    ok(f"{len(tracks)} brani sul telefono")
    for t in sorted(tracks, key=lambda x: (x.get("artist", ""), x.get("title", ""))):
        say(f"  {t.get('artist','?')} — {t.get('title','?')}  [{human_time(t.get('duration', 0))}]")
    for p in data.get("playlists", []):
        say(f"  ♪ {p.get('name')}  ({len(p.get('tracks', []))} brani)")
    return 0



def cmd_backup(args) -> int:
    import json as _json
    from datetime import datetime
    from . import pusher

    device = resolve_device(args.host)
    if device is None:
        return 1
    step(f"Scarico il backup da {device.host}")
    try:
        payload = pusher.fetch_backup(device)
    except Exception as exc:
        err(f"Backup non riuscito: {exc}")
        return 1

    try:
        data = _json.loads(payload)
        label = "%d playlist · %d brani · %d copertine" % (
            len(data.get("playlists", [])),
            len(data.get("tracks", [])),
            len(data.get("covers", {})),
        )
    except Exception:
        label = "contenuto non interpretabile"

    out = Path(args.out).expanduser() if args.out else Path.cwd() / (
        "SborraPlay-%s.sborraplay.json" % datetime.now().strftime("%Y-%m-%d-%H%M"))
    if out.is_dir():
        out = out / ("SborraPlay-%s.sborraplay.json" % datetime.now().strftime("%Y-%m-%d-%H%M"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(payload)
    ok(f"{out}  ({len(payload)/1024:.0f} KB)")
    info(label)
    info("I file audio non sono nel backup: restano nelle cartelle che hai scaricato qui sul PC.")
    return 0


def cmd_restore(args) -> int:
    from . import pusher

    path = Path(args.file).expanduser()
    if not path.exists():
        err(f"Non trovo {path}")
        return 1
    payload = path.read_bytes()

    device = resolve_device(args.host)
    if device is None:
        return 1

    mode = "sostituendo le playlist attuali" if args.replace else "unendo alle playlist attuali"
    step(f"Rimando {path.name} al telefono, {mode}")
    try:
        res = pusher.send_backup(device, payload, replace=args.replace)
    except Exception as exc:
        err(f"Ripristino non riuscito: {exc}")
        return 1
    if res.get("ok"):
        ok("Ripristinato. Controlla la scheda Playlist sul telefono.")
        return 0
    err(str(res))
    return 1



def cmd_grab(args) -> int:
    """Scarica un singolo link YouTube o SoundCloud e lo manda al telefono."""
    import shutil
    from .spotify import SpotifyTrack
    from .matcher import Candidate
    from .downloader import fetch_and_tag
    from . import pusher

    if shutil.which("ffmpeg") is None:
        err("ffmpeg non trovato nel PATH.")
        return 2

    import yt_dlp
    step("1 · Leggo il link")
    try:
        with yt_dlp.YoutubeDL({"quiet": True, "no_warnings": True,
                               "skip_download": True, "noplaylist": True}) as ydl:
            meta = ydl.extract_info(args.url, download=False)
    except Exception as exc:
        err(f"Link non leggibile: {exc}")
        return 1
    if meta is None:
        err("Link non leggibile.")
        return 1

    title = meta.get("track") or meta.get("title") or "brano"
    artist = meta.get("artist") or meta.get("uploader") or meta.get("channel") or ""
    duration = float(meta.get("duration") or 0)
    ok(f"{artist} - {title}" if artist else title)

    track = SpotifyTrack(title=title, artist=artist, album=meta.get("album") or "",
                         duration=duration, cover_url=meta.get("thumbnail") or "")
    cand = Candidate(video_id=meta.get("id") or "", title=title,
                     channel=artist, duration=duration, url=args.url)

    outdir = Path(args.out).expanduser() if args.out else Path.cwd() / "SborraPlay" / "Singoli"
    step(f"2 · Scarico in {outdir}")
    try:
        path = fetch_and_tag(track, cand, outdir, args.format, args.quality, archive=None)
    except Exception as exc:
        err(f"Download fallito: {exc}")
        return 1
    ok(path.name)

    if args.no_push:
        return 0
    step("3 · Invio al telefono")
    device = resolve_device(args.host)
    if device is None:
        warn(f"Il file resta qui: {path}")
        return 0
    pusher.push_many(device, [path], skip_existing=False)
    ok("Fatto, lo trovi in Libreria.")
    return 0


# ------------------------------------------------------------------ device

def resolve_device(host: str | None):
    from . import pusher
    candidates = []
    if host:
        candidates.append(host)
    else:
        saved = load_config().get("host")
        if saved:
            candidates.append(saved)

    for raw in candidates:
        try:
            device = pusher.normalize_host(raw)
        except ValueError as exc:
            warn(str(exc))
            continue
        if pusher.ping(device):
            save_config({"host": f"{device.host}:{device.port}"})
            return device
        warn(f"{device.host}:{device.port} non risponde")

    info("Provo a scoprirlo via Bonjour…")
    found = pusher.discover(timeout=4.0)
    for device in found:
        if pusher.ping(device):
            save_config({"host": f"{device.host}:{device.port}"})
            ok(f"Trovato: {device.host}:{device.port}")
            return device

    err("Telefono non raggiungibile. Apri SborraPlay, vai in Impostazioni, accendi il server Wi-Fi "
        "e passa l'indirizzo mostrato con --host 192.168.x.x:8080")
    return None


# ------------------------------------------------------------------ parser

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="sborraplay-dl",
        description="Dalla playlist Spotify ai file sul tuo iPhone, passando da YouTube e yt-dlp.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""esempi:
  sborraplay-dl playlist https://open.spotify.com/playlist/37i9dQZF1DX...
  sborraplay-dl playlist miei_brani.csv --format m4a --no-push
  sborraplay-dl playlist <url> --host 192.168.1.42:8080 --workers 4
  sborraplay-dl push ~/Musica/Estate --playlist "Estate 2026"
  sborraplay-dl grab "https://soundcloud.com/artista/brano"
  sborraplay-dl discover
  sborraplay-dl backup -o ~/Backup
  sborraplay-dl restore ~/Backup/SborraPlay-2026-11-08-2340.sborraplay.json
""")
    p.add_argument("--version", action="version", version=f"sborraplay-dl {__version__}")
    sub = p.add_subparsers(dest="command", required=True)

    pl = sub.add_parser("playlist", help="scarica una playlist Spotify (o un file CSV/JSON/TXT)")
    pl.add_argument("reference", help="URL/URI/ID Spotify oppure percorso di un file esportato")
    pl.add_argument("-o", "--out", help="cartella di destinazione")
    pl.add_argument("-f", "--format", default="mp3", help="mp3 (default), m4a o flac")
    pl.add_argument("-q", "--quality", default="320", help="bitrate per mp3 (default 320)")
    pl.add_argument("--host", help="indirizzo del telefono, es. 192.168.1.42:8080")
    pl.add_argument("--no-push", action="store_true", help="non inviare al telefono")
    pl.add_argument("--workers", type=int, default=3, help="download in parallelo (default 3)")
    pl.add_argument("--limit", type=int, help="scarica solo i primi N brani")
    pl.add_argument("--candidates", type=int, default=5, help="risultati YouTube valutati per ricerca")
    pl.add_argument("--min-score", type=float, default=35.0, help="soglia di affidabilità del match")
    pl.add_argument("--overwrite", action="store_true", help="riscarica anche ciò che esiste già")
    pl.add_argument("--no-m3u", dest="m3u", action="store_false", help="non creare il file .m3u")
    pl.add_argument("--no-archive", dest="archive", action="store_false",
                    help="non tenere traccia dei video già scaricati")
    pl.add_argument("--dry-run", action="store_true", help="mostra cosa farebbe e basta")
    pl.add_argument("--cookies-from-browser", help="usa i cookie del browser (chrome, firefox, safari…)")
    pl.set_defaults(func=cmd_playlist, m3u=True, archive=True)

    pu = sub.add_parser("push", help="manda file o cartelle già scaricate al telefono")
    pu.add_argument("paths", nargs="+", help="file o cartelle")
    pu.add_argument("--host", help="indirizzo del telefono")
    pu.add_argument("--playlist", help="crea anche una playlist con questi brani")
    pu.add_argument("--overwrite", action="store_true", help="ricarica anche i file già presenti")
    pu.set_defaults(func=cmd_push)

    di = sub.add_parser("discover", help="cerca l'iPhone sulla rete locale")
    di.add_argument("--timeout", type=float, default=4.0)
    di.set_defaults(func=cmd_discover)

    li = sub.add_parser("library", help="elenca ciò che c'è già sul telefono")
    li.add_argument("--host")
    li.set_defaults(func=cmd_library)

    bk = sub.add_parser("backup", help="scarica da telefono playlist, copertine e impostazioni")
    bk.add_argument("-o", "--out", help="file o cartella di destinazione")
    bk.add_argument("--host")
    bk.set_defaults(func=cmd_backup)

    rs = sub.add_parser("restore", help="rimanda un backup al telefono")
    rs.add_argument("file", help="file .sborraplay.json")
    rs.add_argument("--host")
    rs.add_argument("--replace", action="store_true",
                    help="sostituisce le playlist attuali invece di unirle")
    rs.set_defaults(func=cmd_restore)

    gr = sub.add_parser("grab", help="scarica un singolo link YouTube o SoundCloud")
    gr.add_argument("url")
    gr.add_argument("-o", "--out", help="cartella di destinazione")
    gr.add_argument("-f", "--format", default="mp3", help="mp3 (default), m4a o flac")
    gr.add_argument("-q", "--quality", default="320")
    gr.add_argument("--host", help="indirizzo del telefono")
    gr.add_argument("--no-push", action="store_true", help="non inviare al telefono")
    gr.set_defaults(func=cmd_grab)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except KeyboardInterrupt:
        print()
        warn("Interrotto.")
        return 130


if __name__ == "__main__":
    sys.exit(main())
