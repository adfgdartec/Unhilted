"""All Underworks art: backdrops, props, items, enemies, shopfronts and interiors.
Run from the project root:  python3 tools/art/build_underworks.py

Region look (docs/REGIONS.md): a steampunk city in the old maintenance tunnels.
Gaslight pools of amber, green-black dark between them, white steam; brass and
copper, verdigris green, soot black. Shapes are round and riveted (pipes,
gauges, gears, arched vaults). Same palette and rules as everything else
(pix.py): light from the top-left, a dark outline on objects, none on backdrops.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from pix import Spr

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACK = os.path.join(ROOT, "art", "backdrops")
PROPS = os.path.join(ROOT, "art", "props")
ITEMS = os.path.join(ROOT, "art", "items")
ENEMIES = os.path.join(ROOT, "art", "enemies")
UI = os.path.join(ROOT, "art", "ui")
INTERIORS = os.path.join(ROOT, "art", "interiors")
for d in (BACK, PROPS, ITEMS, ENEMIES, UI, INTERIORS):
    os.makedirs(d, exist_ok=True)

W, H = 640, 400

DARK = (20, 28, 26)
BRICK = (90, 52, 40)
COPPER = (168, 96, 58)
BRASS = (201, 150, 60)
BRASS_HI = (240, 207, 115)
VERD = (79, 154, 132)
VERD_LO = (42, 90, 76)
STEAM = (232, 228, 220)
GAS = (255, 184, 79)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def save(s, folder, name):
    s.save(os.path.join(folder, name + ".png"))


def raw(s, x, y, rgba):
    if 0 <= x < s.w and 0 <= y < s.h:
        s.img.putpixel((s.f * s.w + x, y), rgba)


def _arcade(img, y_base, height, pier_w, bay_w, x0, col, rim):
    """A brick arcade (a wall pierced by round-topped openings) across the
    whole width, wrapping seamlessly. Drawn on its own layer: the wall is
    filled, then the openings are cut back out to transparent."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    top = y_base - height
    d.rectangle([0, top - 18, W, H], fill=col)
    span = bay_w - pier_w
    for dx in (-W, 0, W):
        x = x0 + pier_w + dx
        while x < W + bay_w:
            d.rectangle([x, top + span / 2, x + span, H], fill=(0, 0, 0, 0))
            d.ellipse([x, top, x + span, top + span], fill=(0, 0, 0, 0))
            d.arc([x, top, x + span, top + span], 180, 360, fill=rim, width=1)
            x += bay_w
    d.line([(0, top - 18), (W, top - 18)], fill=rim)
    img.alpha_composite(layer)


def _radial(img, cx, cy, rx, ry, rgb, peak):
    """A soft glow: alpha falls off smoothly from the centre (no visible rings)."""
    o = Image.new("RGBA", img.size, (0, 0, 0, 0))
    po = o.load()
    for y in range(max(0, int(cy - ry)), min(img.height, int(cy + ry) + 1)):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            t = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if t < 1.0:
                po[x % img.width, y] = rgb + (int(peak * (1 - t) ** 2),)
    img.alpha_composite(o)


def uw_far():
    """Vaults receding into warm haze: three arcades, a giant flywheel, lit
    windows of houses built on the pipes, and the glow of the furnaces below."""
    img = Image.new("RGBA", (W, H))
    px = img.load()
    for y in range(H):
        t = y / H
        c = lerp((16, 22, 22), (26, 34, 32), min(t * 2, 1)) if t < 0.5 else lerp((26, 34, 32), (74, 52, 34), (t - 0.5) * 2)
        for x in range(W):
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(img, "RGBA")
    _arcade(img, 300, 150, 20, 60, 6, (40, 44, 40, 255), (66, 64, 52, 255))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy, r = 470, 170, 92
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(34, 40, 36, 255), width=10)
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(34, 40, 36, 255))
    for a in range(6):
        ang = a * math.pi / 3
        d.line([(cx, cy), (cx + math.cos(ang) * r, cy + math.sin(ang) * r)], fill=(34, 40, 36, 255), width=5)
    d.arc([cx - r, cy - r, cx + r, cy + r], 200, 260, fill=(90, 80, 58, 255), width=2)
    _arcade(img, 330, 130, 28, 92, 30, (32, 36, 32, 255), (82, 70, 50, 255))
    d = ImageDraw.Draw(img, "RGBA")
    houses = [(40, 210, 30, 40), (112, 196, 24, 54), (200, 222, 36, 34), (300, 188, 22, 60), (372, 214, 28, 40), (560, 200, 30, 50), (612, 224, 22, 30)]
    for hx, hy, hw, hh in houses:
        for dx in (-W, 0, W):
            d.rectangle([hx + dx, hy, hx + hw + dx, hy + hh], fill=(26, 30, 28, 255))
            d.polygon([(hx - 3 + dx, hy), (hx + hw / 2 + dx, hy - 10), (hx + hw + 3 + dx, hy)], fill=(26, 30, 28, 255))
            d.rectangle([hx + hw - 6 + dx, hy - 16, hx + hw - 3 + dx, hy - 4], fill=(26, 30, 28, 255))
            for wy in range(hy + 6, hy + hh - 6, 12):
                for wx in range(hx + 4, hx + hw - 4, 9):
                    if (wx * 7 + wy * 3) % 5 != 0:
                        d.rectangle([wx + dx, wy, wx + 3 + dx, wy + 4], fill=(255, 176, 80, 200))
    d.rectangle([0, 262, W, 270], fill=(30, 34, 30, 255))
    d.line([(0, 262), (W, 262)], fill=(88, 72, 50, 255))
    for gx in (90, 330, 560):
        _radial(img, gx, 400, 150, 90, (255, 150, 70), 90)
    for sx in (150, 260, 420, 600):
        for k in range(4):
            _radial(img, sx, 330 - k * 46, 26 + k * 8, 18 + k * 4, (220, 220, 210), 26 - k * 5)
    img.save(os.path.join(BACK, "uw_far.png"))


