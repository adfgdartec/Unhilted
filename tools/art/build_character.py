"""Layered sprites for the rogue robot (v2: the design from Jai's drawing,
drawn for a 1280x720 screen, cel-shaded in the Dead Cells manner).
Run from the project root:  python3 tools/art/build_character.py

The design
----------
A metal robot in thin cloth. The frame: armoured chest with the core light,
an exposed segmented spine and waist, a hip block, ball joints at shoulder,
elbow and knee, armour on forearms and shins, a round screen face. The
cloth: a pointy-cap hood (the tip leaves the back of the head and curls up),
a thin mantle over the shoulders that's open at the front (no shirt: the
chest frame shows) with a strap across the bare metal, a light cape behind,
thin loose trousers that crease where the knees press through. Chunky
striped boots, and two short light daggers, each on a neon wire that runs
back to a reel on the hip. The hood and poncho are cosmetics, so every
colour in the shop restyles them.

How it works
------------
One 2D rig (hips, knees, feet, shoulders, elbows, hands, head) is posed by
hand for every frame; every layer is drawn from those same joints, so any
outfit lines up on every frame. The poses are written in the old 48 px
frame and re-fitted to the new proportions, then doubled to 96 px.

Shading: each part is a mask. Its outward normal comes from a blurred copy
of the mask; the normal against a light from the upper right (the Heap's
sun) picks one of five cel tones, so rounded parts get a lit rim and a
shadow side like a 3D model rendered to pixels. Every layer gets a dark,
tinted outline.

Frames are 96x96, facing right, feet on row 88. The game shows them at half
scale, so in the world the robot is the same size as before with four times
the pixels. Output:
  art/character/<layer>.png            one row of frames, all animations
  art/character/frames/<layer>.tres    Godot SpriteFrames for that sheet
  art/ui/cosmetics/<item>.png          32x32 shop / wardrobe icon
  art/character/blade_thrown.png       the thrown dagger (drawn at half scale)
"""
import colorsys
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "character")
FR = os.path.join(OUT, "frames")
ICONS = os.path.join(ROOT, "art", "ui", "cosmetics")
for d in (OUT, FR, ICONS):
    os.makedirs(d, exist_ok=True)

K = 2                # detail factor over the old 48 px frames
S = 48 * K           # frame size
FEET = 44 * K        # feet row
OLD_FEET = 44

ANIMS = [
    ("idle", 8, 8.0, True), ("run", 12, 18.0, True), ("jump", 3, 12.0, False), ("fall", 3, 9.0, True),
    ("attack", 6, 26.0, False), ("attack_up", 5, 24.0, False), ("attack_down", 5, 24.0, False),
    ("throw", 4, 24.0, False), ("grapple", 2, 8.0, True), ("dash", 3, 16.0, True),
    ("hurt", 3, 12.0, False), ("dead", 7, 7.0, False),
    ("slide", 3, 12.0, True), ("wall", 3, 9.0, True),
]


