"""Props, interactables, pickups, effects and UI textures.
Style rules (see STYLE.md): one palette, 1 px darkest outline on props and
items, no outlines on backdrops, light from the upper left, neon only where
something is powered.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art")


def out(*p):
    return os.path.join(OUT, *p)


def junk_mound(s, x0, x1, top, bottom, seed):
    """Irregular pile of scrap along the bottom of a sprite (buries things)."""
    rnd = random.Random(seed)
    for x in range(x0, x1):
        h = top + int(2 * math.sin(x * 0.7 + seed) + rnd.randint(0, 1))
        for y in range(h, bottom):
            s.px(x, y, "m" if y > h + 1 else "g")
    for _ in range((x1 - x0) // 4):
        x = rnd.randint(x0, x1 - 1)
        y = rnd.randint(top + 2, bottom - 1)
        s.px(x, y, rnd.choice(["l", "d", "R", "d"]))


def ancient_casing():
    """The robot's brass pod, cracked open where it woke. Old-world brass among modern junk."""
    s = Spr(50, 26)
    cx, cy, rx, ry = 23, 12, 19, 8
    for y in range(26):
        for x in range(50):
            if ((x - cx + 0.5) / rx) ** 2 + ((y - cy + 0.5) / ry) ** 2 <= 1.0:
                k = "B"
                if y < cy - 4:
                    k = "y"
                if y > cy + 3:
                    k = "b"
                s.px(x, y, k)
    for x in range(8, 38, 3):
        s.px(x, cy - 7, "Y")
    for rx_ in (12, 33):
        for y in range(cy - 7, cy + 8):
            if s.get(rx_, y)[3]:
                s.px(rx_, y, "b")
        s.px(rx_, cy - 5, "Y"); s.px(rx_, cy + 1, "Y")
    s.ellipse(41, cy, 3, 6, "k")
    s.px(41, cy - 1, "c"); s.px(40, cy, "c"); s.px(41, cy, "C"); s.px(42, cy + 2, "c")
    for (x, y) in ((19, 5), (20, 6), (20, 7), (21, 8), (22, 9), (22, 10), (23, 11)):
        s.px(x, y, "k")
    s.ellipse(46, 20, 3, 2, "B"); s.px(45, 19, "y")
    junk_mound(s, 2, 50, 18, 26, 3)
    s.outline().save(out("props", "ancient_casing.png"))


def crt_pile():
    s = Spr(36, 30, frames=2)
    for f in range(2):
        s.frame(f)
        s.rect(1, 16, 20, 14, "g"); s.hline(1, 16, 20, "l")
        s.rect(3, 18, 12, 9, "s")
        for y in range(18, 27, 2):
            s.hline(3, y + f % 2, 12, "S")
        s.rect(17, 19, 2, 1, "l"); s.rect(17, 22, 2, 1, "l")
        s.rect(20, 21, 15, 9, "m"); s.rect(22, 23, 9, 5, "k")
        s.line(23, 23, 27, 27, "d")
        s.rect(6, 6, 16, 10, "g"); s.hline(6, 6, 16, "l")
        s.rect(8, 8, 10, 6, "s"); s.px(9, 9, "S"); s.px(10, 9, "S")
        s.line(11, 6, 8, 1, "l"); s.line(15, 6, 19, 2, "l")
    s.outline().save(out("props", "crt_pile.png"))


def tyres():
    s = Spr(24, 14)
    for cy in (9, 4):
        s.ellipse(12, cy, 10, 3.5, "d")
        for x in range(3, 22, 2):
            s.px(x, cy + 2, "m"); s.px(x, cy - 2, "g")
        s.ellipse(12, cy, 4.5, 1.2, "k")
        s.hline(9, cy - 1, 6, "m")
    s.outline().save(out("props", "tyres.png"))


def barrel():
    s = Spr(16, 20)
    s.rect(2, 4, 12, 15, "R")
    s.hline(2, 8, 12, "r"); s.hline(2, 14, 12, "r")
    s.vline(4, 4, 15, "O"); s.vline(5, 4, 15, "o")
    s.ellipse(8, 4, 6, 2.2, "o"); s.ellipse(8, 4, 4, 1, "k")
    s.px(13, 11, "T"); s.px(13, 12, "T"); s.px(14, 18, "T"); s.px(15, 18, "t")
    s.outline().save(out("props", "barrel.png"))


