#!/usr/bin/env python3
"""Genera l'icona dell'app (1024x1024) dentro Assets.xcassets."""
import math, os
from PIL import Image, ImageDraw

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "SborraPlay", "Resources",
                   "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

img = Image.new("RGB", (S, S), (12, 10, 22))
d = ImageDraw.Draw(img)

# gradiente diagonale
top = (28, 20, 58)
bot = (120, 40, 140)
for y in range(S):
    t = y / (S - 1)
    c = tuple(int(top[i] + (bot[i] - top[i]) * (t ** 1.25)) for i in range(3))
    d.line([(0, y), (S, y)], fill=c)

cx = cy = S / 2

# disco
disc_r = S * 0.295
d.ellipse([cx - disc_r, cy - disc_r, cx + disc_r, cy + disc_r], fill=(18, 14, 30))
for i in range(14):
    r = disc_r * (0.42 + i * 0.042)
    a = 34 - i
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(90 + a, 80 + a, 120 + a), width=3)

# etichetta centrale
lab = S * 0.115
d.ellipse([cx - lab, cy - lab, cx + lab, cy + lab], fill=(236, 92, 120))
hole = S * 0.018
d.ellipse([cx - hole, cy - hole, cx + hole, cy + hole], fill=(18, 14, 30))

# barre waveform attorno al disco
bars = 56
for i in range(bars):
    ang = (i / bars) * 2 * math.pi - math.pi / 2
    h = 0.030 + 0.062 * abs(math.sin(i * 1.7)) * (0.6 + 0.4 * abs(math.cos(i * 0.6)))
    r0 = disc_r + S * 0.040
    r1 = r0 + S * h
    x0, y0 = cx + math.cos(ang) * r0, cy + math.sin(ang) * r0
    x1, y1 = cx + math.cos(ang) * r1, cy + math.sin(ang) * r1
    d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255), width=10)

img = img.resize((S, S), Image.LANCZOS)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print("scritta", os.path.normpath(OUT))
