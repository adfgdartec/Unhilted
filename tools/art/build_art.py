"""Builds every non-character asset for Unhilted into res://art/.
Run from the project root:  python3 tools/art/build_art.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr, dither_band, PAL  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art")
for sub in ("tiles", "backdrops", "props", "items", "ui", "fx"):
    os.makedirs(os.path.join(OUT, sub), exist_ok=True)


def out(*parts):
    return os.path.join(OUT, *parts)


# ====================================================================== TILES
# Atlas layout (16x16 cells, left to right):
#   0-3 fill variants | 4-6 top caps | 7 left edge | 8 right edge | 9 bottom edge
TILE = 16


def heap_scrap_tiles():
    s = Spr(TILE * 10, TILE)
    for v in range(4):  # compacted-junk fill, tileable
        rnd = random.Random(100 + v)
        cell = Spr(TILE, TILE)
        # Ground must stay quieter than props and characters: dark base, two
        # low-contrast buried plates, one rust fleck, a couple of specks.
        cell.rect(0, 0, TILE, TILE, "d")
        for i in range(2):
            w, h = rnd.randint(5, 9), 2
            x, y = rnd.randint(0, 15), rnd.randint(0, 15)
            cell.rect(x, y, w, h, "m", wrap=True)
            cell.rect(x, y + h, w, 1, "k", wrap=True)
        if v in (1, 3):
            cell.rect(rnd.randint(0, 15), rnd.randint(0, 15), 3, 1, "r", wrap=True)
        for _ in range(2):
            cell.px(rnd.randint(0, 15), rnd.randint(0, 15), "g", wrap=True)
        if v == 2:  # a buried cable
            for i in range(9):
                cell.px(3 + i, 12 - i // 3, "k", wrap=True)
        s.img.paste(cell.img, (v * TILE, 0))
    for v in range(3):  # top caps: brightest row = the walkable edge
        rnd = random.Random(200 + v)
        cap = Spr(TILE, TILE)
        depth = [rnd.choice([3, 4, 4, 5]) for _ in range(TILE)]
        for x in range(TILE):
            cap.px(x, 0, "l" if rnd.random() < 0.8 else "w")
            cap.px(x, 1, "g")
            for y in range(2, depth[x]):
                cap.px(x, y, "m")
            cap.px(x, depth[x], "k")
        bx = rnd.randint(2, 12)
        if v == 0:
            cap.px(bx, 0, "w"); cap.px(bx + 1, 0, "w")
        if v == 1:
            cap.ascii(bx, 1, ["o", "R"])
        s.img.paste(cap.img, ((4 + v) * TILE, 0))
    edge = Spr(TILE, TILE)  # left edge
    for y in range(TILE):
        edge.px(0, y, "k")
        if y % 2 == 0:
            edge.px(1, y, "k")
    s.img.paste(edge.img, (7 * TILE, 0))
    edge = Spr(TILE, TILE)  # right edge
    for y in range(TILE):
        edge.px(15, y, "k")
        if y % 2 == 1:
            edge.px(14, y, "k")
    s.img.paste(edge.img, (8 * TILE, 0))
    edge = Spr(TILE, TILE)  # underside
    for x in range(TILE):
        edge.px(x, 15, "k")
        if x % 2 == 0:
            edge.px(x, 14, "k")
    s.img.paste(edge.img, (9 * TILE, 0))
    s.save(out("tiles", "heap_scrap.png"))


def heap_industrial_tiles():
    s = Spr(TILE * 10, TILE)
    for v in range(4):  # riveted corp plates
        c = Spr(TILE, TILE)
        c.rect(0, 0, TILE, TILE, "m")
        c.hline(0, 0, TILE, "g"); c.vline(0, 0, TILE, "g")
        c.hline(0, 15, TILE, "k"); c.vline(15, 0, TILE, "k")
        for (rx, ry) in ((2, 2), (13, 2), (2, 13), (13, 13)):
            c.px(rx, ry, "l"); c.px(rx + 1, ry + 1, "d")
        if v == 1:  # vent slots
            for yy in (6, 8, 10):
                c.hline(5, yy, 6, "k")
        if v == 2:  # rust streak running down from a rivet
            for yy in range(4, 14):
                c.px(3, yy, "R" if yy < 10 else "r")
            c.px(4, 6, "r")
        if v == 3:  # dent
            c.ascii(6, 6, ["dd", "dg"])
        s.img.paste(c.img, (v * TILE, 0))
    cap = Spr(TILE, TILE)  # hazard-striped walking edge
    for x in range(TILE):
        for y in range(4):
            cap.px(x, y, "a" if ((x + y) // 3) % 2 == 0 else "k")
        cap.px(x, 4, "k")
    s.img.paste(cap.img, (4 * TILE, 0))
    cap = Spr(TILE, TILE)  # plain polished edge
    for x in range(TILE):
        cap.px(x, 0, "w"); cap.px(x, 1, "l"); cap.px(x, 2, "k")
    s.img.paste(cap.img, (5 * TILE, 0))
    cap = Spr(TILE, TILE)  # edge with a worn amber warning dash
    for x in range(TILE):
        cap.px(x, 0, "w"); cap.px(x, 1, "l"); cap.px(x, 2, "k")
    cap.hline(5, 1, 6, "a")
    s.img.paste(cap.img, (6 * TILE, 0))
    for i, (cx, alt) in enumerate(((0, 1), (15, 14))):
        e = Spr(TILE, TILE)
        for y in range(TILE):
            e.px(cx, y, "k")
        s.img.paste(e.img, ((7 + i) * TILE, 0))
    e = Spr(TILE, TILE)
    e.hline(0, 15, TILE, "k")
    s.img.paste(e.img, (9 * TILE, 0))
    s.save(out("tiles", "heap_industrial.png"))


# ================================================================= BACKDROPS
BW, BH = 640, 400  # wraps horizontally


def seamless_wave(x, terms):
    return sum(a * math.sin(2 * math.pi * k * x / BW + ph) for a, k, ph in terms)


def heap_outdoor():
    # L0 sky (screen-fixed)
    sky = Spr(BW, BH)
    dither_band(sky, 0, 160, "5", "1")
    dither_band(sky, 160, 250, "1", "2")
    dither_band(sky, 250, 320, "2", "4")
    dither_band(sky, 320, 360, "4", "8")
    sky.rect(0, 360, BW, 40, "8")
    rnd = random.Random(7)
    for _ in range(55):
        x, y = rnd.randint(0, BW - 1), rnd.randint(0, 170)
        sky.px(x, y, rnd.choice(["g", "g", "l", "w"]))
    # the Spire's cold beam, far away: foreshadows the final region
    for y in range(0, 230):
        a = int(60 * (1 - y / 230))
        sky.px(420, y, "c", a); sky.px(419, y, "c", a // 3); sky.px(421, y, "c", a // 3)
    sky.save(out("backdrops", "heap_sky.png"))

    # L1 megacity skyline
    city = Spr(BW, BH)
    rnd = random.Random(11)
    x = 0
    while x < BW:
        w = rnd.randint(14, 38)
        top = 300 - rnd.randint(30, 105)
        for xx in range(x, x + w):
            for yy in range(top, BH):
                city.px(xx, yy, "3", wrap=True)
        # windows: sparse lit pixels in neat rows
        for wy in range(top + 4, 296, 5):
            for wx in range(x + 2, x + w - 2, 3):
                if rnd.random() < 0.11:
                    city.px(wx, wy, rnd.choice(["a", "a", "a", "c", "p"]), 150, wrap=True)
        if rnd.random() < 0.4:  # antenna + red beacon
            ax = x + w // 2
            for yy in range(top - 8, top):
                city.px(ax, yy, "6", wrap=True)
            city.px(ax, top - 9, "x", wrap=True)
        x += w + rnd.randint(0, 6)
    # The Spire (centre of the corp, final region), always on the skyline
    sx = 420
    for yy in range(70, 300):
        half = 3 if yy < 110 else (7 if yy < 180 else 12)
        for xx in range(sx - half, sx + half + 1):
            city.px(xx, yy, "5")
    for yy in range(110, 296, 6):
        city.px(sx - 2, yy, "c", 150); city.px(sx + 2, yy, "c", 150)
    city.px(sx, 68, "C"); city.px(sx, 69, "c")
    city.save(out("backdrops", "heap_city.png"))

    # L2 far junk ridge
    far = Spr(BW, BH)
    for x in range(BW):
        ridge = int(305 + seamless_wave(x, [(9, 2, 0.3), (5, 5, 1.1), (2, 13, 2.0)]))
        for y in range(ridge, BH):
            far.px(x, y, "9")
        if x % 3 == 0:
            far.px(x, ridge, "4")
    # silhouettes on the ridge: a dead crane, poles, a dish
    for yy in range(250, 305):
        far.px(150, yy, "9")
    for xx in range(150, 196):
        far.px(xx, 252, "9")
    for yy in range(252, 266):
        far.px(194, yy, "9")
    for px_ in (300, 306, 470, 560):
        for yy in range(286, 305):
            far.px(px_, yy, "9")
    far.ellipse(520, 292, 8, 4, "9")
    far.save(out("backdrops", "heap_far.png"))

    # L3 near junk hills (darkest), rim-lit by the smoggy city glow
    near = Spr(BW, BH)
    for x in range(BW):
        ridge = int(338 + seamless_wave(x, [(12, 3, 0.7), (6, 7, 0.2), (2, 19, 1.5)]))
        for y in range(ridge, BH):
            near.px(x, y, "5")
        near.px(x, ridge, "7" if x % 2 == 0 else "8")
    # recognisable junk shapes poking out
    near.rect(90, 318, 14, 24, "5"); near.hline(90, 318, 14, "7")        # fridge
    near.ellipse(250, 332, 7, 7, "5"); near.ellipse(262, 334, 7, 7, "5")  # tyres
    for i in range(30):                                                   # bent pipe
        near.px(400 + i, 330 - i // 3, "5"); near.px(400 + i, 331 - i // 3, "5")
    near.save(out("backdrops", "heap_near.png"))


def intake_interior():
    wall = Spr(BW, BH)
    for x in range(BW):
        key = "6" if x % 6 < 2 else "5"
        for y in range(BH):
            wall.px(x, y, key)
    for by in (118, 250):  # horizontal beams with rivets
        wall.rect(0, by, BW, 6, "3")
        for x in range(4, BW, 16):
            wall.px(x, by + 2, "m")
    # faded stencil "07": this is Intake Unit 7's bay
    digits = {
        "0": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"],
        "7": ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."],
    }
    for di, d in enumerate("07"):
        for gy, row in enumerate(digits[d]):
            for gx, ch in enumerate(row):
                if ch == "#":
                    for yy in range(9):
                        for xx in range(9):
                            wall.px(236 + di * 60 + gx * 9 + xx, 140 + gy * 9 + yy, "a", 34)
    for x in range(BW):  # worn hazard band low on the wall
        for y in range(296, 306):
            if ((x + y) // 6) % 2 == 0:
                wall.px(x, y, "a", 60)
    for vx in (80, 560):  # vents
        for vy in range(60, 84, 4):
            wall.hline(vx, vy, 22, "k")
    wall.save(out("backdrops", "intake_wall.png"))

    girders = Spr(BW, BH)
    for x in range(BW):
        girders.px(x, 34, "3"); girders.px(x, 35, "3"); girders.px(x, 66, "3"); girders.px(x, 67, "3")
    for x0 in range(0, BW, 32):
        girders.line(x0, 36, x0 + 16, 65, "3")
        girders.line(x0 + 16, 65, x0 + 32, 36, "3")
    for cx in (0, 213, 426):
        girders.rect(cx, 36, 12, BH - 36, "3")
        for yy in range(80, BH, 40):
            girders.line(cx, yy, cx + 11, yy + 20, "5")
    girders.save(out("backdrops", "intake_girders.png"))


if __name__ == "__main__":
    heap_scrap_tiles()
    heap_industrial_tiles()
    heap_outdoor()
    intake_interior()
    print("tiles + backdrops built")
