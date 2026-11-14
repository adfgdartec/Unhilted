"""Hand-composed painterly backdrops (replaces the procedural night skyline).

Principles: big shapes, few values, smooth colour, aerial perspective (the
farther a layer, the lighter and warmer it is, melting into the smog sun),
and specific landmarks instead of random buildings. All shapes below are
authored point lists; nothing is random.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "backdrops")
W, H = 640, 400


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(img, stops):
    px = img.load()
    for y in range(H):
        for i in range(len(stops) - 1):
            y0, c0 = stops[i]
            y1, c1 = stops[i + 1]
            if y0 <= y <= y1:
                c = lerp(c0, c1, (y - y0) / max(y1 - y0, 1))
                break
        for x in range(W):
            px[x, y] = c + (255,)


def wrap_poly(draw, pts, fill):
    """Draw a polygon three times so shapes crossing the edge wrap seamlessly."""
    for dx in (-W, 0, W):
        draw.polygon([(x + dx, y) for x, y in pts], fill=fill)


def wrap_line(draw, pts, fill, width=1):
    for dx in (-W, 0, W):
        draw.line([(x + dx, y) for x, y in pts], fill=fill, width=width)


def ridge(points, step=4):
    """Piecewise-linear silhouette through hand-placed (x, y) control points.
    Returns a dense list of (x, y) across 0..W (first point is repeated at W)."""
    pts = sorted(points)
    pts = pts + [(pts[0][0] + W, pts[0][1])]
    out = []
    for x in range(0, W + 1, 1):
        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            xx = x if x >= pts[0][0] else x + W
            if x0 <= xx <= x1:
                out.append((x, y0 + (y1 - y0) * (xx - x0) / max(x1 - x0, 1)))
                break
    return out


def fill_ridge(img, profile, color, rim=None, rim_hot=None):
    """Fill below a silhouette; light the top edge (hotter where the slope faces the sun, right)."""
    px = img.load()
    for i, (x, y) in enumerate(profile[:-1]):
        if x >= W:
            continue
        yi = int(round(y))
        for yy in range(max(yi, 0), H):
            px[x, yy] = color + (255,)
        if rim:
            nxt = profile[i + 1][1]
            facing_sun = nxt > y + 0.15
            px[x, max(yi, 0)] = (rim_hot if (facing_sun and rim_hot) else rim) + (255,)


# ------------------------------------------------------------------ THE HEAP
SKY = [(0, (34, 48, 62)), (110, (66, 72, 82)), (190, (126, 98, 88)), (250, (198, 128, 84)),
       (292, (230, 166, 106)), (322, (240, 194, 138)), (400, (240, 194, 138))]
SUN = (470, 268)


def overlay(img, paint):
    """Paint translucent shapes on a separate layer, then blend it in
    (ImageDraw alone overwrites alpha instead of blending)."""
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    paint(ImageDraw.Draw(ov, "RGBA"))
    img.alpha_composite(ov)


def cloud(d, cx, width, base, thick, col, lit):
    """One elongated cloud: rounded lumpy top, flat sunlit underside."""
    half = width / 2
    for dx in (-W, 0, W):
        top = []
        for i in range(0, int(width) + 1, 2):
            x = cx - half + i
            u = (x - cx) / half
            h = thick * math.sqrt(max(0.0, 1 - u * u)) * (0.75 + 0.25 * math.sin(x * 0.11 + cx))
            top.append((x + dx, base - h))
        d.polygon(top + [(cx + half + dx, base), (cx - half + dx, base)], fill=col + (255,))
        d.line([(cx - half * 0.85 + dx, base), (cx + half * 0.85 + dx, base)], fill=lit + (255,), width=1)


def heap_sky():
    img = Image.new("RGBA", (W, H))
    gradient(img, SKY)

    def sun(d):
        for r, a in ((100, 22), (68, 40)):
            d.ellipse([SUN[0] - r, SUN[1] - r, SUN[0] + r, SUN[1] + r], fill=(250, 214, 160, a))
    overlay(img, sun)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([SUN[0] - 40, SUN[1] - 40, SUN[0] + 40, SUN[1] + 40], fill=(252, 226, 176, 255))
    # high cool clouds, warm mid clouds lit from below, thin streaks across the sun
    for args in (
        (90, 170, 72, 9, (56, 64, 76), (78, 82, 90)), (370, 230, 58, 12, (60, 66, 78), (84, 86, 94)),
        (600, 110, 86, 6, (62, 68, 80), (86, 88, 96)),
        (160, 270, 160, 13, (138, 102, 94), (214, 150, 108)), (520, 190, 176, 9, (150, 108, 96), (222, 156, 110)),
        (440, 240, 218, 5, (214, 146, 102), (242, 186, 132)), (40, 150, 230, 4, (206, 140, 98), (236, 176, 124)),
    ):
        cloud(d, *args)
    img.save(os.path.join(OUT, "heap_sky.png"))


def heap_city():
    """The megacity on the horizon, dissolved in smog; the Spire is the one dark needle."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    haze = (170, 116, 94)
    towers = [  # x, width, top y  (hand-placed skyline, tall to the left of the Spire, low near the sun)
        (0, 30, 236), (26, 18, 214), (40, 34, 244), (70, 22, 222), (88, 40, 252), (124, 16, 230),
        (136, 28, 246), (160, 20, 206), (176, 36, 238), (208, 24, 226), (228, 42, 250), (266, 18, 232),
        (280, 30, 244), (306, 24, 218), (398, 30, 248), (424, 20, 262), (440, 44, 270), (480, 26, 258),
        (502, 36, 274), (536, 22, 262), (556, 40, 276), (592, 26, 250), (614, 26, 240),
    ]
    for x, w, top in towers:
        d.rectangle([x, top, x + w, H], fill=haze + (255,))
        if w > 26:  # stepped crowns on the wide ones
            d.rectangle([x + 4, top - 6, x + w - 6, top], fill=haze + (255,))
    # trash conveyors from the city down toward the Heap (story: the city dumps on you)
    for (x0, y0, x1, y1) in ((150, 250, 40, 300), (520, 262, 640, 306)):
        d.line([(x0, y0), (x1, y1)], fill=(150, 100, 84, 255), width=3)
        for t in (0.25, 0.5, 0.75):
            lx, ly = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.line([(lx, ly), (lx, 300)], fill=(150, 100, 84, 255), width=1)
    # a trash fall pouring off the right conveyor
    for i in range(0, 34, 3):
        d.line([(634 - i % 7, 306), (630 - i % 5, 340)], fill=(186, 128, 100, 160), width=1)
    # The Spire: corp HQ, darkest thing on the horizon, a red beacon on top
    sx = 352
    d.polygon([(sx - 16, H), (sx - 16, 236), (sx - 9, 236), (sx - 9, 150), (sx - 4, 150), (sx - 2, 72),
               (sx + 2, 72), (sx + 4, 150), (sx + 9, 150), (sx + 9, 236), (sx + 16, 236), (sx + 16, H)],
              fill=(118, 78, 72, 255))
    d.rectangle([sx - 1, 68, sx + 1, 70], fill=(255, 90, 70, 255))
    img.save(os.path.join(OUT, "heap_city.png"))


