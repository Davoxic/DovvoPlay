#!/usr/bin/env python3
"""Esegue le stesse chiamate dell'app contro SoundCloud e Piped e stampa cosa
rispondono davvero. Gira su un runner GitHub, che ha rete vera."""
import json, re, sys, urllib.error, urllib.parse, urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

def req(url, headers=None, method="GET", timeout=20):
    r = urllib.request.Request(url, method=method,
                               headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:400]
    except Exception as e:
        return 0, str(e).encode()

def head_range(url):
    code, body = req(url, headers={"Range": "bytes=0-1"})
    return code, body[:120]

def section(t):
    print("\n" + "=" * 70)
    print(t)
    print("=" * 70)

# ---------------------------------------------------------------- SOUNDCLOUD
section("SOUNDCLOUD")
code, body = req("https://soundcloud.com/discover")
print(f"pagina discover: HTTP {code}, {len(body)} byte")
html = body.decode("utf-8", "replace")

scripts = re.findall(r'https://a-v2\.sndcdn\.com/assets/[^"\']+\.js', html)
print(f"script trovati: {len(scripts)}")
client_id = None
for s in reversed(scripts):
    c, js = req(s)
    if c != 200:
        continue
    m = re.search(r'client_id\s*:\s*"([a-zA-Z0-9]{32})"', js.decode("utf-8", "replace"))
    if m:
        client_id = m.group(1)
        print(f"client_id trovato in {s.rsplit('/',1)[-1]}: {client_id[:8]}…")
        break
if not client_id:
    print("!! NESSUN client_id TROVATO — la ricerca non puo' funzionare")
    sys.exit(0)

q = urllib.parse.urlencode({"q": "break", "client_id": client_id, "limit": 5})
code, body = req(f"https://api-v2.soundcloud.com/search/tracks?{q}")
print(f"ricerca: HTTP {code}")
if code != 200:
    print(body[:300]); sys.exit(0)
coll = json.loads(body).get("collection", [])
print(f"risultati: {len(coll)}")

for item in coll[:3]:
    tid = item.get("id")
    print(f"\n--- traccia {tid}: {item.get('title')!r}")
    print(f"    policy={item.get('policy')} snipped={item.get('snipped')} "
          f"streamable={item.get('streamable')}")
    print(f"    duration={item.get('duration')} full_duration={item.get('full_duration')}")
    auth = item.get("track_authorization")
    print(f"    track_authorization: {'SI (' + str(len(auth)) + ' car)' if auth else 'ASSENTE'}")
    media = (item.get("media") or {}).get("transcodings") or []
    print(f"    transcodings: {len(media)}")
    for t in media:
        f = t.get("format") or {}
        print(f"      preset={t.get('preset'):<16} protocol={f.get('protocol'):<12} mime={f.get('mime_type')}")

    prog = None
    for t in media:
        f = t.get("format") or {}
        preset = (t.get("preset") or "").lower()
        if f.get("protocol") == "progressive" and "opus" not in preset:
            prog = t; break
    if prog is None:
        for t in media:
            if "opus" not in (t.get("preset") or "").lower():
                prog = t; break
    if prog is None:
        print("    !! solo opus, non riproducibile su iOS")
        continue

    params = {"client_id": client_id}
    if auth:
        params["track_authorization"] = auth
    surl = prog["url"] + "?" + urllib.parse.urlencode(params)
    code, body = req(surl)
    print(f"    richiesta stream ({(prog.get('format') or {}).get('protocol')}): HTTP {code}")
    if code != 200:
        print(f"    corpo: {body[:200]}")
        # riprova senza token, per capire se e' quello a fare la differenza
        code2, _ = req(prog["url"] + "?" + urllib.parse.urlencode({"client_id": client_id}))
        print(f"    senza track_authorization: HTTP {code2}")
        continue
    cdn = json.loads(body).get("url")
    print(f"    url cdn: {cdn[:90] if cdn else None}…")
    if cdn:
        c, b = head_range(cdn)
        print(f"    >>> RANGE SUL FILE: HTTP {c}  {'OK, SI RIPRODUCE' if c in (200,206) else 'RIFIUTATO'}")

# ---------------------------------------------------------------- PIPED
section("PIPED")
INSTANCES = ["https://pipedapi.ducks.party", "https://api.piped.private.coffee",
             "https://pipedapi.kavin.rocks", "https://pipedapi.adminforge.de",
             "https://api.piped.yt", "https://pipedapi.drgns.space"]
video_id = None
for base in INSTANCES:
    url = base + "/search?" + urllib.parse.urlencode({"q": "daft punk", "filter": "music_songs"})
    code, body = req(url, timeout=12)
    n = 0
    if code == 200:
        try:
            items = json.loads(body).get("items") or []
            n = len(items)
            if n and video_id is None:
                first = items[0]
                video_id = (first.get("url") or "").split("v=")[-1]
                print(f"  primo risultato: {first.get('title')!r} id={video_id}")
        except Exception as e:
            print("  parse fallito:", e)
    print(f"{base:42} ricerca HTTP {code} items={n}")

if not video_id:
    print("!! nessuna istanza ha restituito risultati")
    sys.exit(0)

section(f"PIPED /streams/{video_id}")
for base in INSTANCES:
    code, body = req(f"{base}/streams/{video_id}", timeout=15)
    if code != 200:
        print(f"{base:42} HTTP {code}")
        continue
    try:
        data = json.loads(body)
    except Exception:
        print(f"{base:42} risposta illeggibile"); continue
    audio = data.get("audioStreams") or []
    m4a = [a for a in audio if "mp4" in (a.get("mimeType") or "")]
    print(f"{base:42} HTTP 200  audioStreams={len(audio)} di cui mp4={len(m4a)}")
    if not m4a:
        continue
    best = sorted(m4a, key=lambda a: a.get("bitrate") or 0)[-1]
    u = best.get("url") or ""
    print(f"    scelto {best.get('bitrate')} bps  host={urllib.parse.urlparse(u).netloc}")
    c, b = head_range(u)
    print(f"    >>> RANGE SUL FILE: HTTP {c}  {'OK, SI RIPRODUCE' if c in (200,206) else 'RIFIUTATO ' + str(b[:80])}")