# --------------------------------------------------------------- colour ramps
def ramp_from(rgb, warm=0.03):
    """outline, shadow, base, light, highlight: cool shadows, warm lights."""
    r, g, b = [c / 255.0 for c in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    def c(dh, sm, vm, va=0.0):
        rr, gg, bb = colorsys.hsv_to_rgb((h + dh) % 1.0, max(0.0, min(1.0, s * sm)), max(0.0, min(1.0, v * vm + va)))
        return (int(rr * 255), int(gg * 255), int(bb * 255))
    return [c(0.05, 1.1, 0.3), c(0.03, 1.12, 0.62), c(0, 1, 1), c(-warm, 0.84, 1.22, 0.05), c(-warm * 1.6, 0.55, 1.4, 0.16)]


STEEL = [(26, 24, 28), (92, 90, 94), (138, 138, 142), (184, 186, 188), (232, 232, 230)]
STEEL_BACK = [(20, 19, 22), (62, 61, 66), (92, 92, 98), (122, 122, 128), (154, 154, 158)]
GRIP = [(16, 16, 24), (38, 40, 52), (58, 60, 74), (86, 90, 106), (124, 128, 144)]
GLASS = [(6, 7, 14), (12, 14, 24), (18, 21, 34), (40, 50, 78), (96, 116, 156)]
BRASS = [(40, 26, 14), (120, 82, 34), (176, 128, 54), (222, 176, 84), (250, 226, 150)]
STRAP = [(30, 18, 12), (62, 40, 26), (92, 62, 41), (122, 86, 58), (150, 112, 80)]
CYAN = (56, 242, 255)
CYAN_MID = (34, 170, 196)
CYAN_HI = (200, 253, 255)
RED = (255, 84, 70)
LIGHT = np.array([0.55, -0.83])   # from the upper right


# --------------------------------------------------------------- raster helpers
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


def ribbon(pts, w0, w1, jag=0, jag_from=0.65):
    """Tapered band along a polyline (for the cap tip, scarves)."""
    m = np.zeros((S, S), dtype=bool)
    n = len(pts)
    for i in range(n - 1):
        t0, t1 = i / (n - 1), (i + 1) / (n - 1)
        r0 = (w0 + (w1 - w0) * t0) / 2
        r1 = (w0 + (w1 - w0) * t1) / 2
        if jag and t0 > jag_from and i % 2 == 1:
            r0 *= 0.5
            r1 *= 0.5
        m |= capsule(pts[i], pts[i + 1], r0, r1)
    return m


def bez(p0, p1, p2, p3, n=16):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(u ** 3 * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t ** 3 * p3)
    return out


class Layer:
    def __init__(self):
        self.rgba = np.zeros((S, S, 4), dtype=np.uint8)

    def opaque(self):
        return self.rgba[:, :, 3] > 0

    def paint(self, mask, ramp, flat=False, soft=2.2, bias=0.0):
        """Cel-shade a part: tone from the part's normal against the light."""
        if not mask.any():
            return
        lvl = np.full((S, S), 2, dtype=np.int8)
        if not flat:
            b = gaussian_filter(mask.astype(np.float32), soft)
            gy, gx = np.gradient(b)
            mag = np.hypot(gx, gy) + 1e-6
            nx, ny = -gx / mag, -gy / mag            # outward normal
            d = nx * LIGHT[0] + ny * LIGHT[1]
            edge = np.clip(mag * 9.0, 0, 1)          # 1 at the rim, 0 deep inside
            t = d * edge + bias
            lvl[t > 0.14] = 3
            lvl[t > 0.58] = 4
            lvl[t < -0.22] = 1
            # the very rim facing away from the light reads as a thin dark edge
            rim_dark = mask & ~shifted(mask, -1, -1) & (t < -0.45)
            lvl[rim_dark] = 1
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

    def line(self, p0, p1, rgb, a=255, w=1):
        if w > 1:
            self.stamp(capsule(p0, p1, w / 2), rgb)
            return
        n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.dot(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, rgb, a)

    def stamp(self, mask, rgb):
        self.rgba[mask, :3] = rgb
        self.rgba[mask, 3] = 255

    def glow(self, mask, rgb, alpha=70, spread=2):
        """Soft halo around a light source (only where the layer is empty)."""
        g = mask.copy()
        for _ in range(spread):
            g = g | shifted(g, 1, 0) | shifted(g, -1, 0) | shifted(g, 0, 1) | shifted(g, 0, -1)
        halo = g & ~mask & (self.rgba[:, :, 3] == 0)
        self.rgba[halo, :3] = rgb
        self.rgba[halo, 3] = alpha

    def erase(self, mask):
        self.rgba[mask, 3] = 0

    def outline(self, rgb):
        op = self.rgba[:, :, 3] >= 200
        ring = ~op & (shifted(op, 1, 0) | shifted(op, -1, 0) | shifted(op, 0, 1) | shifted(op, 0, -1))
        ring &= self.rgba[:, :, 3] < 200
        self.rgba[ring, :3] = rgb
        self.rgba[ring, 3] = 255
        return self

    def under(self, other):
        out = Layer()
        out.rgba = self.rgba.copy()
        m = other.rgba[:, :, 3] > 0
        out.rgba[m] = other.rgba[m]
        return out


# --------------------------------------------------------------- the rig
def v(x, y):
    return np.array([float(x), float(y)])


def norm(a):
    n = math.hypot(a[0], a[1])
    return a / n if n > 1e-6 else v(0, 1)


def knee_for(hip, foot, length):
    d = foot - hip
    dist = min(math.hypot(*d), length * 0.999)
    mid = hip + d * 0.5
    off = math.sqrt(max((length / 2) ** 2 - (dist / 2) ** 2, 0))
    perp = norm(v(d[1], -d[0])) * -1.0
    if perp[0] < 0:
        perp = -perp
    return mid + perp * off


def elbow_for(sh, hand, length, down=True):
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


# proportions in old 48 px units (read off the drawing): head+hood ~1/4 of
# the height, legs longer than the torso
LEG, ARM, TORSO, NECK = 17.4, 13.2, 11.0, 5.6
LEG_SCALE = 16.6 / 11.0
ARM_SCALE = ARM / 10.0
HEAD_R = 3.7 * K


class Pose:
    """Keyword poses in the old 48 px frame (feet on row 44, stocky body).
    They're re-fitted to the new proportions and doubled to 96 px."""

    def __init__(self, **k):
        self.hip = v(23, 33)
        self.lean = 0.0
        self.bob = 0.0
        self.head = v(0, 0)
        self.footF = v(27, OLD_FEET)
        self.footB = v(20, OLD_FEET)
        self.handF = v(28, 32)
        self.handB = v(20, 32)
        self.elbow_down_F = True
        self.elbow_down_B = True
        self.blade = 72.0
        self.blade_back = None      # override for the off-hand blade angle
        self.trail = 0.0
        self.flutter = 0.0
        self.lift = 0.0
        self.eyes = "open"
        self.tip = v(0, 0)
        self.lying = False
        for key, val in k.items():
            setattr(self, key, val)
        # the old rig's shoulders, as the reference the hands were posed from
        old_hip = self.hip + v(0, self.bob * 0.5)
        old_sh = old_hip + v(1 + self.lean, -10 + self.bob * 0.5)
        old_shF, old_shB = old_sh + v(1.5, 1), old_sh + v(-2.5, 1)
        if self.lying:
            old_sh = old_hip + v(10, -1)
            old_shF, old_shB = old_sh + v(1.5, 1), old_sh + v(-2.5, 1)
        hip = v(old_hip[0], OLD_FEET - (OLD_FEET - old_hip[1]) * LEG_SCALE)
        if self.lying:
            sh = hip + v(TORSO, -1)
            headc = sh + v(NECK + 0.5, -1) + self.head
        else:
            sh = hip + v(0.8 + self.lean * 0.9, -TORSO + self.bob * 0.4)
            headc = sh + v(0.8 + self.lean * 0.25, -NECK) + self.head
        handF = sh + v(1.2, 1) + (self.handF - old_shF) * ARM_SCALE
        handB = sh + v(-2.0, 1) + (self.handB - old_shB) * ARM_SCALE
        # everything below is in 96 px space
        self.hip, self.sh, self.headc = hip * K, sh * K, headc * K
        self.footF, self.footB = self.footF * K, self.footB * K
        self.hipF, self.hipB = self.hip + v(1.5 * K, 0), self.hip + v(-1.5 * K, 0)
        self.kneeF = knee_for(self.hipF, self.footF, LEG * K)
        self.kneeB = knee_for(self.hipB, self.footB, LEG * K)
        self.shF, self.shB = self.sh + v(1.2 * K, 1 * K), self.sh + v(-2.0 * K, 1 * K)
        self.handF, self.handB = handF * K, handB * K
        self.elbowF = elbow_for(self.shF, self.handF, ARM * K, down=self.elbow_down_F)
        self.elbowB = elbow_for(self.shB, self.handB, ARM * K, down=self.elbow_down_B)
        self.tip = self.tip * K


def P(**k):
    return Pose(**k)


def poses():
    """Hand-keyed poses, written in the old 48 px frame (feet on row 44)."""
    F = OLD_FEET
    out = {}
    # idle: slow breathing, the cape and cap tip sway, the blades drift
    idle = []
    for i in range(8):
        ph = i / 8 * math.tau
        b = (1 - math.cos(ph)) / 2
        idle.append(P(bob=b * 1.0, flutter=i * 0.785, handF=v(29, 32 + b * 0.7), handB=v(18, 32 + b * 0.7),
                      footF=v(30, F), footB=v(17, F), blade=35.0 + math.sin(ph) * 4, tip=v(0, math.sin(ph) * 0.7),
                      trail=0.1 + 0.08 * math.sin(ph)))
    out["idle"] = idle
    # run: 12 frames, long stride, the body rides highest when the legs pass
    run = []
    for i in range(12):
        p = i / 12 * math.tau
        bob = -abs(math.sin(p)) * 1.3 + 0.3
        run.append(P(lean=2.6, bob=bob,
                     footF=v(23 + 8.2 * math.cos(p), F - max(0.0, 4.6 * math.sin(p))),
                     footB=v(23 - 8.2 * math.cos(p), F - max(0.0, -4.6 * math.sin(p))),
                     handF=v(26 - 4.8 * math.cos(p), 31 + bob * 0.5), handB=v(21 + 4.8 * math.cos(p), 31 + bob * 0.5),
                     blade=40 - 22 * math.cos(p), trail=0.85 + 0.1 * math.sin(p * 2), flutter=i * 0.7,
                     tip=v(0, math.sin(p * 2) * 0.8)))
    out["run"] = run
    out["jump"] = [P(footF=v(27, 42), footB=v(19, 42), handF=v(30, 29), handB=v(17, 29), blade=35, trail=0.3, lift=-0.5, bob=-1),
                   P(footF=v(27, 41), footB=v(19, 40), handF=v(29, 27), handB=v(17, 27), blade=30, trail=0.3, lift=-0.35, flutter=1),
                   P(footF=v(27, 40), footB=v(20, 39), handF=v(29, 25), handB=v(17, 25), blade=20, trail=0.25, lift=-0.1, flutter=2)]
    out["fall"] = [P(footF=v(26, 45), footB=v(20, 44), handF=v(30, 24), handB=v(16, 24), blade=10, trail=0.2, lift=0.8,
                     flutter=f, tip=v(0, -1.5)) for f in (0, 1.1, 2.2)]
    # attack: deep wind-up, a fast strike, a long follow-through
    out["attack"] = [
        P(lean=-1, footF=v(28, F), footB=v(18, F), handF=v(20, 22), elbow_down_F=False, blade=-150, handB=v(22, 32)),
        P(lean=-1.6, footF=v(28, F), footB=v(18, F), handF=v(19, 20), elbow_down_F=False, blade=-168, handB=v(22, 31), flutter=0.6),
        P(lean=3, footF=v(30, F), footB=v(17, F), handF=v(35, 26), blade=0, handB=v(18, 30), trail=0.55, flutter=1.2),
        P(lean=3, footF=v(30, F), footB=v(17, F), handF=v(34, 29), blade=28, handB=v(18, 31), trail=0.45, flutter=1.8),
        P(lean=2.4, footF=v(30, F), footB=v(17, F), handF=v(32, 31), blade=50, handB=v(19, 31), trail=0.3, flutter=2.4),
        P(lean=1, footF=v(29, F), footB=v(18, F), handF=v(29, 31), blade=62, handB=v(20, 32), flutter=3.0),
    ]
    out["attack_up"] = [
        P(footF=v(27, F), footB=v(19, F), handF=v(29, 32), blade=100),
        P(footF=v(27, F), footB=v(19, F), handF=v(30, 30), blade=120, bob=1),
        P(footF=v(27, F), footB=v(19, F), handF=v(28, 16), elbow_down_F=False, blade=-90, head=v(0, -1), lift=-0.3),
        P(footF=v(27, F), footB=v(19, F), handF=v(23, 15), elbow_down_F=False, blade=-140, lift=-0.2),
        P(footF=v(27, F), footB=v(19, F), handF=v(28, 30), blade=70),
    ]
    out["attack_down"] = [
        P(footF=v(27, 40), footB=v(19, 39), handF=v(30, 26), blade=-40, lift=-0.3),
        P(footF=v(27, 40), footB=v(19, 39), handF=v(30, 24), blade=-60, lift=-0.35),
        P(footF=v(26, 39), footB=v(20, 38), handF=v(28, 38), blade=90, lift=-0.4),
        P(footF=v(26, 39), footB=v(20, 38), handF=v(27, 39), blade=95, lift=-0.4),
        P(footF=v(27, 41), footB=v(19, 40), handF=v(29, 33), blade=70, lift=-0.2),
    ]
    out["throw"] = [
        P(lean=-1, footF=v(28, F), footB=v(18, F), handF=v(18, 20), elbow_down_F=False, blade=-160),
        P(lean=-1.5, footF=v(28, F), footB=v(18, F), handF=v(17, 19), elbow_down_F=False, blade=-170, flutter=0.7),
        P(lean=3, footF=v(30, F), footB=v(17, F), handF=v(36, 23), blade=None, trail=0.5, flutter=1.4),
        P(lean=2, footF=v(29, F), footB=v(18, F), handF=v(33, 28), blade=None, trail=0.3, flutter=2.1),
    ]
    out["grapple"] = [P(lean=2, footF=v(22, 43), footB=v(15, 41), handF=v(33, 14), elbow_down_F=False, handB=v(18, 30),
                        blade=None, trail=0.95, flutter=f) for f in (0, 1.5)]
    out["dash"] = [P(lean=4, bob=1, footF=v(29, 42), footB=v(14, 41), handF=v(28, 31), handB=v(14, 29), blade=20,
                     trail=1.0, flutter=f, tip=v(0, -1)) for f in (0, 1.0, 2.0)]
    out["slide"] = [P(hip=v(21, 41), lean=-5, footF=v(34, F), footB=v(17, F), handF=v(29, 33), handB=v(11, 43),
                      blade=8, trail=1.0, flutter=f, lift=-0.2) for f in (0, 0.9, 1.8)]
    out["wall"] = [P(lean=-1, footF=v(24, 43), footB=v(17, 40), handF=v(31, 29), handB=v(13, 24), elbow_down_B=False,
                     blade=30, blade_back=-120, trail=0.0, lift=0.7, flutter=f) for f in (0, 1.0, 2.0)]
    out["hurt"] = [P(lean=-3, head=v(-1, 0), footF=v(26, F), footB=v(19, F), handF=v(31, 22), handB=v(15, 23),
                     elbow_down_F=False, elbow_down_B=False, blade=-60, eyes="hurt", trail=0.4),
                   P(lean=-2.5, head=v(-0.5, 0), footF=v(26, F), footB=v(19, F), handF=v(30, 24), handB=v(16, 25),
                     elbow_down_F=False, blade=-45, eyes="hurt", trail=0.25, flutter=1),
                   P(lean=-1.5, footF=v(26, F), footB=v(19, F), handF=v(30, 27), handB=v(17, 27), blade=-20, eyes="hurt", flutter=2)]
    # death: hit, stagger, knees buckle, kneel, slump, topple, lie still
    out["dead"] = [
        P(lean=-3, head=v(-1, 0), footF=v(26, F), footB=v(19, F), handF=v(31, 24), handB=v(16, 24), blade=-40, eyes="hurt", trail=0.4),
        P(lean=-2, hip=v(23, 35), footF=v(27, F), footB=v(18, F), handF=v(28, 33), handB=v(20, 33), blade=70, eyes="hurt", flutter=0.8),
        P(lean=1, hip=v(23, 38), footF=v(28, F), footB=v(18, F), handF=v(27, 38), handB=v(20, 38), blade=85, eyes="open", flutter=1.6),
        P(lean=3, hip=v(22, 40), footF=v(29, F), footB=v(17, F), handF=v(30, 42), handB=v(22, 42), blade=90, eyes="off", flutter=2.2),
        P(lean=5, hip=v(22, 40.5), head=v(1, 1), footF=v(30, F), footB=v(16, F), handF=v(32, 43), handB=v(24, 43), blade=90, eyes="hurt", flutter=2.8),
        P(lean=7, hip=v(20, 41), head=v(2, 2), footF=v(28, F), footB=v(15, F), handF=v(34, 43), handB=v(27, 43), blade=0, eyes="off", flutter=3.2),
        P(hip=v(16, 41), lying=True, footF=v(6, 43), footB=v(5, 41), handF=v(30, 43), handB=v(24, 43), blade=0, eyes="off"),
    ]
    return out


# --------------------------------------------------------------- body (the metal frame)
def joint(L, c, r, ramp=None):
    ramp = ramp or STEEL
    L.paint(disk(c[0], c[1], r), ramp, soft=1.0)
    L.dot(c[0] + r * 0.35, c[1] - r * 0.35, ramp[4])


def limb(L, a, b, r0, r1, ramp, plate=False):
    """A rod between joints; plate=True gives an armour shell with a seam."""
    L.paint(capsule(a, b, r0, r1), ramp, soft=1.2)
    if plate:
        d = norm(b - a)
        n = v(-d[1], d[0])
        L.line(a + d * 2 + n * 0.6, b - d * 2 + n * 0.6, ramp[1])


def draw_body(p, girl):
    L = Layer()
    sh, hp, h = p.sh, p.hip, p.headc
    B = STEEL_BACK
    if girl:
        tip = h + v(-10 - p.trail * 6, 13 + p.lift * 6) + v(0, math.sin(p.flutter) * 1.6)
        L.paint(capsule(h + v(-5, 2), tip, 1.8, 1.4), B)
        L.paint(disk(tip[0], tip[1], 2.4), [STEEL[0], CYAN_MID, CYAN, CYAN_HI, CYAN_HI], flat=True)
    # far limbs (darker): rods, ball joints, armour on forearm and shin
    joint(L, p.shB, 2.6, B)
    limb(L, p.shB, p.elbowB, 1.5, 1.4, B)
    joint(L, p.elbowB, 2.0, B)
    limb(L, p.elbowB, p.handB, 2.4, 2.0, B, plate=True)
    L.paint(disk(p.handB[0], p.handB[1], 2.6), B, soft=1.0)
    limb(L, p.hipB, p.kneeB, 2.0, 1.7, B)
    joint(L, p.kneeB, 2.4, B)
    limb(L, p.kneeB, p.footB, 2.4, 1.8, B, plate=True)
    # spine: the exposed waist, three vertebra discs on a dark core with two pistons
    lying = p.lying
    top = sh + v(0.4, 9.0) if not lying else sh + v(-9, 0.4)
    bot = hp + v(0, -3.0) if not lying else hp + v(3, 0)
    L.paint(capsule(top, bot, 1.6), GRIP, soft=0.8)
    for side in (-2.6, 2.6):
        o = v(side, 0) if not lying else v(0, side)
        L.stamp(capsule(top + o, bot + o, 0.6), STEEL[1])
    for k in range(3):
        c = top + (bot - top) * ((k + 0.5) / 3)
        L.paint(ellipse(c[0], c[1], 3.6, 1.5) if not lying else ellipse(c[0], c[1], 1.5, 3.6), STEEL, soft=0.8)
    # pelvis block
    pel = poly([hp + v(-5.6, -3.6), hp + v(5.0, -3.6), hp + v(6.0, 1.8), hp + v(-6.0, 1.8)]) if not lying \
        else ellipse(hp[0], hp[1], 4.2, 5.4)
    L.paint(pel, STEEL)
    # chest: an armoured shell, rounder at the front, with the core light and vents
    if not lying:
        cw = 7.2 if girl else 8.0
        chest = poly([sh + v(-cw, -2.0), sh + v(cw - 1.6, -2.4), sh + v(cw + 0.6, 2.0), sh + v(cw, 7.0),
                      sh + v(cw - 2.4, 10.2), sh + v(-cw + 2.0, 10.2), sh + v(-cw + 0.2, 6.0)])
    else:
        chest = ellipse(sh[0] - 3, sh[1], 7.5, 5.5)
    L.paint(chest, STEEL, soft=2.0)
    core = sh + v(4.6 + p.lean * 0.2, 4.4) if not lying else sh + v(-3, -2)
    if not lying:
        L.line(sh + v(-cw + 1.5, 1.0), sh + v(cw - 2.0, 1.0), STEEL[1])      # collar seam
        L.line(sh + v(-1.0, 1.5), sh + v(-1.0, 9.5), STEEL[1])               # centre seam
        for k in range(3):                                                    # vents
            L.line(sh + v(-4.8, 4.2 + k * 1.8), sh + v(-2.4, 4.2 + k * 1.8), STEEL[1])
        L.dot(sh[0] + cw - 1.5, sh[1] + 8.5, STEEL[4])                       # rivets
        L.dot(sh[0] - cw + 1.8, sh[1] + 8.5, STEEL[3])
    L.stamp(disk(core[0], core[1], 2.4), GRIP[1])
    L.stamp(disk(core[0], core[1], 1.7), CYAN)
    L.dot(core[0] - 0.5, core[1] - 0.6, CYAN_HI)
    L.glow(disk(core[0], core[1], 1.7), CYAN, 90, 0)
    # near leg: rod, knee, shin plate (mostly under the trousers)
    limb(L, p.hipF, p.kneeF, 2.2, 1.9, STEEL)
    joint(L, p.kneeF, 2.6)
    limb(L, p.kneeF, p.footF, 2.6, 2.0, STEEL, plate=True)
    # neck: rod with two rings
    nk0, nk1 = (sh + v(0.6, -2), h + v(0, 4)) if not lying else (sh + v(2, 0), h + v(-4, 0))
    L.paint(capsule(nk0, nk1, 1.4), GRIP, soft=0.8)
    for k in (0.35, 0.7):
        c = nk0 + (nk1 - nk0) * k
        L.paint(ellipse(c[0], c[1], 2.4, 0.9) if not lying else ellipse(c[0], c[1], 0.9, 2.4), STEEL, flat=True)
    # head: a rounded casing with a jaw plate; the hood hides most of it
    L.paint(ellipse(h[0], h[1], HEAD_R, HEAD_R * 1.06), STEEL)
    L.paint(poly([h + v(-HEAD_R * 0.6, HEAD_R * 0.5), h + v(HEAD_R * 0.9, HEAD_R * 0.5),
                  h + v(HEAD_R * 0.7, HEAD_R + 1.2), h + v(-HEAD_R * 0.4, HEAD_R + 1.2)]), STEEL, soft=1.0)
    if girl:
        L.paint(ellipse(h[0] - 1, h[1] - HEAD_R + 1.2, 5.0, 2.2), STEEL)
    else:
        L.stamp(capsule(h + v(-2, -HEAD_R + 1), h + v(-3.2, -HEAD_R - 3.6), 0.9), STEEL[2])
        L.dot(h[0] - 3.2, h[1] - HEAD_R - 4.4, CYAN)
    return L.outline(STEEL[0])


def reel_pos(p):
    return p.hip + v(-7.6, -0.6) if not p.lying else p.hip + v(0, -4)


def draw_arm(p):
    """Near arm (ball joints, rod upper arm, armoured forearm, mechanical
    hand), plus the wire reel on the back of the hip."""
    L = Layer()
    r = reel_pos(p)
    L.paint(disk(r[0], r[1], 4.2), STEEL)
    L.stamp(disk(r[0], r[1], 2.2), GRIP[1])
    for a in range(0, 360, 90):
        rr = math.radians(a + 20)
        L.dot(r[0] + math.cos(rr) * 3.0, r[1] + math.sin(rr) * 3.0, STEEL[1])
    L.stamp(disk(r[0], r[1], 1.0), CYAN)
    joint(L, p.shF, 3.0)
    limb(L, p.shF, p.elbowF, 1.7, 1.6, STEEL)
    joint(L, p.elbowF, 2.3)
    limb(L, p.elbowF, p.handF, 2.8, 2.3, STEEL, plate=True)
    L.paint(disk(p.handF[0], p.handF[1], 2.9), STEEL, soft=1.0)
    d = norm(p.handF - p.elbowF)
    for k in (-1, 1):
        f = p.handF + d * 2.2 + v(-d[1], d[0]) * k * 1.3
        L.dot(f[0], f[1], STEEL[1])
    return L.outline(STEEL[0])


def draw_face(p):
    """Round screen face filling the hood opening; two tall oval eyes."""
    L = Layer()
    c = p.headc + v(2.4, 1.0)
    fr = HEAD_R * 0.9
    L.paint(disk(c[0], c[1], fr), GLASS, soft=1.4)
    for a in range(200, 260, 9):
        rr = math.radians(a)
        L.dot(c[0] + math.cos(rr) * fr * 0.72, c[1] + math.sin(rr) * fr * 0.72, GLASS[4], 200)
    if p.eyes == "open":
        for ex in (-2.3, 3.0):
            e = c + v(ex, -0.4)
            L.stamp(ellipse(e[0], e[1], 1.4, 2.4), CYAN)
            L.dot(e[0] - 0.4, e[1] - 1.1, CYAN_HI)
        L.glow(ellipse(c[0] + 0.4, c[1] - 0.4, 5.0, 3.0) & disk(c[0], c[1], fr - 1), CYAN, 40, 0)
    elif p.eyes == "hurt":
        for ex in (-2.3, 3.0):
            e = c + v(ex, -0.2)
            L.line(e + v(-1.3, -1.3), e + v(1.3, 1.3), RED)
            L.line(e + v(-1.3, 1.3), e + v(1.3, -1.3), RED)
    else:
        L.line(c + v(-3.4, 0), c + v(3.4, 0), (40, 60, 80))
    return L.outline(GLASS[0])


# --------------------------------------------------------------- blades + wires
def dagger(L, hand, ang, dim=False, length=16.0):
    """Short light dagger with a small dark grip and guard (as drawn)."""
    a = math.radians(ang)
    d = v(math.cos(a), math.sin(a))
    n = v(-d[1], d[0])
    edge = CYAN if not dim else CYAN_MID
    core = CYAN_HI if not dim else (128, 214, 226)
    pommel = hand - d * 4.8
    base = hand + d * 4.0
    tip = hand + d * length
    blade = poly([base + n * 2.0, base + d * 5.0 + n * 3.4, tip, base + d * 5.0 - n * 3.4, base - n * 2.0])
    L.glow(blade, edge, 60 if not dim else 40, 2)
    L.stamp(blade, edge)
    L.stamp(capsule(base + d * 1.0, tip - d * 4.0, 0.9, 0.3), core)
    # grip and guard
    L.paint(capsule(pommel, hand + d * 1.2, 1.9), GRIP, soft=1.2)
    g = hand + d * 2.6
    L.paint(capsule(g - n * 3.8, g + n * 3.8, 1.4), GRIP, soft=1.0)
    L.stamp(disk(pommel[0], pommel[1], 1.2), CYAN if not dim else CYAN_MID)
    return pommel - d * 1.5


def wire(L, a, b, sag=6.0, alpha=200, color=CYAN):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) * 2 + 2
    for i in range(n + 1):
        t = i / n
        q = a + (b - a) * t + v(0, sag * 4 * t * (1 - t))
        L.dot(q[0], q[1], color, alpha)


