"""Tiny pixel-art toolkit for Unhilted.

Every asset is drawn pixel by pixel from ONE shared palette (PAL) so the whole
game stays consistent. Shapes are placed deliberately; random() is only used
with fixed seeds for texture clusters, so rebuilding gives identical output.
"""
import random
from PIL import Image

# ---------------------------------------------------------------- palette
# Keys are single characters so sprites can also be written as ASCII maps.
PAL = {
    # neutrals / scrap metal (dark -> light)
    # warm neutrals: outlines and metal lean brown, so props sit in the dusk light
    "k": (30, 20, 22), "d": (44, 32, 34), "m": (68, 54, 54), "g": (98, 82, 80),
    "l": (138, 118, 108), "w": (192, 170, 150),
    # rust
    "r": (74, 42, 34), "R": (122, 63, 40), "o": (168, 90, 48), "O": (212, 132, 74),
    # ancient brass
    "b": (90, 63, 28), "B": (140, 100, 40), "y": (201, 150, 60), "Y": (240, 207, 115),
    # neon
    "c": (56, 242, 255), "C": (184, 251, 255), "p": (255, 79, 160), "P": (255, 194, 223),
    "a": (255, 179, 71), "A": (255, 224, 168),
    # toxic
    "t": (63, 143, 46), "T": (143, 224, 90),
    # cloth / wood
    "q": (35, 74, 72), "Q": (58, 112, 106), "e": (90, 63, 48), "E": (138, 100, 72),
    # rubber, glass, warning, white, fire
    "z": (26, 26, 30), "s": (31, 58, 68), "S": (79, 138, 150),
    "x": (168, 48, 42), "X": (255, 90, 58), "W": (242, 236, 228),
    "f": (255, 138, 42), "F": (255, 210, 90),
    # violet (Reflex chip family)
    "v": (122, 84, 214), "V": (190, 166, 255),
    # backdrop silhouettes (no outlines on backgrounds)
    "1": (27, 24, 40), "2": (35, 29, 44), "3": (26, 21, 32), "4": (59, 47, 74),
    "5": (21, 19, 26), "6": (28, 25, 34), "7": (92, 52, 70), "8": (60, 36, 52),
    "9": (40, 33, 50),
}


def rgba(key, alpha=255):
    r, g, b = PAL[key]
    return (r, g, b, alpha)


class Spr:
    def __init__(self, w, h, frames=1):
        self.w, self.h, self.frames = w, h, frames
        self.img = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
        self.f = 0  # current frame being drawn

    def frame(self, i):
        self.f = i
        return self

    # all coordinates are frame-local
    def px(self, x, y, key, alpha=255, wrap=False):
        if wrap:
            x %= self.w
            y %= self.h
        if 0 <= x < self.w and 0 <= y < self.h:
            pos = (self.f * self.w + x, y)
            if key and alpha < 255:
                # blend over what is already there (keeps the base pixel's opacity)
                br, bg, bb, ba = self.img.getpixel(pos)
                r, g, b = PAL[key]
                t = alpha / 255.0
                if ba == 0:
                    self.img.putpixel(pos, (r, g, b, alpha))
                else:
                    self.img.putpixel(pos, (int(br + (r - br) * t), int(bg + (g - bg) * t), int(bb + (b - bb) * t), ba))
                return
            self.img.putpixel(pos, rgba(key, alpha) if key else (0, 0, 0, 0))

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.img.getpixel((self.f * self.w + x, y))
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, key, wrap=False):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, key, wrap=wrap)

    def hline(self, x, y, w, key):
        self.rect(x, y, w, 1, key)

    def vline(self, x, y, h, key):
        self.rect(x, y, 1, h, key)

    def line(self, x0, y0, x1, y1, key):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, key)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, key):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx + 0.5) / max(rx, 0.5)) ** 2 + ((y - cy + 0.5) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.px(x, y, key)

    def ascii(self, x0, y0, rows):
        """Stamp an ASCII map. '.' and ' ' are transparent (skipped)."""
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch not in ". ":
                    self.px(x0 + x, y0 + y, ch)

    def outline(self, key="k"):
        """1 px dark outline around every opaque shape (the prop style rule)."""
        for fi in range(self.frames):
            self.f = fi
            add = []
            for y in range(self.h):
                for x in range(self.w):
                    if self.get(x, y)[3] == 0:
                        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                            if self.get(nx, ny)[3] > 0:
                                add.append((x, y))
                                break
            for x, y in add:
                self.px(x, y, key)
        self.f = 0
        return self

    def save(self, path):
        self.img.save(path)
        return self


def dither_band(spr, y0, y1, key_a, key_b):
    """Ordered (Bayer 2x2) dither from key_a (top) to key_b (bottom)."""
    bayer = [[0, 2], [3, 1]]
    n = max(y1 - y0, 1)
    for y in range(y0, y1):
        t = (y - y0) / n
        for x in range(spr.w):
            spr.px(x, y, key_b if t * 4 > bayer[y % 2][x % 2] + 0.5 else key_a)
