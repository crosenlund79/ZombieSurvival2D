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
from inkkit import Canvas, hexc, mix, INK
from gen_homestead import out

SKIN, SKIN_D = hexc("#C09676"), hexc("#8E6A4E")
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
JACKET, JACKET_D, JACKET_L = hexc("#5A6034"), hexc("#3D4224"), hexc("#7A7E46")
TROUSER, TROUSER_D = hexc("#4A4236"), hexc("#322B23")
PACK, PACK_D = hexc("#76644A"), hexc("#504330")
SCARF, SCARF_D = hexc("#7A4632"), hexc("#55301F")
HAIR, BEARD, CAP = hexc("#3A2A1D"), hexc("#4A3426"), hexc("#4E4A3C")


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


if __name__ == "__main__":
    for v in ("down", "up", "side"):
        survivor(v); zombie(v)
    zombie("down", True); zombie("side", True)
    print("figures generated")
