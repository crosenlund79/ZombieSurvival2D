#!/usr/bin/env python3
"""Visual overhaul — survivor and zombie figures with natural proportions.

Same canvases, base lines and file names as before (survivor 104x168 base 160,
zombie 110x172 base 164) so sprite dimensions, pivots and creator overrides
keep working. Bodies are built from smooth tapered limbs and curved torsos
rather than boxes; side views face right. Run from the repository root,
after gen_overhaul.py (tools/art/regenerate_all.py does this).
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import ImageFilter
from inkkit import Canvas, hexc, mix, INK, SS
from gen_homestead import out

SKIN, SKIN_D = hexc("#BC9A80"), hexc("#8A6C56")  # cold, pale
Z_SKIN, Z_SKIN_D, Z_SKIN_L = hexc("#8A8E78"), hexc("#5C6152"), hexc("#A6A68E")
LIGHT = (-1, -1, 0.32)


# ---------------------------------------------------------------- geometry
def spline(pts, closed=True, steps=6):
    """Catmull-Rom through control points -> dense polygon/polyline."""
    n = len(pts)
    res = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed else pts[max(i - 1, 0)]
        p1 = pts[i]
        p2 = pts[(i + 1) % n] if closed else pts[i + 1]
        p3 = pts[(i + 2) % n] if closed else pts[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            res.append(tuple(0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    if not closed:
        res.append(tuple(pts[-1]))
    return res


def limb(path, widths, steps=5):
    """Tapered capsule along a joint path; widths are full widths at each joint."""
    pts = spline(path, closed=False, steps=steps)
    m = len(pts)
    ws = []
    for i in range(m):
        f = i / (m - 1) * (len(widths) - 1)
        j = min(int(f), len(widths) - 2)
        ws.append(widths[j] + (widths[j + 1] - widths[j]) * (f - j))
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(m - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        h = ws[i] / 2
        left.append((x + nx * h, y + ny * h))
        right.append((x - nx * h, y - ny * h))

    def cap(p, q, w, n=6):
        ang = math.atan2(q[1] - p[1], q[0] - p[0])
        return [(p[0] + math.cos(ang + math.pi / 2 - math.pi * k / n) * w / 2,
                 p[1] + math.sin(ang + math.pi / 2 - math.pi * k / n) * w / 2) for k in range(1, n)]
    end = cap(pts[-1], (2 * pts[-1][0] - pts[-2][0], 2 * pts[-1][1] - pts[-2][1]), ws[-1])
    start = cap(pts[0], (2 * pts[0][0] - pts[1][0], 2 * pts[0][1] - pts[1][1]), ws[0])
    return left + end + right[::-1] + start


def part(c, pts, col, tex=0.22, cell=8, ink=1.9, shade=None, light=LIGHT, alpha=230):
    m = c.fill(pts, col, tex=tex, cell=cell, light=light)
    if shade:
        c.shade(m, *shade)
    if ink:
        c.ink_poly(pts, width=ink, alpha=alpha)
    return m


def fold(c, pts, col=INK, w=1.0, a=120):
    c.ink(pts, width=w, color=col, alpha=a)


def boot(c, x, y, w, facing=0, col=hexc("#2A221B")):
    """Boot with its sole at y. facing: 0 front, 1 right (side view)."""
    if facing:
        pts = [(x - w * 0.45, y - 11), (x + w * 0.3, y - 11), (x + w * 0.5, y - 6), (x + w * 0.95, y - 3),
               (x + w * 0.95, y), (x - w * 0.5, y)]
    else:
        pts = spline([(x - w / 2, y - 11), (x + w / 2, y - 11), (x + w / 2 + 1.5, y - 2), (x, y + 0.5),
                      (x - w / 2 - 1.5, y - 2)], steps=4)
    part(c, pts, col, tex=0.15, ink=1.7)
    c.ink([(x - w * 0.45, y - 2.2), (x + w * 0.45 + (w * 0.45 if facing else 0), y - 2.2)], width=1.0,
          color=hexc("#55463A"), alpha=200)


def hand(c, x, y, r, col):
    pts = c.blob(x, y, r, r * 1.1, n=10, irregular=0.08)
    part(c, pts, col, tex=0.12, ink=1.3)


# ---------------------------------------------------------------- survivor
# Red Thaw: a faded blue-grey winter parka, dark wool trousers, grey knit hat
JACKET, JACKET_D, JACKET_L = hexc("#56625F"), hexc("#3A4442"), hexc("#7A8582")
TROUSER, TROUSER_D = hexc("#3E3B37"), hexc("#2A2725")
PACK, PACK_D = hexc("#76644A"), hexc("#504330")
SCARF, SCARF_D = hexc("#6A5546"), hexc("#4A3A30")
HAIR, BEARD, CAP = hexc("#3A2A1D"), hexc("#4A3426"), hexc("#55524C")


def survivor(view):
    W, H = 104, 168
    c = Canvas(W, H, seed=3161 + ["down", "up", "side"].index(view))
    base = 160
    c.soft_shadow((22, base - 9, 82, base + 6), alpha=130, blur=4)
    if view == "side":
        _survivor_side(c, base)
    else:
        _survivor_front(c, base, view == "down")
    c.save(out("characters/player/template_survivor_%s.png" % view), size=(W, H))


def _survivor_front(c, base, front):
    cx = 52
    # legs (hip 100 -> knee 128 -> ankle 149)
    for sx in (-1, 1):
        x = cx + sx * 9
        leg = limb([(x, 98), (x + sx * 0.5, 126), (x + sx * 1.0, 149)], [16, 13, 11])
        col = TROUSER if (sx < 0) == front else TROUSER_D
        m = part(c, leg, col, shade=(1, 0.3, 4, 70) if sx > 0 else None)
        fold(c, [(x - 4, 124), (x + 3, 127), (x + 5, 125)], a=110)
        if front and sx < 0:  # knee patch
            p = [(x - 5, 120), (x + 5, 119), (x + 5, 130), (x - 5, 131)]
            part(c, p, mix(TROUSER, hexc("#6A5E48"), 0.5), tex=0.3, ink=1.0, alpha=170)
        boot(c, x + sx * 1.0, base - 1, 15)
    # backpack behind (front view: just the frame top edges peek over shoulders)
    if front:
        for sx in (-1, 1):
            p = [(cx + sx * 20, 44), (cx + sx * 25, 46), (cx + sx * 26, 60), (cx + sx * 21, 58)]
            part(c, p, PACK_D, ink=1.4)
    # torso: shoulders 47, waist 92, hem 104
    torso = spline([(cx - 21, 49), (cx - 12, 44), (cx + 12, 44), (cx + 21, 49), (cx + 20, 72), (cx + 18, 92),
                    (cx + 20, 105), (cx, 107), (cx - 20, 105), (cx - 18, 92), (cx - 20, 72)], steps=5)
    m = part(c, torso, JACKET if front else JACKET_D, ink=2.1, shade=(1, 0.4, 4.2, 78))
    c.grime(m, 0.18, drips=False)
    if front:
        fold(c, [(cx, 52), (cx + 0.5, 80), (cx, 106)], col=JACKET_D, w=1.4, a=200)  # zip / placket
        for sx in (-1, 1):  # pockets
            p = [(cx + sx * 5, 78), (cx + sx * 15, 77), (cx + sx * 16, 90), (cx + sx * 6, 91)]
            c.ink_poly(p, width=1.0, color=JACKET_D, alpha=200)
            fold(c, [(cx + sx * 5, 81), (cx + sx * 15, 80)], col=JACKET_D, w=1.2, a=200)
        fold(c, [(cx - 15, 60), (cx - 9, 66)], a=90)
        fold(c, [(cx + 14, 62), (cx + 8, 70)], a=90)
        c.ink([(cx - 18, 95), (cx + 18, 95)], width=2.2, color=hexc("#2F2618"), alpha=220)  # belt
        c.fill([(cx - 3, 93), (cx + 3, 93), (cx + 3, 97.5), (cx - 3, 97.5)], hexc("#8A7B5A"))
        for sx in (-1, 1):  # pack straps
            c.ink([(cx + sx * 14, 46), (cx + sx * 13, 64), (cx + sx * 15, 84)], width=3.4, color=PACK_D, alpha=240)
    else:
        bp = spline([(cx - 18, 47), (cx + 18, 47), (cx + 20, 70), (cx + 19, 98), (cx - 19, 98), (cx - 20, 70)], steps=4)
        m = part(c, bp, PACK, tex=0.3, ink=2.2, shade=(1, 0.5, 4, 85))
        c.grime(m, 0.3, drips=True)
        flap = spline([(cx - 17, 49), (cx + 17, 49), (cx + 16, 66), (cx, 69), (cx - 16, 66)], steps=4)
        part(c, flap, mix(PACK, PACK_D, 0.4), tex=0.3, ink=1.6)
        c.ink([(cx - 4, 66), (cx - 4, 74)], width=2.0, color=PACK_D)
        c.ink([(cx + 4, 66), (cx + 4, 74)], width=2.0, color=PACK_D)
        for sx in (-1, 1):
            p = [(cx + sx * 7, 76), (cx + sx * 17, 76), (cx + sx * 17, 94), (cx + sx * 7, 94)]
            part(c, p, PACK_D, tex=0.25, ink=1.2)
        roll = limb([(cx - 21, 102), (cx + 21, 102)], [11, 11])
        part(c, roll, hexc("#5B5848"), ink=1.6)
        for x in (cx - 12, cx + 12):
            c.ink([(x, 97), (x, 107)], width=1.6, color=hexc("#2F2618"))
    # arms (shoulder -> elbow -> wrist), hands
    for sx in (-1, 1):
        sx0 = cx + sx * 18
        arm = limb([(sx0, 51), (sx0 + sx * 6, 76), (sx0 + sx * 5, 98)], [13, 11, 9])
        col = JACKET_D if (sx > 0) == front else JACKET
        part(c, arm, col, shade=(sx, 0.2, 4, 70) if sx > 0 else None)
        fold(c, [(sx0 + sx * 3, 74), (sx0 + sx * 8, 77)], a=110)
        c.ink([(sx0 + sx * 1, 95), (sx0 + sx * 9, 95)], width=1.6, color=JACKET_D, alpha=200)  # cuff
        hand(c, sx0 + sx * 5, 102, 5, SKIN)
    # neck / scarf / head
    if front:
        part(c, [(cx - 5, 36), (cx + 5, 36), (cx + 5, 44), (cx - 5, 44)], SKIN_D, ink=0)
        scarf = spline([(cx - 13, 41), (cx, 45), (cx + 13, 41), (cx + 12, 48), (cx, 52), (cx - 12, 48)], steps=4)
        part(c, scarf, SCARF, tex=0.3, ink=1.6)
        tail = [(cx + 4, 49), (cx + 10, 49), (cx + 11, 64), (cx + 5, 63)]
        part(c, tail, SCARF_D, tex=0.3, ink=1.3)
        head = c.blob(cx, 25, 11.5, 13.5, n=20, irregular=0.03)
        part(c, head, SKIN, tex=0.14, ink=2.0, light=(-1, -1, 0.4))
        for sx in (-1, 1):  # ears
            part(c, c.blob(cx + sx * 11.5, 26, 2.5, 4, n=8, irregular=0.05), SKIN_D, ink=1.2)
        beard = spline([(cx - 10, 26), (cx - 6, 31), (cx + 6, 31), (cx + 10, 26), (cx + 9, 34), (cx, 40), (cx - 9, 34)], steps=4)
        part(c, beard, BEARD, tex=0.4, ink=1.3, alpha=200)
        c.fill([(cx - 4, 33), (cx + 4, 33), (cx + 3, 35), (cx - 3, 35)], hexc("#7A4A3A"))  # mouth
        for sx in (-1, 1):
            c.ellipse_fill((cx + sx * 4.5 - 1.6, 22, cx + sx * 4.5 + 1.6, 25.5), INK)
            c.ink([(cx + sx * 2, 19.5), (cx + sx * 7.5, 19)], width=1.3, alpha=210)
        c.ink([(cx, 23), (cx - 1, 28), (cx + 1.5, 28.5)], width=0.9, color=SKIN_D, alpha=200)
        cap = spline([(cx - 12.5, 21), (cx - 11, 12), (cx, 9), (cx + 11, 12), (cx + 12.5, 21), (cx, 19)], steps=5)
        m = part(c, cap, CAP, tex=0.35, ink=1.8)
        for k in range(-3, 4):
            fold(c, [(cx + k * 3.2, 12), (cx + k * 3.6, 19)], w=0.8, a=90)
        c.ink([(cx - 12.5, 19.5), (cx + 12.5, 19.5)], width=1.6, alpha=200)
    else:
        part(c, [(cx - 5, 36), (cx + 5, 36), (cx + 5, 45), (cx - 5, 45)], SKIN_D, ink=1.2)
        scarf = spline([(cx - 13, 42), (cx, 40), (cx + 13, 42), (cx + 12, 48), (cx, 47), (cx - 12, 48)], steps=4)
        part(c, scarf, SCARF, tex=0.3, ink=1.6)
        head = c.blob(cx, 25, 11.5, 13.5, n=20, irregular=0.03)
        part(c, head, HAIR, tex=0.35, ink=2.0, shade=(0.4, 1, 3.4, 70))
        for sx in (-1, 1):
            part(c, c.blob(cx + sx * 11.5, 27, 2.5, 4, n=8, irregular=0.05), SKIN_D, ink=1.2)
        cap = spline([(cx - 12.5, 22), (cx - 11, 12), (cx, 9), (cx + 11, 12), (cx + 12.5, 22), (cx, 24)], steps=5)
        part(c, cap, CAP, tex=0.35, ink=1.8, shade=(0.5, 1, 3.4, 70))
        for k in range(-3, 4):
            fold(c, [(cx + k * 3.2, 12), (cx + k * 3.6, 22)], w=0.8, a=90)


def _survivor_side(c, base):
    cx = 50
    # far leg (behind), near leg
    for x, ofs, col in ((47, -5, TROUSER_D), (53, 5, TROUSER)):
        leg = limb([(x, 98), (x + ofs * 0.6 + 2, 126), (x + ofs, 149)], [16, 13, 11])
        part(c, leg, col, shade=(1, 0, 4, 60) if col == TROUSER else None)
        fold(c, [(x + ofs * 0.6 - 2, 124), (x + ofs * 0.6 + 6, 126)], a=100)
        boot(c, x + ofs, base - 1, 15, facing=1)
    # far arm behind torso
    arm_b = limb([(cx + 2, 52), (cx - 4, 76), (cx - 2, 97)], [11, 10, 8])
    part(c, arm_b, mix(JACKET_D, INK, 0.2), ink=1.6)
    # backpack on the back (left)
    bp = spline([(cx - 26, 50), (cx - 10, 46), (cx - 8, 98), (cx - 24, 102), (cx - 28, 76)], steps=4)
    m = part(c, bp, PACK, tex=0.3, ink=2.2, shade=(-1, 0.5, 4, 85))
    c.grime(m, 0.3, drips=True)
    c.ink([(cx - 26, 70), (cx - 9, 68)], width=1.5, color=PACK_D)
    part(c, [(cx - 27, 78), (cx - 20, 78), (cx - 20, 94), (cx - 27, 94)], PACK_D, ink=1.1)
    roll = c.blob(cx - 18, 104, 10, 6, n=14, irregular=0.04)
    part(c, roll, hexc("#5B5848"), ink=1.5)
    # torso (chest faces right, slight forward lean)
    torso = spline([(cx - 11, 47), (cx + 6, 44), (cx + 14, 50), (cx + 15, 72), (cx + 12, 92), (cx + 14, 105),
                    (cx - 2, 107), (cx - 13, 104), (cx - 11, 90), (cx - 13, 70)], steps=5)
    m = part(c, torso, JACKET, ink=2.1, shade=(-0.6, 0.8, 4.2, 80))
    c.grime(m, 0.18, drips=False)
    c.ink([(cx - 12, 94), (cx + 13, 95)], width=2.2, color=hexc("#2F2618"))
    c.ink([(cx - 8, 47), (cx - 7, 66), (cx - 9, 86)], width=3.2, color=PACK_D)  # strap
    fold(c, [(cx + 10, 56), (cx + 12, 74)], col=JACKET_D, w=1.3, a=180)
    p = [(cx + 1, 78), (cx + 11, 77), (cx + 11, 89), (cx + 1, 90)]
    c.ink_poly(p, width=1.0, color=JACKET_D, alpha=200)
    # neck, scarf, head (facing right)
    part(c, [(cx - 2, 36), (cx + 7, 36), (cx + 7, 45), (cx - 2, 45)], SKIN_D, ink=0)
    scarf = spline([(cx - 8, 41), (cx + 4, 43), (cx + 13, 40), (cx + 12, 49), (cx + 2, 51), (cx - 8, 48)], steps=4)
    part(c, scarf, SCARF, tex=0.3, ink=1.6)
    part(c, [(cx - 7, 46), (cx - 1, 47), (cx - 4, 60), (cx - 9, 58)], SCARF_D, ink=1.3)
    hx = cx + 4
    head = spline([(hx - 11, 24), (hx - 9, 14), (hx + 2, 11), (hx + 11, 16), (hx + 13, 25), (hx + 14.5, 27),
                   (hx + 12, 30), (hx + 11, 36), (hx + 2, 39), (hx - 8, 35)], steps=4)
    part(c, head, SKIN, tex=0.14, ink=2.0, light=(1, -1, 0.35))
    beard = spline([(hx - 2, 30), (hx + 4, 31), (hx + 12, 30), (hx + 11, 36), (hx + 3, 40), (hx - 3, 36)], steps=4)
    part(c, beard, BEARD, tex=0.4, ink=1.3, alpha=200)
    part(c, c.blob(hx - 4, 27, 2.6, 4, n=8, irregular=0.05), SKIN_D, ink=1.2)  # ear
    c.ellipse_fill((hx + 6.5, 22.5, hx + 9.5, 26), INK)
    c.ink([(hx + 4.5, 20), (hx + 11, 19.5)], width=1.3, alpha=210)
    cap = spline([(hx - 12, 23), (hx - 10, 13), (hx + 1, 9), (hx + 11, 13), (hx + 13, 21), (hx, 20)], steps=5)
    part(c, cap, CAP, tex=0.35, ink=1.8)
    for k in range(-3, 4):
        fold(c, [(hx + k * 3.2, 12), (hx + k * 3.5, 20)], w=0.8, a=90)
    # near arm in front
    arm = limb([(cx + 1, 51), (cx + 6, 76), (cx + 9, 97)], [13, 11, 9])
    part(c, arm, JACKET_D, shade=(1, 0.2, 4, 60))
    fold(c, [(cx + 2, 74), (cx + 9, 76)], a=110)
    c.ink([(cx + 4, 94), (cx + 13, 94)], width=1.6, color=mix(JACKET_D, INK, 0.3), alpha=200)
    hand(c, cx + 9.5, 101, 5, SKIN)


# ---------------------------------------------------------------- zombie
Z_CLOTH, Z_CLOTH_D, Z_SHIRT, Z_STAIN = hexc("#55524A"), hexc("#3A3832"), hexc("#6E6853"), hexc("#4A2622")
Z_HAIR = hexc("#2A2520")


def zombie(view, lunge=False):
    W, H = 110, 172
    c = Canvas(W, H, seed=3601 + ["down", "up", "side"].index(view) + (10 if lunge else 0))
    base = 164
    c.soft_shadow((24, base - 9, 88, base + 6), alpha=130, blur=4)
    if view == "side":
        _zombie_side(c, base, lunge)
    else:
        _zombie_front(c, base, view == "down", lunge)
    suffix = "_lunge" if lunge else ""
    c.save(out("characters/zombie/template_zombie_%s%s.png" % (view, suffix)), size=(W, H))


def _zface(c, hx, hy, tilt=0.0):
    for sx in (-1, 1):
        ex, ey = hx + sx * 5 + tilt, hy - 1 + sx * tilt * 0.3
        sock = c.blob(ex, ey, 3.6, 3.0, n=10, irregular=0.12)
        c.fill(sock, hexc("#2A2622"))
        c.ellipse_fill((ex - 0.9, ey - 0.6, ex + 0.9, ey + 1.0), hexc("#C9C4A2"))
    c.ink([(hx - 1 + tilt, hy + 2), (hx - 2 + tilt, hy + 5)], width=0.9, color=Z_SKIN_D, alpha=200)
    jaw = spline([(hx - 4 + tilt, hy + 8), (hx + 4 + tilt, hy + 8), (hx + 3 + tilt, hy + 12), (hx - 3 + tilt, hy + 12)], steps=3)
    c.fill(jaw, hexc("#2A1A18"))
    c.ink([(hx - 3 + tilt, hy + 8.5), (hx + 3 + tilt, hy + 8.5)], width=0.8, color=hexc("#B8B090"), alpha=170)


def _zombie_front(c, base, front, lunge):
    cx = 55
    # legs: knock-kneed, one dragging
    for sx in (-1, 1):
        x = cx + sx * 9
        knee = (x - sx * 2, 132)
        foot = (x + sx * (3 if sx > 0 else 0), 153)
        leg = limb([(x, 104), knee, foot], [15, 12, 10])
        m = part(c, leg, Z_CLOTH if (sx < 0) == front else Z_CLOTH_D, shade=(1, 0.3, 4, 70) if sx > 0 else None)
        c.grime(m, 0.4, drips=False)
        if sx > 0:  # torn trouser hem showing shin
            c.fill(limb([(foot[0], 145), (foot[0], 152)], [8, 8]), Z_SKIN_D)
            c.ink([(foot[0] - 6, 144), (foot[0] - 2, 146), (foot[0] + 1, 143), (foot[0] + 5, 145)], width=1.2)
            boot(c, foot[0], base - 1, 13, col=hexc("#3A3530"))
        else:
            boot(c, foot[0], base - 1, 14)
    # torso hunched: shoulders uneven (left lower)
    torso = spline([(cx - 21, 58), (cx - 12, 51), (cx + 10, 48), (cx + 20, 52), (cx + 18, 78), (cx + 15, 96),
                    (cx + 18, 108), (cx + 6, 106), (cx - 2, 110), (cx - 10, 106), (cx - 18, 109), (cx - 16, 94),
                    (cx - 19, 76)], steps=5)
    m = part(c, torso, Z_SHIRT if front else mix(Z_SHIRT, Z_CLOTH, 0.4), tex=0.35, ink=2.1, shade=(1, 0.5, 4, 90))
    c.grime(m, 0.7, drips=True, color=Z_STAIN)
    if front:
        tear = spline([(cx - 6, 70), (cx + 2, 66), (cx + 8, 74), (cx + 3, 86), (cx - 5, 84)], steps=4)
        part(c, tear, Z_SKIN_D, tex=0.3, ink=1.4)
        for k in range(3):  # ribs
            fold(c, [(cx - 4, 72 + k * 4), (cx + 1, 71 + k * 4), (cx + 5, 73 + k * 4)], col=hexc("#3E4136"), w=1.0, a=170)
        fold(c, [(cx - 14, 60), (cx - 8, 66)], a=100)
        fold(c, [(cx + 12, 60), (cx + 8, 70)], a=100)
        c.ink([(cx - 17, 98), (cx + 16, 96)], width=2.0, color=hexc("#2A241C"))
        c.ellipse_fill((cx + 6, 88, cx + 14, 96), Z_STAIN)
    else:
        fold(c, [(cx, 54), (cx + 1, 100)], col=hexc("#3E3A30"), w=1.2, a=150)
        tear = spline([(cx + 4, 66), (cx + 12, 64), (cx + 13, 76), (cx + 6, 78)], steps=3)
        part(c, tear, Z_SKIN_D, tex=0.3, ink=1.3)
        c.ink([(cx - 17, 98), (cx + 16, 96)], width=2.0, color=hexc("#2A241C"))
    # arms
    for sx in (-1, 1):
        sh = (cx + sx * 18, 56 if sx < 0 else 53)
        if lunge:
            path = [sh, (sh[0] + sx * 10, 70), (sh[0] + sx * 6, 52), (sh[0] + sx * 2, 40)] if front else \
                [sh, (sh[0] + sx * 10, 68), (sh[0] + sx * 8, 50)]
            widths = [12, 10, 9, 8] if front else [12, 10, 8]
        else:
            path = [sh, (sh[0] + sx * 5, 84), (sh[0] + sx * 3, 110)]
            widths = [12, 9, 8]
        arm = limb(path, widths)
        sleeve = limb(path[:2], widths[:2])
        part(c, arm, Z_SKIN_D if sx > 0 else Z_SKIN, tex=0.3, ink=1.8)
        part(c, sleeve, Z_CLOTH_D if front else Z_CLOTH, tex=0.3, ink=1.6)
        tip = path[-1]
        prev = path[-2]
        ang = math.atan2(tip[1] - prev[1], tip[0] - prev[0])
        hx, hy = tip[0] + math.cos(ang) * 4, tip[1] + math.sin(ang) * 4
        hand(c, hx, hy, 5.2, Z_SKIN)
        for k in (-1, 0, 1):  # long fingers
            a2 = ang + k * 0.35
            c.ink([(hx + math.cos(a2) * 4, hy + math.sin(a2) * 4), (hx + math.cos(a2) * 9, hy + math.sin(a2) * 9)],
                  width=1.5, color=mix(Z_SKIN_D, INK, 0.4))
    # neck + head (tilted, sunk forward)
    hx, hy = cx + 3, 33
    part(c, [(cx - 3, 42), (cx + 7, 42), (cx + 6, 52), (cx - 3, 52)], Z_SKIN_D, ink=1.2)
    head = spline([(hx - 11, 28), (hx - 9, 19), (hx + 1, 15), (hx + 11, 19), (hx + 12.5, 30), (hx + 8, 43),
                   (hx, 47), (hx - 8, 43)], steps=4)
    if front:
        part(c, head, Z_SKIN, tex=0.3, ink=2.1, shade=(1, 0.4, 3.5, 80), light=(-1, -1, 0.3))
        _zface(c, hx, hy, tilt=0.8)
        hair = [(hx - 12, 26), (hx - 9, 15), (hx + 2, 12), (hx + 11, 17), (hx + 9, 21), (hx + 2, 19), (hx - 6, 21), (hx - 9, 30)]
        part(c, spline(hair, steps=3), Z_HAIR, tex=0.4, ink=1.4)
        c.ellipse_fill((hx + 6, 25, hx + 10, 29), Z_STAIN)
    else:
        part(c, head, Z_SKIN_D, tex=0.3, ink=2.1)
        hair = spline([(hx - 12, 30), (hx - 9, 15), (hx + 2, 12), (hx + 11, 17), (hx + 12, 32), (hx + 4, 36),
                       (hx - 4, 34)], steps=4)
        part(c, hair, Z_HAIR, tex=0.45, ink=1.6, shade=(0.5, 1, 3.4, 80))
        part(c, c.blob(hx - 4, 26, 4, 3, n=8, irregular=0.2), Z_SKIN_D, ink=1.0)  # bald patch


def _zombie_side(c, base, lunge):
    cx = 52
    lean = 8 if lunge else 4
    for x, ofs, col in ((49, -7, Z_CLOTH_D), (55, 8, Z_CLOTH)):
        leg = limb([(x, 104), (x + ofs * 0.4 + 3, 132), (x + ofs, 153)], [15, 12, 10])
        m = part(c, leg, col, shade=(1, 0, 4, 60) if col == Z_CLOTH else None)
        c.grime(m, 0.4, drips=False)
        boot(c, x + ofs, base - 1, 14, facing=1)
    # far arm
    if lunge:
        far = limb([(cx + lean + 4, 58), (cx + lean + 20, 62), (cx + lean + 33, 57)], [11, 9, 8])
    else:
        far = limb([(cx + 4, 58), (cx + 2, 84), (cx + 6, 108)], [11, 9, 8])
    part(c, far, mix(Z_SKIN_D, INK, 0.25), ink=1.6)
    torso = spline([(cx - 12 + lean, 52), (cx + 6 + lean, 50), (cx + 14 + lean * 0.6, 60), (cx + 14, 82),
                    (cx + 12, 98), (cx + 15, 109), (cx + 2, 106), (cx - 10, 110), (cx - 12, 92), (cx - 14 + lean * 0.4, 70)], steps=5)
    m = part(c, torso, Z_SHIRT, tex=0.35, ink=2.1, shade=(-0.4, 1, 4, 90))
    c.grime(m, 0.7, drips=True, color=Z_STAIN)
    tear = spline([(cx + 4, 72), (cx + 12, 70), (cx + 13, 84), (cx + 5, 86)], steps=3)
    part(c, tear, Z_SKIN_D, tex=0.3, ink=1.3)
    for k in range(3):
        fold(c, [(cx + 6, 75 + k * 4), (cx + 12, 74 + k * 4)], col=hexc("#3E4136"), a=160)
    c.ink([(cx - 12, 98), (cx + 13, 97)], width=2.0, color=hexc("#2A241C"))
    # head pushed forward
    hx, hy = cx + 8 + lean * 1.4, 34
    part(c, [(hx - 10, 42), (hx - 2, 41), (hx - 2, 54), (hx - 12, 54)], Z_SKIN_D, ink=1.2)
    head = spline([(hx - 11, 30), (hx - 8, 19), (hx + 3, 16), (hx + 11, 22), (hx + 13, 31), (hx + 12, 38),
                   (hx + 6, 46), (hx - 4, 45), (hx - 10, 40)], steps=4)
    part(c, head, Z_SKIN, tex=0.3, ink=2.1, shade=(-1, 0.6, 3.5, 85), light=(1, -1, 0.3))
    sock = c.blob(hx + 6, 29, 3.4, 3.0, n=10, irregular=0.12)
    c.fill(sock, hexc("#2A2622"))
    c.ellipse_fill((hx + 6, 28.6, hx + 7.8, 30.4), hexc("#C9C4A2"))
    jaw = spline([(hx + 6, 38), (hx + 12, 37), (hx + 11, 42), (hx + 6, 42)], steps=3)
    c.fill(jaw, hexc("#2A1A18"))
    hair = spline([(hx - 12, 34), (hx - 9, 18), (hx + 3, 14), (hx + 11, 19), (hx + 4, 21), (hx - 3, 24), (hx - 6, 36)], steps=3)
    part(c, hair, Z_HAIR, tex=0.45, ink=1.4)
    part(c, c.blob(hx - 3, 31, 2.4, 3.6, n=8, irregular=0.1), Z_SKIN_D, ink=1.1)  # ear
    # near arm
    if lunge:
        path = [(cx + lean, 58), (cx + lean + 20, 66), (cx + lean + 36, 62)]
    else:
        path = [(cx, 58), (cx + 4, 84), (cx + 8, 110)]
    arm = limb(path, [12, 10, 8])
    part(c, arm, Z_SKIN, tex=0.3, ink=1.8, shade=(0.3, 1, 4, 60))
    part(c, limb(path[:2], [13, 11]), Z_CLOTH_D, tex=0.3, ink=1.6)
    tip, prev = path[-1], path[-2]
    ang = math.atan2(tip[1] - prev[1], tip[0] - prev[0])
    hx2, hy2 = tip[0] + math.cos(ang) * 4, tip[1] + math.sin(ang) * 4
    hand(c, hx2, hy2, 5.2, Z_SKIN)
    for k in (-1, 0, 1):
        a2 = ang + k * 0.35
        c.ink([(hx2 + math.cos(a2) * 4, hy2 + math.sin(a2) * 4), (hx2 + math.cos(a2) * 9.5, hy2 + math.sin(a2) * 9.5)],
              width=1.5, color=mix(Z_SKIN_D, INK, 0.4))


# ---------------------------------------------------------------- Burnt Ones (Red Thaw)
# Human survivors gone wrong: damaged winter coats, scarred and burned skin, dried
# and frozen blood, ragged silhouettes. Built on the zombie body (same canvas, base
# line and proportions) with a new palette and overlays. Restrained faces: a hood
# shadow hides the eyes.
B_SKIN, B_SKIN_D, B_SKIN_L = hexc("#A09488"), hexc("#6E645C"), hexc("#B8AEA2")
B_COAT, B_COAT_D, B_SHIRT = hexc("#3E3934"), hexc("#28241F"), hexc("#4E4740")
B_BURN, B_RAW, B_BLOOD, B_BLOOD_D = hexc("#1E1A18"), hexc("#6A3A32"), hexc("#561814"), hexc("#30100E")
FROST = hexc("#DDE3E6")


def _burn(c, x, y, rx, ry):
    """Charred patch with a raw, healed-red rim."""
    b = c.blob(x, y, rx, ry, n=10, irregular=0.35)
    c.fill(c.blob(x, y, rx * 1.35, ry * 1.35, n=10, irregular=0.3), B_RAW[:3] + (200,), tex=0.3)
    c.fill(b, B_BURN, tex=0.4)


def _blood(c, x, y, rx, ry, drips=2, frost=True):
    b = c.blob(x, y, rx, ry, n=10, irregular=0.45)
    c.fill(b, mix(B_BLOOD, B_BLOOD_D, 0.3 + c.rng.random() * 0.5)[:3] + (205,), tex=0.3)
    for _ in range(drips):
        dx = x + c.rng.uniform(-rx * 0.6, rx * 0.6)
        c.ink([(dx, y), (dx + c.rng.uniform(-1, 1), y + ry + c.rng.uniform(4, 11))], width=1.6, color=B_BLOOD_D, alpha=220)
    if frost:  # the blood is frozen: rime crystals over it
        for _ in range(int(rx * ry / 14) + 1):
            fx, fy = x + c.rng.uniform(-rx * 0.7, rx * 0.7), y + c.rng.uniform(-ry * 0.7, ry * 0.7)
            c.ellipse_fill((fx - 0.45, fy - 0.45, fx + 0.45, fy + 0.45), mix(FROST, B_BLOOD, 0.35))


def _tatters(c, x0, x1, y, n, length=(6, 16), col=None):
    col = col or B_COAT_D
    for _ in range(n):
        x = c.rng.uniform(x0, x1); L = c.rng.uniform(*length); w = c.rng.uniform(3, 6)
        p = [(x - w / 2, y - 2), (x + w / 2, y - 2), (x + w * 0.2 + c.rng.uniform(-2, 2), y + L)]
        c.fill(p, col, tex=0.3)
        c.ink([p[0], p[2], p[1]], width=1.0, alpha=200)


def _hood(c, hx, hy, side=False, back=False):
    # Shapes below are authored for the upright figure (hood centre y 33/34);
    # dy shifts them so lower postures can place the head anywhere.
    dy = hy - (34 if side else 33)
    S = lambda pts: [(x, y + dy) for x, y in pts]
    if back:
        hood = spline(S([(hx - 15, 34), (hx - 13, 16), (hx, 9), (hx + 13, 15), (hx + 15, 34), (hx + 9, 46), (hx - 9, 46)]), steps=4)
        part(c, hood, B_COAT, tex=0.4, ink=2.0, shade=(0.5, 1, 3.4, 90))
        _burn(c, hx + 6, 22 + dy, 5, 3.5)
        return
    if side:
        hood = spline(S([(hx - 14, 40), (hx - 12, 18), (hx + 2, 11), (hx + 12, 16), (hx + 13, 22), (hx + 4, 21), (hx - 2, 30), (hx - 4, 44)]), steps=4)
    else:
        hood = spline(S([(hx - 15, 40), (hx - 14, 18), (hx, 10), (hx + 14, 17), (hx + 15, 40), (hx + 10, 30), (hx + 7, 22), (hx, 20),
                       (hx - 7, 22), (hx - 10, 30)]), steps=4)
    part(c, hood, B_COAT, tex=0.4, ink=2.0)
    # shadow over the eyes: the face stays restrained, almost unseen
    eye = [(hx - 9, 24), (hx + 10, 24), (hx + 9, 33), (hx - 8, 33)] if not side else [(hx - 2, 24), (hx + 12, 24), (hx + 12, 33), (hx - 1, 33)]
    eye = c.blob(sum(p[0] for p in eye) / 4, 27 + dy, 10 if not side else 7, 5.5, n=14, irregular=0.15)
    c.fill(eye, (22, 19, 17, 205), tex=0.2)
    c.fill(c.blob(eye[0][0] - 10 if not side else hx + 5, 25 + dy, 11 if not side else 8, 3, n=10, irregular=0.1), (22, 19, 17, 150), tex=0.2)


def burnt(view, lunge=False):
    g = globals()
    saved = {k: g[k] for k in ("Z_SKIN", "Z_SKIN_D", "Z_SKIN_L", "Z_CLOTH", "Z_CLOTH_D", "Z_SHIRT", "Z_STAIN", "Z_HAIR")}
    g.update(Z_SKIN=B_SKIN, Z_SKIN_D=B_SKIN_D, Z_SKIN_L=B_SKIN_L, Z_CLOTH=B_COAT, Z_CLOTH_D=B_COAT_D, Z_SHIRT=B_SHIRT,
             Z_STAIN=B_BLOOD_D, Z_HAIR=B_COAT_D)
    try:
        W, H = 110, 172
        c = Canvas(W, H, seed=5601 + ["down", "up", "side"].index(view) + (10 if lunge else 0))
        base = 164
        c.soft_shadow((24, base - 9, 88, base + 6), alpha=130, blur=4)
        if view == "side":
            lean = 8 if lunge else 4
            _zombie_side(c, base, lunge)
            hx = 52 + 8 + lean * 1.4
            _tatters(c, 40, 68, 108, 6)
            _hood(c, hx, 34, side=True)
            _burn(c, hx + 8, 38, 3.5, 2.5)
            _blood(c, 60, 74, 6, 8, drips=2)
            _blood(c, 47, 96, 4, 3, drips=1)
        else:
            front = view == "down"
            _zombie_front(c, base, front, lunge)
            _tatters(c, 36, 74, 108, 9)
            _hood(c, 58, 33, back=not front)
            if front:
                _burn(c, 52, 37, 4, 3)
                _burn(c, 64, 88, 6, 4)
                _blood(c, 50, 70, 8, 10, drips=3)
                _blood(c, 66, 100, 5, 4, drips=1)
                c.ink([(54, 41), (62, 40)], width=1.0, color=B_BLOOD_D, alpha=220)  # cracked lips
            else:
                _blood(c, 62, 76, 6, 6, drips=2)
                _burn(c, 46, 64, 7, 5)
        suffix = "_lunge" if lunge else ""
        c.save(out("characters/burnt/template_burnt_%s%s.png" % (view, suffix)), size=(W, H))
    finally:
        g.update(saved)


def burnt_dead():
    W, H = 190, 90
    c = Canvas(W, H, seed=5701)
    base = 60
    c.soft_shadow((14, base - 14, 176, base + 12), alpha=110, blur=5)
    coat = spline([(30, 40), (70, 30), (130, 32), (162, 44), (150, 62), (90, 66), (36, 60)], steps=4)
    part(c, coat, B_COAT, tex=0.4, ink=2.0, shade=(0, 1, 3.5, 80))
    _tatters(c, 40, 150, 62, 7, (4, 10))
    hood = c.blob(164, 44, 15, 13, n=14, irregular=0.1)
    part(c, hood, B_COAT_D, tex=0.4, ink=1.8)
    arm = limb([(120, 40), (150, 22), (172, 18)], [10, 8, 7])
    part(c, arm, B_SKIN_D, tex=0.3, ink=1.6)
    leg = limb([(40, 50), (16, 46), (6, 52)], [12, 10, 9])
    part(c, leg, B_COAT_D, tex=0.3, ink=1.6)
    _blood(c, 96, 48, 14, 7, drips=0)
    # blood that thawed under it and soaked the snow (Red Thaw motif, cosmetic)
    c.fill(c.blob(110, 70, 34, 8, n=14, irregular=0.4), mix(B_BLOOD, (200, 205, 207, 255), 0.25)[:3] + (180,), tex=0.2)
    c.save(out("characters/burnt/template_burnt_dead.png"), size=(W, H))


def npc_huddled():
    """The frightened survivor: sitting against a wall, knees drawn up, arms around
    them, head down, a blanket over the shoulders. Same canvas/pivot as char.npc."""
    W, H = 104, 168
    c = Canvas(W, H, seed=5801)
    base = 160
    c.soft_shadow((18, base - 10, 88, base + 6), alpha=130, blur=4)
    coat, coat_d = hexc("#4E5A64"), hexc("#34404A")   # Mara's faded blue coat
    blanket = hexc("#5E4E40")
    # feet / boots in front
    boot(c, 38, base - 1, 16)
    boot(c, 64, base - 1, 16)
    # shins rising to the knees
    for x in (40, 62):
        part(c, limb([(x, base - 10), (x + 1, 116)], [14, 15]), mix(TROUSER, coat_d, 0.3), shade=(1, 0.2, 4, 60))
    # blanket over back and shoulders, a hump behind the knees
    bl = spline([(16, 150), (14, 112), (24, 90), (52, 80), (80, 90), (90, 112), (88, 150)], steps=5)
    m = part(c, bl, blanket, tex=0.4, ink=2.1, shade=(1, 0.5, 4, 85))
    c.grime(m, 0.3, drips=False)
    for k in range(5):
        c.ink([(20 + k * 14, 96 + abs(2 - k) * 3), (18 + k * 15, 148)], width=0.9, alpha=110)
    # knees (in front of the blanket)
    for x in (40, 62):
        part(c, c.blob(x, 116, 10, 9, n=12, irregular=0.05), mix(TROUSER, coat_d, 0.3), tex=0.25, ink=1.6)
    # arms wrapped around the knees, hands clasped
    part(c, limb([(24, 104), (34, 126), (52, 128)], [12, 10, 9]), coat, shade=(0.3, 1, 4, 60))
    part(c, limb([(82, 104), (72, 126), (54, 128)], [12, 10, 9]), coat_d)
    hand(c, 53, 127, 5, SKIN)
    # head bowed onto the knees: only the top of the head and hair visible
    head = c.blob(51, 98, 13, 11, n=16, irregular=0.05)
    part(c, head, hexc("#4A3A2C"), tex=0.4, ink=2.0, shade=(0.4, 1, 3.4, 70))
    for k in range(5):
        c.ink([(42 + k * 4, 90), (40 + k * 4.5, 104)], width=0.8, alpha=120)
    c.save(out("characters/survivor/template_npc_huddled.png"), size=(W, H))


def shadow_figure():
    """A distant human silhouette for night sightings: flat ink, softened edges."""
    W, H = 104, 168
    c = Canvas(W, H, seed=5901)
    base = 160
    col = hexc("#0F0E0E")
    for x, ofs in ((46, -4), (58, 5)):
        c.fill(limb([(x, 100), (x + ofs * 0.5, 128), (x + ofs, base - 2)], [14, 11, 10]), col)
    c.fill(spline([(30, 56), (44, 46), (66, 48), (76, 58), (74, 82), (72, 104), (32, 106), (30, 82)], steps=5), col)
    c.fill(limb([(32, 58), (26, 84), (28, 108)], [11, 9, 8]), col)
    c.fill(limb([(74, 60), (80, 86), (78, 110)], [11, 9, 8]), col)
    c.fill(c.blob(56, 34, 11, 13, n=16, irregular=0.06), col)   # head, a little tilted
    c.img = c.img.filter(ImageFilter.GaussianBlur(1.4 * SS))
    c.save(out("characters/shadow/template_shadow_figure.png"), size=(W, H), finish=False, winter=False)



# ---------------------------------------------------------------- Burnt One postures (iteration 011)
# Crouched and crawling poses on the same 110x172 canvas, base line 164 and
# pivot as the upright figure, so they swap in place. Crawl has two frames
# (alternating limbs) for an awkward animal scramble.
def _bcanvas(name, seed):
    c = Canvas(110, 172, seed=seed)
    return c


def _blimb(c, path, widths, col, ink=1.8):
    return part(c, limb(path, widths), col, tex=0.32, ink=ink)


def burnt_crouch(view):
    c = _bcanvas("crouch_" + view, 5901 + ["down", "up", "side"].index(view))
    base = 164
    c.soft_shadow((22, base - 9, 90, base + 6), alpha=130, blur=4)
    if view == "side":  # facing right, knees bent, torso pitched forward, arms hanging low
        for k, (hip, knee, foot) in enumerate((((44, 118), (64, 134), (50, 160)), ((50, 118), (72, 138), (62, 161)))):
            _blimb(c, [hip, knee, foot], [15, 12, 10], B_COAT_D if k == 0 else B_COAT)
            boot(c, foot[0] + 2, base - 1, 13, facing=1)
        _blimb(c, [(58, 78), (66, 108), (70, 134)], [11, 9, 8], mix(B_SKIN_D, INK, 0.25))
        torso = spline([(36, 84), (52, 70), (74, 74), (82, 92), (70, 120), (44, 124), (36, 108)], steps=5)
        part(c, torso, B_SHIRT, tex=0.35, ink=2.1, shade=(-0.4, 1, 4, 90))
        c.grime(c.mask(torso), 0.7, drips=True, color=B_BLOOD_D)
        _tatters(c, 40, 72, 122, 6)
        _blood(c, 66, 92, 6, 7, drips=2)
        _blimb(c, [(66, 80), (74, 110), (80, 138)], [12, 10, 8], B_SKIN)
        hand(c, 81, 142, 5.2, B_SKIN)
        _hood(c, 84, 66, side=True)
        _burn(c, 90, 70, 3.5, 2.5)
    else:
        front = view == "down"
        cx = 55
        for sx in (-1, 1):
            hip, knee, foot = (cx + sx * 9, 120), (cx + sx * 20, 138), (cx + sx * 12, 160)
            _blimb(c, [hip, knee, foot], [15, 13, 10], B_COAT if (sx < 0) == front else B_COAT_D)
            boot(c, foot[0], base - 1, 13)
        torso = spline([(cx - 22, 82), (cx - 10, 72), (cx + 12, 72), (cx + 22, 82), (cx + 18, 112), (cx, 124), (cx - 18, 112)], steps=5)
        part(c, torso, B_SHIRT if front else mix(B_SHIRT, B_COAT, 0.4), tex=0.35, ink=2.1, shade=(1, 0.5, 4, 90))
        c.grime(c.mask(torso), 0.7, drips=True, color=B_BLOOD_D)
        _tatters(c, cx - 18, cx + 18, 120, 8)
        for sx in (-1, 1):
            _blimb(c, [(cx + sx * 20, 80), (cx + sx * 26, 108), (cx + sx * 24, 134)], [12, 9, 8], B_SKIN if sx < 0 else B_SKIN_D)
            hand(c, cx + sx * 24, 138, 5, B_SKIN)
        if front:
            _blood(c, cx - 4, 94, 7, 8, drips=2)
        _hood(c, cx + 2, 62, back=not front)
    suffix = view
    c.save(out("characters/burnt/template_burnt_crouch_%s.png" % suffix), size=(110, 172))


def burnt_crawl(view, frame):
    c = _bcanvas("crawl", 6001 + ["down", "up", "side"].index(view) * 3 + frame)
    base = 164
    c.soft_shadow((14, base - 12, 98, base + 6), alpha=140, blur=4)
    a = 1 if frame == 0 else -1  # which diagonal pair reaches forward
    if view == "side":  # on all fours facing right, low and long, head pushed forward
        # far limbs (darker, behind)
        _blimb(c, [(38, 128), (26 + 6 * a, 146), (36 + 10 * a, 162)], [13, 10, 9], B_COAT_D)
        _blimb(c, [(76, 126), (84 - 5 * a, 144), (90 - 8 * a, 161)], [11, 9, 8], mix(B_SKIN_D, INK, 0.3))
        body = spline([(26, 128), (40, 112), (70, 108), (90, 114), (88, 132), (60, 138), (34, 140)], steps=5)
        part(c, body, B_SHIRT, tex=0.35, ink=2.1, shade=(0, 1, 4, 90))
        c.grime(c.mask(body), 0.7, drips=True, color=B_BLOOD_D)
        _tatters(c, 30, 80, 138, 7, (5, 12))
        _blood(c, 58, 120, 7, 6, drips=1)
        # near limbs
        _blimb(c, [(44, 130), (34 - 6 * a, 148), (44 - 10 * a, 162)], [14, 11, 9], B_COAT)
        boot(c, 48 - 10 * a, base - 1, 12, facing=1)
        _blimb(c, [(80, 124), (88 + 5 * a, 142), (94 + 6 * a, 160)], [12, 10, 8], B_SKIN)
        hand(c, 96 + 6 * a, 161, 5, B_SKIN)
        _hood(c, 90, 104, side=True)
        _burn(c, 95, 108, 3.5, 2.5)
    elif view == "down":  # coming toward the viewer: head low and close, arms splayed forward
        cx = 55
        back = spline([(cx - 18, 104), (cx, 96), (cx + 18, 104), (cx + 22, 124), (cx, 132), (cx - 22, 124)], steps=5)
        part(c, back, mix(B_SHIRT, B_COAT, 0.3), tex=0.35, ink=2.0, shade=(1, 0.5, 4, 85))
        c.grime(c.mask(back), 0.6, drips=False, color=B_BLOOD_D)
        for sx in (-1, 1):  # knees behind, low
            _blimb(c, [(cx + sx * 12, 112), (cx + sx * 26, 120), (cx + sx * 30, 132)], [12, 10, 9], B_COAT_D)
        for sx in (-1, 1):
            reach = 8 * a * sx
            _blimb(c, [(cx + sx * 20, 128), (cx + sx * 34, 142 - reach), (cx + sx * 30, 160 - reach)], [12, 10, 8], B_SKIN if sx < 0 else B_SKIN_D)
            hand(c, cx + sx * 30, 162 - reach, 5.5, B_SKIN)
        _tatters(c, cx - 16, cx + 16, 130, 6, (4, 10))
        _hood(c, cx, 116)
        _blood(c, cx + 8, 138, 5, 4, drips=1)
    else:  # crawling away: hunched back and hood, soles toward the viewer
        cx = 55
        for sx in (-1, 1):
            _blimb(c, [(cx + sx * 12, 132), (cx + sx * 20, 146), (cx + sx * 16 + 4 * a * sx, 160)], [13, 11, 10], B_COAT_D)
            c.fill(c.blob(cx + sx * 16 + 4 * a * sx, 160, 7, 4, n=10, irregular=0.1), hexc("#2A221B"))
        back = spline([(cx - 22, 120), (cx - 10, 100), (cx + 10, 100), (cx + 22, 120), (cx + 16, 138), (cx - 16, 138)], steps=5)
        part(c, back, mix(B_SHIRT, B_COAT, 0.5), tex=0.35, ink=2.0, shade=(0.5, 1, 4, 85))
        _burn(c, cx - 6, 116, 7, 5)
        for sx in (-1, 1):
            _blimb(c, [(cx + sx * 18, 106), (cx + sx * 28, 96 - 6 * a * sx), (cx + sx * 26, 84 - 6 * a * sx)], [11, 9, 8], B_SKIN_D)
        _hood(c, cx, 92, back=True)
    c.save(out("characters/burnt/template_burnt_crawl_%s_%d.png" % (view, frame)), size=(110, 172))


def track_decals():
    """Signs of their presence: a boot print, a bare hand/knee print (crawling) and blood flecks."""
    from gen_homestead import out as _o
    for name, draw in (("boot", 0), ("hand", 1), ("blood", 2)):
        c = Canvas(48, 32, seed=6101 + draw)
        if draw == 0:
            for dx, dy in ((12, 20), (30, 11)):
                b = c.blob(dx, dy, 6, 4, n=12, irregular=0.1)
                c.fill(b, (120, 132, 140, 150), tex=0.2)
                c.ink(b[5:12], width=0.9, alpha=90)
        elif draw == 1:
            for dx, dy in ((12, 14), (34, 20)):
                c.fill(c.blob(dx, dy, 5, 4.5, n=10, irregular=0.15), (110, 120, 128, 150), tex=0.2)
                for k in range(4):
                    a = -2.3 + k * 0.45
                    c.ink([(dx + math.cos(a) * 5, dy + math.sin(a) * 4.5), (dx + math.cos(a) * 9, dy + math.sin(a) * 8)], width=1.3, color=(110, 120, 128), alpha=150)
        else:
            for _ in range(6):
                x, y, r = c.rng.uniform(8, 40), c.rng.uniform(8, 24), c.rng.uniform(1.2, 3.2)
                c.fill(c.blob(x, y, r, r * 0.7, n=8, irregular=0.4), (86, 22, 18, 210), tex=0.2)
        c.save(_o("characters/burnt/template_track_%s.png" % name), size=(48, 32), finish=False, winter=False)


def write_manifest():
    """Manifest for the Red Thaw figures (Burnt Ones, huddled survivor, night silhouette)."""
    import json
    from gen_homestead import ROOT
    def e(aid, name, rel, display, source, pivot):
        return {"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": display,
                "source_size": source, "pivot": pivot, "transparency": "required", "directions": "none",
                "complexity": "moderate", "status": "READY",
                "notes": "Generated placeholder (tools/art/gen_figures.py) - replace with tablet art."}
    z = ([56, 88], [110, 172], [0.5, 0.953])
    assets = [
        e("char.burnt", "Burnt One — facing down", "characters/burnt/template_burnt_down.png", *z),
        e("char.burnt_up", "Burnt One — facing up", "characters/burnt/template_burnt_up.png", *z),
        e("char.burnt_side", "Burnt One — side", "characters/burnt/template_burnt_side.png", *z),
        e("char.burnt_lunge", "Burnt One — lunging (down)", "characters/burnt/template_burnt_down_lunge.png", *z),
        e("char.burnt_side_lunge", "Burnt One — lunging (side)", "characters/burnt/template_burnt_side_lunge.png", *z),
        e("char.burnt_dead", "Burnt One — fallen", "characters/burnt/template_burnt_dead.png", [95, 45], [190, 90], [0.5, 0.67]),
        e("char.npc_huddled", "Frightened survivor — huddled", "characters/survivor/template_npc_huddled.png", [52, 84], [104, 168], [0.5, 0.9524]),
        e("char.shadow_figure", "Night silhouette (distant human shape)", "characters/shadow/template_shadow_figure.png", [52, 84], [104, 168], [0.5, 0.9524]),
    ]
    for v in ("down", "up", "side"):
        assets.append(e("char.burnt_crouch_" + v, "Burnt One — crouched (%s)" % v, "characters/burnt/template_burnt_crouch_%s.png" % v, *z))
    for v, frames in (("down", 2), ("up", 2), ("side", 2)):
        for f in range(frames):
            assets.append(e("char.burnt_crawl_%s_%d" % (v, f), "Burnt One — crawling (%s, frame %d)" % (v, f + 1),
                            "characters/burnt/template_burnt_crawl_%s_%d.png" % (v, f), *z))
    for t in ("boot", "hand", "blood"):
        assets.append(e("fx.track_" + t, "Track decal — %s" % t, "characters/burnt/template_track_%s.png" % t, [24, 16], [48, 32], [0.5, 0.5]))
    with open(os.path.join(ROOT, "assets", "manifest", "visual_burnt.json"), "w") as f:
        json.dump({"kind": "visual", "category": "burnt", "assets": assets}, f, indent="\t"); f.write("\n")


if __name__ == "__main__":
    for v in ("down", "up", "side"):
        survivor(v); zombie(v)
    zombie("down", True); zombie("side", True)
    for v in ("down", "up", "side"):
        burnt(v)
    burnt("down", True); burnt("side", True); burnt_dead()
    npc_huddled(); shadow_figure()
    for v in ("down", "up", "side"):
        burnt_crouch(v)
        for f in (0, 1):
            burnt_crawl(v, f)
    track_decals()
    write_manifest()
    print("figures generated")
