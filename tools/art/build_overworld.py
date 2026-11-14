"""Top-down (Undertale-style) walking sprites for the robot, for walk-in buildings.
Run from the project root:  python3 tools/art/build_overworld.py

Uses the same drawing kit as the side-view sprites (build_character.py: 5-step
hue-shifted ramps lit from the top-left, a dark outline per layer), so the robot
looks like the same character from every side.

Each layer is a 4x3 sheet of 48x48 frames, feet on row 44:
    rows:    0 = walking down (facing you), 1 = walking up (back), 2 = walking right (left = mirrored)
    columns: 0 = standing, 1 = step, 2 = standing, 3 = other step
Layers, back to front: cloak_back, body, pants, shoes, shirt, cloak_front, face, hood, mask.
Output: art/overworld/body_boy.png, body_girl.png, face.png and, per outfit
piece, <id>.png (cloaks: <id>_back.png and <id>_front.png).
"""
import math
import os
import sys

import numpy as np
from PIL import Image

# the top-down sprites are 48 px and use the v1 character helpers (the side-view
# sprites moved to 96 px in build_character.py v2)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "legacy"))
import build_character_v1 as bc  # noqa: E402
from build_character_v1 import (Layer, ramp_from, capsule, disk, ellipse, poly, v, PX, PY,  # noqa: E402
                             STEEL, STEEL_BACK, GLASS, BRASS, CYAN, CYAN_HI)

ROOT = bc.ROOT
OUT = os.path.join(ROOT, "art", "overworld")
os.makedirs(OUT, exist_ok=True)
S = bc.S
DOWN, UP, SIDE = 0, 1, 2


class Pose:
    def __init__(self, view, k):
        self.view = view
        self.k = k
        step = [0, 1, 0, -1][k]           # which foot is lifted / forward
        self.bob = -1 if step != 0 else 0
        self.step = step
        self.head = v(24, 15 + self.bob)
        self.sh = v(24, 22 + self.bob)     # shoulder line centre
        self.hip = v(24, 32 + self.bob)
        if view == SIDE:
            fx = 3.5 * step
            self.footF = v(24 + fx + 1, 44 - (1 if step > 0 else 0))
            self.footB = v(24 - fx - 1, 44 - (1 if step < 0 else 0))
            self.handF = v(24 - 3 * step + 1, 31 + self.bob)
            self.handB = v(24 + 3 * step - 1, 31 + self.bob)
        else:
            self.footL = v(21, 44 - (2 if step > 0 else 0))
            self.footR = v(27, 44 - (2 if step < 0 else 0))
            self.handL = v(17, 31 + self.bob + (-1 if step < 0 else 0))
            self.handR = v(31, 31 + self.bob + (-1 if step > 0 else 0))


