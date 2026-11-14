"""Sprite sheets for the Heap's new enemies (same palette + outline rule as props).
Run from the project root:  python3 tools/art/build_enemies.py

rustcrawler.png  20x16 frames: walk 0-3, cling 4-5 (upside down), hop 6
compactor.png    40x32 frames: walk 0-3, windup 4-5, charge 6-7, stunned 8-9
Sprites face RIGHT; the game flips them.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "enemies")
os.makedirs(OUT, exist_ok=True)


def rustcrawler():
    W, H = 20, 16
    s = Spr(W, H, frames=7)
    for f in range(7):
        s.frame(f)
        cling = f in (4, 5)
        hop = f == 6
        phase = (f % 4) / 4 * math.tau
        by = 6 if not hop else 4
        for i, lx in enumerate((5, 9, 13)):
            swing = math.sin(phase + i * 2.1) * 1.5 if not (cling or hop) else (1 if hop else 0)
            kx, ky = lx + swing, by + 4
            fx, fy = lx + swing * 1.6 + (1 if i == 2 else -1 if i == 0 else 0), 15
            if hop:
                fy = 13
            s.line(int(lx), by + 2, int(kx), int(ky), "k")
            s.line(int(kx), int(ky), int(fx), int(fy), "d")
        s.ellipse(9.5, by + 1.5, 7.5, 4.5, "R")
        s.ellipse(8.5, by, 6, 3, "o")
        s.ellipse(7.5, by - 1, 3.5, 1.5, "O")
        s.hline(4, by + 3, 12, "r")
        for x in (6, 10, 14):
            s.px(x, by + 2, "O")
        s.rect(15, by, 4, 4, "m")
        s.px(17, by + 1, "X")
        s.px(18, by + 1, "F")
        s.px(19, by + 3, "l")
        s.px(19, by + 4, "l")
        s.px(16, by - 1 - (f % 2), "g")
    s.frame(0)
    s.outline("k")
    from PIL import Image
    img = s.img
    for f in (4, 5):
        box = (f * W, 0, (f + 1) * W, H)
        img.paste(img.crop(box).transpose(Image.FLIP_TOP_BOTTOM), box)
    img.save(os.path.join(OUT, "rustcrawler.png"))


def compactor():
    W, H = 40, 32
    s = Spr(W, H, frames=10)
    for f in range(10):
        s.frame(f)
        stunned = f >= 8
        charge = f in (6, 7)
        wind = f in (4, 5)
        bob = (f % 2) if not stunned else 0
        lean = 2 if charge else (-1 if wind else 0)
        s.rect(4, 25, 26, 6, "z")
        s.rect(5, 26, 24, 1, "m")
        for x in range(6 + (f % 2) * 2, 29, 4):
            s.rect(x, 28, 2, 2, "g")
        bx = 6 + lean
        s.rect(bx, 9 + bob, 22, 16, "R")
        s.rect(bx, 9 + bob, 22, 2, "O")
        s.rect(bx, 23 + bob, 22, 2, "r")
        for x in range(bx + 1, bx + 21, 4):
            s.rect(x, 18 + bob, 2, 2, "F")
            s.rect(x + 2, 18 + bob, 2, 2, "k")
        s.rect(bx + 2, 3 + bob, 4, 7, "m")
        s.rect(bx + 2, 3 + bob, 4, 1, "l")
        if wind:
            for (px, py) in ((bx + 3, 1), (bx + 6, 0), (bx + 1, -1 + f % 2)):
                if py >= 0:
                    s.px(px, py, "W")
        s.rect(bx + 13, 5 + bob, 8, 5, "m")
        s.rect(bx + 15, 7 + bob, 5, 1, "X" if not stunned else "g")
        rx = bx + 22 + (3 if charge else 0)
        s.rect(rx, 7 + bob, 5, 19, "l")
        s.rect(rx, 7 + bob, 1, 19, "w")
        s.rect(rx + 4, 7 + bob, 1, 19, "g")
        for y in (10, 16, 22):
            s.px(rx + 2, y + bob, "W")
        if stunned:
            for i, (px, py) in enumerate(((bx + 14, 2), (bx + 19, 1), (bx + 22, 3))):
                if (i + f) % 2 == 0:
                    s.px(px, py, "F")
                    s.px(px + 1, py, "A")
    s.frame(0)
    s.outline("k").save(os.path.join(OUT, "compactor.png"))


def brass_head():
    """The brass giant's head, half-buried in the heap, in profile facing left.
    Frames: 0 eye shut, 1 opening, 2 open, 3 charging (glowing), 4 broken."""
    W, H = 150, 180
    s = Spr(W, H, frames=5)
    profile = [(60, 0), (34, 18), (20, 46), (14, 78), (6, 96), (6, 104), (22, 108), (24, 136), (14, 150),
               (4, 158), (6, 166), (16, 170), (14, 180)]
    for f in range(5):
        s.frame(f)
        for y in range(H):
            for i in range(len(profile) - 1):
                (x0, y0), (x1, y1) = profile[i], profile[i + 1]
                if y0 <= y <= y1:
                    xl = int(x0 + (x1 - x0) * (y - y0) / max(y1 - y0, 1))
                    break
            dy = (y - 92) / 92.0
            xr = int(92 + 58 * max(0.0, 1 - dy * dy) ** 0.5)
            for x in range(xl, min(xr, W)):
                d = ((x - 50) ** 2 + (y - 40) ** 2) ** 0.5
                key = "y" if d < 46 else ("B" if d < 110 else "b")
                if x - xl < 3:
                    key = "Y" if y < 110 else "y"
                s.px(x, y, key)
        for k, r in enumerate((40, 64, 88)):
            for a_ in range(-70, 80, 3):
                import math as _m
                x = int(96 + r * _m.cos(_m.radians(a_ + 180)) * -0.55 + r * 0.25)
                y = int(92 + r * _m.sin(_m.radians(a_)) * 0.9)
                if 0 <= y < H and s.get(x, y)[3]:
                    s.px(x, y, "b")
            s.px(110 - k * 6, 30 + k * 26, "Y")
        s.rect(10, 100, 46, 8, "b")
        s.rect(8, 98, 46, 3, "y")
        s.px(52, 99, "Y")
        ex, ey = 40, 122
        s.ellipse(ex, ey, 15, 12, "k")
        s.ellipse(ex + 2, ey + 1, 14, 11, "z")
        if f == 0:
            s.ellipse(ex, ey, 12, 9, "B")
            s.hline(ex - 12, ey, 24, "b")
            s.hline(ex - 10, ey - 3, 20, "y")
        elif f == 1:
            s.ellipse(ex, ey, 12, 9, "B")
            s.ellipse(ex, ey, 11, 3, "a")
            s.hline(ex - 9, ey - 1, 18, "A")
        elif f in (2, 3):
            s.ellipse(ex, ey, 11, 9, "a" if f == 2 else "c")
            s.ellipse(ex, ey, 6, 5, "A" if f == 2 else "C")
            s.ellipse(ex - 3, ey - 3, 2, 2, "W")
        else:
            s.ellipse(ex, ey, 11, 9, "z")
            s.line(ex - 8, ey - 6, ex + 6, ey + 5, "m")
            s.line(ex + 6, ey - 6, ex - 4, ey + 6, "m")
            s.line(ex - 9, ey + 2, ex + 8, ey - 1, "d")
        s.line(24, 138, 60, 146, "b")
        for y in range(156, 172, 4):
            s.rect(8, y, 22, 2, "b")
            s.rect(8, y, 22, 1, "k")
        s.line(96, 6, 104, 34, "b")
        s.line(104, 34, 98, 52, "b")
        s.line(98, 52, 102, 62, "b")
        for (x, y, w, h) in ((84, 150, 66, 30), (110, 132, 40, 20), (60, 166, 40, 14)):
            s.rect(x, y, w, h, "d")
            s.rect(x, y, w, 1, "m")
        for (x, y) in ((96, 156), (120, 140), (70, 170), (136, 162)):
            s.rect(x, y, 5, 2, "t")
            s.px(x + 1, y - 1, "T")
        s.rect(100, 160, 8, 4, "R")
        s.rect(128, 150, 6, 3, "x")
    s.frame(0)
    s.outline("k").save(os.path.join(OUT, "brass_head.png"))


if __name__ == "__main__":
    brass_head()
    rustcrawler()
    compactor()
    print("enemy sprites built")
