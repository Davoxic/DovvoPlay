#!/usr/bin/env python3
"""Verifica la regola di scelta nuova: quanti brani restano riproducibili e,
soprattutto, se i flussi scelti si aprono davvero con AVPlayer."""
import json, re, sys, urllib.error, urllib.parse, urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

def req(url, headers=None, timeout=20):
    r = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:400]
    except Exception as e:
        return 0, str(e).encode()

code, body = req("https://soundcloud.com/discover")
cid = None
for s in reversed(re.findall(r'https://a-v2\.sndcdn\.com/assets/[^"\']+\.js',
                             body.decode("utf-8","replace"))):
    c, js = req(s)
    if c == 200:
        m = re.search(r'client_id\s*:\s*"([a-zA-Z0-9]{32})"', js.decode("utf-8","replace"))
        if m: cid = m.group(1); break
print("client_id:", (cid or "NESSUNO")[:8])
if not cid: sys.exit(0)

def pick(transcodings):
    """La stessa regola che ora usa l'app."""
    opts = []
    for t in transcodings:
        f = t.get("format") or {}
        proto = (f.get("protocol") or "").lower()
        mime = (f.get("mime_type") or "").lower()
        preset = (t.get("preset") or "").lower()
        if "encrypted" in proto: continue
        if "opus" in preset or "opus" in mime or "ogg" in mime: continue
        playlist = "mpegurl" in mime
        is_mp3 = "mp3" in preset or ("mpeg" in mime and not playlist)
        is_aac = "aac" in preset or "mp4" in mime
        prog = proto == "progressive"
        if prog and is_mp3: r = 0
        elif prog and is_aac: r = 1
        elif prog: r = 2
        elif is_mp3: r = 3
        elif is_aac: r = 4
        elif playlist: r = 5
        else: continue
        opts.append((r, prog, t["url"], proto, preset))
    opts.sort(key=lambda o: o[0])
    return opts

totale = riproducibili = protetti = anteprime = 0
scelto_hls = scelto_prog = None
for query in ["rock", "techno", "rap italiano", "break", "lofi"]:
    q = urllib.parse.urlencode({"q": query, "client_id": cid, "limit": 20})
    c, b = req(f"https://api-v2.soundcloud.com/search/tracks?{q}")
    if c != 200: continue
    for item in json.loads(b).get("collection", []):
        totale += 1
        if item.get("policy") == "SNIP": anteprime += 1; continue
        opts = pick((item.get("media") or {}).get("transcodings") or [])
        if not opts: protetti += 1; continue
        riproducibili += 1
        r, prog, url, proto, preset = opts[0]
        params = {"client_id": cid}
        if item.get("track_authorization"): params["track_authorization"] = item["track_authorization"]
        if (prog and scelto_prog is None) or (not prog and scelto_hls is None):
            c2, b2 = req(url + "?" + urllib.parse.urlencode(params))
            if c2 == 200:
                final = json.loads(b2).get("url")
                if prog and scelto_prog is None:
                    scelto_prog = final
                    print(f"progressive scelto: {item.get('title')!r} preset={preset}")
                elif not prog and scelto_hls is None:
                    scelto_hls = final
                    print(f"hls in chiaro scelto: {item.get('title')!r} preset={preset} proto={proto}")

print(f"\nsu {totale} brani: {riproducibili} riproducibili, "
      f"{protetti} protetti FairPlay, {anteprime} anteprime 30s")
print(f"copertura utile: {100*riproducibili/max(totale-anteprime,1):.0f}% dei brani non-anteprima")

open("/tmp/sc_hls.txt","w").write(scelto_hls or "")
open("/tmp/sc_prog.txt","w").write(scelto_prog or "")
