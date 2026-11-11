"""Scarica l'audio con yt-dlp e scrive i tag."""
from __future__ import annotations

import glob
import os
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from .matcher import Candidate
from .spotify import SpotifyTrack
from .util import safe_filename

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

# iOS riproduce questi; opus/ogg/wma no, quindi non li offriamo
AUDIO_FORMATS = ("mp3", "m4a", "flac")


@dataclass
class DownloadResult:
    track: SpotifyTrack
    ok: bool
    path: Path | None = None
    reason: str = ""
    candidate: Candidate | None = None
    match_score: float = 0.0
    skipped: bool = False


def target_name(track: SpotifyTrack, ext: str) -> str:
    artist = track.artist.split(",")[0].strip() if track.artist else ""
    base = f"{artist} - {track.title}" if artist else track.title
    return safe_filename(base) + "." + ext


def _fetch_cover(url: str) -> bytes | None:
    if not url:
        return None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = resp.read()
        return data if len(data) > 500 else None
    except Exception:
        return None


def write_tags(path: Path, track: SpotifyTrack, cover: bytes | None) -> None:
    ext = path.suffix.lower()
    try:
        if ext == ".mp3":
            from mutagen.id3 import ID3, ID3NoHeaderError, TIT2, TPE1, TPE2, TALB, TRCK, TDRC, TSRC, APIC
            try:
                tags = ID3(path)
            except ID3NoHeaderError:
                tags = ID3()
            tags.delall("APIC")
            tags["TIT2"] = TIT2(encoding=3, text=track.title)
            if track.artist:
                tags["TPE1"] = TPE1(encoding=3, text=track.artist)
                tags["TPE2"] = TPE2(encoding=3, text=track.artist.split(",")[0].strip())
            if track.album:
                tags["TALB"] = TALB(encoding=3, text=track.album)
            if track.track_number:
                tags["TRCK"] = TRCK(encoding=3, text=str(track.track_number))
            if track.year:
                tags["TDRC"] = TDRC(encoding=3, text=str(track.year))
            if track.isrc:
                tags["TSRC"] = TSRC(encoding=3, text=track.isrc)
            if cover:
                mime = "image/png" if cover[:4] == b"\x89PNG" else "image/jpeg"
                tags["APIC"] = APIC(encoding=3, mime=mime, type=3, desc="Cover", data=cover)
            tags.save(path, v2_version=3)

        elif ext in (".m4a", ".mp4", ".m4b"):
            from mutagen.mp4 import MP4, MP4Cover
            mp4 = MP4(path)
            mp4["\xa9nam"] = [track.title]
            if track.artist:
                mp4["\xa9ART"] = [track.artist]
                mp4["aART"] = [track.artist.split(",")[0].strip()]
            if track.album:
                mp4["\xa9alb"] = [track.album]
            if track.track_number:
                mp4["trkn"] = [(track.track_number, 0)]
            if track.year:
                mp4["\xa9day"] = [str(track.year)]
            if cover:
                fmt = MP4Cover.FORMAT_PNG if cover[:4] == b"\x89PNG" else MP4Cover.FORMAT_JPEG
                mp4["covr"] = [MP4Cover(cover, imageformat=fmt)]
            mp4.save()

        elif ext == ".flac":
            from mutagen.flac import FLAC, Picture
            fl = FLAC(path)
            fl["title"] = track.title
            if track.artist:
                fl["artist"] = track.artist
                fl["albumartist"] = track.artist.split(",")[0].strip()
            if track.album:
                fl["album"] = track.album
            if track.track_number:
                fl["tracknumber"] = str(track.track_number)
            if track.year:
                fl["date"] = str(track.year)
            if cover:
                pic = Picture()
                pic.type = 3
                pic.mime = "image/png" if cover[:4] == b"\x89PNG" else "image/jpeg"
                pic.data = cover
                fl.clear_pictures()
                fl.add_picture(pic)
            fl.save()
    except ImportError:
        pass   # mutagen non installato: i file restano senza tag ma funzionano
    except Exception:
        pass


def download(track: SpotifyTrack, candidate: Candidate, outdir: Path,
             audio_format: str = "mp3", quality: str = "320",
             archive: Path | None = None, overwrite: bool = False,
             cookies_from_browser: str | None = None) -> Path:
    """Scarica il candidato e restituisce il percorso del file finale."""
    import yt_dlp

    outdir.mkdir(parents=True, exist_ok=True)
    final_name = target_name(track, audio_format)
    final_path = outdir / final_name
    if final_path.exists() and not overwrite:
        return final_path

    stem = final_path.with_suffix("")
    opts = {
        "format": "bestaudio/best",
        "outtmpl": str(stem) + ".%(ext)s",
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "ignoreerrors": False,
        "retries": 3,
        "fragment_retries": 3,
        "socket_timeout": 30,
        "overwrites": overwrite,
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": audio_format,
            "preferredquality": quality,
        }],
    }
    if archive:
        opts["download_archive"] = str(archive)
    if cookies_from_browser:
        opts["cookiesfrombrowser"] = (cookies_from_browser,)

    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([candidate.watch_url])

    if final_path.exists():
        return final_path
    # il postprocessore può aver scelto un'estensione diversa
    matches = sorted(glob.glob(glob.escape(str(stem)) + ".*"),
                     key=lambda p: os.path.getmtime(p), reverse=True)
    for m in matches:
        if not m.endswith((".part", ".ytdl", ".webp", ".jpg", ".png")):
            return Path(m)
    raise RuntimeError("file scaricato non trovato (controlla che ffmpeg sia installato)")


def fetch_and_tag(track: SpotifyTrack, candidate: Candidate, outdir: Path,
                  audio_format: str = "mp3", quality: str = "320",
                  archive: Path | None = None, overwrite: bool = False,
                  cookies_from_browser: str | None = None) -> Path:
    path = download(track, candidate, outdir, audio_format, quality,
                    archive, overwrite, cookies_from_browser)
    write_tags(path, track, _fetch_cover(track.cover_url))
    return path