def car_cube():
    s = Spr(36, 26)
    bands = [("x", 5), ("m", 3), ("s", 3), ("R", 5), ("g", 3), ("x", 4)]
    y = 1
    for key, h in bands:
        s.rect(1, y, 34, h, key)
        y += h
    rnd = random.Random(5)
    for _ in range(12):
        s.px(rnd.randint(2, 33), rnd.randint(1, 4), "X")
    for _ in range(6):
        s.px(rnd.randint(2, 33), rnd.randint(9, 11), "S")
    for x in (15, 24, 30):
        s.vline(x, 1, 23, "k")
    s.hline(1, 1, 34, "O")
    s.ellipse(7, 20, 5, 3.5, "z"); s.ellipse(7, 20, 2, 1.2, "l")
    s.rect(30, 5, 4, 2, "A"); s.px(31, 5, "W")
    s.hline(19, 13, 3, "w")
    s.outline().save(out("props", "car_cube.png"))


def street_lamp():
    s = Spr(16, 62)
    s.rect(6, 12, 2, 46, "m"); s.vline(6, 12, 46, "g")
    s.rect(4, 56, 6, 5, "m"); s.hline(4, 56, 6, "g")
    s.line(7, 12, 9, 8, "m"); s.hline(9, 7, 4, "m")
    s.rect(10, 6, 5, 3, "g"); s.hline(10, 6, 5, "l")
    s.px(12, 9, "A"); s.px(13, 9, "A"); s.px(12, 10, "a")
    s.outline().save(out("props", "street_lamp.png"))


def toxic_puddle():
    s = Spr(32, 6, frames=2)
    for f in range(2):
        s.frame(f)
        s.ellipse(16, 3, 15, 2.4, "t")
        s.ellipse(16, 3, 11, 1.4, "T")
        for x in range(6 + f * 3, 28, 7):
            s.px(x, 2, "W")
    s.save(out("props", "toxic_puddle.png"))


def bus():
    """The scavenger camp lives in a half-buried bus: the region's landmark."""
    s = Spr(124, 60)
    s.rect(4, 10, 114, 40, "Q")
    s.rect(6, 7, 110, 3, "q"); s.hline(8, 6, 106, "q")
    s.hline(4, 10, 114, "S")
    s.rect(6, 13, 11, 18, "s")
    s.line(7, 29, 15, 15, "S"); s.line(8, 29, 16, 15, "S")
    s.rect(6, 8, 10, 3, "k"); s.ascii(8, 8, ["a.aaa", "a...a", "a..a."])
    wx = 21
    lit = [True, False, True, "board", True, False]
    for state in lit:
        s.rect(wx, 14, 11, 11, "q")
        if state == "board":
            s.rect(wx + 1, 15, 9, 9, "E")
            s.hline(wx + 1, 17, 9, "e"); s.hline(wx + 1, 21, 9, "e")
        elif state:
            s.rect(wx + 1, 15, 9, 9, "A"); s.rect(wx + 1, 21, 9, 3, "a")
        else:
            s.rect(wx + 1, 15, 9, 9, "s")
        wx += 13
    s.rect(102, 26, 10, 24, "q"); s.vline(106, 27, 23, "A")
    s.rect(4, 31, 114, 2, "a")
    rnd = random.Random(9)
    for _ in range(40):
        x, y = rnd.randint(5, 116), rnd.randint(34, 48)
        s.px(x, y, rnd.choice(["R", "o", "q"]))
    for ax in (16, 82):
        s.ellipse(ax + 9, 50, 9, 6, "k")
    s.line(30, 6, 33, 0, "l"); s.ellipse(34, 2, 3, 2, "l"); s.px(34, 2, "g")
    s.rect(58, 3, 22, 3, "s"); s.hline(58, 3, 22, "S")
    s.vline(96, 0, 6, "l"); s.px(96, 0, "x")
    junk_mound(s, 0, 124, 46, 60, 11)
    s.outline().save(out("props", "bus.png"))


def tarp_shelter():
    s = Spr(54, 34)
    s.vline(4, 6, 27, "E"); s.vline(48, 8, 25, "E")
    for x in range(2, 52):
        top = 6 + int(3 * math.sin(math.pi * (x - 2) / 50))
        bottom = top + 8 + (x * 7) % 3
        for y in range(top, bottom):
            s.px(x, y, "Q" if y < top + 5 else "q")
    s.rect(10, 23, 13, 10, "E"); s.hline(10, 27, 13, "e"); s.vline(16, 23, 10, "e")
    s.rect(25, 27, 9, 6, "e"); s.hline(25, 27, 9, "E")
    s.line(4, 7, 0, 33, "l"); s.line(48, 9, 53, 33, "l")
    s.outline().save(out("props", "tarp_shelter.png"))