def heap_far():
    """Mountains of trash with two landmarks: a toppled crane and a buried brass giant."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    body = (118, 76, 66)
    prof = ridge([(0, 300), (40, 290), (90, 276), (130, 284), (180, 268), (230, 282), (280, 296),
                  (330, 288), (380, 300), (420, 284), (470, 270), (520, 280), (560, 294), (600, 302)])
    # the brass giant: a colossal old-world head, half sunk, one eye socket (foreshadowing)
    hx, hy = 486, 262
    d.ellipse([hx - 44, hy - 30, hx + 44, hy + 58], fill=(126, 92, 58, 255))
    d.ellipse([hx - 30, hy - 20, hx + 30, hy + 40], fill=(134, 98, 62, 255))
    d.ellipse([hx - 18, hy - 2, hx - 4, hy + 10], fill=(70, 48, 40, 255))      # eye socket
    d.line([(hx + 6, hy - 26), (hx + 12, hy - 8), (hx + 8, hy + 6)], fill=(90, 62, 46, 255), width=1)  # crack
    d.arc([hx - 44, hy - 30, hx + 44, hy + 58], 280, 350, fill=(230, 178, 108, 255), width=2)  # sun rim
    fill_ridge(img, prof, body, rim=(166, 106, 84), rim_hot=(222, 150, 100))
    # toppled crane: boom lattice lying across the slope
    bx0, by0, bx1, by1 = 70, 296, 214, 240
    d.line([(bx0, by0), (bx1, by1)], fill=(96, 60, 54, 255), width=2)
    d.line([(bx0, by0 - 8), (bx1, by1 - 8)], fill=(96, 60, 54, 255), width=2)
    for i in range(0, 12):
        t0, t1 = i / 12, (i + 1) / 12
        ax, ay = bx0 + (bx1 - bx0) * t0, by0 + (by1 - by0) * t0
        cx, cy = bx0 + (bx1 - bx0) * t1, by0 + (by1 - by0) * t1
        d.line([(ax, ay), (cx, cy - 8)], fill=(96, 60, 54, 255), width=1)
    d.rectangle([56, 284, 76, 300], fill=(96, 60, 54, 255))                     # cab
    d.line([(bx1, by1 - 4), (bx1 + 10, by1 + 24)], fill=(96, 60, 54, 255), width=1)  # dangling cable
    img.save(os.path.join(OUT, "heap_far.png"))


def heap_near():
    """Close junk hills, darker and warmer, with readable shapes on the crest."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    body = (70, 46, 44)
    prof = ridge([(0, 334), (50, 322), (100, 330), (150, 316), (200, 328), (260, 338), (320, 324),
                  (380, 314), (430, 326), (490, 336), (540, 322), (590, 330)])
    # silhouettes standing on the crest (drawn first so the hill rim runs over their feet)
    d.ellipse([140, 296, 172, 314], fill=body + (255,))                          # dish, tilted
    d.line([(156, 310), (152, 324)], fill=body + (255,), width=2)
    d.rounded_rectangle([360, 296, 404, 318], radius=6, fill=body + (255,))      # car on its side
    d.ellipse([366, 308, 380, 322], fill=(52, 34, 34, 255))
    d.ellipse([388, 308, 402, 322], fill=(52, 34, 34, 255))
    d.rectangle([520, 300, 532, 326], fill=body + (255,))                        # fridge
    d.line([(250, 334), (262, 312)], fill=body + (255,), width=2)                # rebar
    d.line([(256, 336), (270, 318)], fill=body + (255,), width=1)
    fill_ridge(img, prof, body, rim=(120, 76, 62), rim_hot=(196, 124, 86))
    d.arc([140, 296, 172, 314], 300, 20, fill=(196, 124, 86, 255), width=1)
    d.line([(404, 298), (404, 316)], fill=(196, 124, 86, 255), width=1)
    img.save(os.path.join(OUT, "heap_near.png"))


