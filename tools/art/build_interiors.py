"""Art for the walk-in buildings (top-down, Undertale style) and their shopfronts in the camp.
Run from the project root:  python3 tools/art/build_interiors.py

Same palette and rules as every other asset (pix.py): light from the top-left,
dark outlines on objects, brass for old-world things, cyan only for robot tech.
Interiors are drawn at 1:1 in pixels, seen from above with the back wall facing you.

Surfaces (tile seamlessly):  floor_plate / floor_planks / floor_concrete (32x32)
                             wall_corrugated / wall_boards / wall_brick (32x64)
Furniture (front-facing, standing on the floor):
    shelf, shelf_b, counter, crates, desk, globe, bench, robot_frame, engine, stool, papers
Wall decals: window, map_a, map_b, pegboard, poster
Floor decals: rug, doormat
Camp shopfronts (2D side view, feet on the bottom row): front_rusty, front_dot, front_mags
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr, PAL

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "interiors")
FRONTS = os.path.join(ROOT, "art", "props")
os.makedirs(OUT, exist_ok=True)


def raw(s, x, y, rgba):
    if 0 <= x < s.w and 0 <= y < s.h:
        s.img.putpixel((s.f * s.w + x, y), rgba)


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k))) for c in rgb)


def save(s, name, folder=OUT):
    s.save(os.path.join(folder, name + ".png"))


def floor_plate():
    """Diamond-plate steel, scuffed, with rust blooming at the seams."""
    s = Spr(32, 32)
    s.rect(0, 0, 32, 32, "m")
    for y in range(0, 32, 8):
        for x in range(0, 32, 8):
            ox = 4 if (y // 8) % 2 else 0
            cx, cy = (x + ox) % 32, y
            s.px(cx + 2, cy + 3, "l", wrap=True)
            s.px(cx + 3, cy + 2, "l", wrap=True)
            s.px(cx + 3, cy + 4, "d", wrap=True)
            s.px(cx + 4, cy + 3, "d", wrap=True)
    s.hline(0, 0, 32, "d")
    s.vline(0, 0, 32, "d")
    s.hline(0, 16, 32, "d")
    s.vline(16, 0, 32, "d")
    rnd = random.Random(3)
    for _ in range(40):
        x, y = rnd.randrange(32), rnd.randrange(32)
        s.px(x, y, rnd.choice(["r", "R", "g"]), alpha=120)
    for (x, y) in ((1, 1), (17, 1), (1, 17), (17, 17)):
        s.px(x, y, "w")
    return s


def floor_planks():
    s = Spr(32, 32)
    rnd = random.Random(5)
    for row in range(4):
        y0 = row * 8
        tone = ["e", "E", "e", "E"][row]
        s.rect(0, y0, 32, 8, tone)
        s.hline(0, y0, 32, "r")
        cut = (row * 13 + 7) % 32
        s.vline(cut, y0, 8, "r")
        for _ in range(5):
            x = rnd.randrange(32)
            s.hline(x, y0 + rnd.randrange(2, 7), rnd.randrange(3, 8), "b" if tone == "E" else "r")
        s.px((cut + 3) % 32, y0 + 3, "k", alpha=160)
    return s


def floor_concrete():
    s = Spr(32, 32)
    rnd = random.Random(9)
    s.rect(0, 0, 32, 32, "g")
    for _ in range(90):
        s.px(rnd.randrange(32), rnd.randrange(32), rnd.choice(["m", "l", "m"]))
    s.hline(0, 0, 32, "m")
    s.vline(0, 0, 32, "m")
    for y in range(32):
        for x in range(32):
            d = math.hypot(min(abs(x - 22), 32 - abs(x - 22)), min(abs(y - 20), 32 - abs(y - 20)))
            if d < 5.5:
                s.px(x, y, "z" if d < 3.5 else "d", alpha=150)
    return s


WH = 64


def wall_corrugated():
    """Rusty's shop: corrugated sheet steel, a beam along the top, rust streaks."""
    s = Spr(32, WH)
    for x in range(32):
        s.vline(x, 0, WH, ["l", "g", "m", "g"][x % 4])
    rnd = random.Random(2)
    for x0 in (5, 18, 27):
        top = rnd.randrange(8, 26)
        for y in range(top, top + rnd.randrange(12, 30)):
            s.px(x0, y, "R", alpha=170)
            if rnd.random() < 0.5:
                s.px(x0 + 1, y, "r", alpha=120)
    s.rect(0, 0, 32, 6, "e")
    s.hline(0, 0, 32, "E")
    s.hline(0, 6, 32, "k")
    s.rect(0, WH - 7, 32, 7, "d")
    s.hline(0, WH - 7, 32, "k")
    for x in range(2, 32, 8):
        s.px(x, 2, "y")
        s.px(x, 3, "b")
    return s


