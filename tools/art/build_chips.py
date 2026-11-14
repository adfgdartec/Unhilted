"""Port sockets and chip emblems for the loadout screen.
Run from the project root:  python3 tools/art/build_chips.py

Chips are 28x28 brass-rimmed discs (like a coin you press into a socket);
each emblem is drawn on its own 16x16 layer, outlined, then set into the
disc face. Sockets are 32x32 so a seated chip leaves a 2 px ring of brass.
Light comes from the top-left, like every other asset.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr, PAL

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui")
os.makedirs(os.path.join(OUT, "chips"), exist_ok=True)


def ring(s, cx, cy, r0, r1, key_fn):
    """Fill the annulus r0 <= r < r1; key_fn(angle, r) picks the colour (None = skip)."""
    for y in range(s.h):
        for x in range(s.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r0 <= r < r1:
                k = key_fn(math.atan2(dy, dx), r)
                if k:
                    s.px(x, y, k)


def lit(angle):
    """-1 (facing the top-left light) .. 1 (bottom-right, in shadow)."""
    return math.cos(angle - math.pi / 4)


def disc():
    s = Spr(28, 28)
    c = 14.0
    ring(s, c, c, 0, 11, lambda a, r: "d" if (lit(a) < -0.4 and r > 7) else "z")
    def rim(a, r):
        l = lit(a)
        if r >= 12.5:
            return "b"
        if l < -0.55:
            return "Y" if r < 11.8 else "y"
        if l < 0.2:
            return "y" if r < 11.8 else "B"
        return "B" if r < 11.8 else "b"
    ring(s, c, c, 11, 13.5, rim)
    ring(s, c, c, 10.4, 11, lambda a, r: "k" if lit(a) < 0 else "m")
    for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        x, y = int(c + math.cos(a) * 12.4), int(c + math.sin(a) * 12.4)
        s.px(x, y, "k")
    s.outline("k")
    return s


def set_emblem(base, emblem):
    """Centre a 16x16 emblem on the disc and add a faint glow of its main colour."""
    ox, oy = 6, 6
    for y in range(16):
        for x in range(16):
            px = emblem.get(x, y)
            if px[3]:
                base.img.putpixel((ox + x, oy + y), px)
    return base


def emb():
    return Spr(16, 16)


def long_tether():
    e = emb()
    cx, cy = 6.5, 9.5
    pts = []
    for i in range(80):
        t = i / 79
        a = t * math.pi * 2 * 1.7
        r = 0.8 + t * 4.6
        pts.append((round(cx + math.cos(a) * r), round(cy + math.sin(a) * r)))
    for i, (x, y) in enumerate(pts):
        e.px(x, y, "c" if i % 9 else "C")
    ex, ey = pts[-1]
    e.line(ex, ey, 11, 4, "c")
    e.ascii(10, 0, [
        "..CW.",
        ".CWWC",
        "CWWc.",
        ".Cc..",
    ])
    e.outline("k")
    return e


def magnet_coil():
    e = emb()
    cx, cy = 8.0, 8.5
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            in_arc = dy >= 0 and 2.6 <= r < 5.6
            in_leg = dy < 0 and (2.6 <= abs(dx) < 5.6) and y >= 3
            if in_arc or in_leg:
                key = "A" if (r < 3.6 if in_arc else abs(dx) < 3.6) else "a"
                if in_leg and y <= 4:
                    key = "W"
                e.px(x, y, key)
    for y in range(5, 15):
        for x in range(9, 15):
            if e.get(x, y)[3] and e.get(x + 1, y)[3] == 0:
                e.px(x, y, "o")
    e.px(8, 1, "A")
    e.px(7, 2, "a")
    e.px(9, 2, "a")
    e.px(5, 0, "A")
    e.px(11, 0, "A")
    e.outline("k")
    return e


def recall_saw():
    e = emb()
    cx, cy = 8.0, 8.0
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = (a / (math.pi * 2) * 8) % 1.0
            if r < 4.8:
                e.px(x, y, "X" if (lit(a) < -0.3 and r > 2.8) else "x")
            elif tooth < 0.6 and r < 4.8 + 2.8 * (1.0 - tooth / 0.6):
                e.px(x, y, "W" if lit(a) < -0.5 else ("X" if lit(a) < 0.3 else "x"))
    e.ellipse(8, 8, 1.6, 1.6, "k")
    e.px(7, 7, "l")
    e.outline("k")
    return e


def reflex_core():
    e = emb()
    rows = [
        "..vvvvvvvvvv..",
        ".vVVVVVVVVVvv.",
        ".vVVvvvvvvvvv.",
        ".vVvvvvvvvvvv.",
        ".vVvvvvvvvvvv.",
        ".vVvvvvvvvvvv.",
        ".vvvvvvvvvvvv.",
        "..vvvvvvvvvv..",
        "..vvvvvvvvvv..",
        "...vvvvvvvv...",
        "....vvvvvv....",
        ".....vvvv.....",
        "......vv......",
    ]
    e.ascii(1, 1, rows)
    e.ascii(5, 3, [
        "WWWWWW",
        ".WAAW.",
        "..WW..",
        "..WW..",
        ".WAAW.",
        "WWWWWW",
    ])
    e.outline("k")
    return e


def scrap_plating():
    e = emb()
    e.rect(2, 2, 12, 12, "g")
    e.rect(2, 2, 12, 1, "w")
    e.rect(2, 2, 1, 12, "l")
    e.rect(2, 13, 12, 1, "m")
    e.rect(13, 2, 1, 12, "m")
    for x, y in [(2, 2), (13, 2), (2, 13), (13, 13)]:
        e.px(x, y, None)
    for x, y in [(4, 4), (11, 4), (4, 11), (11, 11)]:
        e.px(x, y, "W")
        e.px(x + 1, y + 1, "m")
    e.rect(6, 5, 4, 7, "s")
    e.rect(7, 4, 2, 1, "s")
    e.rect(7, 6, 2, 5, "c")
    e.rect(6, 8, 4, 1, "C")
    e.rect(7, 7, 2, 3, "C")
    e.outline("k")
    return e


def steam_vent():
    e = emb()
    cx, cy = 8.0, 10.5
    ring(e, cx, cy, 3.6, 5.2, lambda a, r: "y" if lit(a) < 0 else "B")
    for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        for d in range(1, 4):
            e.px(int(cx + math.cos(a) * d), int(cy + math.sin(a) * d), "B")
    e.px(7, 10, "Y")
    e.px(8, 10, "y")
    for (px, py, r) in [(5.5, 4.0, 2.2), (9.5, 2.6, 2.0), (12.2, 4.6, 1.5)]:
        e.ellipse(px, py, r, r * 0.85, "w")
        e.ellipse(px - 0.6, py - 0.6, r * 0.6, r * 0.5, "W")
    e.outline("k")
    return e


def piston_heart():
    e = emb()
    e.rect(5, 6, 6, 9, "g")
    e.rect(5, 6, 1, 9, "l")
    e.rect(10, 6, 1, 9, "m")
    e.rect(6, 2, 4, 5, "w")
    e.rect(6, 2, 4, 1, "W")
    e.rect(7, 0, 2, 2, "c")
    e.rect(4, 10, 8, 1, "d")
    e.rect(4, 13, 8, 1, "d")
    e.px(12, 3, "C"); e.px(13, 2, "c"); e.px(3, 4, "c"); e.px(2, 3, "C")
    e.outline("k")
    return e


def piston_legs():
    e = emb()
    e.rect(6, 1, 4, 5, "g")
    e.rect(6, 1, 1, 5, "l")
    for y in (7, 9, 11):
        e.rect(5, y, 6, 1, "y")
        e.px(5, y, "B")
    e.rect(7, 6, 2, 7, "m")
    e.rect(4, 13, 8, 2, "d")
    e.rect(4, 13, 8, 1, "l")
    e.px(12, 4, "Y"); e.px(13, 3, "y"); e.px(3, 5, "Y")
    e.outline("k")
    return e


def ball_bearings():
    e = emb()
    e.ellipse(8, 8, 6, 6, "B")
    e.ellipse(8, 8, 4, 4, None)
    for (x, y) in ((8, 3), (12, 6), (11, 11), (5, 11), (4, 6)):
        e.ellipse(x, y, 1.5, 1.5, "w")
        e.px(x - 1, y - 1, "W")
    e.px(3, 2, "c"); e.px(13, 13, "c")
    e.outline("k")
    return e


EMBLEMS = {
    "piston_legs": piston_legs,
    "ball_bearings": ball_bearings,
    "piston_heart": piston_heart,
    "long_tether": long_tether,
    "magnet_coil": magnet_coil,
    "recall_saw": recall_saw,
    "reflex_core": reflex_core,
    "scrap_plating": scrap_plating,
    "steam_vent": steam_vent,
}


def socket(kind):
    s = Spr(32, 32)
    c = 16.0
    def collar(a, r):
        l = lit(a)
        if r >= 15.0:
            return "k"
        return "g" if l < -0.5 else ("m" if l < 0.4 else "d")
    ring(s, c, c, 13.5, 16, collar)
    ring(s, c, c, 0, 13.5, lambda a, r: "k" if (r > 11.5 and lit(a) < 0.2) else "z")
    contact = {"empty": "m", "lit": "c", "over": "x", "locked": None}[kind]
    if contact:
        for i in range(8):
            a = i * math.pi / 4
            x, y = int(c + math.cos(a) * 12.4), int(c + math.sin(a) * 12.4)
            s.px(x, y, contact)
            if kind != "empty":
                s.px(int(c + math.cos(a) * 13.4), int(c + math.sin(a) * 13.4), "C" if kind == "lit" else "X")
    if kind == "locked":
        ring(s, c, c, 0, 12, lambda a, r: "g" if lit(a) < -0.3 else "m")
        ring(s, c, c, 11, 12, lambda a, r: "k")
        s.hline(7, 16, 18, "k")
        s.hline(7, 15, 18, "l")
        for x, y in [(11, 10), (20, 21)]:
            s.ellipse(x, y, 1.6, 1.6, "w")
            s.px(x - 1, y, "d")
            s.px(x, y, "d")
            s.px(x + 1, y, "d")
    return s


def conduit():
    """Short lit bridge drawn between two sockets used by one 2-port chip."""
    s = Spr(12, 6)
    s.rect(0, 1, 12, 4, "s")
    s.rect(0, 2, 12, 1, "c")
    s.rect(0, 3, 12, 1, "C")
    s.outline("k")
    return s


if __name__ == "__main__":
    for name, fn in EMBLEMS.items():
        set_emblem(disc(), fn()).save(os.path.join(OUT, "chips", name + ".png"))
    for kind in ("empty", "lit", "over", "locked"):
        socket(kind).save(os.path.join(OUT, "socket_%s.png" % kind))
    conduit().save(os.path.join(OUT, "socket_conduit.png"))
    print("chips and sockets written")