def uw_mid():
    """Nearer: big copper pipes crossing the vault with brass flanges, stone
    piers with brass bands, hanging chains, and wall lamps."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    pier = (24, 26, 24, 255)
    rim = (110, 86, 58, 255)
    for x0, w in ((60, 34), (300, 40), (520, 30)):
        d.rectangle([x0, 0, x0 + w, H], fill=pier)
        d.line([(x0 + w, 0), (x0 + w, H)], fill=rim, width=1)
        for by in (60, 200, 330):
            d.rectangle([x0 - 3, by, x0 + w + 3, by + 6], fill=(64, 50, 30, 255))
            d.line([(x0 - 3, by), (x0 + w + 3, by)], fill=(150, 116, 60, 255))
    for y0, thick in ((92, 12), (238, 9)):
        d.rectangle([0, y0, W, y0 + thick], fill=(52, 34, 26, 255))
        d.line([(0, y0), (W, y0)], fill=(140, 90, 60, 255))
        for fx in range(20, W, 80):
            d.rectangle([fx, y0 - 2, fx + 4, y0 + thick + 2], fill=(70, 54, 30, 255))
    d.rectangle([420, 0, 428, 240], fill=(46, 30, 24, 255))
    d.line([(420, 0), (420, 240)], fill=(130, 84, 56, 255))
    for cx, length in ((180, 120), (196, 80), (610, 150)):
        for y in range(0, length, 4):
            d.ellipse([cx - 1, y, cx + 2, y + 4], outline=(40, 38, 34, 255))
    for lx, ly in ((95, 150), (342, 120), (552, 170)):
        _radial(img, lx, ly, 44, 44, (255, 180, 90), 70)
    img.save(os.path.join(BACK, "uw_mid.png"))


def uw_works():
    """Machinery hall layer: boilers, gauge faces, pistons and a governor's
    spinning silhouette, for the Boiler Works, Gearworks and the Governor."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    body = (26, 26, 26, 255)
    rim = (120, 92, 58, 255)
    for bx, by, bw, bh in ((30, 200, 90, 160), (250, 170, 110, 200), (470, 210, 80, 150)):
        d.rounded_rectangle([bx, by, bx + bw, by + bh + 200], radius=30, fill=body)
        d.arc([bx, by, bx + bw, by + 60], 180, 270, fill=rim, width=1)
        for ry in range(by + 20, by + bh + 200, 18):
            d.line([(bx + 4, ry), (bx + bw - 4, ry)], fill=(36, 34, 32, 255))
        d.ellipse([bx + bw / 2 - 12, by + 40, bx + bw / 2 + 12, by + 64], fill=(52, 44, 30, 255), outline=rim)
        d.line([(bx + bw / 2, by + 52), (bx + bw / 2 + 7, by + 46)], fill=(200, 70, 50, 255))
        d.rectangle([bx + bw / 2 - 10, by + bh + 20, bx + bw / 2 + 10, by + bh + 34], fill=(120, 50, 20, 255))
    for pxp in (170, 410, 600):
        d.rectangle([pxp, 0, pxp + 10, 220], fill=body)
        d.rectangle([pxp - 4, 220, pxp + 14, 236], fill=body)
        d.line([(pxp, 0), (pxp, 220)], fill=rim)
    img.save(os.path.join(BACK, "uw_works.png"))


def gaslamp():
    """Iron lamp post with a glass cage and a gas flame (2 frames: flicker)."""
    s = Spr(12, 44, 2)
    for f in range(2):
        s.frame(f)
        s.rect(5, 14, 2, 30, "d")
        s.vline(5, 14, 30, "m")
        s.rect(3, 42, 6, 2, "d")
        s.rect(2, 2, 8, 12, "k")
        s.rect(3, 3, 6, 10, "A" if f == 0 else "a")
        s.rect(5, 6, 2, 5, "W" if f == 0 else "A")
        s.hline(1, 1, 10, "B")
        s.hline(2, 0, 8, "y")
        s.hline(2, 13, 8, "B")
    s.outline("k")
    return s


