"""Lettura di una playlist Spotify.

Quattro strade, provate in ordine:
  1. API ufficiale, se in ambiente ci sono SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET
     (è l'unica senza limiti: registrare l'app su developer.spotify.com richiede 2 minuti)
  2. pagina embed pubblica (nessuna credenziale, ma si ferma a ~100 brani)
  3. token anonimo del web player + API (spesso bloccato da Spotify, tentativo finale)
  4. file locale CSV/JSON/TXT (per esempio l'export di Exportify)
"""
from __future__ import annotations

import base64
import csv
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable

from .util import info, warn, err

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")


@dataclass
class SpotifyTrack:
    title: str
    artist: str
    album: str = ""
    duration: float = 0.0          # secondi
    track_number: int = 0
    year: int = 0
    isrc: str = ""
    cover_url: str = ""
    spotify_id: str = ""

    @property
    def label(self) -> str:
        return f"{self.artist} - {self.title}" if self.artist else self.title

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class SpotifyPlaylist:
    name: str
    tracks: list[SpotifyTrack] = field(default_factory=list)
    source: str = ""
    truncated: bool = False


# ------------------------------------------------------------------ http

def _get(url: str, headers: dict | None = None, timeout: int = 25) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Accept-Language": "it,en;q=0.8",
                                               **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _get_json(url: str, headers: dict | None = None, timeout: int = 25):
    return json.loads(_get(url, headers, timeout).decode("utf-8", "replace"))


# ------------------------------------------------------------------ id

PLAYLIST_RE = re.compile(r"(?:playlist[/:])([A-Za-z0-9]{16,})")
ALBUM_RE = re.compile(r"(?:album[/:])([A-Za-z0-9]{16,})")


def parse_reference(ref: str) -> tuple[str, str]:
    """Restituisce (tipo, id) a partire da URL, URI o id nudo."""
    ref = ref.strip()
    m = PLAYLIST_RE.search(ref)
    if m:
        return "playlist", m.group(1)
    m = ALBUM_RE.search(ref)
    if m:
        return "album", m.group(1)
    if re.fullmatch(r"[A-Za-z0-9]{16,}", ref):
        return "playlist", ref
    raise ValueError(f"Non riesco a capire che playlist sia: {ref!r}")


# ------------------------------------------------------------------ 1. API ufficiale

def _client_credentials_token() -> str | None:
    cid = os.environ.get("SPOTIFY_CLIENT_ID")
    secret = os.environ.get("SPOTIFY_CLIENT_SECRET")
    if not cid or not secret:
        return None
    basic = base64.b64encode(f"{cid}:{secret}".encode()).decode()
    data = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=data,
        headers={"Authorization": f"Basic {basic}",
                 "Content-Type": "application/x-www-form-urlencoded",
                 "User-Agent": UA},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read())["access_token"]
    except Exception as exc:
        warn(f"Credenziali Spotify presenti ma rifiutate: {exc}")
        return None


