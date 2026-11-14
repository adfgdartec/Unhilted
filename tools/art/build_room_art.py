"""Painted room art: a full pixel-painted terrain layer per room, plus redrawn
backdrops, for a darker, more detailed look (Blasphemous / Dead Cells
direction). Collision is untouched: this only reads each room's solids.
These are the style samples (gothic / verdigris / ember); none is switched on
by default. Set Fx.art_variant to one to see it in game.

Run from the project root:
    python3 tools/art/build_room_art.py              # every variant, sample rooms
    python3 tools/art/build_room_art.py gothic uw_02_market

Writes art/rooms/<variant>/<room_id>_terrain.png (drawn over the solids, so
it may spill a few pixels past them: ledge lips, rubble, hanging chains),
<room_id>_front.png (near-black foreground silhouettes, drawn over the
robot), art/backdrops/<variant>/uw_far.png / uw_mid.png / uw_works.png, and
palette-matched copies of the Underworks props in art/props/<variant>/.

How it avoids the "generated" look:
- no primitives: stones, plates and grates are laid out as irregular units
  (random bond brick, plates of varying width), each one shaded by hand rules
  (lit top-left edge, dark bottom-right, chipped corners)
- one fixed palette per variant, every pixel snapped to it
- mass: solids get darker with depth, falling to near-black (dithered bands,
  no gradients), so walls read as heavy things, not flat fills
- drawn light: lamp positions from the scene light the terrain in hard
  dithered bands
- wear: soot and verdigris drips under edges, cracks, moss, rubble on floors
- symmetry is broken on purpose everywhere (seeded, so it's stable)
- the background is kept darker and flatter than the playable stone
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


VARIANTS = {
    "gothic": dict(
        void="0b0a0e", mortar="15121a",
        stone=["1d1a22", "2a252d", "3a333a", "4d444a", "675b5c", "8a7a74"],
        plate=["1c1816", "2c2420", "45382c", "65503a", "8c7048", "c9a35f"],
        iron=["111014", "1e1c22", "2f2c33", "48434a", "6a6369"],
        stain="1f2a24", stain2="3b1414", moss=["1f2b20", "33432e"],
        light=["8c6a3c", "c99a52", "f0cf8a"], light_strength=1.0, noise=0.06,
        sky_top="06060a", sky_bot="1a1418", fog="241e24", fog2="3a2e30",
        win=["4a2e18", "a8702e", "f2c26a"], ambient=(0.86, 0.84, 0.88)),
    "verdigris": dict(
        void="070d0c", mortar="0d1513",
        stone=["14201d", "1e2e2a", "2a3f39", "3a544b", "4f6e62", "6f8f80"],
        plate=["16130f", "2a2018", "4a3322", "6e4a2c", "9a6a3c", "d0995a"],
        iron=["0d1312", "182220", "26332f", "3a4b45", "566b62"],
        stain="2f6b58", stain2="1a2a22", moss=["1d3a2e", "2f5a44"],
        light=["7a5a30", "c08a46", "f5c878"], light_strength=0.95, noise=0.08,
        sky_top="040808", sky_bot="0f1c18", fog="15241f", fog2="22382f",
        win=["3e2a14", "a06a28", "f0b85a"], ambient=(0.82, 0.88, 0.86)),
    "ember": dict(
        void="0d0807", mortar="170e0c",
        stone=["21140f", "321e16", "4a2c1e", "653c26", "8a5232", "b8763e"],
        plate=["1a110d", "2e1c14", "4c2c1a", "744226", "a85f30", "e89a4c"],
        iron=["120c0b", "211715", "332522", "4d3833", "6f544a"],
        stain="0c0706", stain2="5a2a12", moss=["2a2a14", "4a4a20"],
        light=["9a5428", "e08a3c", "ffd08a"], light_strength=1.05, noise=0.04,
        sky_top="0a0505", sky_bot="22120c", fog="2c1810", fog2="44261a",
        win=["5a2a10", "c86a24", "ffc066"], ambient=(0.9, 0.82, 0.78)),
}


def pal(v, key):
    c = v[key]
    return [hexc(x) for x in c] if isinstance(c, list) else hexc(c)


def parse_room(room_id):
    folder = "underworks" if room_id.startswith("uw_") else "heap"
    t = open(os.path.join(ROOT, "scenes", "rooms", folder, room_id + ".tscn")).read()
    b = [float(x) for x in re.search(r"bounds = Rect2\(([^)]*)\)", t).group(1).split(",")]
    solids = [tuple(float(x) for x in m.split(",")) for m in re.findall(r"Rect2\(([^)]*)\)", re.search(r"solids = Array\[Rect2\]\(\[(.*?)\]\)", t).group(1))]
    styles = re.findall(r'"(\w+)"', re.search(r"solid_styles = PackedStringArray\((.*?)\)", t).group(1))
    lamp_ext = re.search(r'path="res://scripts/world/gas_lamp.gd" id="(\w+)"', t)
    lamps = []
    if lamp_ext:
        for block in t.split("\n\n"):
            if 'ExtResource("%s")' % lamp_ext.group(1) in block and "script =" in block:
                p = re.search(r"position = Vector2\(([^)]*)\)", block)
                if not p:
                    continue
                x, y = (float(q) for q in p.group(1).split(","))
                wall = "wall_mounted = true" in block
                r = re.search(r"radius = ([\d.]+)", block)
                lamps.append((x, y - (8 if wall else 36), float(r.group(1)) if r else 90.0))
    return dict(id=room_id, w=int(b[2]), h=int(b[3]), solids=solids, styles=styles, lamps=lamps)


class Canvas:
    """An RGBA canvas that only ever receives palette colours."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def px(self, x, y, c, alpha=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, :3] = c
            self.a[y, x, 3] = alpha

    def rect(self, x, y, w, h, c):
        x0, y0, x1, y1 = max(0, x), max(0, y), min(self.w, x + w), min(self.h, y + h)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1, :3] = c
            self.a[y0:y1, x0:x1, 3] = 255

    def image(self):
        return Image.fromarray(self.a, "RGBA")