def wall_lamp():
    s = Spr(10, 16, 2)
    for f in range(2):
        s.frame(f)
        s.rect(0, 6, 4, 2, "B")
        s.rect(3, 2, 6, 10, "k")
        s.rect(4, 3, 4, 8, "A" if f == 0 else "a")
        s.rect(5, 5, 2, 4, "W" if f == 0 else "A")
        s.hline(3, 1, 6, "y")
    s.outline("k")
    return s


def gauge():
    """Pressure gauge: brass rim, cream dial, needle (2 frames: needle twitch)."""
    s = Spr(20, 22, 2)
    for f in range(2):
        s.frame(f)
        s.ellipse(9, 9, 9, 9, "B")
        s.ellipse(9, 9, 7, 7, "W")
        for a in range(7):
            ang = math.pi * (0.75 + a * 0.25)
            s.px(int(9 + math.cos(ang) * 6), int(9 + math.sin(ang) * 6), "k")
        s.px(15, 12, "x"); s.px(14, 13, "x")
        ang = math.pi * (1.6 if f == 0 else 1.75)
        s.line(9, 9, int(9 + math.cos(ang) * 6), int(9 + math.sin(ang) * 6), "x")
        s.px(9, 9, "k")
        s.px(6, 5, "y")
        s.rect(8, 18, 3, 4, "B")
    s.outline("k")
    return s


def boiler():
    """A riveted boiler with a firebox glow (2 frames)."""
    s = Spr(48, 58, 2)
    for f in range(2):
        s.frame(f)
        s.rect(4, 8, 40, 46, "e")
        s.ellipse(24, 10, 20, 8, "e")
        s.vline(5, 8, 46, "E")
        s.vline(6, 8, 46, "o")
        s.vline(42, 8, 46, "r")
        for y in (18, 30, 42):
            s.hline(4, y, 40, "r")
            for x in range(7, 42, 5):
                s.px(x, y - 1, "o")
        s.rect(16, 40, 16, 10, "k")
        s.rect(17, 41, 14, 8, "f" if f == 0 else "F")
        s.rect(19, 43, 10, 4, "A" if f == 0 else "f")
        s.rect(20, 0, 6, 6, "m")
        s.hline(20, 0, 6, "l")
        s.rect(2, 52, 44, 4, "d")
        s.ellipse(34, 24, 5, 5, "B")
        s.ellipse(34, 24, 3, 3, "W")
        s.px(34, 24, "x")
    s.outline("k")
    return s


def pipes_bundle():
    s = Spr(64, 52)
    for i, y in enumerate((8, 20, 32)):
        s.rect(0, y, 64, 8, "e" if i % 2 else "E")
        s.hline(0, y, 64, "o")
        s.hline(0, y + 7, 64, "r")
        for x in (14, 46):
            s.rect(x, y - 1, 3, 10, "B")
            s.vline(x, y - 1, 10, "y")
    s.rect(52, 32, 8, 20, "E")
    s.vline(52, 32, 20, "o")
    s.outline("k")
    return s


def stall():
    """Market stall: a copper awning on poles, a counter of gears and kettles."""
    s = Spr(76, 58)
    s.rect(4, 6, 2, 50, "d")
    s.rect(70, 6, 2, 50, "d")
    for i in range(0, 76, 8):
        s.rect(i, 2, 4, 10, "e")
        s.rect(i + 4, 2, 4, 10, "q")
        s.px(i + 2, 12, "e")
        s.px(i + 6, 12, "q")
    s.hline(0, 1, 76, "B")
    s.rect(6, 36, 64, 20, "E")
    s.hline(6, 36, 64, "o")
    s.hline(6, 44, 64, "r")
    s.ellipse(16, 32, 4, 4, "B"); s.px(16, 32, "k")
    s.ellipse(26, 33, 3, 3, "B"); s.px(26, 33, "k")
    s.rect(34, 26, 8, 10, "l"); s.rect(42, 29, 3, 2, "l"); s.hline(34, 26, 8, "w")
    s.rect(50, 30, 6, 6, "W"); s.ellipse(53, 33, 2, 2, "B")
    s.rect(60, 28, 4, 8, "t"); s.rect(61, 26, 2, 2, "s")
    s.outline("k")
    return s


def house(variant):
    """A Bellows Row house: tall and narrow, riveted, a round lit window, a
    chimney pipe, standing on pipe stilts."""
    s = Spr(64, 92)
    body = "e" if variant == 0 else "r"
    s.rect(8, 18, 48, 56, body)
    s.vline(8, 18, 56, "E" if variant == 0 else "R")
    s.vline(55, 18, 56, "k")
    for y in range(24, 74, 10):
        for x in range(12, 54, 8):
            s.px(x, y, "o" if variant == 0 else "R")
    s.rect(4, 12, 56, 6, "m")
    s.hline(4, 12, 56, "l")
    s.rect(40, 0, 8, 12, "m")
    s.hline(40, 0, 8, "l")
    s.ellipse(32, 36, 8, 8, "B")
    s.ellipse(32, 36, 6, 6, "a")
    s.ellipse(32, 36, 4, 4, "A")
    s.vline(32, 30, 13, "B")
    s.hline(26, 36, 13, "B")
    s.rect(16, 52, 12, 22, "k")
    s.rect(17, 53, 10, 20, "E")
    s.px(25, 63, "y")
    for x in (12, 48):
        s.rect(x, 74, 4, 18, "m")
        s.vline(x, 74, 18, "l")
    s.rect(8, 74, 48, 3, "d")
    s.outline("k")
    return s