def brazier():
    s = Spr(16, 22, frames=3)
    flames = [
        ["...X....", "..XfX...", ".XfFfX..", ".fFFFf..", "XfFFFfX."],
        ["....X...", "...XfX..", "..XfFX..", ".XfFFfX.", ".fFFFFf."],
        ["..X.....", "..fX.X..", ".XfFfX..", ".fFFFfX.", "XfFFFFf."],
    ]
    for f in range(3):
        s.frame(f)
        s.ascii(4, 4, flames[f])
        s.rect(3, 9, 10, 12, "r"); s.hline(3, 9, 10, "R"); s.vline(4, 10, 11, "R")
        for x in (5, 7, 9, 11):
            s.px(x, 17, "f" if (x + f) % 2 else "F"); s.px(x, 18, "f")
    s.outline().save(out("props", "brazier.png"))


def string_lights():
    s = Spr(128, 12, frames=2)
    colors = ["a", "p", "c", "A"]
    for f in range(2):
        s.frame(f)
        for x in range(128):
            y = 1 + int(6 * (1 - ((x - 64) / 64) ** 2))
            s.px(x, y, "k")
        for i, x in enumerate(range(4, 124, 10)):
            y = 1 + int(6 * (1 - ((x - 64) / 64) ** 2)) + 1
            key = colors[i % 4] if f == 1 else "m"
            s.px(x, y, "k"); s.px(x, y + 1, key); s.px(x + 1, y + 1, key); s.px(x, y + 2, key)
    s.save(out("props", "string_lights.png"))


def generator():
    """Tinker's generator. Frame 0: dead, empty cell slot. Frame 1: running."""
    s = Spr(30, 26, frames=2)
    for f in range(2):
        s.frame(f)
        s.rect(2, 8, 26, 16, "g"); s.hline(2, 8, 26, "l"); s.rect(2, 22, 26, 2, "m")
        s.rect(5, 11, 8, 8, "k")
        if f == 1:
            s.rect(6, 12, 6, 6, "a"); s.hline(6, 12, 6, "A")
        for y in range(11, 20, 2):
            s.hline(16, y, 9, "m")
        s.rect(20, 3, 3, 5, "m")
        s.px(26, 10, "T" if f == 1 else "x")
        s.line(28, 18, 29, 25, "k")
    s.outline().save(out("props", "generator.png"))