def hsh(*v):
    """Stable integer hash (FNV-1a over the values)."""
    h = 2166136261
    for x in v:
        h = ((h ^ (int(x) & 0xffffffff)) * 16777619) & 0xffffffff
    return h


def light_map(room, w, h, v):
    """Lamp light as a 0..1 field (smooth here, banded later by the dither)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    L = np.zeros((h, w), np.float32)
    for (lx, ly, r) in room["lamps"]:
        rr = r * 1.15
        d = np.sqrt((xx - lx) ** 2 + ((yy - ly) * 1.25) ** 2) / rr
        L = np.maximum(L, np.clip(1.0 - d, 0, 1) ** 1.6)
    return L * v["light_strength"]


def band(value, x, y):
    """Ordered-dither a 0..N float to an integer band (hard pixel bands, no gradients)."""
    return int(math.floor(value + BAYER[y % 4, x % 4]))


def paint_terrain(room, vname):
    v = VARIANTS[vname]
    W, H = room["w"], room["h"]
    pad = 24
    cw, chh = W + pad * 2, H + pad * 2
    C = Canvas(cw, chh)
    stone, plate, iron = pal(v, "stone"), pal(v, "plate"), pal(v, "iron")
    void, mortar = pal(v, "void"), pal(v, "mortar")
    lights = pal(v, "light")
    stain, stain2, moss = pal(v, "stain"), pal(v, "stain2"), pal(v, "moss")

    mask = np.zeros((chh, cw), bool)
    kind = np.full((chh, cw), "", object)
    for (x, y, w, h), st in zip(room["solids"], room["styles"]):
        x, y, w, h = int(x) + pad, int(y) + pad, int(w), int(h)
        if st == "grate":
            continue
        mask[y:y + h, x:x + w] = True
        kind[y:y + h, x:x + w] = st
    outside = np.ones((chh, cw), bool)
    outside[pad:pad + H, pad:pad + W] = False
    solid_or_out = mask | outside
    depth = ndimage.distance_transform_cdt(solid_or_out, metric="chessboard").astype(np.float32)
    air = ~solid_or_out
    air_above = np.zeros_like(mask)
    air_above[1:] = air[:-1]
    air_below = np.zeros_like(mask)
    air_below[:-1] = air[1:]
    air_left = np.zeros_like(mask)
    air_left[:, 1:] = air[:, :-1]
    air_right = np.zeros_like(mask)
    air_right[:, :-1] = air[:, 1:]
    top_dist = np.full((chh, cw), 999, np.int32)
    for x in range(cw):
        run = 999
        for y in range(chh):
            if mask[y, x]:
                run = 0 if (y == 0 or not mask[y - 1, x]) else run + 1
                top_dist[y, x] = run
            else:
                run = 999
    L = np.zeros((chh, cw), np.float32)
    L[pad:pad + H, pad:pad + W] = light_map(room, W, H, v)

    row_of = {}
    yb = -pad
    row = 0
    while yb < chh:
        hgt = 5 + hsh(row, 11) % 4
        for yy in range(yb, yb + hgt):
            row_of[yy] = (row, yb, hgt)
        yb += hgt
        row += 1
    stone_cache = {}

    def stone_at(wx, wy):
        row, y0, hgt = row_of[wy]
        if row not in stone_cache:
            xs = []
            x = -pad - (hsh(row, 3) % 14)
            k = 0
            while x < cw + 40:
                wdt = 9 + hsh(row, k, 5) % 13
                xs.append((x, wdt, k))
                x += wdt
                k += 1
            stone_cache[row] = xs
        for (x0, wdt, k) in stone_cache[row]:
            if x0 <= wx < x0 + wdt:
                return row, k, wx - x0, wy - y0, wdt, hgt
        return row, 0, 0, 0, 10, hgt

    out = np.zeros((chh, cw, 3), np.uint8)
    alpha = np.zeros((chh, cw), np.uint8)
    ys, xs = np.nonzero(mask)
    noise = v["noise"]
    for y, x in zip(ys, xs):
        d = depth[y, x]
        k = kind[y, x]
        lit = L[y, x]
        if k == "plate" and top_dist[y, x] < 10:
            sx = -pad
            pid = 0
            while True:
                pw = 28 + hsh(pid, 77) % 25
                if sx + pw > x:
                    break
                sx += pw
                pid += 1
            lx = x - sx
            ty = top_dist[y, x]
            base = {0: 5, 1: 4, 2: 3, 7: 1, 8: 0, 9: 0}.get(ty, 2)
            if lx == 0:
                base = 0
            elif lx == 1 and ty > 0:
                base = min(base + 1, 4)
            if ty == 4 and (lx % 12 == 5):
                base = 4
            if ty == 5 and (lx % 12 == 5):
                base = 1
            if ty == 0 and hsh(x, 9) % 5 == 0:
                base = 4
            lb = band(lit * 3.0, x, y)
            if lb >= 1 and ty <= 1:
                out[y, x] = lights[min(2, lb)]
                alpha[y, x] = 255
                continue
            base += min(lb, 1)
            out[y, x] = plate[max(0, min(5, base))]
            alpha[y, x] = 255
            continue
        row, sid, sx, sy, sw, shh = stone_at(x, y)
        if sy == shh - 1 or sx == 0:
            col = mortar
        else:
            v0 = 2 + (hsh(row, sid, 13) % 3) - 1
            if sy == 0 or sx == 1:
                v0 += 1
            if sy == shh - 2 or sx == sw - 1:
                v0 -= 1
            if (sx in (1, sw - 1)) and (sy in (0, shh - 2)) and hsh(row, sid, 21) % 3 == 0:
                v0 = -9
            if hsh(row, sid, 31) % 9 == 0 and abs((sx - 2) - (sy * 2)) == 0:
                v0 = -9
            td = top_dist[y, x]
            if td < 2:
                v0 += 2
            elif td < 6:
                v0 += 1
            if air_below[y, x] or (d < 3 and td > 900):
                v0 -= 1
            v0 -= band(min(d, 40) / 7.0, x, y)
            lb = band(lit * 3.2, x, y)
            if lb >= 2 and d <= 3 and (sy == 0 or td == 0):
                out[y, x] = lights[min(2, lb - 1)]
                alpha[y, x] = 255
                continue
            v0 += min(lb, 2)
            if hsh(row, sid, 6) % 100 < noise * 100:
                v0 += 1
            if v0 <= -9:
                col = mortar
            elif v0 < 0:
                col = void if d > 6 else mortar
            else:
                col = stone[min(5, v0)]
        out[y, x] = col
        alpha[y, x] = 255

    C.a[..., :3] = out
    C.a[..., 3] = alpha

    for y, x in zip(*np.nonzero(mask & air_above)):
        if kind[y, x] == "brick" and hsh(x, 41) % 11 == 0 and y > 0:
            C.px(x, y - 1, stone[3])
        if hsh(x, y, 43) % 23 == 0 and kind[y, x] != "plate":
            C.px(x, y - 1, moss[1])
            if hsh(x, 44) % 2:
                C.px(x + 1, y - 1, moss[0])
    for y, x in zip(*np.nonzero(mask & air_below)):
        if hsh(x, 51) % 7 == 0:
            ln = 2 + hsh(x, 52) % 9
            for k in range(ln):
                if hsh(x, k, 53) % 4 != 0:
                    C.px(x, y + 1 + k, stain if k < ln - 1 else stone[1])
        if hsh(x, 54) % 31 == 0:
            ln = 8 + hsh(x, 55) % 28
            for k in range(ln):
                C.px(x, y + 1 + k, iron[2] if k % 3 != 2 else iron[4])
                if k % 3 == 1:
                    C.px(x + 1, y + 1 + k, iron[1])
    for y, x in zip(*np.nonzero(mask & (air_left | air_right))):
        if hsh(x, y // 24, 61) % 6 == 0 and top_dist[y, x] < 999:
            for k in range(1, 4):
                xx = x + (k if air_left[y, x] else -k)
                if 0 <= xx < cw and mask[y, xx] and hsh(x, y, k) % 3:
                    C.px(xx, y, stain2)

    tops = [(y, x) for y, x in zip(*np.nonzero(mask & air_above)) if top_dist[y, x] == 0]
    for (y, x) in tops:
        h_ = hsh(x, y, 71) % 97
        if h_ < 3:
            n = 2 + hsh(x, 72) % 4
            for i in range(n):
                dx = (hsh(x, i, 73) % 9) - 4
                s = 1 + hsh(x, i, 74) % 2
                for yy in range(s):
                    for xx in range(s + 1):
                        C.px(x + dx + xx, y - 1 - yy, stone[2 + (xx + yy) % 2] if yy < s - 1 or xx else stone[4])
        elif h_ < 4:
            for (dx, dy, c) in ((0, -1, 4), (1, -1, 3), (2, -1, 4), (0, -2, 3), (2, -2, 5), (1, -3, 4)):
                C.px(x + dx, y + dy, plate[c])
        elif h_ < 5:
            for dx in range(6 + hsh(x, 75) % 6):
                C.px(x + dx, y, iron[1])
            C.px(x + 2, y, lights[1] if L[y, x] > 0.15 else iron[3])

    for (x, y, w, h), st in zip(room["solids"], room["styles"]):
        if st != "grate":
            continue
        x, y, w, h = int(x) + pad, int(y) + pad, int(w), int(h)
        for xx in range(x, x + w):
            lit = L[min(chh - 1, y), min(cw - 1, xx)]
            b = band(lit * 2.0, xx, y)
            C.px(xx, y, iron[min(4, 3 + b)])
            C.px(xx, y + 1, iron[min(4, 2 + b)])
            C.px(xx, y + h - 1, iron[1])
            for yy in range(y + 2, y + h - 1):
                if (xx - x) % 4 == 0:
                    C.px(xx, yy, iron[2 + min(1, b)])
                elif (xx - x) % 4 == 2 and yy == y + h // 2:
                    C.px(xx, yy, iron[1])
        bx = x + 6
        while bx < x + w - 4:
            for k in range(6):
                C.px(bx + k // 2, y + h + k, iron[1])
                C.px(bx, y + h + k, iron[2])
            bx += 30 + hsh(bx, 81) % 14
        for xx in range(x, x + w):
            if hsh(xx, 82) % 13 == 0:
                for k in range(1 + hsh(xx, 83) % 4):
                    C.px(xx, y + h + k, stain2)

    return C.image().crop((pad - 8, pad - 8, pad + W + 8, pad + H + 8))


def paint_front(room, vname):
    """Foreground silhouettes: near-black, sparse, hanging from the ceiling."""
    v = VARIANTS[vname]
    W, H = room["w"], room["h"]
    C = Canvas(W, H)
    void = pal(v, "void")
    iron = pal(v, "iron")
    top = np.zeros(W, int)
    for (x, y, w, h), st in zip(room["solids"], room["styles"]):
        if y <= 0:
            a, b = max(0, int(x)), min(W, int(x + w))
            top[a:b] = np.maximum(top[a:b], int(y + h))
    x = 40 + hsh(W, 1) % 60
    while x < W - 20:
        kind = hsh(x, 2) % 3
        y0 = top[min(W - 1, x)]
        if kind == 0:
            ln = 30 + hsh(x, 3) % 70
            for k in range(ln):
                C.px(x, y0 + k, void)
                if k % 4 in (1, 2):
                    C.px(x - 1, y0 + k, void)
                    C.px(x + 1, y0 + k, void)
            for k in range(3):
                C.rect(x - 3, y0 + ln + k, 7, 1, void)
        elif kind == 1:
            ln = 16 + hsh(x, 4) % 30
            C.rect(x - 4, y0, 9, ln, void)
            C.rect(x - 6, y0 + ln - 3, 13, 3, void)
            C.px(x - 3, y0 + 2, iron[1])
        else:
            for t in range(40):
                a = t / 39.0
                cx = int(x + a * 46)
                cy = int(y0 + 4 + math.sin(a * math.pi) * (10 + hsh(x, 5) % 12))
                C.px(cx, cy, void)
                C.px(cx, cy + 1, void)
        x += 170 + hsh(x, 6) % 210
    return C.image()


def dither_mix(c0, c1, t, x, y):
    return c1 if t > BAYER[y % 4, x % 4] else c0


def paint_backdrop(vname):
    v = VARIANTS[vname]
    W, H = 640, 400
    stone = pal(v, "stone")
    iron = pal(v, "iron")
    fog, fog2 = hexc(v["fog"]), hexc(v["fog2"])
    top, bot = hexc(v["sky_top"]), hexc(v["sky_bot"])
    win = pal(v, "win")
    far = Canvas(W, H)
    for y in range(H):
        t = y / H
        for x in range(W):
            if t < 0.45:
                c = dither_mix(top, bot, t / 0.45 * 0.7, x, y)
            elif t < 0.7:
                c = dither_mix(bot, fog, (t - 0.45) / 0.25, x, y)
            else:
                c = dither_mix(fog, fog2, (t - 0.7) / 0.3 * 0.8, x, y)
            far.px(x, y, c)
    sil = stone[0]
    sil2 = stone[1]
    x = -10
    while x < W + 20:
        pw = 10 + hsh(x, 1) % 10
        span = 44 + hsh(x, 2) % 34
        base_top = 150 + hsh(x, 3) % 30
        for xx in range(x, x + pw):
            for yy in range(base_top, H):
                far.px(xx % W, yy, sil)
        r = span / 2
        cx = x + pw + r
        broken = hsh(x, 4) % 5 == 0
        for xx in range(int(x + pw), int(x + pw + span)):
            dy = math.sqrt(max(0.0, r * r - (xx - cx) ** 2))
            ytop = base_top - 14
            ya = int(base_top + 12 - dy)
            if broken and xx > cx:
                continue
            for yy in range(ytop, ya):
                far.px(xx % W, yy, sil)
            far.px(xx % W, ya, sil2)
        x += pw + span
    for xx in range(W):
        for yy in range(122, 130 + (hsh(xx // 37, 9) % 3)):
            far.px(xx, yy, sil)
    for i in range(9):
        hx = (i * 73 + hsh(i, 11) % 40) % W
        hw = 18 + hsh(i, 12) % 22
        hh = 26 + hsh(i, 13) % 34
        hy = 210 - hh + hsh(i, 14) % 18
        for xx in range(hx, hx + hw):
            for yy in range(hy, 240):
                far.px(xx % W, yy, sil)
        if hsh(i, 15) % 2:
            for k in range(hw // 2):
                for yy in range(hy - k // 2, hy):
                    far.px((hx + k) % W, yy, sil)
                    far.px((hx + hw - 1 - k) % W, yy, sil)
        cxp = hx + 3 + hsh(i, 16) % max(1, hw - 6)
        for yy in range(hy - 12, hy):
            far.px(cxp % W, yy, sil)
            far.px((cxp + 1) % W, yy, sil)
        for wy in range(hy + 5, 232, 9):
            for wx in range(hx + 3, hx + hw - 3, 7):
                if hsh(wx, wy, i) % 3 == 0:
                    continue
                c = win[2] if hsh(wx, wy, 17) % 4 == 0 else win[1]
                ww, wh = (2, 3) if hsh(wx, 18) % 2 else (3, 4)
                for a in range(ww):
                    for b in range(wh):
                        far.px((wx + a) % W, wy + b, c if (a, b) != (0, 0) else win[0])
    for xx in range(W):
        far.px(xx, 240, sil2)
        for yy in range(241, 247):
            far.px(xx, yy, sil)
        if xx % 41 == 7:
            for yy in range(238, 250):
                far.px(xx, yy, sil2)
    cx, cy, r = 470, 150, 84
    for a in range(0, 720):
        t = a / 720 * math.tau
        for rr in range(r - 6, r + 1):
            far.px(int(cx + math.cos(t) * rr) % W, int(cy + math.sin(t) * rr), sil)
    for s in range(7):
        t = s / 7 * math.tau + 0.2
        for k in range(r):
            for w_ in (-1, 0, 1):
                far.px(int(cx + math.cos(t) * k + w_) % W, int(cy + math.sin(t) * k), sil)
    for y in range(260, H):
        t = (y - 260) / (H - 260)
        for x in range(W):
            if (t * 0.6) > BAYER[y % 4, x % 4] and (x + y) % 2 == 0:
                far.px(x, y, fog2)

    mid = Canvas(W, H)
    for (px, pw) in ((40, 34), (262, 44), (488, 30)):
        row = 0
        y = 0
        while y < H:
            hgt = 6 + hsh(row, px) % 3
            xx = px - (hsh(row, px, 1) % 9)
            while xx < px + pw:
                sw = 8 + hsh(row, xx, 2) % 10
                for a in range(max(px, xx), min(px + pw, xx + sw)):
                    for b in range(y, min(H, y + hgt)):
                        if a == xx or b == y + hgt - 1:
                            c = stone[0]
                        else:
                            v0 = hsh(row, xx, 3) % 2
                            if b == y or a == xx + 1:
                                v0 += 1
                            if a > px + pw * 0.66:
                                v0 = 0
                            c = stone[max(0, min(1, v0))] if v0 < 2 else hexc(v["fog2"])
                        mid.px(a, b, c)
                xx += sw
            y += hgt
            row += 1
        for b in (96, 97, 98, 300, 301):
            for a in range(px - 3, px + pw + 3):
                mid.px(a, b, stone[2] if b in (96, 300) else stone[0])
    for (y0, th) in ((70, 11), (226, 8)):
        for xx in range(W):
            for b in range(th):
                c = iron[2] if b == 0 else (iron[0] if b > th - 3 else iron[1])
                mid.px(xx, y0 + b, c)
            if xx % 67 == 13:
                for b in range(-2, th + 2):
                    for a in range(4):
                        mid.px(xx + a, y0 + b, iron[2] if a == 0 else iron[0])
    for (x0, x1, sag) in ((90, 250, 26), (320, 470, 18), (520, 660, 30)):
        for xx in range(x0, x1):
            t = (xx - x0) / (x1 - x0)
            yy = int(110 + math.sin(t * math.pi) * sag)
            mid.px(xx % W, yy, iron[0])
    for (lx, ly) in ((74, 150), (300, 132), (500, 160)):
        for b in range(6):
            mid.px(lx + b, ly, iron[2])
        mid.rect(lx + 5, ly - 4, 4, 6, win[1])
        mid.px(lx + 6, ly - 3, win[2])
    return far.image(), mid.image()


def remap_prop(path, vname):
    """Re-colour a picture onto the variant's palette: brass/orange -> plate
    ramp, greys -> iron, greens/teals -> stone, very bright warm pixels (lit
    glass, flames) -> the light ramp."""
    v = VARIANTS[vname]
    plate, iron, stone, lights = pal(v, "plate"), pal(v, "iron"), pal(v, "stone"), pal(v, "light")
    a = np.array(Image.open(path).convert("RGBA"))
    out = a.copy()
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            r, g, b, al = (int(c) for c in a[y, x])
            if al == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            sat = (mx - mn) / max(mx, 1)
            if lum > 0.72 and r >= g >= b and sat > 0.2:
                ramp = lights
                i = 2 if lum > 0.86 else 1
            else:
                if sat < 0.22:
                    ramp = iron
                elif r > g and g >= b:
                    ramp = plate
                elif g >= r:
                    ramp = stone
                else:
                    ramp = plate
                i = int(round((lum ** 0.85) * (len(ramp) - 1) * 1.1))
            out[y, x, :3] = ramp[max(0, min(len(ramp) - 1, i))]
    Image.fromarray(out, "RGBA").save(os.path.join(os.path.dirname(path), vname, os.path.basename(path)))


SAMPLE_ROOMS = ["uw_02_market", "uw_08_gauge"]


def main():
    args = sys.argv[1:]
    variants = [a for a in args if a in VARIANTS] or list(VARIANTS)
    rooms = [a for a in args if a not in VARIANTS] or SAMPLE_ROOMS
    for vname in variants:
        out = os.path.join(ROOT, "art", "rooms", vname)
        os.makedirs(out, exist_ok=True)
        bdir = os.path.join(ROOT, "art", "backdrops", vname)
        os.makedirs(bdir, exist_ok=True)
        far, mid = paint_backdrop(vname)
        far.save(os.path.join(bdir, "uw_far.png"))
        mid.save(os.path.join(bdir, "uw_mid.png"))
        with open(os.path.join(out, "style.cfg"), "w") as f:
            f.write("[style]\nambient=Color(%g, %g, %g, 1)\n" % VARIANTS[vname]["ambient"])
        pdir = os.path.join(ROOT, "art", "props")
        os.makedirs(os.path.join(pdir, vname), exist_ok=True)
        for fn in sorted(os.listdir(pdir)):
            if fn.endswith(".png") and (fn.startswith("uw_") or fn.startswith("front_")):
                remap_prop(os.path.join(pdir, fn), vname)
        remap_prop(os.path.join(ROOT, "art", "backdrops", "uw_works.png"), vname)
        for rid in rooms:
            room = parse_room(rid)
            paint_terrain(room, vname).save(os.path.join(out, rid + "_terrain.png"))
            paint_front(room, vname).save(os.path.join(out, rid + "_front.png"))
        print("painted", vname, rooms)


if __name__ == "__main__":
    main()
