"""Heap outdoor backdrop, v2: dithered pixel-art style.
Run from the project root:  python3 tools/art/build_backdrops_v2.py [--install]

Style: small hue-shifted palette, 4x4 ordered (Bayer) dithering for every
gradient and texture, atmospheric depth (far layers sit close to the sky,
near layers are dark and contrasty), one strong light (the smog sun) with a
dithered halo, warm rim light along every ridge facing it.

Writes four 640x400 layers that tile horizontally, the same files and roles
as tools/art/build_backdrops.py: heap_sky (static), heap_city, heap_far,
heap_near. Without --install they go to art/backdrops/v2_preview/; with it
they replace art/backdrops/heap_*.png (back up first).
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
W, H = 640, 400
INSTALL = "--install" in sys.argv
OUT = os.path.join(ROOT, "art", "backdrops") if INSTALL else os.path.join(ROOT, "art", "backdrops", "v2_preview")
os.makedirs(OUT, exist_ok=True)

YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) + 0.5) / 16.0
BAYER = np.tile(BAYER4, (H // 4, W // 4))


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


SKY = [hexc(c) for c in ("#141226", "#1d1933", "#2a2142", "#3b2a4d", "#523453", "#6e3d55",
                         "#8c4652", "#ad554b", "#c96a48", "#de8650", "#eda65c", "#f5c272", "#fbdc98")]
SUN = [hexc(c) for c in ("#f7c470", "#fbdc98", "#fff0c4")]
CITY = [hexc(c) for c in ("#5c3550", "#743f55", "#8f4a55", "#a65752", "#c26c50")]
FAR = [hexc(c) for c in ("#2c1f37", "#3b2740", "#4d3046", "#653a4a", "#83474b", "#a8584b", "#d27a52")]
NEAR = [hexc(c) for c in ("#120d18", "#1a1220", "#241827", "#30202e", "#432a34", "#6a3a3a", "#a5543f", "#e08a52")]
AMBER = hexc("#ffc46a")
RED = hexc("#ff5a48")


def dither_index(t, n):
    """Continuous ramp position t (0..n-1) -> palette index with ordered dither."""
    return np.clip(np.floor(t + BAYER), 0, n - 1).astype(np.int32)


def paint(img, mask, ramp, t):
    idx = dither_index(t, len(ramp))
    pal = np.array(ramp, dtype=np.uint8)
    img[mask, :3] = pal[idx[mask]]
    img[mask, 3] = 255


def pnoise(freqs, seed, x=XX, y=None, amp_falloff=0.55):
    """Sum of sines periodic in x over W (so layers tile)."""
    rng = np.random.default_rng(seed)
    out = np.zeros_like(x)
    a = 1.0
    for f in freqs:
        ph = rng.uniform(0, math.tau)
        out += a * np.sin(x / W * math.tau * f + ph + (0 if y is None else y * rng.uniform(0.02, 0.06)))
        a *= amp_falloff
    return out


def ridge(freqs, seed, base, amp):
    x = np.arange(W, dtype=np.float32)
    rng = np.random.default_rng(seed)
    y = np.full(W, base, dtype=np.float32)
    a = amp
    for f in freqs:
        y += a * np.sin(x / W * math.tau * f + rng.uniform(0, math.tau))
        a *= 0.5
    return y


def blobs(seed, n, ymin, ymax, rmin, rmax):
    rng = np.random.default_rng(seed)
    return [(rng.uniform(0, W), rng.uniform(ymin, ymax), rng.uniform(rmin, rmax)) for _ in range(n)]


def wrapdist(cx):
    d = np.abs(XX - cx)
    return np.minimum(d, W - d)


SUN_C = (470.0, 196.0)
SUN_R = 26.0


def sky():
    img = np.zeros((H, W, 4), dtype=np.uint8)
    n = len(SKY)
    v = np.clip(YY / 330.0, 0, 1) ** 1.6 * (n - 2.2)
    d = np.hypot(XX - SUN_C[0], (YY - SUN_C[1]) * 1.25)
    v += np.clip(1 - d / 230.0, 0, 1) ** 2 * 4.2
    streak = pnoise([3, 7, 13], 4, y=YY) * 0.5 + np.sin(YY / 9.0) * 0.4
    bands = (np.abs(YY - 128) < 22) | (np.abs(YY - 172) < 10) | (np.abs(YY - 236) < 7)
    v -= np.where(bands, np.clip(streak, 0, 1) * 1.3, 0)
    paint(img, np.ones((H, W), bool), SKY, np.clip(v, 0, n - 1))
    rng0 = np.random.default_rng(5)
    for yc, half in ((128, 22), (172, 10), (236, 7)):
        y0 = int(yc + half)
        near_sun = np.clip(1 - np.abs(np.arange(W) - SUN_C[0]) / 220.0, 0, 1)
        wob = (np.sin(np.arange(W) / 23.0 + yc) * 1.5).astype(int)
        for x in range(W):
            if near_sun[x] > 0.25 and rng0.random() < near_sun[x] * 0.8:
                yy = y0 + wob[x]
                k = min(n - 1, int(v[yy, x] + 1 + near_sun[x] * 2))
                img[yy, x, :3] = SKY[k]
                continue
            if False:
                k = min(n - 1, int(v[y0, x] + 1 + near_sun[x] * 2))
                img[y0, x, :3] = SKY[k]
    rng = np.random.default_rng(11)
    for _ in range(70):
        x, y = rng.integers(0, W), rng.integers(2, 110)
        img[y, x, :3] = (200, 190, 220) if rng.random() < 0.7 else (255, 236, 200)
    for _ in range(6):
        x, y = rng.integers(4, W - 4), rng.integers(6, 90)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            img[y + dy, x + dx, :3] = (240, 232, 255)
    ds = np.hypot(XX - SUN_C[0], YY - SUN_C[1])
    disc = ds <= SUN_R
    t = np.clip((SUN_R - ds) / SUN_R * 3.0, 0, 2.0)
    paint(img, disc, SUN, t)
    for yy in (190, 203, 213):
        row = disc[yy] & (np.arange(W) % 2 == 0)
        img[yy, row, :3] = SUN[0]
    return img


def city():
    img = np.zeros((H, W, 4), dtype=np.uint8)
    rng = np.random.default_rng(21)
    top = np.full(W, H, dtype=np.int32)
    x = 0
    while x < W:
        w = int(rng.integers(10, 34))
        h = int(rng.integers(26, 92))
        if rng.random() < 0.25:
            h = int(rng.integers(90, 130))
        for xx in range(x, min(x + w, W)):
            top[xx] = min(top[xx], 300 - h)
        if rng.random() < 0.5:
            s = int(rng.integers(3, max(4, w // 2)))
            for xx in range(x + s, min(x + w - s, W)):
                top[xx] = min(top[xx], 300 - h - int(rng.integers(6, 14)))
        x += w - int(rng.integers(0, 5))
    sx = 330
    for xx in range(sx - 14, sx + 15):
        top[xx] = min(top[xx], 300 - 150)
    for xx in range(sx - 8, sx + 9):
        top[xx] = min(top[xx], 300 - 190)
    for xx in range(sx - 4, sx + 5):
        top[xx] = min(top[xx], 300 - 232)
    for xx in range(sx - 1, sx + 2):
        top[xx] = 300 - 268
    mask = YY >= top[None, :].astype(np.float32)
    mask &= YY < 330
    sunw = np.clip(1 - np.abs(XX - SUN_C[0]) / 300.0, 0, 1)
    t = 0.6 + np.clip((YY - 200) / 120.0, 0, 1) * 1.6 + sunw * 1.4
    paint(img, mask, CITY, t)
    lit_edge = mask & ~np.roll(mask, -1, axis=1) & (XX < SUN_C[0])
    lit_edge |= mask & ~np.roll(mask, 1, axis=1) & (XX > SUN_C[0])
    lit_top = mask & ~np.roll(mask, 1, axis=0)
    rim = (lit_edge | lit_top) & (sunw > 0.15)
    img[rim, :3] = CITY[-1]
    for _ in range(90):
        xx, yy = int(rng.integers(0, W)), int(rng.integers(200, 296))
        if mask[yy, xx] and mask[yy - 3, xx] and rng.random() < 0.55:
            img[yy, xx, :3] = AMBER
            if rng.random() < 0.3:
                img[yy, (xx + 1) % W, :3] = AMBER
    img[300 - 270, sx, :3] = RED
    img[300 - 271, sx, :3] = RED
    return img


def scrap_texture(seed, scale):
    """Clustered junk texture: blobby low-frequency field plus fine grit."""
    a = pnoise([5, 11, 23, 41], seed, y=YY) * 0.6
    b = np.sin(XX / scale + np.sin(YY / (scale * 0.7)) * 2.0) * np.cos(YY / (scale * 0.9) + XX / (scale * 3.1))
    return a + b * 0.5


def far():
    img = np.zeros((H, W, 4), dtype=np.uint8)
    top = ridge([2, 5, 9, 17], 31, 268, 18)
    mask = YY >= top[None, :]
    gx, gy, gr = 520.0, 262.0, 46.0
    dg = np.hypot(XX - gx, YY - gy)
    ang = np.arctan2(YY - gy, XX - gx)
    teeth = (np.sin(ang * 14) > 0.2) & (dg < gr + 6) & (dg >= gr)
    gear = ((dg < gr) | teeth) & ~((dg < 12)) & (YY < top[None, :] + 30)
    spokes = (dg > 12) & (dg < gr - 7) & ~((np.abs(np.sin(ang * 3)) < 0.18))
    gear &= ~spokes | (dg >= gr - 7)
    crane = np.zeros((H, W), bool)
    for i in range(0, 120):
        cx = 92 + i * 0.55
        cy = 270 - i * 1.15
        crane |= (np.abs(XX - cx) < 2.2) & (np.abs(YY - cy) < 1.2)
    for i in range(0, 150):
        cx = 150 - 20 + i
        cy = 132 + i * 0.08
        crane |= (np.abs(XX - cx) < 1) & (np.abs(YY - cy) < 1.6) & (i % 9 < 7)
    crane |= (np.abs(XX - 255) < 0.8) & (YY > 143) & (YY < 190)
    solid = mask | gear | crane
    sunw = np.clip(1 - wrapdist(SUN_C[0]) / 340.0, 0, 1)
    depth = np.clip((YY - top[None, :]) / 60.0, 0, 1)
    tex = scrap_texture(32, 7.0)
    t = 3.4 - depth * 2.2 + tex * 0.7 + sunw * 0.8
    t = np.where(gear | crane, 1.4 + sunw * 1.2, t)
    paint(img, solid, FAR, np.clip(t, 0, len(FAR) - 1))
    up_edge = solid & ~np.roll(solid, 1, axis=0)
    rim2 = (solid & ~np.roll(solid, 2, axis=0)) & ~up_edge
    img[up_edge, :3] = np.where((sunw[up_edge] > 0.35)[:, None], FAR[6], FAR[5])
    img[rim2 & (sunw > 0.45), :3] = FAR[5]
    side = solid & ~np.roll(solid, -1, axis=1) & (XX < SUN_C[0]) & (sunw > 0.2) & (gear | crane)
    img[side, :3] = FAR[5]
    rng = np.random.default_rng(33)
    for _ in range(26):
        x0 = int(rng.integers(0, W))
        y0 = int(top[x0])
        kind = rng.integers(0, 3)
        if kind == 0:
            for k in range(int(rng.integers(5, 12))):
                yy = y0 - k
                if 0 <= yy < H:
                    img[yy, x0 % W, :3] = FAR[1]
                    img[yy, x0 % W, 3] = 255
                    img[yy, (x0 + 1) % W, :3] = FAR[2]
                    img[yy, (x0 + 1) % W, 3] = 255
        elif kind == 1:
            r = int(rng.integers(3, 6))
            for yy in range(y0 - 2 * r, y0 + 1):
                for xx in range(x0 - r, x0 + r + 1):
                    if (xx - x0) ** 2 + (yy - (y0 - r)) ** 2 <= r * r and 0 <= yy < H:
                        img[yy, xx % W, :3] = FAR[1] if (xx + yy) % 2 else FAR[2]
                        img[yy, xx % W, 3] = 255
        else:
            w = int(rng.integers(6, 14))
            for yy in range(y0 - 4, y0 + 1):
                for xx in range(x0, x0 + w):
                    if 0 <= yy < H:
                        img[yy, xx % W, :3] = FAR[2]
                        img[yy, xx % W, 3] = 255
            for xx in range(x0, x0 + w):
                img[max(y0 - 5, 0), xx % W, :3] = FAR[5]
                img[max(y0 - 5, 0), xx % W, 3] = 255
    return img


def near():
    img = np.zeros((H, W, 4), dtype=np.uint8)
    top = ridge([2, 3, 7, 13, 29], 41, 318, 16)
    mask = YY >= top[None, :]
    junk = np.zeros((H, W), bool)
    def rect(x0, y0, x1, y1):
        return (XX >= x0) & (XX < x1) & (YY >= y0) & (YY < y1)
    cx = 170
    cy = int(top[cx])
    junk |= rect(cx - 26, cy - 14, cx + 26, cy + 2) | rect(cx - 14, cy - 24, cx + 12, cy - 13)
    for wx in (cx - 16, cx + 16):
        junk |= np.hypot(XX - wx, YY - (cy + 1)) < 6
    sx = 430
    sy = int(top[sx])
    junk |= rect(sx - 1, sy - 34, sx + 2, sy + 2)
    sign = (np.abs((XX - sx) * 0.96 + (YY - (sy - 40)) * 0.26) < 15) & (np.abs((YY - (sy - 40)) * 0.96 - (XX - sx) * 0.26) < 7)
    junk |= sign
    tx = 560
    ty = int(top[tx])
    for k, (dx, dy) in enumerate(((0, 0), (12, 0), (6, -9))):
        junk |= np.hypot(XX - (tx + dx), (YY - (ty - 5 + dy)) * 1.3) < 7
    ax = 300
    ay = int(top[ax])
    arch = (np.hypot(XX - ax, YY - ay) < 22) & (np.hypot(XX - ax, YY - ay) > 16) & (YY < ay)
    junk |= arch
    solid = mask | junk
    sunw = np.clip(1 - wrapdist(SUN_C[0]) / 360.0, 0, 1)
    depth = np.clip((YY - top[None, :]) / 40.0, 0, 1)
    tex = scrap_texture(42, 5.0)
    t = 3.6 - depth * 2.6 + tex * 0.9 + sunw * 0.5
    t = np.where(junk & ~mask, 1.6 + tex * 0.6 + sunw * 0.6, t)
    paint(img, solid, NEAR, np.clip(t, 0, len(NEAR) - 1))
    up_edge = solid & ~np.roll(solid, 1, axis=0)
    rim2 = (solid & ~np.roll(solid, 2, axis=0)) & ~up_edge
    img[up_edge, :3] = np.where((sunw[up_edge] > 0.3)[:, None], NEAR[7], NEAR[6])
    img[rim2 & (sunw > 0.4), :3] = NEAR[6]
    side = solid & ~np.roll(solid, -1, axis=1) & (XX < SUN_C[0]) & junk
    img[side & (sunw > 0.2), :3] = NEAR[6]
    for k, x in enumerate(range(sx - 9, sx + 10, 3)):
        y = int(sy - 42 + (x - sx) * 0.27)
        img[y, x, :3] = AMBER if k != 3 else NEAR[4]
        img[y + 1, x, :3] = AMBER if k != 3 else NEAR[4]
    img[cy - 21:cy - 16, cx - 10:cx - 2, :3] = NEAR[5]
    img[cy - 21, cx - 10:cx - 2, :3] = NEAR[6]
    return img


def smog():
    """Thin drifting smog bands. Mostly empty: sparse dithered pixels so the
    sky shows through; the game scrolls two copies at different speeds."""
    img = np.zeros((H, W, 4), dtype=np.uint8)
    dens = np.zeros((H, W), dtype=np.float32)
    for yc, half, seed in ((150, 10, 51), (212, 7, 52), (262, 12, 53)):
        band = np.clip(1 - np.abs(YY - yc - pnoise([2, 5], seed) * 6) / half, 0, 1)
        dens += band * np.clip(pnoise([3, 7, 11], seed + 10, y=YY) * 0.8 + 0.5, 0, 1)
    sunw = np.clip(1 - wrapdist(SUN_C[0]) / 260.0, 0, 1)
    on = dens > BAYER * 1.4
    lit = sunw > 0.35
    img[on, :3] = SKY[7]
    img[on & lit, :3] = SKY[9]
    img[on, 3] = 255
    return img


def main():
    layers = {"heap_sky": sky(), "heap_city": city(), "heap_far": far(), "heap_near": near(), "heap_smog": smog()}
    for name, arr in layers.items():
        Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".png"))
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for name in ("heap_sky", "heap_smog", "heap_city", "heap_far", "heap_near"):
        comp.alpha_composite(Image.fromarray(layers[name], "RGBA"))
    comp.save(os.path.join(OUT, "_composite.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