def back_angle(p):
    if p.blade_back is not None:
        return p.blade_back
    arm = p.handB - p.elbowB
    return math.degrees(math.atan2(arm[1], arm[0])) + 15


def draw_blade(p):
    """The main-hand dagger and its wire to the reel (hidden while thrown)."""
    L = Layer()
    if p.blade is None:
        return L
    end = dagger(L, p.handF, p.blade)
    wire(L, end, reel_pos(p), sag=6.0, alpha=190)
    return L


def draw_blade_back(p):
    """The off-hand dagger, behind the body, and its wire."""
    L = Layer()
    if p.lying:
        dagger(L, p.handB + v(4, 0), 10.0, dim=True, length=14.0)
        return L
    end = dagger(L, p.handB, back_angle(p), dim=True, length=14.0)
    wire(L, end, reel_pos(p), sag=5.0, alpha=150, color=CYAN_MID)
    return L


# --------------------------------------------------------------- outfit parts
def draw_hood(p, item):
    """Round hood with a big face opening and a cowl at the neck; the pointy
    cap tip leaves the back of the head and curls up at the end. Thin cloth."""
    L = Layer()
    R = ramp_from(item["color"])
    h = p.headc
    if p.lying:
        back, up = v(0, 1), v(1, 0)
    else:
        back, up = v(-1, 0), v(0, -1)
    shell = disk(h[0] - 0.5, h[1] - 0.6, HEAD_R + 2.5)
    cowl = ellipse(*(h + up * -(HEAD_R + 1.4) + back * 1.6), 5.0, 1.5)
    sway = math.sin(p.flutter) * 1.4
    pts = []
    n = 12
    for i in range(n + 1):
        t = i / n
        reach = 5.0 + t * (23.0 + p.trail * 6)
        droop = 4.4 * math.sin(t * math.pi * 0.9) - 6.0 * max(0.0, t - 0.6) / 0.4 * (1 - p.lift * 0.3)
        pts.append(h + back * reach + up * (2.0 - droop - p.lift * 6 * t + p.trail * 3 * t) + v(0, sway * t) + p.tip * t)
    tattered = item["id"] == "hood_tattered"
    tip = ribbon(pts, 9.0, 1.4, jag=1 if tattered else 0)
    shape = shell | cowl | tip
    opening = disk(h[0] + 2.6, h[1] + 1.0, HEAD_R * 0.9 + 1.4)
    shape &= ~opening
    L.paint(shape, R)
    ring = (shifted(opening, 1, 0) | shifted(opening, -1, 0) | shifted(opening, 0, 1) | shifted(opening, 0, -1)) & shape
    L.stamp(ring, R[1])
    L.stamp(ring & (PY < h[1] - 1.5) & (PX < h[0] + 3), R[0])
    for i in range(1, n - 3):
        q = pts[i] + up * 1.4
        L.dot(q[0], q[1], R[1])
    cw = h + up * -(HEAD_R + 2.6)
    L.line(cw + back * 4.5 + up * -0.2, cw + back * -2, R[1])
    return L.outline(R[0])