def _tracks_from_api(kind: str, sid: str, token: str) -> SpotifyPlaylist:
    headers = {"Authorization": f"Bearer {token}"}
    if kind == "album":
        meta = _get_json(f"https://api.spotify.com/v1/albums/{sid}", headers)
        name = meta.get("name", "Album")
        cover = (meta.get("images") or [{}])[0].get("url", "")
        year = int((meta.get("release_date") or "0")[:4] or 0)
        out = SpotifyPlaylist(name=name, source="api")
        url = f"https://api.spotify.com/v1/albums/{sid}/tracks?limit=50"
        while url:
            page = _get_json(url, headers)
            for it in page.get("items", []):
                out.tracks.append(SpotifyTrack(
                    title=it.get("name", ""),
                    artist=", ".join(a["name"] for a in it.get("artists", [])),
                    album=name,
                    duration=(it.get("duration_ms") or 0) / 1000.0,
                    track_number=it.get("track_number") or 0,
                    year=year,
                    cover_url=cover,
                    spotify_id=it.get("id", ""),
                ))
            url = page.get("next")
        return out

    meta = _get_json(f"https://api.spotify.com/v1/playlists/{sid}"
                     "?fields=name,tracks.total", headers)
    out = SpotifyPlaylist(name=meta.get("name", "Playlist"), source="api")
    url = (f"https://api.spotify.com/v1/playlists/{sid}/tracks?limit=100"
           "&fields=next,items(track(name,duration_ms,track_number,id,external_ids,"
           "artists(name),album(name,release_date,images)))")
    while url:
        page = _get_json(url, headers)
        for item in page.get("items", []):
            t = item.get("track") or {}
            if not t.get("name"):
                continue
            album = t.get("album") or {}
            out.tracks.append(SpotifyTrack(
                title=t.get("name", ""),
                artist=", ".join(a["name"] for a in t.get("artists", [])),
                album=album.get("name", ""),
                duration=(t.get("duration_ms") or 0) / 1000.0,
                track_number=t.get("track_number") or 0,
                year=int((album.get("release_date") or "0")[:4] or 0),
                isrc=(t.get("external_ids") or {}).get("isrc", ""),
                cover_url=(album.get("images") or [{}])[0].get("url", ""),
                spotify_id=t.get("id", ""),
            ))
        url = page.get("next")
    return out


# ------------------------------------------------------------------ 2. embed

def _deep_find(node, key: str):
    """Cerca ricorsivamente la prima occorrenza di una chiave nel JSON."""
    if isinstance(node, dict):
        if key in node:
            return node[key]
        for v in node.values():
            found = _deep_find(v, key)
            if found is not None:
                return found
    elif isinstance(node, list):
        for v in node:
            found = _deep_find(v, key)
            if found is not None:
                return found
    return None


def _tracks_from_embed(kind: str, sid: str) -> SpotifyPlaylist:
    html = _get(f"https://open.spotify.com/embed/{kind}/{sid}").decode("utf-8", "replace")
    m = re.search(r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S)
    if not m:
        m = re.search(r'<script[^>]+type="application/json"[^>]*>(\{.*?\})</script>', html, re.S)
    if not m:
        raise RuntimeError("La pagina embed non contiene i dati attesi")
    data = json.loads(m.group(1))

    entity = _deep_find(data, "entity") or data
    name = (entity.get("name") if isinstance(entity, dict) else None) or "Playlist Spotify"
    raw_tracks = _deep_find(data, "trackList") or []
    if not raw_tracks:
        raise RuntimeError("Nessun brano trovato nella pagina embed")

    cover = ""
    visual = _deep_find(data, "coverArt") or _deep_find(data, "visualIdentity")
    if isinstance(visual, dict):
        sources = visual.get("sources") or visual.get("image") or []
        if isinstance(sources, list) and sources:
            cover = sources[-1].get("url", "") if isinstance(sources[-1], dict) else ""

    out = SpotifyPlaylist(name=name, source="embed")
    for i, t in enumerate(raw_tracks, start=1):
        if not isinstance(t, dict):
            continue
        title = t.get("title") or t.get("name") or ""
        if not title:
            continue
        out.tracks.append(SpotifyTrack(
            title=title,
            artist=t.get("subtitle") or t.get("artist") or "",
            album="",
            duration=(t.get("duration") or 0) / 1000.0,
            track_number=i,
            cover_url=cover,
            spotify_id=(t.get("uri") or "").split(":")[-1],
        ))
    out.truncated = len(out.tracks) >= 100
    return out


# ------------------------------------------------------------------ 3. token anonimo

def _anonymous_token() -> str | None:
    try:
        data = _get_json(
            "https://open.spotify.com/get_access_token?reason=transport&productType=web_player",
            {"Referer": "https://open.spotify.com/", "App-Platform": "WebPlayer"},
        )
        return data.get("accessToken")
    except Exception:
        return None


# ------------------------------------------------------------------ 4. file locale

