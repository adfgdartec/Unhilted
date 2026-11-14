"""Layered pixel-art sprites for the rogue robot, every outfit piece and the blade.
Run from the project root:  python3 tools/art/build_character.py

How it works
------------
A small 2D rig (hips, knees, feet, shoulders, elbows, hands, head) is posed by
hand for every frame of every animation. Each layer (body, pants, shoes, shirt,
arm, cloak, face, hood, mask, blade) is drawn from those same joints, so any
combination of outfit pieces lines up on every frame. Each part is shaded with
a 5-step ramp lit from the top-left (outline, shadow, base, light, highlight)
and every layer gets its own dark outline, like the props.

Frames are 48x48, facing right, feet on row 44 (the game offsets sprites so
row 44 sits on the floor). Output:
  art/character/<layer>.png            one row of frames, all animations
  art/character/frames/<layer>.tres    Godot SpriteFrames for that sheet
  art/ui/cosmetics/<item>.png          32x32 shop / wardrobe icon
"""
import colorsys
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "character")
FR = os.path.join(OUT, "frames")
ICONS = os.path.join(ROOT, "art", "ui", "cosmetics")
for d in (OUT, FR, ICONS):
    os.makedirs(d, exist_ok=True)

S = 48
FEET = 44

ANIMS = [
    ("idle", 4, 5.0, True), ("run", 8, 14.0, True), ("jump", 2, 10.0, False), ("fall", 2, 8.0, True),
    ("attack", 4, 18.0, False), ("attack_up", 4, 18.0, False), ("attack_down", 4, 18.0, False),
    ("throw", 3, 20.0, False), ("grapple", 2, 8.0, True), ("dash", 2, 14.0, True),
    ("hurt", 2, 10.0, False), ("dead", 4, 8.0, False),
    ("slide", 2, 12.0, True), ("wall", 2, 8.0, True),
]