def wall_boards():
    """Dot's house: tall boards over a darker wainscot."""
    s = Spr(32, WH)
    top = WH - 18
    for b in range(4):
        x0 = b * 8
        s.rect(x0, 0, 8, top, "E" if b % 2 else "e")
        s.vline(x0, 0, top, "r")
        s.px(x0 + 3, 5, "k")
        s.px(x0 + 3, top - 5, "k")
    s.rect(0, top, 32, 18, "r")
    s.hline(0, top, 32, "o")
    s.hline(0, top + 1, 32, "R")
    for b in range(4):
        s.rect(b * 8 + 2, top + 5, 4, 9, "R")
    s.hline(0, WH - 1, 32, "k")
    return s


def wall_brick():
    """Mags' garage: sooty brick with a pipe along the top."""
    s = Spr(32, WH)
    s.rect(0, 0, 32, WH, "d")
    for row in range(WH // 6 + 1):
        y0 = row * 6
        off = 4 if row % 2 else 0
        for bx in range(-1, 4):
            x0 = bx * 8 + off
            s.rect(x0 + 1, y0 + 1, 7, 5, "r" if (row + bx) % 3 else "R")
            s.hline(x0 + 1, y0 + 1, 7, "R" if (row + bx) % 3 else "o")
    for y in range(0, 26):
        for x in range(32):
            if (x * 7 + y * 3) % 11 < (26 - y) // 3:
                s.px(x, y, "k", alpha=90)
    s.rect(0, 10, 32, 4, "g")
    s.hline(0, 10, 32, "l")
    s.hline(0, 13, 32, "m")
    s.rect(14, 9, 3, 6, "B")
    return s


def shelf(variant):
    s = Spr(48, 60)
    s.rect(2, 2, 3, 58, "e")
    s.rect(43, 2, 3, 58, "e")
    s.vline(2, 2, 58, "E")
    s.vline(43, 2, 58, "E")
    for y in (14, 30, 46, 58):
        s.rect(2, y, 44, 2, "E")
        s.hline(2, y + 2, 44, "r")
    rnd = random.Random(variant)
    for shelf_y in (14, 30, 46, 58):
        x = 6
        while x < 40:
            kind = rnd.randrange(6)
            if kind == 0:
                s.rect(x, shelf_y - 6, 4, 6, "l"); s.hline(x, shelf_y - 6, 4, "w"); s.hline(x, shelf_y - 3, 4, "x"); x += 6
            elif kind == 1:
                s.ellipse(x + 3, shelf_y - 4, 3, 3, "B"); s.px(x + 3, shelf_y - 4, "k"); s.px(x + 1, shelf_y - 6, "y"); x += 8
            elif kind == 2:
                s.rect(x + 1, shelf_y - 8, 2, 8, "t"); s.px(x + 1, shelf_y - 8, "T"); s.rect(x + 1, shelf_y - 10, 2, 2, "s"); x += 5
            elif kind == 3:
                s.rect(x, shelf_y - 7, 8, 7, "e"); s.rect(x + 1, shelf_y - 6, 3, 3, "k"); s.px(x + 6, shelf_y - 5, "a"); x += 10
            elif kind == 4:
                s.ellipse(x + 3, shelf_y - 3, 3, 2, "z"); s.ellipse(x + 3, shelf_y - 3, 1, 1, "d"); x += 7
            else:
                s.rect(x, shelf_y - 5, 5, 5, "w"); s.rect(x + 1, shelf_y - 4, 3, 2, "A"); x += 7
    s.outline("k")
    return s


def counter():
    """Rusty's counter: a corrugated front under a worn wooden top, a till and a scale on it."""
    s = Spr(84, 40)
    for x in range(2, 82):
        s.vline(x, 18, 20, ["g", "m", "d", "m"][x % 4])
    s.hline(2, 37, 80, "k")
    s.rect(0, 13, 84, 5, "E")
    s.hline(0, 13, 84, "o")
    s.hline(0, 17, 84, "r")
    s.rect(52, 2, 18, 11, "B")
    s.hline(52, 2, 18, "y")
    s.rect(54, 4, 9, 3, "k")
    s.px(55, 5, "a"); s.px(57, 5, "a"); s.px(59, 5, "a")
    for i in range(4):
        s.px(55 + i * 3, 9, "Y")
    s.rect(50, 11, 22, 2, "b")
    s.rect(18, 9, 12, 2, "l")
    s.vline(23, 4, 5, "g")
    s.hline(14, 4, 20, "g")
    s.rect(14, 5, 5, 2, "B")
    s.rect(29, 5, 5, 2, "B")
    for i, ch in enumerate([[1, 1, 1], [1, 0, 0], [1, 1, 1], [0, 0, 1], [1, 1, 1]]):
        for j, on in enumerate(ch):
            if on:
                s.px(8 + j, 23 + i, "O")
    s.outline("k")
    return s


def crates():
    s = Spr(36, 38)
    def crate(x, y, w, h):
        s.rect(x, y, w, h, "E")
        s.rect(x, y, w, 2, "o")
        s.rect(x, y + h - 2, w, 2, "r")
        s.line(x + 1, y + 2, x + w - 2, y + h - 3, "e")
        s.vline(x, y, h, "e")
        s.vline(x + w - 1, y, h, "r")
    crate(0, 18, 20, 20)
    crate(17, 22, 18, 16)
    crate(5, 2, 18, 16)
    s.outline("k")
    return s


def desk():
    """Dot's desk: map sheets, an ink pot, a lamp and a stack of rolled maps."""
    s = Spr(70, 36)
    s.rect(2, 12, 66, 4, "E")
    s.hline(2, 12, 66, "o")
    s.rect(4, 16, 4, 20, "e")
    s.rect(62, 16, 4, 20, "e")
    s.rect(36, 16, 24, 12, "e")
    s.rect(38, 18, 20, 3, "r"); s.px(47, 19, "y")
    s.rect(38, 23, 20, 3, "r"); s.px(47, 24, "y")
    s.rect(10, 7, 22, 5, "w")
    s.line(12, 10, 18, 8, "e"); s.line(18, 8, 24, 10, "e"); s.rect(26, 8, 2, 2, "x")
    s.rect(34, 8, 4, 4, "k"); s.px(35, 8, "s")
    s.line(37, 4, 39, 9, "w")
    s.rect(50, 0, 3, 12, "l")
    s.rect(46, 0, 10, 3, "B")
    s.rect(47, 3, 8, 1, "A")
    for i in range(3):
        s.rect(58 + i * 3, 6, 3, 6, "w"); s.px(59 + i * 3, 6, "l")
    s.outline("k")
    return s


def globe():
    s = Spr(26, 36)
    s.ellipse(12, 12, 10, 10, "s")
    for (x, y, w) in ((7, 6, 6), (5, 9, 9), (12, 13, 7), (9, 17, 5)):
        s.hline(x, y, w, "Q")
        s.hline(x + 1, y + 1, w - 2, "q")
    s.px(8, 6, "S"); s.px(9, 5, "S")
    s.line(2, 12, 22, 12, "B")
    s.vline(12, 1, 22, "B")
    s.rect(11, 22, 3, 8, "e")
    s.rect(6, 30, 13, 3, "e")
    s.hline(6, 30, 13, "E")
    s.outline("k")
    return s


def papers():
    s = Spr(22, 14)
    s.rect(1, 6, 18, 8, "w")
    s.rect(3, 3, 16, 4, "l")
    s.rect(4, 1, 14, 3, "w")
    s.hline(1, 9, 18, "l")
    s.hline(4, 2, 10, "e")
    s.outline("k")
    return s


def stool():
    s = Spr(16, 18)
    s.rect(1, 3, 14, 3, "E")
    s.hline(1, 3, 14, "o")
    s.line(3, 6, 1, 17, "e")
    s.line(12, 6, 14, 17, "e")
    s.hline(3, 12, 10, "e")
    s.outline("k")
    return s


def bench():
    """Mags' workbench: a vise, a half-stripped motor, hand tools."""
    s = Spr(78, 38)
    s.rect(2, 14, 74, 5, "e")
    s.hline(2, 14, 74, "E")
    s.rect(4, 19, 4, 19, "m")
    s.rect(70, 19, 4, 19, "m")
    s.rect(4, 30, 70, 2, "d")
    s.rect(10, 4, 10, 10, "g")
    s.rect(8, 8, 14, 3, "l")
    s.hline(6, 6, 18, "B")
    s.rect(30, 5, 16, 9, "m")
    s.ellipse(38, 9, 4, 4, "d")
    s.ellipse(38, 9, 2, 2, "B")
    s.rect(46, 8, 4, 2, "l")
    s.line(52, 12, 60, 8, "l")
    s.rect(60, 7, 3, 3, "l")
    s.rect(64, 10, 7, 4, "x")
    s.hline(64, 10, 7, "X")
    s.rect(26, 33, 10, 5, "e")
    s.outline("k")
    return s


def robot_frame():
    """A half-built robot on a stand: Mags' side project. Its eye is dark."""
    s = Spr(34, 50)
    s.rect(15, 34, 4, 12, "g")
    s.rect(9, 46, 16, 3, "d")
    s.rect(7, 12, 20, 22, "m")
    s.hline(7, 12, 20, "l")
    s.vline(7, 12, 22, "l")
    s.rect(10, 18, 14, 10, "d")
    for y in (20, 23, 26):
        s.hline(11, y, 12, "B")
    s.rect(10, 0, 14, 11, "g")
    s.hline(10, 0, 14, "l")
    s.rect(12, 4, 10, 4, "z")
    s.px(15, 5, "s"); s.px(18, 5, "s")
    s.rect(1, 13, 6, 3, "g")
    s.rect(1, 16, 3, 10, "g")
    s.line(27, 14, 31, 20, "z")
    s.line(27, 16, 30, 23, "x")
    s.outline("k")
    return s


def engine():
    s = Spr(34, 26)
    s.rect(2, 6, 30, 18, "m")
    s.hline(2, 6, 30, "l")
    for x in range(5, 30, 6):
        s.rect(x, 2, 4, 6, "g")
        s.hline(x, 2, 4, "l")
    s.rect(4, 12, 26, 2, "d")
    s.ellipse(9, 18, 3, 3, "d"); s.ellipse(9, 18, 1, 1, "B")
    s.rect(18, 16, 10, 5, "x")
    s.outline("k")
    return s


def window():
    s = Spr(34, 26)
    s.rect(0, 0, 34, 26, "e")
    s.rect(2, 2, 30, 22, "4")
    for y in range(2, 24):
        key = "4" if y < 9 else ("7" if y < 16 else "o")
        s.hline(2, y, 30, key)
    for (x, h) in ((3, 6), (7, 9), (11, 4), (15, 12), (19, 7), (23, 10), (27, 5)):
        s.rect(x, 24 - h, 4, h, "2")
        s.px(x + 1, 24 - h + 2, "a")
    s.vline(16, 2, 22, "e")
    s.hline(2, 12, 30, "e")
    s.hline(0, 25, 34, "E")
    s.outline("k")
    return s


def wall_map(seed, w, h):
    s = Spr(w, h)
    s.rect(1, 1, w - 2, h - 2, "w")
    rnd = random.Random(seed)
    x, y = 3, h // 2
    for _ in range(6):
        nx, ny = min(w - 4, x + rnd.randrange(2, 5)), max(3, min(h - 4, y + rnd.randrange(-3, 4)))
        s.line(x, y, nx, ny, "e")
        x, y = nx, ny
    for _ in range(3):
        rx, ry = rnd.randrange(3, w - 6), rnd.randrange(3, h - 5)
        s.rect(rx, ry, 3, 2, "e")
    s.px(rnd.randrange(3, w - 3), rnd.randrange(3, h - 3), "x")
    s.px(w // 2, 0, "x")
    s.px(w // 2, 1, "X")
    s.outline("k")
    return s


def pegboard():
    s = Spr(52, 34)
    s.rect(1, 1, 50, 32, "E")
    for y in range(4, 32, 4):
        for x in range(4, 50, 4):
            s.px(x, y, "e")
    s.line(6, 6, 6, 22, "l"); s.rect(4, 4, 5, 3, "l")
    s.line(14, 6, 20, 20, "l"); s.rect(19, 19, 3, 3, "l")
    s.rect(26, 6, 3, 14, "x"); s.rect(26, 20, 3, 4, "l")
    s.ellipse(38, 12, 6, 6, "z"); s.ellipse(38, 12, 3, 3, "E")
    s.rect(44, 22, 5, 8, "y")
    s.outline("k")
    return s


def poster():
    s = Spr(22, 30)
    s.rect(1, 1, 20, 28, "W")
    s.rect(3, 3, 16, 14, "x")
    s.rect(7, 6, 8, 8, "k")
    s.rect(9, 8, 4, 4, "X")
    for y in (20, 23, 26):
        s.hline(4, y, 14, "g")
    s.line(2, 28, 20, 2, "k")
    s.outline("k")
    return s


def rug():
    s = Spr(64, 40)
    s.rect(0, 0, 64, 40, "x")
    s.rect(3, 3, 58, 34, "r")
    s.rect(6, 6, 52, 28, "x")
    for i in range(0, 52, 6):
        s.px(6 + i, 6, "a"); s.px(6 + i, 33, "a")
    s.ellipse(32, 20, 12, 8, "r")
    s.ellipse(32, 20, 6, 4, "a")
    for x in range(0, 64, 2):
        s.px(x, 0, "A")
        s.px(x, 39, "A")
    return s


def doormat():
    s = Spr(34, 14)
    s.rect(0, 0, 34, 14, "e")
    for x in range(1, 33):
        s.vline(x, 1, 12, "E" if x % 2 else "e")
    s.hline(0, 0, 34, "r")
    s.hline(0, 13, 34, "r")
    return s


def door(s, x, y, w, h):
    """A doorway with warm light spilling from inside."""
    s.rect(x, y, w, h, "k")
    s.rect(x + 1, y + 1, w - 2, h - 1, "a")
    s.rect(x + 2, y + 2, w - 4, h - 2, "A")
    s.rect(x + 1, y + h - 4, w - 2, 4, "o")
    s.vline(x, y, h, "e")
    s.vline(x + w - 1, y, h, "e")
    s.hline(x - 1, y - 1, w + 2, "E")


def front_rusty():
    """Rusty's: a shed of corrugated sheets with a bent awning and a hand-painted sign."""
    s = Spr(120, 92)
    for x in range(4, 116):
        s.vline(x, 30, 62, ["l", "g", "m", "g"][x % 4])
    rnd = random.Random(1)
    for x0 in (14, 40, 88, 104):
        for y in range(36, 36 + rnd.randrange(14, 30)):
            s.px(x0, y, "R", alpha=170)
    s.rect(2, 24, 116, 7, "e")
    s.hline(2, 24, 116, "E")
    for i in range(0, 116, 10):
        s.rect(2 + i, 31, 5, 8, "R")
        s.rect(7 + i, 31, 5, 8, "w")
    s.hline(2, 39, 116, "k")
    s.rect(18, 2, 84, 20, "E")
    s.rect(20, 4, 80, 16, "e")
    letters = {"R": ["110", "101", "110", "101", "101"], "U": ["101", "101", "101", "101", "111"],
               "S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"],
               "Y": ["101", "101", "010", "010", "010"], "'": ["1", "1", "0", "0", "0"]}
    x = 30
    for ch in "RUSTY'S":
        rows = letters[ch]
        for yy, row in enumerate(rows):
            for xx, on in enumerate(row):
                if on == "1":
                    s.rect(x + xx * 2, 7 + yy * 2, 2, 2, "O")
        x += len(rows[0]) * 2 + 3
    s.vline(30, 22, 2, "z"); s.vline(90, 22, 2, "z")
    door(s, 48, 54, 22, 38)
    s.rect(80, 50, 26, 18, "k")
    s.rect(81, 51, 24, 16, "a")
    s.rect(84, 58, 6, 9, "g"); s.rect(92, 55, 8, 12, "B"); s.px(95, 57, "k")
    s.rect(10, 74, 20, 18, "e")
    s.hline(10, 74, 20, "E")
    s.outline("k")
    return s


def front_dot():
    """Dot's: a narrow plank house on stilts of pipe, maps pinned all over the front."""
    s = Spr(96, 84)
    s.rect(6, 20, 84, 64, "e")
    for x in range(6, 90, 7):
        s.vline(x, 20, 64, "r")
    s.hline(6, 20, 84, "E")
    for y in range(4, 20):
        half = (y - 4) * 3
        s.hline(48 - half, y, half * 2, "m" if y % 2 else "g")
    s.hline(2, 19, 92, "k")
    for (mx, my, mw, mh) in ((10, 28, 16, 12), (66, 26, 18, 14), (14, 50, 14, 10), (70, 48, 14, 12)):
        s.rect(mx, my, mw, mh, "w")
        s.line(mx + 2, my + mh // 2, mx + mw - 3, my + 3, "e")
        s.px(mx + mw // 2, my, "x")
    door(s, 37, 46, 22, 38)
    s.rect(36, 30, 24, 10, "B")
    s.hline(36, 30, 24, "Y")
    s.vline(48, 31, 8, "k"); s.hline(42, 35, 13, "k"); s.px(48, 31, "x")
    s.outline("k")
    return s


def front_mags():
    """Mags': a brick garage with a roll-up door half open and a gear sign."""
    s = Spr(128, 84)
    s.rect(2, 16, 124, 68, "r")
    for row in range(11):
        y0 = 16 + row * 6
        off = 4 if row % 2 else 0
        for bx in range(-1, 17):
            x0 = 2 + bx * 8 + off
            s.rect(max(2, x0 + 1), y0 + 1, 7, 5, "R" if (row + bx) % 3 else "r")
    s.rect(0, 10, 128, 7, "m")
    s.hline(0, 10, 128, "l")
    s.rect(22, 34, 64, 50, "k")
    for y in range(34, 58, 3):
        s.hline(23, y, 62, "g" if y % 2 else "m")
    s.rect(23, 58, 62, 26, "a")
    s.rect(24, 60, 60, 24, "A")
    s.rect(30, 70, 20, 14, "m")
    s.ellipse(40, 76, 4, 4, "d")
    door(s, 96, 46, 20, 38)
    s.ellipse(64, 6, 7, 7, "B")
    s.ellipse(64, 6, 3, 3, "k")
    for a in range(8):
        ang = a * math.pi / 4
        s.px(int(64 + math.cos(ang) * 8), int(6 + math.sin(ang) * 8), "y")
    s.rect(4, 64, 12, 20, "m")
    s.hline(4, 70, 12, "x")
    s.outline("k")
    return s


if __name__ == "__main__":
    save(floor_plate(), "floor_plate")
    save(floor_planks(), "floor_planks")
    save(floor_concrete(), "floor_concrete")
    save(wall_corrugated(), "wall_corrugated")
    save(wall_boards(), "wall_boards")
    save(wall_brick(), "wall_brick")
    save(shelf(1), "shelf")
    save(shelf(7), "shelf_b")
    save(counter(), "counter")
    save(crates(), "crates")
    save(desk(), "desk")
    save(globe(), "globe")
    save(papers(), "papers")
    save(stool(), "stool")
    save(bench(), "bench")
    save(robot_frame(), "robot_frame")
    save(engine(), "engine")
    save(window(), "window")
    save(wall_map(4, 26, 20), "map_a")
    save(wall_map(8, 22, 24), "map_b")
    save(pegboard(), "pegboard")
    save(poster(), "poster")
    save(rug(), "rug")
    save(doormat(), "doormat")
    save(front_rusty(), "front_rusty", FRONTS)
    save(front_dot(), "front_dot", FRONTS)
    save(front_mags(), "front_mags", FRONTS)
    print("interior art written")