def flywheel():
    """A big spoked flywheel in the wall (4 frames of rotation)."""
    s = Spr(72, 72, 4)
    for f in range(4):
        s.frame(f)
        s.ellipse(36, 36, 34, 34, "m")
        s.ellipse(36, 36, 30, 30, None)
        s.ellipse(36, 36, 31, 31, "d")
        s.ellipse(36, 36, 29, 29, None)
        for a in range(6):
            ang = a * math.pi / 3 + f * math.pi / 12
            s.line(36, 36, int(36 + math.cos(ang) * 30), int(36 + math.sin(ang) * 30), "m")
        s.ellipse(36, 36, 6, 6, "B")
        s.ellipse(36, 36, 2, 2, "k")
    s.outline("k")
    return s


def valve():
    """The valve wheel you hit to turn steam on and off (2 frames: shut / open)."""
    s = Spr(22, 26, 2)
    for f in range(2):
        s.frame(f)
        s.rect(9, 14, 4, 12, "m")
        s.vline(9, 14, 12, "l")
        s.ellipse(11, 10, 10, 10, "x" if f == 0 else "t")
        s.ellipse(11, 10, 7, 7, None)
        s.ellipse(11, 10, 3, 3, "B")
        for a in range(4):
            ang = a * math.pi / 2 + (math.pi / 4 if f else 0)
            s.line(11, 10, int(11 + math.cos(ang) * 8), int(10 + math.sin(ang) * 8), "X" if f == 0 else "T")
        s.px(7, 4, "W")
    s.outline("k")
    return s


def anchor():
    """A pendulum anchor: a polished brass ring on a bracket. With Shard II the
    blade can bite into it and you swing; without it the blade skates off."""
    s = Spr(18, 22)
    s.rect(7, 0, 4, 6, "m")
    s.hline(4, 0, 10, "d")
    s.ellipse(9, 13, 8, 8, "B")
    s.ellipse(9, 13, 5, 5, None)
    s.px(5, 8, "Y"); s.px(6, 7, "Y"); s.px(4, 10, "y")
    s.px(13, 18, "b"); s.px(12, 19, "b")
    s.px(9, 6, "t"); s.px(10, 6, "T")
    s.outline("k")
    return s


def tram_uw():
    """The Line 4 tram: riveted brass and green, cold and dark, waiting for power."""
    s = Spr(160, 60)
    s.rect(4, 12, 152, 40, "q")
    s.hline(4, 12, 152, "Q")
    s.rect(4, 6, 152, 6, "B")
    s.hline(4, 6, 152, "y")
    s.ellipse(80, 6, 74, 4, "B")
    for x in range(12, 148, 20):
        s.rect(x, 18, 14, 14, "k")
        s.rect(x + 1, 19, 12, 12, "2")
        s.hline(x + 1, 19, 12, "3")
    s.rect(4, 36, 152, 4, "B")
    s.rect(70, 18, 20, 30, "k")
    s.rect(71, 19, 18, 28, "Q")
    for x in (24, 56, 104, 136):
        s.ellipse(x, 54, 5, 5, "d")
        s.ellipse(x, 54, 2, 2, "B")
    s.rect(140, 38, 10, 6, "k")
    s.ellipse(145, 41, 2, 2, "x")
    s.rect(14, 40, 14, 8, "B")
    s.px(17, 42, "k"); s.px(21, 42, "k"); s.px(25, 42, "k")
    s.outline("k")
    return s


def forge_gate():
    """The sealed Forge Gate at the end of Line 4: a heavy door with a dead
    power lamp (it needs current to open)."""
    s = Spr(72, 96)
    s.rect(4, 8, 64, 88, "d")
    s.ellipse(36, 10, 32, 10, "d")
    s.rect(8, 16, 56, 80, "m")
    s.vline(36, 16, 80, "k")
    for y in range(24, 96, 12):
        s.hline(8, y, 56, "d")
        s.px(12, y + 2, "B"); s.px(59, y + 2, "B")
    s.ellipse(36, 50, 12, 12, "B")
    s.ellipse(36, 50, 8, 8, "k")
    for i in range(7):
        ang = i * math.tau / 7 - math.pi / 2
        s.px(int(36 + math.cos(ang) * 5), int(50 + math.sin(ang) * 5), "y")
    s.rect(32, 2, 8, 6, "k")
    s.rect(33, 3, 6, 4, "2")
    s.outline("k")
    return s