def rusty_stall():
    s = Spr(46, 30)
    s.rect(2, 14, 42, 15, "E"); s.hline(2, 14, 42, "O")
    for x in range(6, 44, 8):
        s.vline(x, 15, 14, "e")
    s.vline(3, 2, 12, "e"); s.vline(42, 2, 12, "e")
    for x in range(1, 45):
        for y in range(0, 4):
            s.px(x, y, "x" if (x // 4) % 2 == 0 else "W")
    s.ellipse(9, 11, 3, 3, "B"); s.px(9, 11, "k")
    s.rect(16, 8, 3, 6, "S"); s.rect(21, 9, 3, 5, "S"); s.px(17, 7, "s")
    s.rect(29, 10, 8, 4, "g"); s.hline(29, 10, 8, "l")
    s.outline().save(out("props", "rusty_stall.png"))


def neon_scrap_sign():
    """Rusty's neon: SCRAP. Frame 1 has the P flickered out."""
    glyphs = {
        "S": ["###", "#..", "###", "..#", "###"], "C": ["###", "#..", "#..", "#..", "###"],
        "R": ["##.", "#.#", "##.", "#.#", "#.#"], "A": ["###", "#.#", "###", "#.#", "#.#"],
        "P": ["###", "#.#", "###", "#..", "#.."],
    }
    s = Spr(25, 11, frames=2)
    for f in range(2):
        s.frame(f)
        s.rect(0, 0, 25, 11, "k")
        for i, ch in enumerate("SCRAP"):
            for gy, row in enumerate(glyphs[ch]):
                for gx, c in enumerate(row):
                    if c == "#":
                        lit = not (f == 1 and ch == "P")
                        s.px(2 + i * 4 + gx, 3 + gy, "c" if lit else "s")
    s.save(out("props", "neon_scrap.png"))


def warning_sign():
    s = Spr(20, 28)
    s.rect(9, 12, 2, 16, "g")
    for y in range(15):
        half = 7 - abs(y - 7)
        s.hline(10 - half, y, half * 2, "a")
    for y in range(15):
        half = 7 - abs(y - 7)
        if half > 0:
            s.px(10 - half, y, "k"); s.px(10 + half - 1, y, "k")
    s.ascii(6, 4, ["..k.k..", "..k.k..", ".kkkkk.", "k..k..k", "k.....k"])
    s.outline().save(out("props", "warning_sign.png"))


def junk_small():
    for name, w, seed in (("junk_a", 28, 21), ("junk_b", 20, 33)):
        s = Spr(w, 12)
        junk_mound(s, 1, w - 1, 5, 12, seed)
        rnd = random.Random(seed)
        px_ = rnd.randint(3, w - 9)
        s.hline(px_, 4, 7, "l"); s.hline(px_, 5, 7, "g")
        s.outline().save(out("props", name + ".png"))


def chute():
    s = Spr(40, 24)
    for y in range(18):
        inset = y // 3
        s.hline(2 + inset, y, 36 - inset * 2, "m")
    s.hline(2, 0, 36, "g")
    for x in range(2, 38):
        for y in range(3, 6):
            if ((x + y) // 3) % 2 == 0 and 2 + y // 3 <= x < 38 - y // 3:
                s.px(x, y, "a")
    s.rect(10, 18, 20, 4, "k")
    s.outline().save(out("props", "chute.png"))


def bale_stack():
    s = Spr(36, 30)
    for (x, y) in ((2, 15), (18, 15), (10, 1)):
        s.rect(x, y, 16, 14, "g"); s.hline(x, y, 16, "l")
        s.vline(x + 5, y, 14, "o"); s.vline(x + 11, y, 14, "o")
        rnd = random.Random(x * 7 + y)
        for _ in range(8):
            s.px(x + rnd.randint(1, 14), y + rnd.randint(2, 12), rnd.choice(["m", "R", "s"]))
    s.outline().save(out("props", "bale_stack.png"))


def warning_lamp():
    s = Spr(10, 10, frames=2)
    for f in range(2):
        s.frame(f)
        s.rect(1, 7, 8, 3, "m")
        s.ellipse(5, 6, 3.5, 3.5, "a" if f == 0 else "b")
        s.rect(1, 7, 8, 3, "m")
        if f == 0:
            s.px(4, 4, "A")
    s.outline().save(out("props", "warning_lamp.png"))


def hanging_cables():
    s = Spr(14, 48)
    for i, (x0, key) in enumerate(((3, "k"), (6, "x"), (9, "k"))):
        for y in range(48 - i * 6):
            s.px(x0 + int(2 * math.sin(y / 9 + i)), y, key)
    s.save(out("props", "hanging_cables.png"))


def hanging_junk():
    """Junk 'stalactites' hanging from the cave roof (anchored at the TOP)."""
    s = Spr(16, 40)
    for x, ln in ((5, 30), (8, 38), (11, 24)):
        s.vline(x, 0, ln, "m")
        s.px(x, ln - 1, "g")
    for y in range(0, 34):
        s.px(3 + int(2 * math.sin(y / 6.0)), y, "k")
    s.ascii(6, 22, [".l.", "lSl", "lSl", "lsl", ".l."])
    s.rect(2, 0, 12, 4, "d")
    s.outline().save(out("props", "hang_a.png"))
    s = Spr(24, 34)
    s.ellipse(12, 6, 11, 7, "d")
    s.ellipse(11, 12, 8, 6, "d")
    s.ellipse(12, 18, 5, 5, "m")
    s.ellipse(10, 4, 4, 2, "g")
    s.rect(8, 9, 4, 2, "R")
    s.px(15, 14, "o")
    for y in range(20, 34):
        s.px(12 + int(1.5 * math.sin(y / 4.0)), y, "k")
    s.px(12, 33, "c")
    s.outline().save(out("props", "hang_b.png"))
    s = Spr(18, 44)
    for y in range(0, 14):
        s.px(9 + (y % 2), y, "g")
    s.rect(3, 14, 12, 26, "w")
    s.rect(3, 14, 1, 26, "l")
    s.rect(14, 14, 1, 26, "g")
    s.rect(4, 38, 10, 2, "l")
    s.rect(12, 20, 1, 8, "m")
    s.rect(5, 30, 4, 3, "R")
    s.outline().save(out("props", "hang_c.png"))


def noticeboard():
    """Camp noticeboard: plank board on two posts with pinned scraps of paper."""
    s = Spr(32, 32)
    s.rect(4, 12, 2, 20, "e")
    s.rect(26, 12, 2, 20, "e")
    s.rect(1, 2, 30, 18, "E")
    s.rect(1, 2, 30, 1, "w")
    for y in (7, 12, 17):
        s.hline(1, y, 30, "e")
    for x, y, w, h, k in ((4, 4, 7, 8, "W"), (13, 5, 6, 6, "A"), (21, 3, 7, 9, "W"), (12, 12, 8, 6, "w")):
        s.rect(x, y, w, h, k)
        s.px(x + w // 2, y, "x")
        for ly in range(y + 2, y + h - 1, 2):
            s.hline(x + 1, ly, w - 2, "l")
    s.rect(1, 20, 30, 1, "e")
    s.outline().save(out("props", "noticeboard.png"))


def telescope():
    """Brass telescope on a scrap tripod (the lookout at the top of the tower)."""
    s = Spr(24, 30)
    s.line(12, 16, 5, 29, "e")
    s.line(12, 16, 19, 29, "e")
    s.line(12, 16, 12, 29, "E")
    s.rect(10, 14, 4, 3, "b")
    for i in range(14):
        x, y = 4 + i, 16 - i // 2
        s.px(x, y, "y")
        s.px(x, y + 1, "B")
        s.px(x, y + 2, "b")
    s.rect(17, 5, 4, 5, "Y")
    s.px(20, 6, "C")
    s.outline().save(out("props", "telescope.png"))


def hatch():
    """Rusted floor hatch, 3 damage stages (intact, cracked, about to go)."""
    s = Spr(40, 12, frames=3)
    for f in range(3):
        s.frame(f)
        s.rect(0, 0, 40, 12, "r")
        s.rect(0, 0, 40, 2, "o")
        s.rect(0, 10, 40, 2, "k")
        for x in range(3, 40, 8):
            s.px(x, 4, "O")
            s.px(x, 8, "R")
        s.rect(16, 3, 8, 6, "R")
        s.hline(17, 5, 6, "k")
        if f >= 1:
            s.line(6, 2, 12, 9, "k")
            s.line(12, 9, 18, 5, "k")
        if f >= 2:
            s.line(24, 2, 30, 10, "k")
            s.line(30, 10, 36, 4, "k")
            s.rect(26, 5, 3, 2, "z")
    s.frame(0)
    s.save(out("props", "hatch.png"))


def brass_door():
    """A sealed round brass door with gear teeth: the first glimpse of the steampunk world below."""
    s = Spr(60, 64)
    cx, cy = 30, 32
    s.ellipse(cx, cy, 29, 30, "b")
    for a in range(0, 360, 20):
        r = math.radians(a)
        s.rect(int(cx + 28 * math.cos(r)) - 1, int(cy + 29 * math.sin(r)) - 1, 3, 3, "B")
    s.ellipse(cx, cy, 25, 26, "B")
    s.ellipse(cx - 2, cy - 3, 21, 22, "y")
    s.ellipse(cx, cy, 20, 21, "B")
    s.ellipse(cx, cy, 8, 8, "b")
    s.ellipse(cx, cy, 5, 5, "z")
    s.ellipse(cx, cy, 2, 2, "c")
    for a in range(0, 360, 45):
        r = math.radians(a)
        s.px(int(cx + 17 * math.cos(r)), int(cy + 18 * math.sin(r)), "Y")
    for a in (30, 150, 270):
        r = math.radians(a)
        for d in range(9, 19):
            s.px(int(cx + d * math.cos(r)), int(cy + d * math.sin(r)), "b")
    s.outline().save(out("props", "brass_door.png"))


def pipe_run():
    """Horizontal brass pipe with flanges and a pressure gauge (wall decoration)."""
    s = Spr(64, 16)
    s.rect(0, 5, 64, 6, "B")
    s.rect(0, 5, 64, 1, "Y")
    s.rect(0, 6, 64, 1, "y")
    s.rect(0, 10, 64, 1, "b")
    for x in (10, 42):
        s.rect(x, 3, 3, 10, "y")
        s.rect(x + 2, 3, 1, 10, "b")
    s.ellipse(27, 4, 4, 4, "b")
    s.ellipse(27, 4, 3, 3, "W")
    s.line(27, 4, 29, 2, "x")
    s.outline().save(out("props", "pipe_run.png"))


def lore_tablet():
    """An old stone slab with glowing glyphs about the sword and its smiths."""
    s = Spr(26, 34)
    s.rect(3, 4, 20, 28, "g")
    s.rect(3, 4, 20, 2, "l")
    s.rect(3, 4, 2, 28, "l")
    s.rect(21, 4, 2, 28, "m")
    s.rect(1, 31, 24, 3, "m")
    for i, y in enumerate((9, 13, 17, 21, 25)):
        x = 7
        while x < 19:
            w = 2 + (x * 7 + y) % 3
            s.hline(x, y, w, "c" if (i + x) % 3 else "C")
            x += w + 1
    s.line(12, 4, 9, 14, "m")
    s.outline().save(out("props", "lore_tablet.png"))


def water_tank():
    s = Spr(32, 44)
    for x in (6, 25):
        s.rect(x, 22, 2, 22, "m")
    s.line(7, 30, 25, 40, "d")
    s.line(25, 30, 7, 40, "d")
    s.ellipse(16, 13, 14, 12, "R")
    s.ellipse(14, 11, 10, 8, "o")
    s.rect(2, 12, 28, 2, "r")
    s.rect(9, 4, 2, 6, "O")
    s.outline().save(out("props", "water_tank.png"))


def dish():
    s = Spr(26, 26)
    s.line(13, 14, 13, 25, "m")
    s.line(13, 25, 7, 25, "m")
    s.line(13, 25, 19, 25, "m")
    for y in range(0, 16):
        for x in range(0, 26):
            if ((x - 10) / 11.0) ** 2 + ((y - 8) / 7.0) ** 2 <= 1.0 and x - 4 < y * 1.2:
                s.px(x, y, "l" if x + y < 16 else "g")
    s.line(10, 8, 20, 2, "m")
    s.px(20, 2, "x")
    s.outline().save(out("props", "dish.png"))


def tram():
    """A dead tram car on a buried line: the old Heap-to-Underworks route."""
    s = Spr(112, 52)
    s.rect(4, 46, 104, 3, "m")
    for x in range(8, 108, 10):
        s.rect(x, 49, 4, 2, "e")
    for x in (20, 88):
        s.ellipse(x, 44, 6, 4, "z")
        s.ellipse(x - 5, 46, 3, 3, "d")
        s.ellipse(x + 5, 46, 3, 3, "d")
    s.rect(6, 12, 100, 30, "q")
    s.rect(6, 12, 100, 2, "Q")
    s.rect(6, 38, 100, 4, "r")
    s.rect(6, 30, 100, 2, "y")
    for x in range(12, 100, 16):
        s.rect(x, 17, 11, 9, "s")
        s.rect(x, 17, 11, 1, "S")
    s.rect(28, 18, 9, 7, "a")
    s.rect(28, 18, 9, 1, "A")
    s.rect(98, 14, 6, 24, "Q")
    s.rect(100, 18, 3, 6, "c")
    s.rect(46, 4, 20, 8, "m")
    s.line(50, 4, 58, 0, "g")
    s.line(58, 0, 66, 4, "g")
    for (x, y) in ((14, 34), (60, 33), (80, 35)):
        s.rect(x, y, 5, 3, "R")
    s.rect(40, 12, 1, 26, "Q")
    s.ascii(42, 34, ["4"])
    s.rect(42, 33, 7, 5, "W")
    s.px(44, 35, "k"); s.px(45, 34, "k"); s.px(45, 35, "k"); s.px(45, 36, "k"); s.px(46, 35, "k")
    s.outline().save(out("props", "tram.png"))


def brass_door_open():
    """The brass door rolled aside: warm light and steam beyond."""
    s = Spr(60, 64)
    cx, cy = 30, 32
    s.ellipse(cx, cy, 29, 30, "b")
    s.ellipse(cx, cy, 25, 26, "B")
    s.ellipse(cx, cy, 21, 22, "f")
    s.ellipse(cx, cy + 4, 16, 16, "F")
    s.ellipse(cx, cy + 8, 9, 9, "A")
    for a in range(0, 360, 20):
        r = math.radians(a)
        s.rect(int(cx + 28 * math.cos(r)) - 1, int(cy + 29 * math.sin(r)) - 1, 3, 3, "B")
    for k in range(5):
        s.rect(cx - 14 + k * 3, cy + 6 + k * 3, 28 - k * 6, 2, "b")
    s.outline().save(out("props", "brass_door_open.png"))


def charging_dock():
    s = Spr(34, 50, frames=4)
    for f in range(4):
        s.frame(f)
        s.rect(0, 44, 34, 6, "m"); s.hline(0, 44, 34, "g")
        s.px(16, 46, "c"); s.px(17, 46, "c")
        for px_ in (2, 26):
            s.rect(px_, 6, 6, 38, "g"); s.vline(px_, 6, 38, "l"); s.vline(px_ + 5, 6, 38, "m")
            for y in range(10, 42, 8):
                s.hline(px_ + 1, y, 4, "k")
        s.rect(0, 0, 34, 7, "m"); s.hline(0, 0, 34, "g")
        s.rect(14, 2, 6, 3, "c"); s.hline(15, 2, 4, "C")
        for x in range(8, 26):
            for y in range(7, 44):
                s.px(x, y, "c", 26)
        for k in range(3):
            y = 43 - ((f * 4 + k * 12) % 36)
            s.hline(9, y, 16, "c")
    s.outline().save(out("items", "charging_dock.png"))


def crane_hook():
    s = Spr(14, 18)
    s.ascii(0, 0, [
        "......ll......",
        ".....l..l.....",
        ".....l..l.....",
        "......ll......",
        "......gg......",
        ".....gllg.....",
        ".....gllg.....",
        "......lw......",
        "......lw......",
        "......lw......",
        "..l...lw......",
        "..lw..lw......",
        "..lw..lw......",
        "...lw.lw......",
        "....lwwl......",
        ".....ll.......",
    ])
    s.outline().save(out("items", "crane_hook.png"))
    c = Spr(4, 8)
    c.ascii(0, 0, [".l..", "l.l.", "l.l.", ".l..", ".g..", ".g..", ".l..", "l.l."])
    c.save(out("items", "chain.png"))


def scrap_wall_tile():
    s = Spr(16, 16)
    rows = [("R", 3), ("m", 2), ("r", 3), ("g", 2), ("R", 3), ("m", 3)]
    y = 0
    for key, h in rows:
        s.rect(0, y, 16, h, key)
        s.hline(0, y + h - 1, 16, "k")
        y += h
    for i in range(16):
        s.px((i + 4) % 16, i, "a"); s.px((i + 5) % 16, i, "O")
    s.save(out("items", "scrap_wall.png"))


def shutter_door():
    s = Spr(16, 48)
    s.rect(0, 0, 16, 48, "m")
    for y in range(4, 44, 4):
        s.hline(0, y, 16, "k")
    s.rect(0, 0, 16, 4, "g")
    for x in range(16):
        for y in range(44, 48):
            s.px(x, y, "a" if ((x + y) // 2) % 2 == 0 else "k")
    s.save(out("items", "shutter_door.png"))


def items():
    def icon(name, w, h, rows, outline=True):
        s = Spr(w, h)
        s.ascii(1, 1, rows)
        if outline:
            s.outline()
        s.save(out("items", name + ".png"))

    icon("scrap", 6, 6, [".lw.", "lgml", "lmgl", ".ll."])
    icon("scrap_cache", 13, 10, [
        "....lw.....", "..lwgl.c...", ".lgmglwl...", "lgmmgmglw..", "gmmdmmgmgl.", "mmdmmdmmmg.", "..........."])
    icon("bottlecap", 9, 9, [".O.O.O.", "OoooooO", ".oAAAo.", "OoAoAoO", ".oAAAo.", "OoooooO", ".R.R.R."])
    icon("chip", 12, 12, [
        ".y.y.y.y.y", "yqqqqqqqqy", ".qQQQQQQq.", "yqQkkkkQqy", ".qQkkkkQq.", "yqQkkkkQqy",
        ".qQkkkkQq.", "yqQQQQQQqy", ".qqqqqqqq.", "y.y.y.y.y."])
    icon("cosmetic", 12, 11, [
        "..wWWWWw..", ".wWWWWWWw.", "wWWwWWwWWw", "wWWwWWwWWw", "wWWWWWWWWw", ".wwWWWWww.", "..wwwwww.."])
    icon("repair_kit", 12, 10, ["...kkkk...", "...k..k...", "xXXXXXXXXx", "xxxxWWxxxx", "xxxWWWWxxx", "xxxxWWxxxx", "xxxxxxxxxx"])
    icon("port", 12, 9, ["mmmmmmmmmm", "mggggggggm", "mgkkgkkgTm", "mgkkgkkgTm", "mggggggggm", "mmmmmmmmmm"])
    icon("core_cell", 9, 12, ["..gg...", ".WXXx..", ".XXXx..", ".XWXx..", ".XXXx..", ".XXXx..", ".xxxx..", "..gg..."])
    icon("shard", 10, 18, [
        "...W....", "..WC....", "..CCc...", ".WCcc...", ".CCcc...", ".Cccc...", "WCcccc..", "CCcccc..",
        ".Cccc...", ".Cccc...", ".Ccc....", "..cc....", "..cc....", "..c.....", "..c....."])
    icon("power_cell", 9, 13, ["..gg...", ".aAAa..", ".aAaa..", ".aaka..", ".akka..", ".aaka..", ".akaa..", ".aaaa..", ".aaaa..", ".bbbb.."])
    icon("bolt", 8, 8, ["..XX..", ".XAAX.", "XAWWAX", "XAWWAX", ".XAAX.", "..XX.."], outline=False)
    b = Spr(16, 16)
    b.rect(1, 1, 14, 14, "g"); b.hline(1, 1, 14, "l")
    b.vline(5, 1, 14, "o"); b.vline(10, 1, 14, "o")
    rnd = random.Random(3)
    for _ in range(10):
        b.px(rnd.randint(2, 13), rnd.randint(3, 13), rnd.choice(["m", "R", "s"]))
    b.outline().save(out("items", "bale.png"))


def fx():
    d = Spr(12, 7, frames=4)
    for f in range(4):
        d.frame(f)
        a = [200, 150, 90, 40][f]
        spread = 2 + f
        for (x, y) in ((6 - spread, 5), (6 + spread - 1, 5), (6 - spread - 1, 4 - f // 2), (6 + spread, 4 - f // 2)):
            d.px(x, y, "l", a); d.px(x + 1, y, "w", a // 2)
    d.save(out("fx", "dust.png"))
    g = Spr(64, 64)
    for y in range(64):
        for x in range(64):
            r = math.hypot(x - 31.5, y - 31.5) / 32
            a = 70 if r < 0.25 else 44 if r < 0.5 else 22 if r < 0.75 else 9 if r < 1.0 else 0
            if a:
                g.img.putpixel((x, y), (255, 255, 255, a))
    g.save(out("fx", "glow.png"))


def ui():
    p = Spr(24, 24)
    p.rect(0, 0, 24, 24, "m")
    p.hline(0, 0, 24, "g"); p.vline(0, 0, 24, "g")
    p.hline(0, 23, 24, "k"); p.vline(23, 0, 24, "k")
    p.rect(3, 3, 18, 18, "q")
    for y in range(4, 20):
        for x in range(4, 20):
            p.img.putpixel((x, y), (11, 13, 19, 246))
    for (x, y) in ((1, 1), (21, 1), (1, 21), (21, 21)):
        p.px(x, y, "l"); p.px(x + 1, y + 1, "d")
    p.save(out("ui", "panel.png"))
    b = Spr(12, 12)
    for y in range(12):
        for x in range(12):
            b.img.putpixel((x, y), (35, 74, 72, 190))
    b.ascii(1, 3, ["c..", "cc.", "ccc", "cc.", "c.."])
    b.hline(0, 11, 12, "c")
    b.save(out("ui", "button_focus.png"))
    for name, frame, fill, hi in (("cell_full", "l", "c", "C"), ("cell_empty", "m", "d", "d")):
        c = Spr(8, 11)
        c.rect(2, 0, 4, 1, frame)
        c.rect(0, 1, 8, 10, frame)
        c.rect(1, 2, 6, 8, fill)
        c.rect(1, 2, 2, 8, hi)
        c.save(out("ui", name + ".png"))
    icons = {
        "icon_scrap": [".lw.", "lgml", "lmgl", ".ll."],
        "icon_cap": [".W.W.", "WWWWW", ".WWW.", "WWWWW", ".W.W."],
        "icon_kit": ["xXXXx", "xxWxx", "xWWWx", "xxWxx", "xxxxx"],
    }
    for name, rows in icons.items():
        s = Spr(7, 7)
        s.ascii(1, 1, rows)
        s.outline().save(out("ui", name + ".png"))


def ground_decals():
    """Debris pressed into the junk ground: 6 shapes in two tones of the ground colour.
    Used sparsely by the room renderer, so the ground reads as packed junk, not a tile grid."""
    LT, DK = (62, 46, 46, 255), (32, 23, 25, 255)
    s = Spr(14 * 6, 10)
    shapes = [
        ["..LLLLLL....", ".LDDDDDDL...", "LD......DL..", "LD..LL..DL..", "LD......DL..", ".LDDDDDDL...", "..LLLLLL...."],
        ["LLLLLLLLLL..", "LDDDDDDDDL..", "LD.L..L.DL..", "LDDDDDDDDL..", "LLLLLLLLLL.."],
        ["....LL......", "...LDDL.....", "LLLLDDLLLLLL", "DDDDDDDDDDDD", "...LDDL.....", "....LL......"],
        [".L.L.L.", "LLLLLLL", ".LDDDL.", "LLDLDLL", ".LDDDL.", "LLLLLLL", ".L.L.L."],
        ["..L..........", "..DL.........", "...DL........", "....DLLLLLLL.", ".....DDDDDDD."],
        ["...LL...", "..LDDL..", "..LDDL..", ".LDDDDL.", ".LDDDDL.", ".LLLLLL."],
    ]
    for i, rows in enumerate(shapes):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in "LD":
                    s.img.putpixel((i * 14 + x + 1, y + 1), LT if ch == "L" else DK)
    s.save(os.path.join(OUT, "tiles", "ground_decals.png"))


def cursor():
    """Pixel crosshair, drawn at 9x9 and doubled so it reads at the 2x window scale."""
    s = Spr(9, 9)
    s.ascii(0, 0, [
        "....C....", "....c....", ".........", ".........",
        "Cc.....cC", ".........", ".........", "....c....", "....C...."])
    s.px(4, 4, "C")
    img = s.img.resize((18, 18), 0)
    img.save(out("ui", "cursor.png"))


if __name__ == "__main__":
    cursor()
    ground_decals()
    for fn in (ancient_casing, crt_pile, tyres, barrel, car_cube, street_lamp, toxic_puddle, bus,
               tarp_shelter, brazier, string_lights, generator, rusty_stall, neon_scrap_sign,
               warning_sign, junk_small, chute, bale_stack, warning_lamp, hanging_cables, hanging_junk,
               noticeboard, telescope, hatch, brass_door, pipe_run, lore_tablet, water_tank, dish, tram, brass_door_open,
               charging_dock, crane_hook, scrap_wall_tile, shutter_door, items, fx, ui):
        fn()
    print("props, items, fx and ui built")