def draw_cloak_front(p, item):
    """A thin mantle over the shoulders: drapes over the near shoulder and
    upper arm, open at the front so the chest frame shows. The strap crosses
    the bare metal."""
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    sh, hp = p.sh, p.hip
    if p.lying:
        L.paint(ellipse(*(sh + v(-4, -4)), 9, 3.5), R)
        return L.outline(R[0])
    sway = p.trail * 3.0
    lift = p.lift * 2.0
    wave = math.sin(p.flutter) * 0.8
    drop = 3.2 - lift
    # a short shoulder piece: covers the shoulder cap and the back of the
    # neck, nothing of the chest
    shape = poly([sh + v(-1.4, -5.4), sh + v(-4.2, -6.0), sh + v(-8.2 - sway, -4.0), sh + v(-9.6 - sway * 1.2, 0.2),
                  sh + v(-8.8 - sway * 1.3, drop + wave), sh + v(-6.2 - sway, drop - 1.2), sh + v(-4.0 - sway * 0.8, drop + 0.4 + wave),
                  sh + v(-2.4 - sway * 0.6, drop - 1.6), sh + v(-1.6 - sway * 0.4, 0.6), sh + v(-0.8, -2.6)])
    L.paint(shape, R, soft=2.2)
    # thin cloth: long folds from the shoulder, a hem that catches light
    for a, b in ((v(-6, -2), v(-7.6 - sway, drop - 0.5)), (v(-3, -3), v(-3.6 - sway * 0.8, drop)), (v(-2.6, -3), v(-3.0 - sway * 0.5, drop - 1.6))):
        L.line(sh + a, sh + b, R[1])
    style = item["id"]
    if style == "cloak_rust":
        for x in (-7, 0):
            q = sh + v(x - sway * 0.8, drop - 0.4)
            L.erase(poly([q + v(-1.4, 2), q + v(0, -2.2), q + v(1.4, 2)]))
    if style == "cloak_teal":
        L.line(sh + v(-9.8 - sway * 1.3, drop), sh + v(-1.8 - sway * 0.6, drop - 2.0), CYAN)
    if style in ("cloak_wren", "cloak_bellows"):
        for k in range(2):
            L.dot(sh[0] - 1.2, sh[1] - 1 + k * 3, BRASS[4])
    if style == "cloak_patchwork":
        L.paint(poly([sh + v(-8, 0), sh + v(-4, 0), sh + v(-4, 4), sh + v(-8, 4)]), A, flat=True)
    # clasp at the throat
    L.paint(disk(sh[0] + 0.4, sh[1] - 3.4, 1.3), BRASS, soft=0.6)
    # strap across the bare chest frame, from the near shoulder to the back hip
    s0, s1 = sh + v(4.6, 0.0), hp + v(-6.0, -4.0)
    L.stamp(capsule(s0, s1, 1.4), STRAP[2])
    L.line(s0 + v(0, 1.2), s1 + v(0, 1.2), STRAP[1])
    L.line(s0 + v(0, -1.0), s1 + v(0, -1.0), STRAP[3])
    bk = s0 + (s1 - s0) * 0.35
    L.paint(poly([bk + v(-1.8, -1.8), bk + v(1.8, -1.8), bk + v(1.8, 1.8), bk + v(-1.8, 1.8)]), BRASS, flat=True)
    L.dot(bk[0], bk[1], STRAP[1])
    return L.outline(R[0])