def sign(text):
    w = len(text) * 8 + 10
    s = Spr(w, 18)
    s.rect(0, 0, w, 18, "B")
    s.rect(1, 1, w - 2, 16, "e")
    s.hline(1, 1, w - 2, "E")
    font = {
        "A": ["111", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "C": ["111", "100", "100", "100", "111"],
        "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"], "G": ["111", "100", "101", "101", "111"],
        "I": ["111", "010", "010", "010", "111"], "K": ["101", "110", "100", "110", "101"], "L": ["100", "100", "100", "100", "111"],
        "M": ["101", "111", "111", "101", "101"], "N": ["111", "101", "101", "101", "101"], "O": ["111", "101", "101", "101", "111"],
        "P": ["111", "101", "111", "100", "100"], "R": ["110", "101", "110", "101", "101"], "S": ["111", "100", "111", "001", "111"],
        "T": ["111", "010", "010", "010", "010"], "U": ["101", "101", "101", "101", "111"], "W": ["101", "101", "111", "111", "101"],
        "4": ["101", "101", "111", "001", "001"], "&": ["010", "101", "010", "101", "011"], " ": ["000", "000", "000", "000", "000"],
    }
    total = sum(len(font[c][0]) * 2 + 2 for c in text) - 2
    x = (w - total) // 2
    for c in text:
        rows = font[c]
        for yy, row in enumerate(rows):
            for xx, on in enumerate(row):
                if on == "1":
                    s.rect(x + xx * 2, 4 + yy * 2, 2, 2, "Y")
        x += len(rows[0]) * 2 + 2
    s.outline("k")
    return s


def front(kind):
    """Shopfronts in Pipe Market (2D side view, feet on the bottom row)."""
    if kind == "gauge":
        s = Spr(104, 92)
        s.rect(4, 20, 96, 72, "r")
        for row in range(12):
            y0 = 20 + row * 6
            off = 4 if row % 2 else 0
            for bx in range(-1, 13):
                x0 = 4 + bx * 8 + off
                s.rect(max(4, x0 + 1), y0 + 1, min(7, 99 - x0), 5, "R" if (row + bx) % 3 else "r")
        s.rect(0, 14, 104, 8, "B")
        s.hline(0, 14, 104, "Y")
        s.ellipse(52, 8, 10, 10, "B")
        s.ellipse(52, 8, 7, 7, "W")
        s.line(52, 8, 57, 4, "x")
        s.rect(14, 40, 30, 26, "k")
        s.rect(15, 41, 28, 24, "a")
        for gx, gy in ((21, 48), (33, 52), (24, 59)):
            s.ellipse(gx, gy, 4, 4, "B"); s.ellipse(gx, gy, 2, 2, "W")
        s.rect(60, 52, 24, 40, "k")
        s.rect(61, 53, 22, 39, "a")
        s.rect(62, 55, 20, 37, "A")
        s.rect(61, 86, 22, 6, "o")
        s.outline("k")
        return s
    if kind == "kettle":
        s = Spr(96, 88)
        s.rect(4, 22, 88, 66, "q")
        for x in range(4, 92, 8):
            s.vline(x, 22, 66, "Q")
        s.rect(0, 16, 96, 7, "e")
        s.hline(0, 16, 96, "E")
        s.rect(34, 0, 26, 16, "l")
        s.ellipse(47, 6, 13, 6, "B")
        s.rect(58, 4, 10, 3, "B")
        s.rect(44, 0, 6, 3, "y")
        s.ellipse(20, 46, 9, 9, "B")
        s.ellipse(20, 46, 7, 7, "a")
        s.ellipse(20, 46, 5, 5, "A")
        s.rect(52, 48, 24, 40, "k")
        s.rect(53, 49, 22, 39, "a")
        s.rect(54, 51, 20, 37, "A")
        s.rect(53, 82, 22, 6, "o")
        s.outline("k")
        return s
    s = Spr(124, 96)
    s.rect(4, 24, 116, 72, "m")
    for x in range(4, 120, 12):
        s.vline(x, 24, 72, "d")
    s.rect(0, 16, 124, 8, "q")
    s.hline(0, 16, 124, "Q")
    s.ellipse(62, 16, 36, 12, "q")
    s.ellipse(62, 16, 30, 9, "Q")
    s.rect(52, 4, 20, 10, "B")
    s.ellipse(62, 9, 4, 4, "W")
    s.line(62, 9, 62, 6, "k")
    s.rect(12, 40, 36, 24, "k")
    s.rect(13, 41, 34, 22, "2")
    s.hline(13, 41, 34, "3")
    s.rect(80, 52, 26, 44, "k")
    s.rect(81, 53, 24, 43, "a")
    s.rect(82, 55, 22, 41, "A")
    s.rect(81, 90, 24, 6, "o")
    s.outline("k")
    return s


def cog_coin():
    """The Underworks' local currency: a brass cog."""
    s = Spr(11, 11)
    s.ellipse(5, 5, 4, 4, "B")
    for (x, y) in ((5, 0), (5, 10), (0, 5), (10, 5), (2, 2), (8, 2), (2, 8), (8, 8)):
        s.px(x, y, "B")
    s.ellipse(5, 5, 1, 1, "k")
    s.px(3, 3, "Y"); s.px(4, 2, "Y")
    s.outline("k")
    return s


def icon_cog():
    """HUD icon (7x7, white: tinted by the region colour)."""
    s = Spr(7, 7)
    s.ascii(0, 0, [".W.W.W.", "WWWWWWW", ".WW.WW.", "WW...WW", ".WW.WW.", "WWWWWWW", ".W.W.W."])
    return s


