#!/usr/bin/env python3
"""Verifica deterministica: il manifest HLS scelto è in chiaro? i segmenti si
scaricano? il progressive è un mp3 vero?"""
import json, re, urllib.error, urllib.parse, urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

def req(url, headers=None, timeout=20):
    r = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:300]
    except Exception as e:
        return 0, str(e).encode()

for nome, path in [("HLS IN CHIARO", "/tmp/sc_hls.txt"), ("PROGRESSIVE", "/tmp/sc_prog.txt")]:
    try:
        url = open(path).read().strip()
    except Exception:
        url = ""
    print("\n" + "="*68 + f"\n{nome}\n" + "="*68)
    if not url:
        print("nessun url"); continue
    print(url[:100])

    if ".m3u8" in url or "playback.media-streaming" in url:
        code, body = req(url)
        text = body.decode("utf-8","replace")
        print(f"manifest HTTP {code}, {len(text)} byte")
        keys = [l for l in text.splitlines() if l.startswith("#EXT-X-KEY")]
        if keys:
            print("CIFRATO:", keys[0][:120])
            fairplay = any("streamingkeydelivery" in k or "SAMPLE-AES" in k for k in keys)
            print("FairPlay:", "SI — non riproducibile" if fairplay else "no, AES-128 semplice")
        else:
            print(">>> NESSUN EXT-X-KEY: manifest in chiaro, AVPlayer lo riproduce")
        seg = [l for l in text.splitlines() if l.startswith("http")]
        print(f"segmenti elencati: {len(seg)}")
        if seg:
            c, b = req(seg[0], headers={"Range":"bytes=0-1023"})
            print(f">>> PRIMO SEGMENTO: HTTP {c} ({len(b)} byte) "
                  f"{'OK' if c in (200,206) else 'RIFIUTATO'}")
    else:
        c, b = req(url, headers={"Range":"bytes=0-2047"})
        print(f">>> RANGE: HTTP {c}, {len(b)} byte")
        if b[:3] == b"ID3" or (len(b) > 1 and b[0] == 0xFF and (b[1] & 0xE0) == 0xE0):
            print(">>> È UN MP3 VERO (header ID3 o frame MPEG)")
        else:
            print("primi byte:", b[:16])