def draw_cloak_back(p, item):
    """The cape: thin cloth hanging from the back of the shoulders to about
    the knee. It flares at the hem, streams back when running, lifts when
    falling (showing its darker lining) and keeps rippling at rest."""
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    if p.lying:
        sh, hp = p.sh, p.hip
        L.paint(poly([sh + v(-2, -5), hp + v(-6, -5), hp + v(-14, 2), sh + v(-4, 3)]), [R[0], R[0], R[1], R[2], R[2]])
        return L.outline(R[0])
    sh, hp = p.sh, p.hip
    lift = p.lift
    n = 12
    hem = []
    for i in range(n + 1):
        t = i / n
        reach = (hp[1] - sh[1] + 17.0) * (1 - 0.32 * lift) - p.trail * 4.0 * t
        xb = 6.0 + t * (8 + p.trail * 24)
        wave = math.sin(p.flutter + t * 7.0) * (1.6 + p.trail * 2.8) + math.sin(p.flutter * 1.7 + t * 13.0) * 0.6
        hem.append(sh + v(-xb * (0.5 + 0.5 * t), reach * (1 - 0.1 * t) + wave * 0.6 - lift * 15 * t))
    pts = [sh + v(-2.4, -4.6), sh + v(-8.0, -4.2)] + hem[::-1]
    shape = poly(pts)
    L.paint(shape, [R[0], R[0], R[1], R[2], R[3]], soft=2.6, bias=-0.1)
    # folds: long creases from the shoulder blade down to the hem's troughs
    for k in (2, 4, 7, 10):
        L.line(sh + v(-5.5 - k * 0.15, -2), hem[k] + v(0, -1.5), R[0])
        L.line(sh + v(-4.8 - k * 0.15, -1), hem[k] + v(1, -2.5), R[1])
    # lining: when the hem lifts or streams, the darker inside shows along it
    if lift > 0.1 or p.trail > 0.5:
        for a2, b2 in zip(hem[:-1], hem[1:]):
            L.line(a2 + v(0, -1), b2 + v(0, -1), R[0])
            L.line(a2 + v(0, -2), b2 + v(0, -2), A[1])
    style = item["id"]
    if style == "cloak_rust":
        for k in (2, 5, 8, 11):
            q = hem[k]
            L.erase(poly([q + v(-1.8, 1), q + v(0, -3.2), q + v(1.8, 1)]))
    if style == "cloak_teal":
        for a2, b2 in zip(hem[:-1], hem[1:]):
            L.line(a2 + v(0, -1), b2 + v(0, -1), CYAN)
    if style == "cloak_wren":
        for a2, b2 in zip(hem[:-1], hem[1:]):
            L.line(a2 + v(0, -1), b2 + v(0, -1), BRASS[3])
    if style == "cloak_bellows":
        for a2, b2 in zip(hem[:-1], hem[1:]):
            L.line(a2 + v(0, -3), b2 + v(0, -3), A[2])
    if style == "cloak_patchwork":
        c = hem[6] + v(2, -8)
        L.paint(poly([c + v(-3, -3), c + v(3, -3), c + v(3, 3), c + v(-3, 3)]), A, flat=True)
    return L.outline(R[0])


