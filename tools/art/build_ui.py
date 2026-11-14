"""Shop, map and journal UI art for Unhilted.
Run from the project root:  python3 tools/art/build_ui.py

Same rules as the loadout sockets (build_chips.py): one palette, light from
the top-left, a dark outline, brass for the old-world parts, cyan only for
the robot's own tech. Frames are 9-slice textures (margins noted per piece)
so Godot can stretch them to any size without blurring the corners.

Shop:   card / card_sel / card_off (9-slice, 7 px), well (round icon recess),
        tag (price tag, 9-slice), stamp (ink frame, tinted in code),
        case (display case, 9-slice), pedestal, btn / btn_hover / btn_off
        (brass push plate, 9-slice), awning (tiles sideways), tray (wallet
        recess, 9-slice), item icons for kit / core cell / map.
Map:    paper (parchment sheet, 9-slice, tiled centre), banner (title ribbon,
        9-slice), compass, map_icons (atlas of 10x10 ink icons), pin.
Journal: tab / tab_on (folder tabs, 9-slice).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr, PAL

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui")
os.makedirs(os.path.join(OUT, "map"), exist_ok=True)


def lit(angle):
    return math.cos(angle - math.pi / 4)


def ring(s, cx, cy, r0, r1, key_fn):
    for y in range(s.h):
        for x in range(s.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r0 <= r < r1:
                k = key_fn(math.atan2(dy, dx), r)
                if k:
                    s.px(x, y, k)


def raw(s, x, y, rgba):
    if 0 <= x < s.w and 0 <= y < s.h:
        s.img.putpixel((s.f * s.w + x, y), rgba)


def rivet(s, x, y, hi="Y", lo="b"):
    s.px(x, y, hi)
    s.px(x + 1, y + 1, lo)


def card(kind):
    """26x26, 9-slice margins 7. An iron plate with brass corner brackets."""
    s = Spr(26, 26)
    W = H = 26
    face = {"normal": "d", "sel": "d", "off": "k"}[kind]
    s.rect(0, 0, W, H, "k")
    s.rect(1, 1, W - 2, H - 2, "m" if kind != "off" else "d")
    s.hline(1, 1, W - 2, "g" if kind != "off" else "m")
    s.vline(1, 1, H - 2, "g" if kind != "off" else "m")
    s.rect(3, 3, W - 6, H - 6, "k")
    s.rect(4, 4, W - 8, H - 8, face)
    if kind == "sel":
        s.hline(4, 4, W - 8, "c")
        s.vline(4, 4, H - 8, "c")
        s.hline(4, H - 5, W - 8, "s")
        s.vline(W - 5, 4, H - 8, "s")
    else:
        s.hline(4, 4, W - 8, "m" if kind == "normal" else "d")
    hi, mid, lo = ("Y", "y", "b") if kind == "sel" else (("y", "B", "b") if kind == "normal" else ("l", "g", "m"))
    for cx, cy, fx, fy in ((0, 0, 1, 1), (W - 1, 0, -1, 1), (0, H - 1, 1, -1), (W - 1, H - 1, -1, -1)):
        for i in range(6):
            for t in range(2):
                x, y = cx + fx * i, cy + fy * t
                s.px(x, y, hi if (t == 0 and fy == 1) else (mid if fy == 1 else lo))
                x, y = cx + fx * t, cy + fy * i
                s.px(x, y, hi if (t == 0 and fx == 1) else (mid if fx == 1 else lo))
        s.px(cx + fx * 6, cy, "k")
        s.px(cx, cy + fy * 6, "k")
        s.px(cx + fx * 6, cy + fy * 1, "k")
        s.px(cx + fx * 1, cy + fy * 6, "k")
        rivet(s, cx + fx * 3 - (1 if fx < 0 else 0), cy + fy * 3 - (1 if fy < 0 else 0), hi, lo)
    return s


def well():
    """34x34 round recess with a brass collar: the same idea as a port socket."""
    s = Spr(34, 34)
    c = 17.0

    def collar(a, r):
        l = lit(a)
        if r >= 16.3:
            return "k"
        if l < -0.5:
            return "y" if r < 15.4 else "B"
        return "B" if l < 0.3 else "b"
    ring(s, c, c, 14.0, 17, collar)
    ring(s, c, c, 0, 14.0, lambda a, r: "k" if (r > 12.2 and lit(a) < 0.15) else ("z" if r > 7 or lit(a) > -0.2 else "d"))
    ring(s, c, c, 13.4, 14.0, lambda a, r: "m" if lit(a) > 0.5 else None)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        s.px(int(c + math.cos(a) * 15.2), int(c + math.sin(a) * 15.2), "Y" if lit(a) < 0 else "y")
    return s


def tag():
    """Price tag, 16x11. 9-slice: left 7 (the punched point), right 2, top/bottom 3."""
    s = Spr(16, 11)
    rows = [
        "....kkkkkkkkkkkk",
        "...kwwwwwwwwwwwk",
        "..kwwwwwwwwwwwlk",
        ".kwwwwwwwwwwwwlk",
        "kwwkkwwwwwwwwwlk",
        "kwwkkwwwwwwwwwlk",
        ".kwwwwwwwwwwwwlk",
        "..kwwwwwwwwwwwlk",
        "...klllllllllllk",
        "....kkkkkkkkkkkk",
        "................",
    ]
    s.ascii(0, 0, rows)
    s.hline(4, 1, 11, "W")
    return s


def stamp():
    """12x12 ink frame (white, tinted in code), 9-slice 4. Rough edges like a rubber stamp."""
    s = Spr(12, 12)
    rnd = random.Random(7)
    for i in range(12):
        for t in range(2):
            for (x, y) in ((i, t), (i, 11 - t), (t, i), (11 - t, i)):
                if rnd.random() > 0.12:
                    raw(s, x, y, (255, 255, 255, 230 if t == 0 else 150))
    return s


def case():
    """Display case, 24x24, 9-slice 7: wooden frame around a dark velvet recess."""
    s = Spr(24, 24)
    s.rect(0, 0, 24, 24, "k")
    s.rect(1, 1, 22, 22, "e")
    s.hline(1, 1, 22, "E")
    s.vline(1, 1, 22, "E")
    s.hline(1, 22, 22, "r")
    s.vline(22, 1, 22, "r")
    s.rect(3, 3, 18, 18, "k")
    for y in range(4, 20):
        for x in range(4, 20):
            raw(s, x, y, (24, 18, 24, 255))
    s.hline(4, 4, 16, "k")
    s.vline(4, 4, 16, "k")
    s.hline(4, 19, 16, "d")
    for (x, y) in ((2, 2), (20, 2), (2, 20), (20, 20)):
        rivet(s, x, y)
    return s


def pedestal():
    """A brass plinth the selected item sits on, 44x14."""
    s = Spr(44, 14)
    s.ellipse(22, 3, 19, 2, "y")
    s.hline(6, 2, 32, "Y")
    s.rect(4, 4, 36, 6, "B")
    s.hline(4, 4, 36, "y")
    s.hline(4, 7, 36, "b")
    s.rect(2, 10, 40, 3, "b")
    s.hline(2, 10, 40, "B")
    for x in range(4, 40):
        if x > 30:
            s.px(x, 5, "b")
            s.px(x, 6, "b")
    s.outline("k")
    return s


def button(kind):
    """Brass push plate, 18x16, 9-slice 6 (bottom 7: the plate's thickness)."""
    s = Spr(18, 16)
    if kind == "off":
        top, face, hi, side, dark = "g", "m", "g", "d", "k"
    elif kind == "hover":
        top, face, hi, side, dark = "Y", "Y", "W", "y", "B"
    else:
        top, face, hi, side, dark = "Y", "y", "Y", "B", "b"
    s.rect(0, 0, 18, 16, "k")
    s.rect(1, 1, 16, 11, face)
    s.hline(1, 1, 16, hi)
    s.vline(1, 1, 11, top)
    s.vline(16, 1, 11, side)
    s.rect(1, 12, 16, 3, side)
    s.hline(1, 14, 16, dark)
    for (x, y) in ((3, 3), (13, 3)):
        s.px(x, y, dark)
        s.px(x + 1, y + 1, hi)
    if kind == "hover":
        s.hline(0, 0, 18, "c")
        s.hline(0, 15, 18, "c")
        s.vline(0, 0, 16, "c")
        s.vline(17, 0, 16, "c")
    return s


def awning():
    """Stall awning, 20x17, tiles sideways: faded rust and canvas stripes, scalloped hem."""
    s = Spr(20, 17)
    s.hline(0, 0, 20, "k")
    s.hline(0, 1, 20, "l")
    s.hline(0, 2, 20, "g")
    s.hline(0, 3, 20, "k")
    for stripe in range(2):
        x0 = stripe * 10
        lo, mid, hi = ("r", "R", "o") if stripe == 0 else ("l", "w", "W")
        for x in range(10):
            depth = 11 + int(round(math.sqrt(max(0.0, 25 - (x - 4.5) ** 2)) * 0.9))
            for y in range(4, depth):
                key = hi if y == 4 else (lo if y >= depth - 2 else mid)
                if x == 0 and y < depth - 2:
                    key = lo
                s.px(x0 + x, y, key)
            s.px(x0 + x, depth, "k")
    return s


def tray():
    """Shallow recess for the wallet, 12x12, 9-slice 4."""
    s = Spr(12, 12)
    for y in range(12):
        for x in range(12):
            raw(s, x, y, (12, 9, 12, 220))
    s.hline(0, 0, 12, "k")
    s.vline(0, 0, 12, "k")
    s.hline(1, 1, 11, "z")
    s.hline(0, 11, 12, "g")
    s.vline(11, 0, 12, "m")
    return s


def item_kit():
    s = Spr(24, 24)
    s.rect(3, 7, 18, 13, "x")
    s.rect(3, 7, 18, 2, "X")
    s.rect(3, 18, 18, 2, "r")
    s.vline(20, 7, 13, "r")
    s.rect(9, 3, 6, 4, "g")
    s.rect(10, 4, 4, 3, None)
    s.rect(10, 5, 4, 2, "k")
    s.rect(10, 11, 4, 6, "W")
    s.rect(8, 13, 8, 2, "W")
    s.px(10, 11, "w")
    for (x, y) in ((4, 9), (19, 9), (4, 17), (19, 17)):
        s.px(x, y, "y")
    s.hline(3, 10, 18, "R")
    s.rect(10, 11, 4, 6, "W")
    s.rect(8, 13, 8, 2, "W")
    s.outline("k")
    return s


def item_cell():
    s = Spr(24, 24)
    s.rect(9, 2, 6, 2, "l")
    s.rect(6, 4, 12, 17, "m")
    s.vline(6, 4, 17, "g")
    s.vline(7, 4, 17, "l")
    s.vline(17, 4, 17, "d")
    s.rect(6, 4, 12, 2, "B")
    s.hline(6, 4, 12, "y")
    s.rect(6, 19, 12, 2, "B")
    s.rect(9, 7, 6, 10, "s")
    s.rect(10, 8, 4, 8, "c")
    s.vline(10, 8, 8, "C")
    for y in (10, 13):
        s.hline(9, y, 6, "s")
    s.outline("k")
    return s


def item_map():
    s = Spr(24, 24)
    s.rect(4, 6, 16, 12, "w")
    s.hline(4, 6, 16, "W")
    s.vline(19, 6, 12, "l")
    s.hline(4, 17, 16, "l")
    s.line(6, 14, 9, 10, "e")
    s.line(9, 10, 13, 12, "e")
    s.line(13, 12, 17, 8, "e")
    s.rect(15, 8, 3, 2, "x")
    s.px(7, 9, "e"); s.px(8, 8, "e")
    s.rect(2, 4, 3, 16, "E")
    s.vline(2, 4, 16, "e")
    s.rect(19, 4, 3, 16, "E")
    s.vline(21, 4, 16, "e")
    s.hline(2, 4, 3, "w")
    s.hline(19, 4, 3, "w")
    s.rect(0, 11, 3, 2, "R")
    s.outline("k")
    return s


PAPER = (198, 178, 146)


def paper():
    """Parchment, 48x48, 9-slice 12 (centre tiles). Burnt, torn edges; faint speckle."""
    s = Spr(48, 48)
    rnd = random.Random(11)
    base = PAPER
    for y in range(48):
        for x in range(48):
            n = rnd.random()
            r, g, b = base
            if n < 0.08:
                r, g, b = r - 14, g - 14, b - 12
            elif n > 0.95:
                r, g, b = r + 8, g + 8, b + 6
            raw(s, x, y, (r, g, b, 255))
    for y in range(48):
        for x in range(48):
            d = min(x, y, 47 - x, 47 - y)
            if d < 6:
                jag = (x * 7 + y * 13) % 5
                if d == 0 or (d == 1 and jag < 2):
                    raw(s, x, y, (0, 0, 0, 0))
                    continue
                if d <= 2 or (d == 3 and jag < 3):
                    raw(s, x, y, PAL["e"] + (255,))
                elif d <= 4:
                    r, g, b, _ = s.img.getpixel((x, y))
                    raw(s, x, y, (r - 30, g - 32, b - 30, 255))
    return s


def banner():
    """Title ribbon, 24x15, 9-slice: left/right 8 (swallowtail ends), top 4, bottom 5."""
    s = Spr(24, 15)
    rows = [
        "........kkkkkkkk........",
        "kkkkkkkkyyyyyyyykkkkkkkk",
        "krrRRRkyRRRRRRRRykRRRrrk",
        ".krRRRkRRRRRRRRRRkRRRrk.",
        "..krRRkRRRRRRRRRRkRRrk..",
        "...krRkRRRRRRRRRRkRrk...",
        "...krRkRRRRRRRRRRkRrk...",
        "..krRRkRRRRRRRRRRkRRrk..",
        ".krRRRkRRRRRRRRRRkRRRrk.",
        "krrRRRkrRRRRRRRRrkRRRrrk",
        "kkkkkkkbyyyyyyyybkkkkkkk",
        ".......kkkkkkkkkk.......",
    ]
    s.ascii(0, 1, rows)
    s.hline(8, 3, 8, "o")
    return s


def compass():
    s = Spr(27, 31)
    cx, cy = 13, 17
    ring(s, cx + 0.5, cy + 0.5, 10.5, 11.5, lambda a, r: "e")
    for i in range(16):
        a = i * math.pi / 8
        if i % 2 == 0:
            s.px(int(cx + 0.5 + math.cos(a) * 9.4), int(cy + 0.5 + math.sin(a) * 9.4), "e")
    for (dx, dy) in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        for t in range(1, 10):
            w = max(0, 2 - t // 4)
            for o in range(-w, w + 1):
                px, py = cx + dx * t + (dy != 0) * o, cy + dy * t + (dx != 0) * o
                dark = o > 0 if dx == 0 else o < 0
                s.px(px, py, "k" if dark else "w")
    for (dx, dy) in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        for t in range(1, 5):
            s.px(cx + dx * t, cy + dy * t, "e")
    s.px(cx, cy, "y")
    s.ascii(cx - 2, 0, ["k...k", "kk..k", "k.k.k", "k..kk", "k...k"])
    return s


ICONS = ["dock", "shop", "boss", "miniboss", "exit", "town", "pin"]


def map_icons():
    """10x10 ink icons on the parchment, one frame each (order = ICONS)."""
    s = Spr(10, 12, len(ICONS))
    art = {
        "dock": [
            "...kkkk...",
            "..kkllkk..",
            "..kssssk..",
            "..kcCcck..",
            "..kcCcck..",
            "..kcCcck..",
            "..kcCcck..",
            "..kssssk..",
            "..kkkkkk..",
        ],
        "shop": [
            "...kkkk...",
            "....kk....",
            "...kRRk...",
            "..kyYyyk..",
            ".kyYyyyBk.",
            ".kyykkyBk.",
            ".kyyyyyBk.",
            "..kBBBBk..",
            "...kkkk...",
        ],
        "boss": [
            "..kkkkkk..",
            ".kWWWWWWk.",
            "kWWWWWWwwk",
            "kWkkWWkkwk",
            "kWkxWWkxwk",
            "kWWWkkWWwk",
            ".kwWWWWwk.",
            "..kWkWkk..",
            "..kkkkkk..",
        ],
        "miniboss": [
            "..kkkkk...",
            ".kyYYyyk..",
            "kyYyyyyBk.",
            "kyykkyyBk.",
            "kyykaaykk.",
            "kyyyyyBk..",
            ".kyyyBBk..",
            "..kBBBk...",
            "...kkk....",
        ],
        "exit": [
            "..kkkkk...",
            ".kEEEEEk..",
            "kEkkkkkEk.",
            "kEkYYYkEk.",
            "kEkkYYkEk.",
            "kEkkkYkEk.",
            "kEkkkkkEk.",
            "kkkkkkkkk.",
            "..........",
        ],
        "town": [
            "....k.....",
            "...kRk....",
            "..kRwRk...",
            ".kRwRwRk..",
            "kRwRkRwRk.",
            "kRwkkkwRk.",
            "kkkkkkkkk.",
            "..........",
            "..........",
        ],
        "pin": [
            "...kkk....",
            "..kqqqk...",
            ".kqqqqqk..",
            ".kqcqcqk..",
            ".kqqqqqk..",
            "..kqqqk...",
            "...kqk....",
            "....k.....",
            "..........",
        ],
    }
    for i, name in enumerate(ICONS):
        s.frame(i)
        s.ascii(0, 0, art[name])
    return s


def tab(on):
    """Folder tab, 16x14. 9-slice: left/right 5, top 5, bottom 3. Open at the bottom when on."""
    s = Spr(16, 14)
    face, hi = ("q", "Q") if on else ("d", "m")
    rows = [
        "...kkkkkkkkkk...",
        "..kHHHHHHHHHHk..",
        ".kHFFFFFFFFFFFk.",
        "kHFFFFFFFFFFFFFk",
    ] + ["kHFFFFFFFFFFFFFk"] * 9 + ["kHFFFFFFFFFFFFFk" if on else "kkkkkkkkkkkkkkkk"]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "k":
                s.px(x, y, "k")
            elif ch == "H":
                s.px(x, y, hi)
            elif ch == "F":
                s.px(x, y, face)
    if on:
        s.hline(3, 0, 10, "c")
    return s


def frame():
    """The panel every menu sits in, 32x32, 9-slice 10: the shop card's iron plate
    and brass corner brackets at a bigger size, around the menus' deep blue-black."""
    s = Spr(32, 32)
    W = H = 32
    s.rect(0, 0, W, H, "k")
    s.rect(1, 1, W - 2, H - 2, "m")
    s.hline(1, 1, W - 2, "g")
    s.vline(1, 1, H - 2, "g")
    s.hline(1, H - 2, W - 2, "d")
    s.vline(W - 2, 1, H - 2, "d")
    s.rect(4, 4, W - 8, H - 8, "k")
    for y in range(5, H - 5):
        for x in range(5, W - 5):
            raw(s, x, y, (11, 13, 19, 246))
    s.hline(5, 5, W - 10, "d")
    for (x, y) in ((15, 2), (2, 15), (15, H - 3), (W - 3, 15)):
        rivet(s, x, y, "l", "k")
    arm = 8
    for cx, cy, fx, fy in ((0, 0, 1, 1), (W - 1, 0, -1, 1), (0, H - 1, 1, -1), (W - 1, H - 1, -1, -1)):
        for i in range(arm):
            for t in range(3):
                for (x, y, horiz) in ((cx + fx * i, cy + fy * t, True), (cx + fx * t, cy + fy * i, False)):
                    lit_side = (fy == 1) if horiz else (fx == 1)
                    key = ("Y" if t == 0 else "y") if lit_side else ("B" if t < 2 else "b")
                    s.px(x, y, key)
        for t in range(3):
            s.px(cx + fx * arm, cy + fy * t, "k")
            s.px(cx + fx * t, cy + fy * arm, "k")
        for i in range(3, arm + 1):
            s.px(cx + fx * i, cy + fy * 3, "k")
            s.px(cx + fx * 3, cy + fy * i, "k")
        rivet(s, cx + fx * 4 - (1 if fx < 0 else 0), cy + fy * 1 - (1 if fy < 0 else 0), "W", "b")
        rivet(s, cx + fx * 1 - (1 if fx < 0 else 0), cy + fy * 4 - (1 if fy < 0 else 0), "W", "b")
    return s


def nameplate():
    """Engraved brass nameplate for headings, 20x16, 9-slice 6 (screw heads in the ends)."""
    s = Spr(20, 16)
    s.rect(0, 0, 20, 16, "k")
    s.rect(1, 1, 18, 14, "y")
    s.hline(1, 1, 18, "Y")
    s.vline(1, 1, 14, "Y")
    s.hline(1, 14, 18, "B")
    s.vline(18, 1, 14, "B")
    s.hline(2, 13, 16, "B")
    for (x, y) in ((3, 7), (15, 7)):
        s.rect(x, y - 1, 2, 3, "b")
        s.px(x, y - 1, "Y")
        s.px(x + 1, y, "k")
    return s


def keycap():
    """A key on a salvaged keyboard, 14x14, 9-slice 4 (bottom 6: the key's front face)."""
    s = Spr(14, 14)
    s.rect(0, 0, 14, 14, "k")
    s.rect(1, 1, 12, 8, "l")
    s.hline(1, 1, 12, "w")
    s.vline(1, 1, 8, "w")
    s.rect(1, 9, 12, 3, "g")
    s.hline(1, 12, 12, "m")
    s.vline(12, 1, 8, "g")
    return s


def check(done):
    """Objective checkbox, 9x9: an empty brass box or one with a cyan tick."""
    s = Spr(9, 9)
    s.rect(0, 0, 9, 9, "k")
    s.rect(1, 1, 7, 7, "B")
    s.rect(2, 2, 5, 5, "z")
    if done:
        for (x, y) in ((2, 4), (3, 5), (4, 6), (5, 5), (6, 4), (7, 3), (8, 2)):
            s.px(x, y, "c")
            s.px(x, y - 1, "C")
    return s


if __name__ == "__main__":
    for kind, name in (("normal", "card"), ("sel", "card_sel"), ("off", "card_off")):
        card(kind).save(os.path.join(OUT, name + ".png"))
    well().save(os.path.join(OUT, "well.png"))
    tag().save(os.path.join(OUT, "tag.png"))
    stamp().save(os.path.join(OUT, "stamp.png"))
    case().save(os.path.join(OUT, "case.png"))
    pedestal().save(os.path.join(OUT, "pedestal.png"))
    for kind in ("normal", "hover", "off"):
        button(kind).save(os.path.join(OUT, "btn.png" if kind == "normal" else "btn_%s.png" % kind))
    awning().save(os.path.join(OUT, "awning.png"))
    tray().save(os.path.join(OUT, "tray.png"))
    item_kit().save(os.path.join(OUT, "item_kit.png"))
    item_cell().save(os.path.join(OUT, "item_cell.png"))
    item_map().save(os.path.join(OUT, "item_map.png"))
    paper().save(os.path.join(OUT, "map", "paper.png"))
    banner().save(os.path.join(OUT, "map", "banner.png"))
    compass().save(os.path.join(OUT, "map", "compass.png"))
    map_icons().save(os.path.join(OUT, "map", "icons.png"))
    tab(False).save(os.path.join(OUT, "tab.png"))
    tab(True).save(os.path.join(OUT, "tab_on.png"))
    frame().save(os.path.join(OUT, "frame.png"))
    nameplate().save(os.path.join(OUT, "nameplate.png"))
    keycap().save(os.path.join(OUT, "keycap.png"))
    check(False).save(os.path.join(OUT, "check_off.png"))
    check(True).save(os.path.join(OUT, "check_on.png"))
    print("ui art written")