def _tracks_from_file(path: Path) -> SpotifyPlaylist:
    name = path.stem
    out = SpotifyPlaylist(name=name, source="file")
    text = path.read_text(encoding="utf-8", errors="replace")

    if path.suffix.lower() == ".json":
        data = json.loads(text)
        items = data if isinstance(data, list) else (data.get("tracks") or [])
        for i, it in enumerate(items, start=1):
            if isinstance(it, str):
                artist, _, title = it.partition(" - ")
                out.tracks.append(SpotifyTrack(title=title or it, artist=artist if title else "",
                                               track_number=i))
            elif isinstance(it, dict):
                out.tracks.append(SpotifyTrack(
                    title=it.get("title") or it.get("name") or it.get("Track Name", ""),
                    artist=it.get("artist") or it.get("Artist Name(s)", ""),
                    album=it.get("album") or it.get("Album Name", ""),
                    duration=float(it.get("duration") or 0) or float(it.get("Duration (ms)", 0) or 0) / 1000.0,
                    track_number=i,
                ))
        return out

    if path.suffix.lower() in {".csv", ".tsv"}:
        delim = "\t" if path.suffix.lower() == ".tsv" else ","
        reader = csv.DictReader(text.splitlines(), delimiter=delim)
        for i, row in enumerate(reader, start=1):
            low = { (k or "").strip().lower(): (v or "").strip() for k, v in row.items() }
            title = low.get("track name") or low.get("title") or low.get("name") or low.get("track")
            artist = low.get("artist name(s)") or low.get("artist name") or low.get("artist") or low.get("artists")
            if not title:
                continue
            ms = low.get("duration (ms)") or low.get("duration_ms") or "0"
            try:
                duration = float(ms) / 1000.0
            except ValueError:
                duration = 0.0
            out.tracks.append(SpotifyTrack(
                title=title,
                artist=artist or "",
                album=low.get("album name") or low.get("album") or "",
                duration=duration,
                track_number=i,
                isrc=low.get("isrc", ""),
            ))
        return out

    # testo semplice: una riga per brano, "Artista - Titolo"
    for i, line in enumerate([l.strip() for l in text.splitlines() if l.strip()], start=1):
        if line.startswith("#"):
            continue
        artist, sep, title = line.partition(" - ")
        out.tracks.append(SpotifyTrack(title=(title if sep else line).strip(),
                                       artist=(artist if sep else "").strip(),
                                       track_number=i))
    return out


# ------------------------------------------------------------------ ingresso unico

def load_playlist(reference: str) -> SpotifyPlaylist:
    """Accetta un URL/URI/ID Spotify oppure il percorso di un file CSV/JSON/TXT."""
    path = Path(reference).expanduser()
    if path.exists() and path.is_file():
        info(f"Leggo la playlist dal file {path.name}")
        return _tracks_from_file(path)

    kind, sid = parse_reference(reference)

    token = _client_credentials_token()
    if token:
        try:
            pl = _tracks_from_api(kind, sid, token)
            info(f"Playlist letta dalle API ufficiali: {len(pl.tracks)} brani")
            return pl
        except Exception as exc:
            warn(f"API ufficiali fallite ({exc}), provo la pagina pubblica")

    try:
        pl = _tracks_from_embed(kind, sid)
        info(f"Playlist letta dalla pagina pubblica: {len(pl.tracks)} brani")
        if pl.truncated:
            warn("La pagina pubblica si ferma a ~100 brani. Per playlist più lunghe usa "
                 "un export CSV (Exportify) oppure imposta SPOTIFY_CLIENT_ID/SECRET.")
        return pl
    except Exception as exc:
        warn(f"Lettura della pagina pubblica fallita: {exc}")

    anon = _anonymous_token()
    if anon:
        try:
            pl = _tracks_from_api(kind, sid, anon)
            info(f"Playlist letta con token anonimo: {len(pl.tracks)} brani")
            return pl
        except Exception as exc:
            warn(f"Anche il token anonimo non ha funzionato: {exc}")

    raise RuntimeError(
        "Non sono riuscito a leggere la playlist.\n"
        "  • controlla che sia pubblica (o condivisa con link)\n"
        "  • oppure esportala in CSV con exportify.net e passa il file a dovvoplay-dl\n"
        "  • oppure imposta SPOTIFY_CLIENT_ID e SPOTIFY_CLIENT_SECRET"
    )
