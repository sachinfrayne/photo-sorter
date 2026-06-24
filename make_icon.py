#!/usr/bin/env python3
"""Generates icon.png for PhotoSorter. Run once, then run build_mac.sh."""
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Run first:  pip3 install pillow")
    raise SystemExit(1)

import math

SIZE = 1024

def gradient(top, bottom):
    img = Image.new('RGB', (SIZE, SIZE))
    d = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        colour = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (SIZE, y)], fill=colour)
    return img

def rounded_mask(radius):
    m = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=radius, fill=255)
    return m

def heart_pts(cx, cy, r):
    pts = []
    for deg in range(361):
        a = math.radians(deg)
        x = r * 16 * math.sin(a)**3 / 16
        y = -r * (13*math.cos(a) - 5*math.cos(2*a) - 2*math.cos(3*a) - math.cos(4*a)) / 16
        pts.append((cx + x, cy + y))
    return pts

# ── Background ────────────────────────────────────────────────────────────────
bg   = gradient((255, 107, 157), (167, 86, 210))   # coral-pink → soft purple
mask = rounded_mask(SIZE // 5)
img  = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
img.paste(bg.convert('RGBA'), mask=mask)
d    = ImageDraw.Draw(img, 'RGBA')

# ── Layout ────────────────────────────────────────────────────────────────────
P   = SIZE // 7          # side padding  (~146 px)
CX  = SIZE // 2          # horizontal centre
BW  = SIZE - 2 * P       # camera body width
BH  = int(BW * 0.68)     # camera body height
BY  = (SIZE - BH) // 2 + SIZE // 28   # body top, slightly below centre
BR  = BH // 8            # body corner radius

# ── Viewfinder bump ───────────────────────────────────────────────────────────
VW  = BW // 3
VH  = BH // 7
VX  = CX - VW // 2
d.rounded_rectangle(
    [VX, BY - VH + BR, VX + VW, BY + BR * 2],
    radius=VH // 2, fill='white',
)

# ── Camera body ───────────────────────────────────────────────────────────────
d.rounded_rectangle([P, BY, P + BW, BY + BH], radius=BR, fill='white')

# ── Lens ──────────────────────────────────────────────────────────────────────
LCX = CX
LCY = BY + int(BH * 0.52)
for r, col in [
    (int(BH * 0.300), (235, 210, 248)),   # pale halo
    (int(BH * 0.225), (190, 145, 225)),   # mid ring
    (int(BH * 0.145), ( 65,  25,  90)),   # dark pupil
]:
    d.ellipse([LCX-r, LCY-r, LCX+r, LCY+r], fill=col)

# Specular highlight
hs = int(BH * 0.055)
hx = LCX - int(BH * 0.095)
hy = LCY - int(BH * 0.095)
d.ellipse([hx, hy, hx + hs, hy + hs], fill=(255, 255, 255, 210))

# ── Heart (bottom-right of camera) ────────────────────────────────────────────
HR  = int(BH * 0.115)
HCX = P + BW - HR - BR
HCY = BY + BH - HR - int(BR * 0.6)
d.polygon(heart_pts(HCX, HCY, HR), fill=(255, 55, 115))

img.save('icon.png')
print('Saved icon.png  (1024×1024)')