# ------------------------------------------------------------------ chassis
def body(p, girl):
    L = Layer()
    h, sh, hp = p.head, p.sh, p.hip
    cw, ww = (4.0, 2.8) if girl else (5.0, 3.8)
    if p.view == SIDE:
        L.paint(capsule(sh + v(-1, 1), p.handB, 1.5), STEEL_BACK)
        L.paint(capsule(hp + v(-1, 0), p.footB + v(0, -1.5), 1.8, 1.4), STEEL_BACK)
        L.paint(poly([p.footB + v(-2, -1.5), p.footB + v(3, -1.5), p.footB + v(3.5, 0.5), p.footB + v(-2, 0.5)]), STEEL_BACK)
        torso = poly([sh + v(-3.5, -1), sh + v(3.5, -1), hp + v(3, 0.5), hp + v(-3, 0.5)])
        L.paint(torso, STEEL)
        L.stamp(disk(sh[0] + 2, sh[1] + 4, 1.4), CYAN)
        L.paint(capsule(hp + v(1, 0), p.footF + v(0, -1.5), 1.9, 1.5), STEEL)
        L.paint(poly([p.footF + v(-2, -1.5), p.footF + v(3.5, -1.5), p.footF + v(4, 0.5), p.footF + v(-2, 0.5)]), STEEL)
        L.paint(capsule(sh + v(1, 1), p.handF, 1.6), STEEL)
        L.paint(disk(p.handF[0], p.handF[1], 1.8), STEEL)
        L.paint(capsule(sh + v(0, -1), h + v(0, 5), 1.5), STEEL_BACK)
        L.paint(disk(h[0], h[1], 7.0), STEEL)
        L.paint(disk(h[0] - 3, h[1] + 0.5, 2.0), STEEL_BACK, deep=False)
        L.dot(h[0] - 3, h[1] + 0.5, CYAN)
    else:
        back = p.view == UP
        # arms at the sides
        for s_, hand in ((-1, p.handL), (1, p.handR)):
            L.paint(capsule(sh + v(s_ * (cw - 0.5), 1), hand, 1.6, 1.5), STEEL)
            L.paint(disk(hand[0], hand[1], 1.9), STEEL)
        # legs
        for s_, foot in ((-1, p.footL), (1, p.footR)):
            L.paint(capsule(hp + v(s_ * 2.5, 0), foot + v(0, -1.5), 2.0, 1.6), STEEL)
            L.paint(ellipse(foot[0], foot[1] - 0.8, 2.6, 1.6), STEEL)
        torso = poly([sh + v(-cw, -1), sh + v(cw, -1), sh + v(cw - 0.5, 3), hp + v(ww, -3), hp + v(ww + 0.6, 0.5),
                      hp + v(-ww - 0.6, 0.5), hp + v(-ww, -3), sh + v(-cw + 0.5, 3)])
        L.paint(torso, STEEL)
        L.line(hp + v(-ww, -2.5), hp + v(ww, -2.5), STEEL[1])
        if back:
            L.line(sh + v(0, 0), hp + v(0, -3), STEEL[1])        # spine seam
            L.stamp(ellipse(sh[0], sh[1] + 4, 2.2, 1.2), STEEL[1])  # vent
        else:
            L.stamp(disk(sh[0], sh[1] + 4, 1.6), CYAN)            # core light
            L.dot(sh[0] - 0.5, sh[1] + 3.5, CYAN_HI)
        L.paint(capsule(sh + v(0, -1), h + v(0, 5), 1.6), STEEL_BACK)
        L.paint(disk(h[0], h[1], 7.2), STEEL)
        for s_ in (-1, 1):                                        # ear plates
            L.paint(disk(h[0] + s_ * 6.6, h[1] + 0.5, 1.8), STEEL_BACK, deep=False)
            L.dot(h[0] + s_ * 6.6, h[1] + 0.5, CYAN)
    if girl:
        L.paint(ellipse(p.head[0], p.head[1] - 6.4, 4.5, 1.8), STEEL)   # rounded crest
        if p.view == UP:   # the cable braid down her back, glowing bead at the end
            tip = p.head + v(0.5 * p.step, 13)
            L.paint(capsule(p.head + v(0, 5), tip, 1.4, 1.1), STEEL_BACK)
            L.paint(disk(tip[0], tip[1], 1.6), [STEEL[0], (30, 140, 160), CYAN, CYAN_HI, CYAN_HI], deep=False)
    else:
        L.paint(capsule(p.head + v(-1, -6.8), p.head + v(-2, -9.6), 0.8), STEEL)  # antenna nub
        L.dot(p.head[0] - 2, p.head[1] - 10, CYAN)
    return L.outline(STEEL[0])


def face(p):
    L = Layer()
    if p.view == UP:
        return L
    h = p.head
    c = h + (v(2.4, 0.8) if p.view == SIDE else v(0, 0.8))
    rx = 4.6 if p.view == SIDE else 5.4
    L.paint(ellipse(c[0], c[1], rx, 4.6), GLASS)
    L.dot(c[0] - 3, c[1] - 3, GLASS[4])
    L.dot(c[0] - 2, c[1] - 3.5, GLASS[3])
    for ex in ((-1.4, 1.8) if p.view == SIDE else (-2.1, 2.1)):
        e = c + v(ex, -0.6)
        L.stamp(ellipse(e[0], e[1], 0.9, 1.7), CYAN)
        L.dot(e[0], e[1] - 1, CYAN_HI)
    return L.outline(GLASS[0])