def draw_shirt(p, item):
    """The hazard vest (a shop item): a thin open vest over the frame."""
    L = Layer()
    R = ramp_from(item["color"], warm=0.0)
    sh, hp = p.sh, p.hip
    if p.lying:
        return L
    vest = poly([sh + v(-7, -1.6), sh + v(-1, -1.6), sh + v(0.5, 6), sh + v(-0.5, 11), sh + v(-7.4, 11), sh + v(-7.4, 5)])
    vest |= poly([sh + v(4.5, -1.2), sh + v(7.4, 2), sh + v(7, 9), sh + v(4.2, 10.4)])
    L.paint(vest, R)
    if item["id"] == "shirt_hazard_vest":
        for yy in (5.0, 8.0):
            L.line(sh + v(-7, yy), sh + v(0, yy), (232, 234, 222))
            L.line(sh + v(4.4, yy), sh + v(7, yy), (232, 234, 222))
    return L.outline(R[0])


def draw_pants(p, item):
    """Thin, loose trousers over metal legs: they hang off the hip, crease at
    the knee where the joint presses through, and gather at the ankle. Straps
    above the knee and on the shin, a flat pocket on the thigh."""
    L = Layer()
    R = ramp_from(item["color"])
    hp = p.hip
    back = [R[0], R[0], R[1], R[2], R[3]]
    if p.lying:
        for hip, knee, foot, ramp in ((p.hipB, p.kneeB, p.footB, back), (p.hipF, p.kneeF, p.footF, R)):
            L.paint(capsule(hip, knee, 4.4, 4.2) | capsule(knee, foot + v(4, 0), 4.2, 3.2), ramp)
        return L.outline(R[0])
    L.paint(poly([hp + v(-6.6, -3.6), hp + v(6.2, -3.6), hp + v(7.4, 3.0), hp + v(-7.4, 3.0)]), R)
    for hip, knee, foot, ramp in ((p.hipB, p.kneeB, p.footB, back), (p.hipF, p.kneeF, p.footF, R)):
        cuff = foot + v(0.4, -4.8)
        mid = knee + (cuff - knee) * 0.55
        leg = capsule(hip, knee, 4.6, 4.2) | capsule(knee, mid, 4.2, 4.4) | capsule(mid, cuff, 4.4, 3.4)
        L.paint(leg, ramp, soft=2.0)
        nn = norm(knee - hip)
        side = v(-nn[1], nn[0])
        sd = norm(cuff - knee)
        s2 = v(-sd[1], sd[0])
        # the knee joint pressing through the cloth: a lit ridge with a crease each side
        kc = knee + v(1.2, 0)
        L.dot(kc[0], kc[1] - 0.5, ramp[4] if ramp is R else ramp[3])
        L.dot(kc[0] + 0.6, kc[1] + 0.6, ramp[3])
        L.line(knee - nn * 3.5 + side * 2.0, knee - nn * 0.5 + side * 3.2, ramp[1])
        L.line(knee + sd * 1.0 + s2 * 2.2, knee + sd * 4.0 + s2 * 1.0, ramp[1])
        # long hanging folds and the gather at the ankle
        L.line(hip + nn * 2 + side * -1.5, knee - nn * 3 + side * -2.2, ramp[1])
        L.line(mid + s2 * -1.8, cuff - sd * 1.5 + s2 * -1.2, ramp[1])
        for k in range(3):
            y = cuff - sd * (0.4 + k * 1.3)
            L.line(y + s2 * -3.0, y + s2 * 2.6 + sd * 0.6, ramp[1] if k % 2 == 0 else ramp[3])
        hi_c = STRAP[3] if ramp is R else STRAP[1]
        lo_c = STRAP[1] if ramp is R else STRAP[0]
        for q, ax in ((hip + (knee - hip) * 0.7, side), (mid + (cuff - mid) * 0.35, s2)):
            band = capsule(q - ax * 7, q + ax * 7, 1.0) & leg
            L.stamp(band, lo_c)
            L.stamp(band & ~shifted(band, 0, 1), hi_c)
    m = p.hipF + (p.kneeF - p.hipF) * 0.42 + v(1.2, 0)
    pk = poly([m + v(-2.4, -3.0), m + v(3.0, -3.0), m + v(3.0, 3.4), m + v(-2.4, 3.4)])
    L.stamp(pk & ~shifted(pk, 0, 1), R[1])
    L.stamp(pk & ~shifted(pk, -1, 0), R[1])
    L.line(m + v(-2.4, -3.0), m + v(3.0, -3.0), R[3])
    L.line(m + v(-2.4, -1.8), m + v(3.0, -1.8), R[1])
    L.stamp(capsule(hp + v(-6.6, -3.2), hp + v(6.2, -3.2), 0.9), STRAP[1])
    return L.outline(R[0])


