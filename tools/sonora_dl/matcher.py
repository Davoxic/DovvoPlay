"""Trova su YouTube il video che corrisponde a un brano Spotify."""
from __future__ import annotations

import math
from dataclasses import dataclass
from difflib import SequenceMatcher

from .spotify import SpotifyTrack
from .util import normalize

# parole che quasi sempre indicano una versione diversa da quella cercata
BAD_WORDS = {
    "live": 22, "concert": 18, "cover": 30, "karaoke": 35, "instrumental": 28,
    "remix": 22, "sped up": 25, "speed up": 25, "slowed": 25, "reverb": 18,
    "nightcore": 30, "8d": 25, "reaction": 40, "tutorial": 35, "lesson": 30,
    "mashup": 22, "medley": 18, "full album": 30, "mix": 8, "loop": 20,
    "ringtone": 30, "bass boosted": 25, "acapella": 25, "a cappella": 25,
}
GOOD_WORDS = {"official audio": 8, "official video": 4, "official music video": 4,
              "audio": 3, "hq": 1, "lyrics": 1, "lyric video": 1}


@dataclass
class Candidate:
    video_id: str
    title: str
    channel: str
    duration: float
    views: int = 0
    url: str = ""

    @property
    def watch_url(self) -> str:
        return self.url or f"https://www.youtube.com/watch?v={self.video_id}"


def score(track: SpotifyTrack, cand: Candidate) -> float:
    """Punteggio (più alto = meglio): quanto è probabile che il video sia proprio quel brano."""
    wanted_title = normalize(track.title)
    wanted_title_full = normalize(track.title, drop_parens=False)
    wanted_artist = normalize(track.artist)
    cand_title = normalize(cand.title, drop_parens=False)
    cand_channel = normalize(cand.channel)

    total = 0.0

    # 1. durata: il segnale più affidabile
    if track.duration > 0 and cand.duration > 0:
        delta = abs(cand.duration - track.duration)
        if delta <= 2:
            total += 42
        elif delta <= 5:
            total += 34
        elif delta <= 10:
            total += 20
        elif delta <= 20:
            total += 5
        elif delta <= 45:
            total -= 20
        else:
            total -= 55
    elif cand.duration > 0 and (cand.duration < 45 or cand.duration > 1800):
        total -= 30   # spezzoni o video lunghissimi

    # 2. somiglianza del titolo
    ratio = SequenceMatcher(None, wanted_title, cand_title).ratio()
    total += 30 * ratio
    if wanted_title and wanted_title in cand_title:
        total += 10

    # 3. artista
    first_artist = normalize(track.artist.split(",")[0]) if track.artist else ""
    if first_artist:
        if first_artist in cand_channel:
            total += 18
        elif first_artist in cand_title:
            total += 12
        else:
            # nessuna traccia dell'artista: sospetto
            total -= 12

    # 4. canali ufficiali generati da YouTube Music
    if cand_channel.endswith("topic"):
        total += 22
    if "vevo" in cand_channel:
        total += 10
    if "official" in cand_channel:
        total += 4

    # 5. parole buone e cattive (solo se non erano già nel titolo cercato)
    for word, bonus in GOOD_WORDS.items():
        if word in cand_title:
            total += bonus
    for word, penalty in BAD_WORDS.items():
        if word in cand_title and word not in wanted_title_full:
            total -= penalty

    # 6. popolarità, con peso minimo
    if cand.views > 0:
        total += min(math.log10(cand.views + 1) * 1.6, 8)

    return total


def build_queries(track: SpotifyTrack) -> list[str]:
    title = track.title.strip()
    artist = track.artist.split(",")[0].strip() if track.artist else ""
    queries = []
    if artist:
        queries.append(f"{artist} - {title} audio")
        queries.append(f"{artist} {title}")
        if track.album:
            queries.append(f"{artist} {title} {track.album}")
    else:
        queries.append(title)
    if track.isrc:
        queries.insert(0, track.isrc)
    # niente doppioni, massimo 3 ricerche per brano
    seen, out = set(), []
    for q in queries:
        k = q.lower()
        if k not in seen:
            seen.add(k)
            out.append(q)
    return out[:3]


def _entry_to_candidate(e: dict) -> Candidate | None:
    vid = e.get("id") or ""
    if not vid or e.get("_type") == "playlist":
        return None
    return Candidate(
        video_id=vid,
        title=e.get("title") or "",
        channel=e.get("channel") or e.get("uploader") or "",
        duration=float(e.get("duration") or 0),
        views=int(e.get("view_count") or 0),
        url=e.get("url") or "",
    )


def search_candidates(query: str, limit: int, ydl_opts: dict | None = None) -> list[Candidate]:
    import yt_dlp  # import tardivo: così --help funziona anche senza dipendenze

    opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extract_flat": "in_playlist",
        "noplaylist": True,
        "socket_timeout": 20,
    }
    if ydl_opts:
        opts.update(ydl_opts)
    with yt_dlp.YoutubeDL(opts) as ydl:
        data = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)
    entries = (data or {}).get("entries") or []
    out = []
    for e in entries:
        c = _entry_to_candidate(e or {})
        if c:
            out.append(c)
    return out


def find_best(track: SpotifyTrack, per_query: int = 5,
              min_score: float = 35.0, ydl_opts: dict | None = None
              ) -> tuple[Candidate | None, float, list[tuple[Candidate, float]]]:
    """Restituisce (migliore, punteggio, tutti i candidati valutati)."""
    seen: dict[str, Candidate] = {}
    for query in build_queries(track):
        try:
            for cand in search_candidates(query, per_query, ydl_opts):
                seen.setdefault(cand.video_id, cand)
        except Exception:
            continue
        # se abbiamo già un ottimo risultato non serve cercare altro
        if seen:
            best_now = max((score(track, c) for c in seen.values()), default=0)
            if best_now >= 75:
                break

    ranked = sorted(((c, score(track, c)) for c in seen.values()),
                    key=lambda p: p[1], reverse=True)
    if not ranked:
        return None, 0.0, []
    best, best_score = ranked[0]
    if best_score < min_score:
        return None, best_score, ranked
    return best, best_score, ranked