# ------------------------------------------------------------------ THE INTAKE
def intake_wall():
    img = Image.new("RGBA", (W, H))
    gradient(img, [(0, (58, 26, 26)), (220, (98, 42, 34)), (400, (116, 52, 38))])
    d = ImageDraw.Draw(img, "RGBA")
    dark = (44, 20, 20, 255)
    # big press columns and a flywheel: the bay is a machine you are standing inside
    for x0, x1 in ((28, 84), (556, 612)):
        d.rectangle([x0, 40, x1, H], fill=dark)
        d.rectangle([x0 - 6, 120, x1 + 6, 134], fill=dark)
    d.ellipse([110, 100, 250, 240], outline=dark, width=12)
    d.ellipse([168, 158, 192, 182], fill=dark)
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([(180, 170), (180 + 62 * math.cos(r), 170 + 62 * math.sin(r))], fill=dark, width=4)
    d.rectangle([0, 262, W, 270], fill=dark)
    glyph = {"0": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"],
             "7": ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."]}

    def paint(o):
        # faded stencil "07": this is Intake Unit 7's bay
        for di, ch in enumerate("07"):
            for gy, row in enumerate(glyph[ch]):
                for gx, c in enumerate(row):
                    if c == "#":
                        x = 300 + di * 62 + gx * 9
                        y = 120 + gy * 9
                        o.rectangle([x, y, x + 8, y + 8], fill=(222, 176, 128, 40))
        # light shafts from the roof vents
        for x0 in (230, 380, 470):
            o.polygon([(x0, 0), (x0 + 34, 0), (x0 + 140, H), (x0 + 70, H)], fill=(255, 176, 116, 22))
    overlay(img, paint)
    img.save(os.path.join(OUT, "intake_wall.png"))


def intake_girders():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    c = (30, 14, 16, 255)
    d.rectangle([0, 30, W, 34], fill=c)
    d.rectangle([0, 60, W, 64], fill=c)
    for x in range(0, W, 40):
        d.line([(x, 34), (x + 20, 60)], fill=c, width=2)
        d.line([(x + 20, 60), (x + 40, 34)], fill=c, width=2)
    for x in (300, 420):  # hanging hooks in silhouette
        d.line([(x, 64), (x, 120)], fill=c, width=1)
        d.arc([x - 6, 116, x + 6, 128], 0, 180, fill=c, width=2)
    img.save(os.path.join(OUT, "intake_girders.png"))


# ------------------------------------------------------------------ UNDER THE HEAP (cave)
def _debris(d, rnd, x0, x1, y0, y1, dark, lite, n):
    """Small pressed-in junk (boards, cans, pipe ends, bottles) as 2-tone marks."""
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        k = rnd.randint(0, 4)
        if k == 0:    # board
            w = rnd.randint(8, 18)
            d.line([(x, y), (x + w, y + rnd.randint(-2, 2))], fill=dark, width=2)
            d.line([(x, y - 1), (x + w, y - 1)], fill=lite, width=1)
        elif k == 1:  # can / pipe end
            d.ellipse([x, y, x + 4, y + 4], fill=dark)
            d.point((x + 1, y + 1), fill=lite)
        elif k == 2:  # bottle
            d.rectangle([x, y, x + 2, y + 5], fill=dark)
            d.point((x + 1, y - 1), fill=dark)
            d.point((x, y + 1), fill=lite)
        elif k == 3:  # wire squiggle
            d.line([(x + i, y + int(2 * math.sin(i / 2.0))) for i in range(0, 12, 2)], fill=dark, width=1)
        else:         # crushed panel
            d.polygon([(x, y), (x + 7, y - 2), (x + 9, y + 3), (x + 2, y + 5)], fill=dark)
            d.line([(x, y), (x + 7, y - 2)], fill=lite, width=1)


def cave_far():
    """The inside of the trash heap: compacted strata with old-world things
    pressed into them, lit only where daylight leaks through cracks."""
    import random
    rnd = random.Random(7)
    img = Image.new("RGBA", (W, H))
    gradient(img, [(0, (18, 14, 22)), (120, (34, 25, 33)), (300, (56, 38, 40)), (400, (62, 42, 42))])
    d = ImageDraw.Draw(img, "RGBA")
    bands = [(64, (38, 28, 36)), (124, (46, 33, 40)), (186, (42, 30, 37)), (246, (54, 38, 42)), (312, (62, 43, 44))]
    for i, (y0, col) in enumerate(bands):
        prof = ridge([(x, y0 + 7 * math.sin(x / (37.0 + i * 9) + i * 1.7) + 4 * math.sin(x / 13.0 + i))
                      for x in range(0, W, 16)])
        fill_ridge(img, prof, col, rim=tuple(min(c + 10, 255) for c in col))
        dark = tuple(max(c - 12, 0) for c in col) + (255,)
        lite = tuple(min(c + 16, 255) for c in col) + (255,)
        _debris(d, rnd, 0, W - 12, y0 + 6, y0 + 56, dark, lite, 46)
    sil = (30, 21, 27, 255)
    edge = (78, 56, 54, 255)
    # things pressed into the walls (top edges catch a little light so they read)
    d.rounded_rectangle([40, 214, 132, 250], radius=10, fill=sil)
    d.polygon([(62, 214), (78, 196), (112, 196), (124, 214)], fill=sil)
    d.line([(78, 196), (112, 196)], fill=edge, width=1)
    d.polygon([(82, 199), (94, 199), (94, 212), (70, 212)], fill=(40, 40, 52, 255))
    d.ellipse([52, 238, 76, 262], fill=(20, 14, 20, 255))
    d.ellipse([98, 238, 122, 262], fill=(20, 14, 20, 255))
    d.ellipse([60, 246, 68, 254], fill=edge)
    d.rectangle([196, 120, 222, 170], fill=sil)
    d.line([(196, 120), (222, 120)], fill=edge, width=1)
    d.line([(201, 140), (217, 140)], fill=(44, 32, 38, 255), width=1)
    d.rectangle([218, 126, 219, 136], fill=edge)
    d.rectangle([300, 268, 334, 300], fill=sil)
    d.line([(300, 268), (334, 268)], fill=edge, width=1)
    d.ellipse([306, 274, 328, 296], outline=(62, 46, 50, 255), width=2)
    d.rectangle([410, 150, 446, 178], fill=sil)
    d.rectangle([414, 154, 438, 172], fill=(40, 42, 56, 255))
    d.line([(415, 155), (424, 155)], fill=(70, 76, 96, 255), width=1)
    d.line([(410, 150), (446, 150)], fill=edge, width=1)
    for x in range(486, 548, 6):
        d.line([(x, 290), (x + 4, 314)], fill=sil, width=1)
    d.line([(482, 290), (552, 290)], fill=edge, width=2)
    d.line([(486, 314), (550, 314)], fill=sil, width=2)

    def paint(o):
        for cx, cy, r in ((90, 330, 100), (330, 360, 80), (560, 300, 90)):
            for k in range(7):
                rr = r * (1 - k / 7)
                o.ellipse([cx - rr, cy - rr * 0.6, cx + rr, cy + rr * 0.6], fill=(255, 168, 108, 9))
        for x0 in (70, 320, 545):
            o.polygon([(x0, 0), (x0 + 14, 0), (x0 + 54, H), (x0 + 22, H)], fill=(255, 200, 150, 12))
    overlay(img, paint)
    img.save(os.path.join(OUT, "cave_far.png"))


def cave_mid():
    """Nearer junk pillars holding the roof up, rim-lit by the shafts, and
    roots of cable and rebar hanging from the ceiling."""
    import random
    rnd = random.Random(11)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    body = (24, 17, 23, 255)
    rim = (128, 84, 62, 255)
    rim_cool = (60, 50, 64, 255)
    for cx, wmid, seed in ((120, 30, 1.0), (380, 40, 2.3), (575, 26, 3.1)):
        right, left = [], []
        for y in range(0, H + 1, 2):
            t = y / H
            flare = 26 * (max(0.0, 0.18 - t) / 0.18) ** 2 + 30 * (max(0.0, t - 0.8) / 0.2) ** 2
            half = wmid / 2 + flare + 5 * math.sin(y / 19.0 + seed) + 3 * math.sin(y / 7.0 + seed * 2)
            lhalf = wmid / 2 + flare + 4 * math.sin(y / 23.0 + seed * 3) + 3 * math.sin(y / 9.0 + seed)
            right.append((cx + half, y))
            left.append((cx - lhalf, y))
        d.polygon(right + list(reversed(left)), fill=body)
        d.line(right, fill=rim, width=1)          # warm light from the shafts on the right
        d.line(left, fill=rim_cool, width=1)
        # junk chunks jutting out of the pillar
        for _ in range(7):
            y = rnd.randint(30, H - 60)
            side = rnd.choice((-1, 1))
            x = cx + side * (wmid / 2 + 2)
            w, h = rnd.randint(5, 10), rnd.randint(3, 6)
            box = [x, y, x + w * side, y + h] if side > 0 else [x + w * side, y, x, y + h]
            d.rectangle([min(box[0], box[2]), box[1], max(box[0], box[2]), box[3]], fill=body)
            d.line([(min(box[0], box[2]), box[1]), (max(box[0], box[2]), box[1])], fill=rim if side > 0 else rim_cool, width=1)
        _debris(d, rnd, int(cx - wmid / 2) + 2, int(cx + wmid / 2) - 12, 20, H - 40, (34, 25, 32, 255), (52, 40, 44, 255), 14)
    for x0, length, sway in ((40, 60, 3), (205, 90, 4), (250, 44, 2), (300, 70, 3), (470, 100, 5), (610, 52, 2)):
        for i in range(2):
            pts = [(x0 + i * 3 + sway * math.sin(y / 15.0 + i), y) for y in range(0, length, 2)]
            d.line(pts, fill=(32, 23, 29, 255), width=1)
        d.line([(x0 + 6, 0), (x0 + 9, length * 0.4)], fill=(58, 44, 46, 255), width=1)
    prof = ridge([(0, 372), (60, 362), (140, 370), (230, 358), (320, 368), (420, 360), (520, 370), (600, 362)])
    fill_ridge(img, prof, (28, 20, 25), rim=(74, 52, 50), rim_hot=(120, 80, 60))
    img.save(os.path.join(OUT, "cave_mid.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    heap_sky(); heap_city(); heap_far(); heap_near(); intake_wall(); intake_girders()
    cave_far(); cave_mid()
    print("painterly backdrops built")