def draw_shoes(p, item):
    """Chunky boots: thick sole, stripes across the front."""
    L = Layer()
    R = ramp_from(item["color"])
    back = [R[0], R[0], R[1], R[2], R[2]]
    for foot, ramp in ((p.footB, back), (p.footF, R)):
        if p.lying:
            boot = poly([foot + v(-1, -6), foot + v(5, -6), foot + v(5, 4), foot + v(-1, 4)])
        else:
            boot = poly([foot + v(-4.0, -6.0), foot + v(2.6, -6.0), foot + v(4.6, -3.6), foot + v(8.0, -2.4),
                         foot + v(8.0, 1.4), foot + v(-4.0, 1.4)])
        L.paint(boot, ramp, soft=1.6)
        if not p.lying:
            L.stamp(boot & (PY > foot[1] - 0.2), (34, 26, 24))      # sole
            L.line(foot + v(-4, -0.6), foot + v(8, -0.6), (52, 40, 34))
            for k in range(3):                                      # the drawing's stripes
                L.dot(foot[0] + 0.6 + k * 2.0, foot[1] - 4.0 + k * 0.8, ramp[4])
                L.dot(foot[0] + 1.6 + k * 2.0, foot[1] - 4.0 + k * 0.8, ramp[3])
    return L.outline(R[0])