# ------------------------------------------------------------------ clothes
def pants(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    hp = p.hip
    if p.view == SIDE:
        L.paint(capsule(hp + v(-1, 0), p.footB + v(0, -4), 2.6, 2.2), [tuple(int(c * 0.8) for c in col) for col in R])  # far leg, in shade
        L.paint(poly([hp + v(-3.5, -2), hp + v(3.5, -2), hp + v(3.5, 2), hp + v(-3.5, 2)]), R)
        L.paint(capsule(hp + v(1, 0), p.footF + v(0, -4), 2.7, 2.3), R)
        L.stamp(ellipse(hp[0] + 1, hp[1] + 4, 1.4, 1.6), R[1])          # thigh pocket
    else:
        L.paint(poly([hp + v(-4.6, -2), hp + v(4.6, -2), hp + v(4.8, 2), hp + v(-4.8, 2)]), R)
        for s_, foot in ((-1, p.footL), (1, p.footR)):
            L.paint(capsule(hp + v(s_ * 2.6, 0), foot + v(0, -4), 2.8, 2.4), R)
        L.line(hp + v(0, -1), hp + v(0, 3), R[1])
        if p.view == DOWN:
            L.stamp(ellipse(hp[0] - 4, hp[1] + 4, 1.2, 1.6), R[1])
    return L.outline(R[0])


def shoes(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    feet = [p.footB, p.footF] if p.view == SIDE else [p.footL, p.footR]
    for f in feet:
        if p.view == SIDE:
            L.paint(poly([f + v(-2.5, -3), f + v(2.5, -3), f + v(4.5, -1), f + v(4.5, 0.6), f + v(-2.5, 0.6)]), R)
        else:
            L.paint(ellipse(f[0], f[1] - 1.2, 3.0, 2.3), R)
            L.line(f + v(-2.5, -0.2), f + v(2.5, -0.2), R[0])
    return L.outline(R[0])


def shirt(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    sh, hp = p.sh, p.hip
    if p.view == SIDE:
        body_ = poly([sh + v(-3.6, -0.5), sh + v(3.6, -0.5), hp + v(3.4, -1.5), hp + v(-3.4, -1.5)])
    else:
        body_ = poly([sh + v(-4.6, -0.5), sh + v(4.6, -0.5), hp + v(4.0, -1.5), hp + v(-4.0, -1.5)])
    L.paint(body_, R)
    if item["id"] == "shirt_hazard_vest":
        for y in (4.5, 7.5):
            L.stamp(body_ & (np.abs(PY - (sh[1] + y)) < 0.6), A[3])
        if p.view == DOWN:
            L.line(sh + v(0, 0), hp + v(0, -2), R[1])     # the zip
    return L.outline(R[0])


def cloak_back(p, item):
    """The part of the cloak behind the body: the sides of the cape (front view)
    or the trailing cape (side view). From behind, the whole cape is in front."""
    L = Layer()
    if p.view == UP:
        return L
    R = ramp_from(item["color"])
    sh = p.sh
    sway = p.step * 1.0
    if p.view == SIDE:
        shape = poly([sh + v(-1, -1), sh + v(-6 - abs(sway), 6), sh + v(-8 - abs(sway), 18), sh + v(-2, 19), sh + v(2, 0)])
    else:
        shape = poly([sh + v(-6, 0), sh + v(6, 0), sh + v(8 + sway, 19), sh + v(-8 + sway, 19)])
    L.paint(shape, [tuple(int(c * 0.82) for c in col) for col in R])
    return L.outline(R[0])


def cloak_front(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    sh = p.sh
    iid = item["id"]
    sway = p.step * 1.0
    if p.view == UP:
        # the whole cape, shoulders to calves, over the robot's back
        cape = poly([sh + v(-5.5, -1.5), sh + v(5.5, -1.5), sh + v(8 + sway, 19), sh + v(3, 20), sh + v(-3, 20.5), sh + v(-8 + sway, 19)])
        L.paint(cape, R)
        L.line(sh + v(-2, 2), sh + v(-3 + sway, 18), R[1])
        L.line(sh + v(2, 2), sh + v(3 + sway, 18), R[1])
        hem_y = sh[1] + 19
    elif p.view == SIDE:
        cape = poly([sh + v(-4, -1.5), sh + v(4, -1.5), sh + v(3.5, 5), sh + v(-5, 6)])
        L.paint(cape, R)
        hem_y = sh[1] + 5.5
    else:
        # a short capelet across the shoulders, open at the front
        cape = poly([sh + v(-6, -1.5), sh + v(6, -1.5), sh + v(7, 5), sh + v(2, 6), sh + v(0, 3), sh + v(-2, 6), sh + v(-7, 5)])
        L.paint(cape, R)
        hem_y = sh[1] + 5
    # per-item details
    if iid == "cloak_teal":         # a thin neon trim along the hem
        L.stamp(cape & (np.abs(PY - hem_y) < 0.7), CYAN)
    elif iid == "cloak_patchwork":  # patches
        for (dx, dy) in ((-3, 3), (3, 9), (-2, 14)):
            q = sh + v(dx, dy)
            L.stamp(cape & ellipse(q[0], q[1], 1.6, 1.3), A[2])
    elif iid == "cloak_rust":       # a bitten hem
        for dx in (-5, -1, 3, 6):
            m = (np.abs(PX - (sh[0] + dx)) < 0.8) & (np.abs(PY - hem_y) < 1.2)
            L.rgba[m, 3] = 0
    elif iid == "cloak_bellows":    # a verdigris band along the hem, buttons down the front
        L.stamp(cape & (np.abs(PY - (hem_y - 1.5)) < 0.7), A[2])
        if p.view != UP:
            for dy in (1, 4):
                L.dot(sh[0] + (1.5 if p.view == SIDE else 0), sh[1] + dy, BRASS[3])
    elif iid == "cloak_wren":       # brass buttons down the front of the coat
        if p.view != UP:
            for dy in (1, 4):
                L.dot(sh[0] + (1.5 if p.view == SIDE else 0), sh[1] + dy, BRASS[3])
    return L.outline(R[0])


def hood(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    h = p.head
    shell = disk(h[0], h[1] - 0.8, 8.6)
    sway = 0.8 * p.step
    if p.view == SIDE:
        tip = poly([h + v(-1, -8.4), h + v(-7, -7), h + v(-11, -4), h + v(-16, -1 + sway), h + v(-10, 1), h + v(-6, -1.5)])
        opening = ellipse(h[0] + 2.8, h[1] + 1.0, 5.3, 5.0)
    elif p.view == DOWN:
        # the long tip flops over to one side behind the head
        tip = poly([h + v(2, -8), h + v(8, -6), h + v(13 + sway, -1), h + v(11, 2), h + v(7, -2)])
        opening = ellipse(h[0], h[1] + 1.2, 6.0, 5.3)
    else:
        # from behind: the hood covers the head; the tip hangs down the back
        tip = poly([h + v(-3, 4), h + v(3, 4), h + v(1.5 + sway, 13), h + v(-0.5 + sway, 14)])
        opening = np.zeros_like(shell)
    shape = (shell | tip) & ~opening
    L.paint(shape, R)
    if opening.any():
        ring = (bc.shifted(opening, 1, 0) | bc.shifted(opening, -1, 0) | bc.shifted(opening, 0, 1) | bc.shifted(opening, 0, -1)) & shape
        L.stamp(ring, R[1])
    if item["id"] == "hood_tattered":
        for q in (h + v(-12, -2), h + v(9, 0), h + v(1, 11)):
            L.dot(q[0], q[1], R[0])
    return L.outline(R[0])


def mask(p, item):
    L = Layer()
    R = ramp_from(item["color"])
    A = ramp_from(item["accent"]) if item["accent"] else R
    h = p.head
    if p.view == UP:
        # only the strap shows from behind
        L.line(h + v(-7, -0.5), h + v(7, -0.5), (60, 40, 30) if item["id"] == "mask_brass_goggles" else R[1])
        return L
    c = h + (v(2.4, 0.8) if p.view == SIDE else v(0, 0.8))
    eyes = (-1.4, 1.8) if p.view == SIDE else (-2.1, 2.1)
    if item["id"] == "mask_monocle":
        e = c + v(eyes[1] if p.view == SIDE else 2.1, -0.6)
        L.paint(disk(e[0], e[1], 2.3), BRASS, deep=False)
        L.stamp(disk(e[0], e[1], 1.3), A[2])
        L.dot(e[0] - 0.5, e[1] - 0.5, A[4])
        return L.outline(R[0])
    if item["id"] == "mask_brass_goggles":
        if p.view == DOWN:
            L.line(c + v(-7, -1), c + v(7, -1), (60, 40, 30))
        else:
            L.line(c + v(-9, -1.2), c + v(-2, -1.2), (60, 40, 30))
        for ex in eyes:
            e = c + v(ex, -0.6)
            L.paint(disk(e[0], e[1], 2.2), BRASS, deep=False)
            L.stamp(disk(e[0], e[1], 1.2), A[2])
            L.dot(e[0] - 0.5, e[1] - 0.5, A[4])
    else:
        plate = ellipse(c[0], c[1] + 0.6, 4.8, 4.2) & (PY > c[1] - 2.5)
        L.paint(plate, R)
        for ex in eyes:
            e = c + v(ex, -0.9)
            L.stamp(ellipse(e[0], e[1], 1.2, 0.8), (12, 12, 18))
            L.dot(e[0], e[1], CYAN)
        for rx, ry in ((-3, 2), (3, 2)):
            L.dot(c[0] + rx, c[1] + ry, A[3])
    return L.outline(R[0])


# ------------------------------------------------------------------ sheets
def sheet(draw):
    img = Image.new("RGBA", (S * 4, S * 3), (0, 0, 0, 0))
    for row in (DOWN, UP, SIDE):
        for k in range(4):
            L = draw(Pose(row, k))
            img.paste(Image.fromarray(L.rgba, "RGBA"), (k * S, row * S))
    return img


def main():
    sheet(lambda p: body(p, False)).save(os.path.join(OUT, "body_boy.png"))
    sheet(lambda p: body(p, True)).save(os.path.join(OUT, "body_girl.png"))
    sheet(face).save(os.path.join(OUT, "face.png"))
    draw = {0: hood, 1: mask, 3: shirt, 4: pants, 5: shoes}
    for item in bc.read_cosmetics():
        if item["slot"] == 2:
            sheet(lambda p, it=item: cloak_back(p, it)).save(os.path.join(OUT, item["id"] + "_back.png"))
            sheet(lambda p, it=item: cloak_front(p, it)).save(os.path.join(OUT, item["id"] + "_front.png"))
        else:
            sheet(lambda p, it=item: draw[it["slot"]](p, it)).save(os.path.join(OUT, item["id"] + ".png"))
    print("overworld sprites written")


if __name__ == "__main__":
    main()