def letter():
    """A lost letter (quest item)."""
    s = Spr(12, 9)
    s.rect(0, 0, 12, 9, "w")
    s.line(0, 0, 5, 5, "l")
    s.line(11, 0, 6, 5, "l")
    s.rect(5, 4, 2, 2, "x")
    s.outline("k")
    return s


def piston_walker():
    """A boiler on two piston legs. Frames: walk 0-3, windup 4, stomp 5."""
    s = Spr(36, 40, 6)
    for f in range(6):
        s.frame(f)
        lift = 6 if f == 4 else (0 if f == 5 else (1 if f in (1, 3) else 0))
        body_y = 6 - lift + (2 if f == 5 else 0)
        for lx, phase in ((11, 0), (23, 2)):
            step = 2 if (f < 4 and (f + phase) % 4 < 2) else 0
            top = body_y + 20
            s.rect(lx, top, 4, 40 - top - 3 - step, "l")
            s.vline(lx, top, 40 - top - 3 - step, "w")
            s.rect(lx - 2, 37 - step, 8, 3, "d")
        s.ellipse(18, body_y + 12, 14, 11, "e")
        s.rect(4, body_y + 12, 28, 10, "e")
        s.hline(4, body_y + 16, 28, "r")
        s.vline(5, body_y + 8, 14, "E")
        for x in range(8, 30, 5):
            s.px(x, body_y + 15, "o")
        s.rect(24, body_y + 6, 8, 6, "k")
        s.rect(25, body_y + 7, 6, 4, "f" if f != 4 else "A")
        s.rect(10, body_y - 2, 5, 6, "m")
        if f == 4:
            s.rect(9, body_y - 6, 7, 4, "w")
    s.outline("k")
    return s


def valve_turret():
    """A wall-mounted steam turret. Frames: idle, charging (valve glows), firing, shut off."""
    s = Spr(26, 26, 4)
    for f in range(4):
        s.frame(f)
        s.rect(0, 4, 6, 18, "d")
        s.vline(0, 4, 18, "m")
        s.ellipse(12, 13, 9, 9, "e")
        s.vline(4, 6, 14, "E")
        s.rect(16, 10, 10, 6, "B")
        s.hline(16, 10, 10, "y")
        s.rect(24, 9, 2, 8, "B")
        col = {0: "x", 1: "A", 2: "W", 3: "t"}[f]
        s.ellipse(11, 12, 4, 4, col)
        s.px(11, 12, "k")
        s.line(8, 9, 14, 15, "k" if f != 3 else "T")
    s.outline("k")
    return s


def bellows_bat():
    """A flying bellows with brass ribs. Frames: flap up, mid, down, dive."""
    s = Spr(30, 22, 4)
    for f in range(4):
        s.frame(f)
        wing = {0: -6, 1: 0, 2: 5, 3: -2}[f]
        for side in (-1, 1):
            tip_x = 15 + side * 14
            s.line(15 + side * 4, 10, tip_x, 10 + wing, "e")
            s.line(15 + side * 4, 12, tip_x, 12 + wing, "e")
            s.line(15 + side * 4, 11, tip_x - side * 2, 11 + wing, "E")
            s.line(15 + side * 4, 9, tip_x, 10 + wing, "B")
        s.ellipse(15, 11, 5, 6 if f != 3 else 4, "q")
        s.ellipse(15, 11, 3, 4 if f != 3 else 2, "Q")
        s.rect(14, 16, 3, 4, "B")
        s.px(13, 9, "A"); s.px(17, 9, "A")
    s.outline("k")
    return s