def draw_mask(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    h = p.headc
    c = h + v(2.8, 1.2)
    if item["id"] == "mask_monocle":
        e = c + v(3.6, -0.4)
        L.paint(disk(e[0], e[1], 4.0), BRASS, soft=1.0)
        L.stamp(disk(e[0], e[1], 2.6), A[2] if p.eyes != "hurt" else RED)
        L.dot(e[0] - 1, e[1] - 1, A[4])
        L.line(e + v(1, 4), e + v(-3, 11), BRASS[3])
        return L.outline(R[0])
    if item["id"] == "mask_brass_goggles":
        L.stamp(capsule(c + v(-14, -2.4), c + v(-4, -2.4), 1.0), (60, 40, 30))
        for ex in (-2.8, 3.6):
            e = c + v(ex, -0.6)
            L.paint(disk(e[0], e[1], 3.6), BRASS, soft=1.0)
            L.stamp(disk(e[0], e[1], 2.2), A[2] if p.eyes != "hurt" else RED)
            L.dot(e[0] - 0.8, e[1] - 0.8, A[4])
        return L.outline(R[0])
    # scrap plate over the lower face with two eye slits
    plate = disk(c[0], c[1] + 0.6, 7.6) & (PY > c[1] - 3.4)
    L.paint(plate, R, soft=1.4)
    for ex in (-2.8, 3.6):
        e = c + v(ex, -1.6)
        L.stamp(ellipse(e[0], e[1], 2.0, 1.2), (12, 12, 18))
        if p.eyes != "off":
            L.dot(e[0], e[1], CYAN if p.eyes == "open" else RED)
    for rx, ry in ((-5, 3.6), (5.6, 3.6), (0.4, 6.0)):
        L.dot(c[0] + rx, c[1] + ry, A[3] if item["accent"] else R[4])
    L.line(c + v(-3.6, 2.8), c + v(4, 2.8), R[1])
    return L.outline(R[0])


# --------------------------------------------------------------- items + output
def read_cosmetics():
    items = []
    d = os.path.join(ROOT, "data", "cosmetics")
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".tres"):
            continue
        t = open(os.path.join(d, fn)).read()

        def col(k):
            m = re.search(k + r' = Color\(([^)]*)\)', t)
            if not m:
                return None
            r, g, b = [float(x) for x in m.group(1).split(",")[:3]]
            return (int(r * 255), int(g * 255), int(b * 255))
        items.append({"id": re.search(r'id = &"(\w+)"', t).group(1), "slot": int(re.search(r'slot = (\d)', t).group(1)),
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
    """Crop a layer's idle frame to its content and fit it in a 32x32 icon:
    halved (the detail the game shows at 1x), then 2x if small enough."""
    a = layer.rgba
    ys, xs = np.nonzero(a[:, :, 3])
    if len(xs) == 0:
        return Image.new("RGBA", (32, 32))
    crop = Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
    if crop.width > 30 or crop.height > 30:
        k = max(crop.width / 30.0, crop.height / 30.0)
        crop = crop.resize((max(1, int(crop.width / k)), max(1, int(crop.height / k))), Image.BOX)
        arr = np.array(crop)
        arr[:, :, 3] = np.where(arr[:, :, 3] > 110, 255, 0)
        crop = Image.fromarray(arr, "RGBA")
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
    save_sheet([draw_blade_back(p) for p in frames], "blade_back")
    idle = P_["idle"][0]
    for item in read_cosmetics():
        for layer in SLOT_LAYERS[item["slot"]]:
            save_sheet([DRAW[layer](p, item) for p in frames], "%s_%s" % (layer, item["id"]))
        if item["slot"] == 2:
            icon_layer = DRAW["cloak_back"](idle, item).under(DRAW["cloak_front"](idle, item))
        else:
            icon_layer = DRAW[SLOT_LAYERS[item["slot"]][0]](idle, item)
        icon_from(icon_layer).save(os.path.join(ICONS, item["id"] + ".png"))
    # the thrown dagger (world sprite), pointing right; the game draws it at half scale
    L = Layer()
    dagger(L, v(16, 24), 0.0, length=20.0)
    ys, xs = np.nonzero(L.rgba[:, :, 3])
    Image.fromarray(L.rgba, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save(os.path.join(OUT, "blade_thrown.png"))
    print("character sheets: %d frames per layer, %d px" % (len(frames), S))


if __name__ == "__main__":
    main()