def ramp_from(rgb, warm=0.02):
    """outline, shadow, base, light, highlight with hue shifting (cool shadows, warm lights)."""
    r, g, b = [c / 255.0 for c in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    def c(dh, sm, vm, va=0.0):
        hh = (h + dh) % 1.0
        rr, gg, bb = colorsys.hsv_to_rgb(hh, max(0.0, min(1.0, s * sm)), max(0.0, min(1.0, v * vm + va)))
        return (int(rr * 255), int(gg * 255), int(bb * 255))
    return [c(0.04, 1.05, 0.26), c(0.025, 1.08, 0.64), c(0, 1, 1), c(-warm, 0.86, 1.16, 0.04), c(-warm * 1.5, 0.6, 1.3, 0.12)]


STEEL = [(24, 22, 32), (62, 66, 82), (104, 112, 128), (154, 162, 176), (210, 216, 224)]
STEEL_BACK = [(20, 18, 28), (46, 48, 62), (74, 80, 96), (106, 114, 130), (140, 148, 160)]
GLASS = [(10, 10, 18), (16, 18, 30), (26, 30, 46), (52, 62, 86), (110, 130, 160)]
BRASS = [(40, 26, 14), (120, 82, 34), (176, 128, 54), (222, 176, 84), (250, 226, 150)]
CYAN = (56, 242, 255)
CYAN_HI = (190, 252, 255)
RED = (255, 84, 70)


YY, XX = np.mgrid[0:S, 0:S]
PX = XX + 0.5
PY = YY + 0.5


def disk(cx, cy, r):
    return (PX - cx) ** 2 + (PY - cy) ** 2 <= r * r


def ellipse(cx, cy, rx, ry):
    return ((PX - cx) / rx) ** 2 + ((PY - cy) / ry) ** 2 <= 1.0


def capsule(p0, p1, r0, r1=None):
    r1 = r0 if r1 is None else r1
    ax, ay = p0
    bx, by = p1
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy
    t = np.clip(((PX - ax) * dx + (PY - ay) * dy) / max(ll, 1e-6), 0, 1)
    qx, qy = ax + t * dx, ay + t * dy
    r = r0 + (r1 - r0) * t
    return (PX - qx) ** 2 + (PY - qy) ** 2 <= r * r


def poly(pts):
    im = Image.new("1", (S, S), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=1)
    return np.array(im, dtype=bool)


def shifted(m, dx, dy):
    out = np.zeros_like(m)
    ys = slice(max(dy, 0), S + min(dy, 0))
    yd = slice(max(-dy, 0), S + min(-dy, 0))
    xs = slice(max(dx, 0), S + min(dx, 0))
    xd = slice(max(-dx, 0), S + min(-dx, 0))
    out[ys, xs] = m[yd, xd]
    return out


class Layer:
    def __init__(self):
        self.rgba = np.zeros((S, S, 4), dtype=np.uint8)

    def opaque(self):
        return self.rgba[:, :, 3] > 0

    def paint(self, mask, ramp, flat=False, deep=True):
        """Fill a part with its ramp: light on the top-left rim, shadow bottom-right."""
        if not mask.any():
            return
        lvl = np.full((S, S), 2, dtype=np.int8)
        if not flat:
            dr = mask & ~shifted(mask, -1, -1)
            if deep:
                dr |= mask & ~shifted(mask, -2, -2) & ~shifted(mask, 0, -2)
            ul = mask & ~shifted(mask, 1, 1)
            hi = mask & ~shifted(mask, 1, 0) & ~shifted(mask, 0, 1)
            lvl[dr] = 1
            lvl[ul] = 3
            lvl[hi & ul] = 4
        for k in range(5):
            sel = mask & (lvl == k)
            self.rgba[sel, :3] = ramp[k]
            self.rgba[sel, 3] = 255

    def dot(self, x, y, rgb, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < S and 0 <= y < S:
            if a >= 255 or self.rgba[y, x, 3] == 0:
                self.rgba[y, x, :3] = rgb
                self.rgba[y, x, 3] = max(a, int(self.rgba[y, x, 3]))
            else:
                t = a / 255.0
                self.rgba[y, x, :3] = (self.rgba[y, x, :3] * (1 - t) + np.array(rgb) * t).astype(np.uint8)

    def line(self, p0, p1, rgb, a=255):
        n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.dot(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, rgb, a)

    def stamp(self, mask, rgb):
        self.rgba[mask, :3] = rgb
        self.rgba[mask, 3] = 255

    def outline(self, rgb):
        op = self.opaque()
        ring = ~op & (shifted(op, 1, 0) | shifted(op, -1, 0) | shifted(op, 0, 1) | shifted(op, 0, -1))
        self.rgba[ring, :3] = rgb
        self.rgba[ring, 3] = 255
        return self

    def under(self, other):
        """Composite this layer below `other` (for icons and previews)."""
        out = Layer()
        out.rgba = self.rgba.copy()
        m = other.rgba[:, :, 3] > 0
        out.rgba[m] = other.rgba[m]
        return out


def v(x, y):
    return np.array([float(x), float(y)])


def norm(a):
    n = math.hypot(a[0], a[1])
    return a / n if n > 1e-6 else v(0, 1)


def knee_for(hip, foot, length=11.5, forward=1.0):
    """Two-bone IK: the knee bends forward (toward +x * forward)."""
    d = foot - hip
    dist = min(math.hypot(*d), length * 0.999)
    mid = hip + d * 0.5
    off = math.sqrt(max((length / 2) ** 2 - (dist / 2) ** 2, 0))
    perp = norm(v(d[1], -d[0])) * -1.0
    if perp[0] * forward < 0:
        perp = -perp
    return mid + perp * off


def elbow_for(sh, hand, length=10.0, down=True):
    d = hand - sh
    dist = min(math.hypot(*d), length * 0.999)
    mid = sh + d * 0.5
    off = math.sqrt(max((length / 2) ** 2 - (dist / 2) ** 2, 0))
    perp = norm(v(-d[1], d[0]))
    if (perp[1] < 0) == down:
        perp = -perp
    if not down and perp[0] > 0:
        perp = -perp
    return mid + perp * off


class Pose:
    def __init__(self, **k):
        self.hip = v(23, 33)
        self.lean = 0.0
        self.bob = 0.0
        self.head = v(0, 0)
        self.footF = v(27, FEET)
        self.footB = v(20, FEET)
        self.handF = v(28, 32)
        self.handB = v(20, 32)
        self.elbow_down_F = True
        self.elbow_down_B = True
        self.blade = 72.0
        self.trail = 0.0
        self.flutter = 0.0
        self.lift = 0.0
        self.eyes = "open"
        self.tip = v(0, 0)
        self.lying = False
        for key, val in k.items():
            setattr(self, key, val)
        self.hip = self.hip + v(0, self.bob * 0.5)
        self.sh = self.hip + v(1 + self.lean, -10 + self.bob * 0.5)
        self.headc = self.sh + v(1 + self.lean * 0.3, -8.5) + self.head
        if self.lying:
            self.sh = self.hip + v(10, -1)
            self.headc = self.sh + v(8, -1) + self.head
        self.hipF = self.hip + v(2, 0)
        self.hipB = self.hip + v(-2, 0)
        self.kneeF = knee_for(self.hipF, self.footF)
        self.kneeB = knee_for(self.hipB, self.footB)
        self.shF = self.sh + v(1.5, 1)
        self.shB = self.sh + v(-2.5, 1)
        self.elbowF = elbow_for(self.shF, self.handF, down=self.elbow_down_F)
        self.elbowB = elbow_for(self.shB, self.handB, down=self.elbow_down_B)
        axis = norm(self.hip - self.sh)
        self.axis = axis
        self.back = v(-axis[1], axis[0]) * -1 if axis[1] < 0 else v(axis[1], -axis[0]) * -1
        self.back = norm(v(-axis[1], axis[0])) * (-1 if self.lying else 1)
        if not self.lying:
            self.back = v(-1, 0) * 1.0 + v(0, 0)


def P(**k):
    return Pose(**k)


def poses():
    out = {}
    out["idle"] = [P(bob=b, flutter=i * 0.8, handF=v(28, 32 + b * 0.5), handB=v(20, 32 + b * 0.5)) for i, b in enumerate((0, 0, 1, 1))]
    run = []
    for i in range(8):
        p = i / 8 * math.tau
        fx, bx = 23 + 6.5 * math.cos(p), 23 - 6.5 * math.cos(p)
        fy = FEET - max(0.0, 3.5 * math.sin(p))
        by = FEET - max(0.0, -3.5 * math.sin(p))
        bob = -1 if i in (1, 2, 5, 6) else 0
        run.append(P(lean=2, bob=bob, footF=v(fx, fy), footB=v(bx, by),
                     handF=v(26 - 4 * math.cos(p), 31 + bob), handB=v(21 + 4 * math.cos(p), 31 + bob),
                     blade=60 - 20 * math.cos(p), trail=0.7, flutter=i * 0.9))
    out["run"] = run
    out["jump"] = [P(footF=v(27, 41), footB=v(19, 40), handF=v(29, 27), handB=v(17, 27), blade=30, trail=0.3, lift=-0.4),
                   P(footF=v(27, 40), footB=v(20, 39), handF=v(29, 25), handB=v(17, 25), blade=20, trail=0.3, lift=-0.2, flutter=1)]
    out["fall"] = [P(footF=v(26, 45), footB=v(20, 44), handF=v(30, 24), handB=v(16, 24), blade=10, trail=0.2, lift=0.8, flutter=f) for f in (0, 1.6)]
    out["attack"] = [
        P(lean=-1, footF=v(28, FEET), footB=v(18, FEET), handF=v(20, 22), elbow_down_F=False, blade=-150, handB=v(22, 32)),
        P(lean=3, footF=v(30, FEET), footB=v(17, FEET), handF=v(35, 26), blade=0, handB=v(18, 30), trail=0.5),
        P(lean=3, footF=v(30, FEET), footB=v(17, FEET), handF=v(33, 31), blade=45, handB=v(18, 31), trail=0.4),
        P(lean=1, footF=v(29, FEET), footB=v(18, FEET), handF=v(29, 31), blade=70, handB=v(20, 32)),
    ]
    out["attack_up"] = [
        P(footF=v(27, FEET), footB=v(19, FEET), handF=v(29, 32), blade=100),
        P(footF=v(27, FEET), footB=v(19, FEET), handF=v(28, 16), elbow_down_F=False, blade=-90, head=v(0, -1)),
        P(footF=v(27, FEET), footB=v(19, FEET), handF=v(23, 15), elbow_down_F=False, blade=-140),
        P(footF=v(27, FEET), footB=v(19, FEET), handF=v(28, 30), blade=80),
    ]
    out["attack_down"] = [
        P(footF=v(27, 40), footB=v(19, 39), handF=v(30, 26), blade=-40, lift=-0.3),
        P(footF=v(26, 39), footB=v(20, 38), handF=v(28, 38), blade=90, lift=-0.4),
        P(footF=v(26, 39), footB=v(20, 38), handF=v(27, 39), blade=95, lift=-0.4),
        P(footF=v(27, 41), footB=v(19, 40), handF=v(29, 33), blade=70, lift=-0.2),
    ]
    out["throw"] = [
        P(lean=-1, footF=v(28, FEET), footB=v(18, FEET), handF=v(18, 20), elbow_down_F=False, blade=-160),
        P(lean=3, footF=v(30, FEET), footB=v(17, FEET), handF=v(36, 23), blade=None, trail=0.5),
        P(lean=2, footF=v(29, FEET), footB=v(18, FEET), handF=v(33, 28), blade=None, trail=0.3),
    ]
    out["grapple"] = [P(lean=2, footF=v(22, 43), footB=v(15, 41), handF=v(33, 14), elbow_down_F=False, handB=v(18, 30),
                        blade=None, trail=0.9, flutter=f) for f in (0, 1.5)]
    out["dash"] = [P(lean=4, bob=1, footF=v(29, 42), footB=v(14, 41), handF=v(28, 31), handB=v(14, 29), blade=20,
                     trail=1.0, flutter=f) for f in (0, 1.2)]
    out["slide"] = [P(hip=v(21, 41), lean=-5, footF=v(34, FEET), footB=v(17, FEET), handF=v(29, 33), handB=v(11, 43),
                      blade=8, trail=1.0, flutter=f, lift=-0.2) for f in (0, 1.4)]
    out["wall"] = [P(lean=-1, footF=v(24, 43), footB=v(17, 40), handF=v(31, 29), handB=v(13, 24), elbow_down_B=False,
                     blade=30, trail=0.0, lift=0.7, flutter=f) for f in (0, 1.5)]
    out["hurt"] = [P(lean=-3, head=v(-1, 0), footF=v(26, FEET), footB=v(19, FEET), handF=v(31, 22), handB=v(15, 23),
                     elbow_down_F=False, elbow_down_B=False, blade=-60, eyes="hurt"),
                   P(lean=-2, footF=v(26, FEET), footB=v(19, FEET), handF=v(30, 26), handB=v(16, 26), blade=-30, eyes="hurt")]
    out["dead"] = [
        P(bob=2, footF=v(27, FEET), footB=v(19, FEET), handF=v(27, 34), handB=v(20, 34), blade=80, eyes="hurt"),
        P(hip=v(23, 38), lean=2, footF=v(29, FEET), footB=v(17, FEET), handF=v(29, 40), handB=v(20, 40), blade=90, eyes="off"),
        P(hip=v(22, 40), lean=5, footF=v(31, FEET), footB=v(15, FEET), handF=v(33, 43), handB=v(24, 43), blade=0, eyes="off"),
        P(hip=v(16, 41), lying=True, footF=v(6, 43), footB=v(5, 41), handF=v(30, 43), handB=v(24, 43), blade=0, eyes="off"),
    ]
    return out


def draw_body(p, girl):
    L = Layer()
    h = p.headc
    if girl:
        tip = h + v(-7 - p.trail * 3, 7 + p.lift * 3) + v(0, math.sin(p.flutter) * 0.8)
        L.paint(capsule(h + v(-4, -1), tip, 1.4, 1.1), STEEL_BACK)
        L.paint(disk(tip[0], tip[1], 1.6), [STEEL[0], (30, 140, 160), CYAN, CYAN_HI, CYAN_HI], deep=False)
    L.paint(capsule(p.shB, p.elbowB, 1.6) | capsule(p.elbowB, p.handB, 1.5), STEEL_BACK)
    L.paint(disk(p.handB[0], p.handB[1], 1.9), STEEL_BACK)
    L.paint(capsule(p.hipB, p.kneeB, 1.9, 1.6) | capsule(p.kneeB, p.footB, 1.6, 1.3), STEEL_BACK)
    L.paint(poly([p.footB + v(-2, -1.5), p.footB + v(3, -1.5), p.footB + v(4, 0.5), p.footB + v(-2, 0.5)]), STEEL_BACK)
    sh, hp = p.sh, p.hip
    cw, ww, hw = (4.0, 2.6, 3.6) if girl else (4.8, 3.6, 4.0)
    torso = poly([sh + v(-cw, -1), sh + v(cw, -1), sh + v(cw - 0.5, 3), hp + v(ww, -3), hp + v(hw, 0.5),
                  hp + v(-hw, 0.5), hp + v(-ww, -3), sh + v(-cw + 0.5, 3)])
    L.paint(torso, STEEL)
    core = sh + v(1.5 + p.lean * 0.1, 4)
    L.line(sh + v(-2, 2), sh + v(2.5, 2), STEEL[1])
    L.stamp(disk(core[0], core[1], 1.6), CYAN)
    L.dot(core[0] - 0.5, core[1] - 0.5, CYAN_HI)
    L.line(hp + v(-ww, -2.5), hp + v(ww, -2.5), STEEL[1])
    L.paint(capsule(p.hipF, p.kneeF, 2.0, 1.7) | capsule(p.kneeF, p.footF, 1.7, 1.4), STEEL)
    L.paint(disk(p.kneeF[0], p.kneeF[1], 1.6), STEEL, deep=False)
    L.paint(poly([p.footF + v(-2, -1.5), p.footF + v(3.5, -1.5), p.footF + v(4.5, 0.5), p.footF + v(-2, 0.5)]), STEEL)
    L.paint(capsule(sh + v(0.5, -1), h + v(0, 5), 1.6), STEEL_BACK)
    L.paint(disk(h[0], h[1], 7.0), STEEL)
    if not girl:
        L.paint(capsule(h + v(-1, -6.5), h + v(-2, -9.5), 0.8), STEEL)
        L.dot(h[0] - 2, h[1] - 10, CYAN)
    else:
        L.paint(ellipse(h[0] - 0.5, h[1] - 6.2, 4.5, 1.8), STEEL)
    L.paint(disk(h[0] - 3, h[1] + 0.5, 2.2), STEEL_BACK, deep=False)
    L.dot(h[0] - 3, h[1] + 0.5, CYAN)
    return L.outline(STEEL[0])


def draw_arm(p):
    L = Layer()
    L.paint(capsule(p.shF, p.elbowF, 1.8, 1.6), STEEL)
    L.paint(capsule(p.elbowF, p.handF, 1.6, 1.5), STEEL)
    L.paint(disk(p.elbowF[0], p.elbowF[1], 1.4), STEEL, deep=False)
    L.paint(disk(p.handF[0], p.handF[1], 2.1), STEEL)
    L.dot(p.handF[0] + 1, p.handF[1] + 1, STEEL[1])
    return L.outline(STEEL[0])


def draw_face(p):
    L = Layer()
    h = p.headc
    c = h + v(2.2, 0.8)
    L.paint(ellipse(c[0], c[1], 5.0, 4.6), GLASS)
    L.dot(c[0] - 3, c[1] - 3, GLASS[4])
    L.dot(c[0] - 2, c[1] - 3.5, GLASS[3])
    if p.eyes == "open":
        for ex in (-1.6, 1.8):
            e = c + v(ex, -0.6)
            L.stamp(ellipse(e[0], e[1], 0.9, 1.7), CYAN)
            L.dot(e[0], e[1] - 1, CYAN_HI)
    elif p.eyes == "hurt":
        for ex, sgn in ((-1.6, 1), (1.8, -1)):
            e = c + v(ex, -0.4)
            L.line(e + v(-1, -1), e + v(1, 1), RED)
            L.line(e + v(-1, 1), e + v(1, -1), RED)
    else:
        L.line(c + v(-2.5, 0), c + v(2.5, 0), (40, 60, 80))
    return L.outline(GLASS[0])


def draw_blade(p):
    L = Layer()
    if p.blade is None:
        return L
    a = math.radians(p.blade)
    d = v(math.cos(a), math.sin(a))
    n = v(-d[1], d[0])
    hand = p.handF
    pommel = hand - d * 3.5
    L.paint(capsule(pommel, hand + d * 0.5, 1.1), BRASS, deep=False)
    L.paint(disk(pommel[0], pommel[1], 1.3), BRASS, deep=False)
    g = hand + d * 1.5
    L.paint(capsule(g - n * 2.8, g + n * 2.8, 0.9), BRASS, deep=False)
    base = hand + d * 2.5
    tip = hand + d * 13.5
    for k in range(18):
        t = k / 17
        q = base + (tip - base) * t
        w = 1.6 * (1 - t) + 0.5
        for sx in (-1, 1):
            o = q + n * sx * (w + 1)
            L.dot(o[0], o[1], CYAN, 70)
    L.stamp(capsule(base, tip, 1.5, 0.4), CYAN)
    L.stamp(capsule(base, tip - d * 2, 0.6, 0.2), CYAN_HI)
    L.dot(pommel[0] - d[0] * 1.5, pommel[1] - d[1] * 1.5, CYAN)
    return L


def draw_pants(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    hp = p.hip
    L.paint(poly([hp + v(-4.8, -3), hp + v(4.8, -3), hp + v(5.2, 1.5), hp + v(-5.2, 1.5)]), R)
    for hip, knee, foot, ramp in ((p.hipB, p.kneeB, p.footB, [R[0], R[0], R[1], R[2], R[3]]), (p.hipF, p.kneeF, p.footF, R)):
        leg = capsule(hip, knee, 3.4, 3.2) | capsule(knee, foot + v(0, -2.5), 3.2, 2.4)
        L.paint(leg, ramp)
        L.paint(capsule(foot + v(-1.5, -2.6), foot + v(1.5, -2.6), 1.2), [ramp[0], ramp[1], ramp[1], ramp[2], ramp[3]], deep=False)
    mid = p.hipF + (p.kneeF - p.hipF) * 0.55
    L.paint(poly([mid + v(-1, -2), mid + v(3, -2), mid + v(3, 2), mid + v(-1, 2)]), A if item["accent"] else R)
    L.line(mid + v(-1, -2), mid + v(3, -2), (A if item["accent"] else R)[3])
    L.line(hp + v(-4.8, -2.5), hp + v(4.8, -2.5), R[0])
    L.dot(hp[0] + 2, hp[1] - 2.5, BRASS[3])
    L.dot(p.kneeF[0] + 1, p.kneeF[1], R[1])
    L.dot(p.kneeF[0] + 1, p.kneeF[1] + 1, R[1])
    return L.outline(R[0])


def draw_shoes(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    for foot, ramp in ((p.footB, [R[0], R[0], R[1], R[2], R[2]]), (p.footF, R)):
        boot = poly([foot + v(-2.5, -3.5), foot + v(1.5, -3.5), foot + v(3, -2), foot + v(5, -1.2), foot + v(5, 0.6), foot + v(-2.5, 0.6)])
        L.paint(boot, ramp)
        L.line(foot + v(-2.5, 0.4), foot + v(5, 0.4), (32, 26, 26))
        L.dot(foot[0] + 1, foot[1] - 2.5, ramp[4])
        L.dot(foot[0] + 2, foot[1] - 1.8, ramp[3])
    return L.outline(R[0])


def draw_shirt(p, item):
    L = Layer()
    R = ramp_from(item["color"], warm=0.0)
    sh, hp = p.sh, p.hip
    vest = poly([sh + v(-5.4, -1.5), sh + v(5.2, -1.5), sh + v(5.0, 3), hp + v(4.6, -1.5), hp + v(4.6, 0),
                 hp + v(-4.6, 0), hp + v(-4.6, -1.5), sh + v(-5.0, 3)])
    L.paint(vest, R)
    L.stamp(poly([sh + v(0, -1.6), sh + v(3, -1.6), sh + v(1.5, 2.5)]), STEEL[2])
    if item["id"] == "shirt_hazard_vest":
        for y in (3.5, 7.0):
            yy = sh[1] + y + (hp[1] - sh[1] - 10) * 0.3
            L.line(v(sh[0] - 5, yy), v(sh[0] + 5, yy), (230, 232, 220))
            L.line(v(sh[0] - 5, yy + 1), v(sh[0] + 5, yy + 1), (170, 170, 160))
    L.line(hp + v(-4.6, -0.5), hp + v(4.6, -0.5), R[1])
    return L.outline(R[0])


def cloak_points(p, length=17.5):
    """Outline of the back drape: from the shoulders down to a wavy hem behind the body."""
    sh = p.sh
    up = v(0, -1)
    back = v(-1, 0)
    if p.lying:
        up = v(1, 0)
        back = v(0, 1)
        down = v(-1, 0)
    else:
        down = v(0, 1)
    lift = p.lift
    pts = [sh + up * 2.5 + back * -1.5, sh + up * 2.5 + back * 6.0]
    hem = []
    n = 7
    for i in range(n + 1):
        t = i / n
        reach = length * (1 - 0.18 * lift) - 3 * t * lift
        x_back = 7.0 + t * (3 + p.trail * 9) + p.trail * 2
        wave = math.sin(p.flutter + t * 5.0) * (0.8 + p.trail * 1.2)
        hem.append(sh + down * (reach * (1 - 0.1 * t) + wave * 0.5) + back * (x_back * (0.25 + 0.75 * t)) + up * (lift * 6 * t))
    pts += list(reversed(hem))
    pts += [sh + down * (length - 2) + back * 0.5]
    return pts, hem


def draw_cloak_back(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    pts, hem = cloak_points(p)
    shape = poly(pts)
    dark = [R[0], R[0], R[1], R[2], R[2]]
    L.paint(shape, dark)
    for k in range(1, 4):
        a = pts[1] + (hem[min(k * 2, len(hem) - 1)] - pts[1]) * 0.25
        b = hem[min(k * 2, len(hem) - 1)]
        L.line(a, b, R[0])
    style = item["id"]
    if style == "cloak_rust":
        for i, hpt in enumerate(hem[1:-1]):
            if i % 2 == 0:
                L.rgba[int(np.clip(hpt[1] - 1, 0, S - 1)), int(np.clip(hpt[0], 0, S - 1)), 3] = 0
                L.rgba[int(np.clip(hpt[1] - 2, 0, S - 1)), int(np.clip(hpt[0], 0, S - 1)), 3] = 0
    if style == "cloak_teal":
        for a, b in zip(hem[:-1], hem[1:]):
            L.line(a, b, CYAN)
    if style == "cloak_wren":
        for a, b in zip(hem[:-1], hem[1:]):
            L.line(a, b, BRASS[3])
    if style == "cloak_bellows":
        for a, b in zip(hem[:-1], hem[1:]):
            L.line(a + v(0, -1.5), b + v(0, -1.5), A[2])
    if style == "cloak_patchwork":
        for i, hpt in enumerate(hem[2:6:2]):
            c = hpt + v(1, -4)
            L.paint(poly([c + v(-1.5, -1.5), c + v(1.5, -1.5), c + v(1.5, 1.5), c + v(-1.5, 1.5)]), A, flat=True)
    return L.outline(R[0])


def draw_cloak_front(p, item):
    """Short capelet over the shoulders with a clasp at the throat."""
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else BRASS
    sh = p.sh
    if p.lying:
        shape = poly([sh + v(2, -3), sh + v(-4, -3.5), sh + v(-6, 2), sh + v(1, 3)])
    else:
        sway = p.trail * 1.5
        shape = poly([sh + v(-4.5 - sway, -2.5), sh + v(1.5, -3.5), sh + v(5.5, -1.5), sh + v(6.5, 3.5),
                      sh + v(3.0, 5.0), sh + v(-1.0, 4.5), sh + v(-5.5 - sway, 3.0)])
    L.paint(shape, R)
    if item["id"] == "cloak_teal":
        L.line(sh + v(-5, 3), sh + v(6.5, 3.5), CYAN)
    if item["id"] == "cloak_patchwork":
        L.paint(poly([sh + v(-4, -1.5), sh + v(-2, -1.5), sh + v(-2, 0.5), sh + v(-4, 0.5)]), A, flat=True)
        L.dot(sh[0] + 4, sh[1] + 1, R[0])
    if item["id"] in ("cloak_wren", "cloak_bellows"):
        for k in range(3):
            L.dot(sh[0] + 3.5, sh[1] + 1 + k * 1.5, BRASS[4])
    if item["id"] == "cloak_rust":
        L.dot(sh[0] + 5.5, sh[1] + 3.5, R[0])
        L.dot(sh[0] + 3, sh[1] + 5, R[0])
    clasp = sh + v(3.5, -1.2)
    L.paint(disk(clasp[0], clasp[1], 1.2), BRASS, deep=False)
    return L.outline(R[0])


def draw_hood(p, item):
    """The pointy hood: a cap around the head with a face opening and a long
    tip drooping back (the concept's 'Link' cap), frayed at the edge."""
    L = Layer()
    R = ramp_from(item["color"])
    h = p.headc
    if p.lying:
        back, up = v(0, 1), v(1, 0)
    else:
        back, up = v(-1, 0), v(0, -1)
    shell = disk(h[0] - 0.6, h[1] - 0.8, 8.6) | ellipse(*(h + back * 1.5 + up * -5.5), 5.5, 3.5)
    sway = v(0, math.sin(p.flutter) * 0.8)
    tipp = h + back * (16 + p.trail * 4) + up * (-1.0 - p.lift * 5 + p.trail * 2) + p.tip + sway
    bend = h + back * (11 + p.trail * 2) + up * (4.5 - p.lift * 2) + sway * 0.5
    tip = poly([h + back * 0.5 + up * 8.6, h + back * 7 + up * 7.0, bend, tipp, h + back * 10 + up * 1.0, h + back * 6 + up * -1.5])
    shape = shell | tip
    opening = ellipse(h[0] + 2.6, h[1] + 1.0, 5.4, 5.0)
    shape &= ~opening
    L.paint(shape, R)
    rim = shifted(opening, 0, 0) & ~opening
    ring = (shifted(opening, 1, 0) | shifted(opening, -1, 0) | shifted(opening, 0, 1) | shifted(opening, 0, -1)) & shape
    L.stamp(ring, R[1])
    L.line(h + up * 8 + back * 1, bend, R[1])
    if item["id"] == "hood_tattered":
        for k in (0.35, 0.6, 0.85):
            q = bend + (tipp - bend) * k
            L.dot(q[0], q[1] + 1, R[0])
    return L.outline(R[0])


def draw_mask(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    h = p.headc
    c = h + v(2.2, 0.8)
    if item["id"] == "mask_monocle":
        e = c + v(1.8, -0.6)
        L.paint(disk(e[0], e[1], 2.4), BRASS, deep=False)
        L.stamp(disk(e[0], e[1], 1.4), A[2] if p.eyes != "hurt" else RED)
        L.dot(e[0] - 0.6, e[1] - 0.6, A[4])
        L.line(e + v(0.5, 2.3), e + v(-1.5, 6.0), BRASS[3])
        return L.outline(R[0])
    if item["id"] == "mask_brass_goggles":
        L.line(c + v(-9, -1.5), c + v(-2, -1.5), (60, 40, 30))
        for ex in (-1.6, 2.2):
            e = c + v(ex, -0.6)
            L.paint(disk(e[0], e[1], 2.3), BRASS, deep=False)
            glass = disk(e[0], e[1], 1.3)
            L.stamp(glass, A[2] if p.eyes != "hurt" else RED)
            L.dot(e[0] - 0.6, e[1] - 0.6, A[4])
        L.line(c + v(0, -0.6), c + v(0.6, -0.6), BRASS[1])
    else:
        plate = ellipse(c[0] + 0.2, c[1] + 0.6, 4.8, 4.2) & (PY > c[1] - 2.5)
        L.paint(plate, R)
        for ex in (-1.6, 1.8):
            e = c + v(ex, -0.9)
            L.stamp(ellipse(e[0], e[1], 1.2, 0.8), (12, 12, 18))
            if p.eyes != "off":
                L.dot(e[0], e[1], CYAN if p.eyes == "open" else RED)
        for rx, ry in ((-3, 2), (3.4, 2), (0.2, 3.6)):
            L.dot(c[0] + rx, c[1] + ry, A[3] if item["accent"] else R[4])
        L.line(c + v(-2, 1.8), c + v(2.2, 1.8), R[1])
    return L.outline(R[0])


def read_cosmetics():
    items = []
    d = os.path.join(ROOT, "data", "cosmetics")
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".tres"):
            continue
        t = open(os.path.join(d, fn)).read()
        get = lambda k: re.search(k + r' = (.*)', t)
        def col(k):
            m = re.search(k + r' = Color\(([^)]*)\)', t)
            if not m:
                return None
            r, g, b = [float(x) for x in m.group(1).split(",")[:3]]
            return (int(r * 255), int(g * 255), int(b * 255))
        items.append({"id": re.search(r'id = &"(\w+)"', t).group(1), "slot": int(get("slot").group(1)),
                      "color": col("color"), "accent": col("accent"), "file": fn})
    return items


SLOT_LAYERS = {0: ["hood"], 1: ["mask"], 2: ["cloak_back", "cloak_front"], 3: ["shirt"], 4: ["pants"], 5: ["shoes"]}
DRAW = {"hood": draw_hood, "mask": draw_mask, "cloak_back": draw_cloak_back, "cloak_front": draw_cloak_front,
        "shirt": draw_shirt, "pants": draw_pants, "shoes": draw_shoes}


def frames_list(P_):
    out = []
    for name, n, fps, loop in ANIMS:
        out += P_[name][:n]
    return out


def save_sheet(layers, name):
    img = Image.new("RGBA", (S * len(layers), S), (0, 0, 0, 0))
    for i, L in enumerate(layers):
        img.paste(Image.fromarray(L.rgba, "RGBA"), (i * S, 0))
    img.save(os.path.join(OUT, name + ".png"))
    write_frames(name)


def write_frames(name):
    total = sum(a[1] for a in ANIMS)
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (total + 2), "",
             '[ext_resource type="Texture2D" path="res://art/character/%s.png" id="1"]' % name, ""]
    for i in range(total):
        lines += ['[sub_resource type="AtlasTexture" id="f%d"]' % i, 'atlas = ExtResource("1")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * S, S, S), ""]
    anims = []
    i = 0
    for aname, n, fps, loop in ANIMS:
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % (i + k) for k in range(n))
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", aname, fps))
        i += n
    lines += ["[resource]", "animations = [%s]" % ", ".join(anims), ""]
    open(os.path.join(FR, name + ".tres"), "w").write("\n".join(lines))


def icon_from(layer):
    """Crop a layer's idle frame to its content and centre it in a 32x32 icon (2x if it fits)."""
    a = layer.rgba
    ys, xs = np.nonzero(a[:, :, 3])
    if len(xs) == 0:
        return Image.new("RGBA", (32, 32))
    crop = Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
    if crop.width * 2 <= 30 and crop.height * 2 <= 30:
        crop = crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST)
    out = Image.new("RGBA", (32, 32))
    out.paste(crop, ((32 - crop.width) // 2, (32 - crop.height) // 2), crop)
    return out


def main():
    P_ = poses()
    frames = frames_list(P_)
    save_sheet([draw_body(p, False) for p in frames], "body_boy")
    save_sheet([draw_body(p, True) for p in frames], "body_girl")
    save_sheet([draw_arm(p) for p in frames], "arm")
    save_sheet([draw_face(p) for p in frames], "face")
    save_sheet([draw_blade(p) for p in frames], "blade")
    idle = P_["idle"][0]
    for item in read_cosmetics():
        for layer in SLOT_LAYERS[item["slot"]]:
            save_sheet([DRAW[layer](p, item) for p in frames], "%s_%s" % (layer, item["id"]))
        if item["slot"] == 2:
            icon_layer = DRAW["cloak_back"](idle, item).under(DRAW["cloak_front"](idle, item))
        else:
            icon_layer = DRAW[SLOT_LAYERS[item["slot"]][0]](idle, item)
        icon_from(icon_layer).save(os.path.join(ICONS, item["id"] + ".png"))
    b = Layer()
    tp = P(handF=v(16, 24), blade=0)
    b = draw_blade(tp)
    crop = Image.fromarray(b.rgba, "RGBA").crop((10, 19, 32, 29))
    crop.save(os.path.join(OUT, "blade_thrown.png"))
    print("character sheets: %d frames per layer" % len(frames))


if __name__ == "__main__":
    main()