def clock_spider():
    """A clockwork spider with a wind-up key on its back. Frames: idle, crouch, leap."""
    s = Spr(26, 20, 3)
    for f in range(3):
        s.frame(f)
        by = {0: 8, 1: 11, 2: 6}[f]
        for i, lx in enumerate((4, 9, 17, 22)):
            fy = 19 if f != 2 else 15
            kx = lx + (-2 if lx < 13 else 2)
            s.line(13 + (lx - 13) // 3, by + 3, kx, by - 1 if f != 1 else by + 1, "d")
            s.line(kx, by - 1 if f != 1 else by + 1, lx, fy, "d")
        s.ellipse(13, by + 3, 7, 4, "B")
        s.ellipse(13, by + 3, 5, 2, "y")
        s.rect(17, by + 2, 3, 2, "x")
        s.px(19, by + 2, "X")
        s.rect(12, by - 4, 2, 4, "m")
        s.rect(10, by - 6, 6, 2, "l")
    s.outline("k")
    return s


def boiler_bloat():
    """A floating pressure tank. Frames: calm, swelling, about to burst."""
    s = Spr(28, 28, 3)
    for f in range(3):
        s.frame(f)
        r = (8, 10, 12)[f]
        s.ellipse(14, 14, r, r, "e" if f < 2 else "R")
        s.ellipse(14, 14, r - 2, r - 2, "E" if f < 2 else "O")
        s.ellipse(11, 11, 2, 2, "o" if f < 2 else "A")
        for a in range(6):
            ang = a * math.pi / 3
            s.px(int(14 + math.cos(ang) * (r - 1)), int(14 + math.sin(ang) * (r - 1)), "B")
        s.rect(12, 14 - r - 3, 4, 3, "m")
        s.ellipse(14, 16, 3, 2, "W" if f == 2 else "B")
    s.outline("k")
    return s


def lamplighter():
    """The Lamplighter: a tall, thin automaton with a hook-pole and a lantern
    for a head. Frames: walk 0-1, sweep windup 2, sweep 3, leap 4."""
    s = Spr(56, 68, 5)
    for f in range(5):
        s.frame(f)
        stride = (3, -3, 0, 2, 0)[f]
        hy = 8 if f != 4 else 4
        s.line(24, 40, 22 - stride, 66, "d")
        s.line(30, 40, 32 + stride, 66, "d")
        s.line(23, 40, 21 - stride, 66, "m")
        s.rect(19 - stride, 65, 6, 3, "k")
        s.rect(30 + stride, 65, 6, 3, "k")
        s.rect(20, hy + 14, 16, 28, "z")
        s.vline(20, hy + 14, 28, "d")
        for y in range(hy + 18, hy + 40, 6):
            s.px(28, y, "B")
        s.rect(18, hy + 12, 20, 4, "d")
        s.rect(22, hy, 12, 12, "k")
        s.rect(23, hy + 1, 10, 10, "A" if f != 2 else "W")
        s.rect(26, hy + 3, 4, 6, "W")
        s.hline(21, hy - 1, 14, "B")
        s.rect(26, hy - 4, 4, 3, "B")
        if f in (0, 1, 4):
            s.line(38, hy + 22, 46, hy - 2, "e")
            s.line(46, hy - 2, 50, hy + 2, "B")
        elif f == 2:
            s.line(36, hy + 24, 8, hy + 6, "e")
            s.line(8, hy + 6, 4, hy + 10, "B")
        else:
            s.line(36, hy + 26, 55, hy + 30, "e")
            s.line(55, hy + 30, 55, hy + 34, "B")
    s.outline("k")
    return s


def governor_head():
    """The Great Governor's head: the brass valve-crown on top of its spindle,
    with one great gauge eye. Frames: calm, angry (overpressure), cracked."""
    s = Spr(56, 44, 3)
    for f in range(3):
        s.frame(f)
        s.ellipse(28, 26, 24, 16, "B")
        s.ellipse(28, 24, 22, 12, "y")
        s.hline(6, 26, 44, "b")
        for a in range(10):
            ang = math.pi + a * math.pi / 9
            s.px(int(28 + math.cos(ang) * 23), int(26 + math.sin(ang) * 15), "Y")
        s.ellipse(28, 24, 10, 10, "k")
        s.ellipse(28, 24, 8, 8, "W" if f == 0 else ("A" if f == 1 else "w"))
        for a in range(7):
            ang = math.pi * (0.8 + a * 0.24)
            s.px(int(28 + math.cos(ang) * 6), int(24 + math.sin(ang) * 6), "k")
        ang = math.pi * (1.3 if f == 0 else 1.95)
        s.line(28, 24, int(28 + math.cos(ang) * 7), int(24 + math.sin(ang) * 7), "x")
        if f == 2:
            s.line(22, 18, 30, 28, "k")
            s.line(30, 28, 27, 32, "k")
        s.rect(24, 0, 8, 10, "B")
        s.ellipse(28, 2, 6, 3, "x")
        s.rect(20, 38, 16, 6, "b")
    s.outline("k")
    return s


def wall_brass():
    """Gauge & Gear shop: brass panels over green tile, gauges set in the wall."""
    s = Spr(32, 64)
    s.rect(0, 0, 32, 64, "B")
    for y in range(0, 40, 10):
        s.hline(0, y, 32, "b")
        s.hline(0, y + 1, 32, "y")
        for x in (3, 28):
            s.px(x, y + 4, "Y")
    s.ellipse(16, 22, 5, 5, "b")
    s.ellipse(16, 22, 4, 4, "W")
    s.line(16, 22, 18, 19, "x")
    s.rect(0, 40, 32, 24, "q")
    for x in range(0, 32, 8):
        for y in range(40, 64, 8):
            s.rect(x + 1, y + 1, 6, 6, "Q")
    s.hline(0, 40, 32, "Y")
    s.hline(0, 63, 32, "k")
    return s


def wall_tea():
    """The Kettle tea house: warm wallpaper with a stripe, a dark wood rail."""
    s = Spr(32, 64)
    s.rect(0, 0, 32, 64, "r")
    for x in range(0, 32, 8):
        s.vline(x + 3, 0, 44, "R")
        for y in range(4, 44, 10):
            s.px(x + 6, y, "o")
    s.rect(0, 44, 32, 4, "E")
    s.hline(0, 44, 32, "o")
    s.rect(0, 48, 32, 16, "e")
    for x in range(0, 32, 8):
        s.rect(x + 2, 51, 4, 10, "E")
    s.hline(0, 63, 32, "k")
    return s


def wall_depot():
    """Tram depot office: green-painted iron with a timetable rail."""
    s = Spr(32, 64)
    s.rect(0, 0, 32, 64, "Q")
    for x in range(0, 32, 16):
        s.vline(x, 0, 64, "q")
        for y in range(4, 64, 12):
            s.px(x + 2, y, "B")
    s.rect(0, 40, 32, 2, "B")
    s.hline(0, 40, 32, "Y")
    s.rect(0, 58, 32, 6, "d")
    s.hline(0, 63, 32, "k")
    return s


def floor_tile():
    """Black and cream tile, chipped (Underworks interiors)."""
    s = Spr(32, 32)
    for y in range(0, 32, 8):
        for x in range(0, 32, 8):
            s.rect(x, y, 8, 8, "w" if (x // 8 + y // 8) % 2 == 0 else "z")
    s.px(5, 3, "l"); s.px(21, 17, "d"); s.px(12, 27, "l")
    return s


def tea_bar():
    """The Kettle's bar: a long counter with an enormous copper urn."""
    s = Spr(96, 44)
    s.rect(2, 22, 92, 22, "E")
    s.hline(2, 22, 92, "o")
    s.rect(0, 18, 96, 5, "e")
    s.hline(0, 18, 96, "E")
    for x in range(8, 92, 16):
        s.rect(x, 27, 10, 13, "e")
    s.rect(60, 0, 22, 18, "e")
    s.ellipse(71, 2, 11, 3, "B")
    s.vline(61, 1, 17, "o")
    s.rect(82, 10, 6, 2, "B")
    s.rect(87, 10, 2, 5, "B")
    for cx in (14, 26, 38):
        s.rect(cx, 13, 5, 5, "W")
        s.px(cx + 5, 15, "W")
        s.hline(cx, 13, 5, "s")
    s.outline("k")
    return s


def gauge_case():
    """A glass case of gauges and dials (Gauge & Gear)."""
    s = Spr(48, 46)
    s.rect(2, 10, 44, 36, "e")
    s.rect(4, 12, 40, 22, "s")
    for gx, gy in ((12, 22), (24, 20), (36, 24)):
        s.ellipse(gx, gy, 5, 5, "B")
        s.ellipse(gx, gy, 3, 3, "W")
        s.px(gx + 1, gy - 1, "x")
    s.line(6, 13, 12, 13, "S")
    s.rect(2, 34, 44, 3, "E")
    s.hline(2, 8, 44, "B")
    s.outline("k")
    return s


def ticket_desk():
    s = Spr(80, 40)
    s.rect(2, 14, 76, 26, "Q")
    s.hline(2, 14, 76, "y")
    s.rect(0, 10, 80, 5, "B")
    s.hline(0, 10, 80, "Y")
    s.rect(10, 0, 14, 10, "W")
    s.hline(12, 3, 10, "l"); s.hline(12, 6, 10, "l")
    s.rect(50, 2, 10, 8, "B")
    s.ellipse(55, 5, 4, 3, "y")
    s.outline("k")
    return s


def timetable():
    s = Spr(40, 30)
    s.rect(0, 0, 40, 30, "B")
    s.rect(2, 2, 36, 26, "k")
    s.hline(4, 5, 32, "y")
    for i, y in enumerate((10, 14, 18, 22)):
        s.hline(4, y, 18, "w")
        s.hline(26, y, 10, "x" if i == 3 else "w")
    return s


if __name__ == "__main__":
    uw_far(); uw_mid(); uw_works()
    for name, fn in (("uw_gaslamp", gaslamp), ("uw_wall_lamp", wall_lamp), ("uw_gauge", gauge), ("uw_boiler", boiler),
                     ("uw_pipes", pipes_bundle), ("uw_stall", stall), ("uw_flywheel", flywheel), ("uw_valve", valve),
                     ("uw_anchor", anchor), ("uw_tram", tram_uw), ("uw_forge_gate", forge_gate)):
        save(fn(), PROPS, name)
    save(house(0), PROPS, "uw_house_a")
    save(house(1), PROPS, "uw_house_b")
    save(sign("PIPE MARKET"), PROPS, "uw_sign_market")
    save(sign("LINE 4"), PROPS, "uw_sign_line4")
    save(sign("BELLOWS ROW"), PROPS, "uw_sign_row")
    save(front("gauge"), PROPS, "front_gauge")
    save(front("kettle"), PROPS, "front_kettle")
    save(front("depot"), PROPS, "front_depot")
    save(cog_coin(), ITEMS, "cog")
    save(letter(), ITEMS, "letter")
    save(icon_cog(), UI, "icon_cog")
    for name, fn in (("piston_walker", piston_walker), ("valve_turret", valve_turret), ("bellows_bat", bellows_bat),
                     ("clock_spider", clock_spider), ("boiler_bloat", boiler_bloat), ("lamplighter", lamplighter),
                     ("governor_head", governor_head)):
        save(fn(), ENEMIES, name)
    for name, fn in (("wall_brass", wall_brass), ("wall_tea", wall_tea), ("wall_depot", wall_depot), ("floor_tile", floor_tile),
                     ("tea_bar", tea_bar), ("gauge_case", gauge_case), ("ticket_desk", ticket_desk), ("timetable", timetable)):
        save(fn(), INTERIORS, name)
    print("underworks art written")
