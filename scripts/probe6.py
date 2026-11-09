#!/usr/bin/env python3
"""Quanti risultati musicali di YouTube sono davvero incorporabili?
Usa l'endpoint oEmbed ufficiale: risponde 401/403 per i video che il
titolare ha escluso dall'incorporamento."""
import json, urllib.error, urllib.parse, urllib.request

def get(url, timeout=15):
    r = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:
        return 0, str(e).encode()

def embeddable(video_id):
    u = ("https://www.youtube.com/oembed?format=json&url="
         + urllib.parse.quote(f"https://www.youtube.com/watch?v={video_id}", safe=""))
    code, _ = get(u)
    return code, code == 200

INSTANCES = ["https://pipedapi.ducks.party", "https://api.piped.private.coffee",
             "https://pipedapi.kavin.rocks"]

def cerca(q, filtro="music_songs"):
    for base in INSTANCES:
        code, body = get(base + "/search?" + urllib.parse.urlencode({"q": q, "filter": filtro}), 12)
        if code == 200:
            try:
                items = json.loads(body).get("items") or []
                if items: return items, base
            except Exception: pass
    return [], None

totale = ok = 0
for q in ["deadmau5 strobe", "daft punk instant crush", "sfera ebbasta", "lofi hip hop", "adele hello"]:
    items, base = cerca(q)
    if not items:
        print(f"\n{q!r}: nessun risultato"); continue
    print(f"\n{q!r} — {len(items)} risultati da {base}")
    for it in items[:6]:
        vid = (it.get("url") or "").split("v=")[-1]
        if not vid: continue
        code, can = embeddable(vid)
        totale += 1
        if can: ok += 1
        canale = (it.get("uploaderName") or "")
        topic = " [TOPIC]" if canale.lower().endswith("- topic") else ""
        print(f"   {'OK ' if can else f'NO({code})'} {canale[:26]:26}{topic:8} {(it.get('title') or '')[:40]}")

print(f"\n==> incorporabili: {ok} su {totale}")

# e con la ricerca video normale invece che music_songs?
print("\n--- stessa prova con filter=videos ---")
t2 = ok2 = 0
for q in ["deadmau5 strobe topic", "deadmau5 strobe audio"]:
    items, base = cerca(q, "videos")
    print(f"\n{q!r} — {len(items)} risultati")
    for it in items[:6]:
        vid = (it.get("url") or "").split("v=")[-1]
        if not vid: continue
        code, can = embeddable(vid)
        t2 += 1
        if can: ok2 += 1
        print(f"   {'OK ' if can else f'NO({code})'} {(it.get('uploaderName') or '')[:26]:26} {(it.get('title') or '')[:40]}")
print(f"\n==> incorporabili: {ok2} su {t2}")
