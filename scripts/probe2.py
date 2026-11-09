#!/usr/bin/env python3
"""Secondo giro: cosa c'e' dentro l'HLS di SoundCloud, esiste ancora il
progressive, e Invidious risponde? Scrive l'URL migliore in /tmp/sc_url.txt
cosi' il passo successivo lo prova con AVPlayer."""
import json, re, sys, urllib.error, urllib.parse, urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

def req(url, headers=None, timeout=20):
    r = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:500]
    except Exception as e:
        return 0, str(e).encode()

def sec(t): print("\n" + "="*70 + f"\n{t}\n" + "="*70)

# client id
code, body = req("https://soundcloud.com/discover")
html = body.decode("utf-8","replace")
client_id = None
for s in reversed(re.findall(r'https://a-v2\.sndcdn\.com/assets/[^"\']+\.js', html)):
    c, js = req(s)
    if c == 200:
        m = re.search(r'client_id\s*:\s*"([a-zA-Z0-9]{32})"', js.decode("utf-8","replace"))
        if m: client_id = m.group(1); break
print("client_id:", (client_id or "NESSUNO")[:8])
if not client_id: sys.exit(0)

sec("QUANTI BRANI HANNO ANCORA UNA TRANSCODIFICA IN CHIARO")
q = urllib.parse.urlencode({"q":"rock","client_id":client_id,"limit":20})
code, body = req(f"https://api-v2.soundcloud.com/search/tracks?{q}")
coll = json.loads(body).get("collection", []) if code==200 else []
stats = {"progressive":0, "hls_chiaro":0, "solo_cifrato":0, "snip":0, "totale":len(coll)}
best_hls, best_prog = None, None
for item in coll:
    media = (item.get("media") or {}).get("transcodings") or []
    protos = {(t.get("format") or {}).get("protocol") for t in media}
    if item.get("policy") == "SNIP": stats["snip"] += 1
    if "progressive" in protos:
        stats["progressive"] += 1
        if best_prog is None and item.get("policy") != "SNIP":
            best_prog = (item, [t for t in media if (t.get("format") or {}).get("protocol")=="progressive"][0])
    elif "hls" in protos:
        stats["hls_chiaro"] += 1
    else:
        stats["solo_cifrato"] += 1
        if best_hls is None:
            aac = [t for t in media if "aac" in (t.get("preset") or "")]
            if aac: best_hls = (item, aac[0])
print(json.dumps(stats, indent=2))

def stream_url(item, trans):
    params = {"client_id": client_id}
    if item.get("track_authorization"): params["track_authorization"] = item["track_authorization"]
    c, b = req(trans["url"] + "?" + urllib.parse.urlencode(params))
    if c != 200: return None
    return json.loads(b).get("url")

chosen = None
if best_hls:
    item, trans = best_hls
    sec(f"DENTRO L'HLS CIFRATO — {item.get('title')!r}")
    u = stream_url(item, trans)
    print("manifest:", (u or "")[:110])
    if u:
        c, b = req(u)
        text = b.decode("utf-8","replace")
        print(f"HTTP {c}, {len(text)} byte")
        for line in text.splitlines()[:14]:
            print("   ", line[:160])
        chosen = u
if best_prog:
    item, trans = best_prog
    sec(f"PROGRESSIVE NON-ANTEPRIMA — {item.get('title')!r} (durata {item.get('full_duration')} ms)")
    u = stream_url(item, trans)
    print("file:", (u or "")[:110])

sec("INVIDIOUS")
for base in ["https://inv.nadeko.net","https://invidious.nerdvpn.de","https://yewtu.be",
             "https://invidious.f5.si","https://invidious.privacyredirect.com"]:
    c, b = req(base + "/api/v1/search?" + urllib.parse.urlencode({"q":"daft punk","type":"video"}), timeout=12)
    n = 0
    vid = None
    if c == 200:
        try:
            items = json.loads(b); n = len(items)
            if n: vid = items[0].get("videoId")
        except Exception: pass
    print(f"{base:46} search HTTP {c} items={n}")
    if vid:
        c2, b2 = req(f"{base}/api/v1/videos/{vid}", timeout=15)
        na = 0
        if c2 == 200:
            try:
                af = json.loads(b2).get("adaptiveFormats") or []
                audio = [a for a in af if (a.get("type") or "").startswith("audio/")]
                na = len(audio)
                if audio:
                    u = sorted(audio, key=lambda a: int(a.get("bitrate") or 0))[-1]["url"]
                    c3, _ = req(u, headers={"Range":"bytes=0-1"}, timeout=12)
                    print(f"{'':46} videos HTTP {c2} audio={na} → RANGE {c3} "
                          f"{'OK' if c3 in (200,206) else 'RIFIUTATO'}")
                    continue
            except Exception as e: print("   parse:", e)
        print(f"{'':46} videos HTTP {c2} audio={na}")

with open("/tmp/sc_url.txt","w") as f:
    f.write(chosen or "")
print("\nurl salvato per il test AVPlayer:", bool(chosen))
