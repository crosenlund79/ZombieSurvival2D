#!/usr/bin/env python3
"""Generates the Phase B homestead placeholder illustrations (templates).

Run from the repository root:  python3 tools/art/gen_homestead.py
Output: assets/templates/... (template_ prefix). Never touches assets/overrides/.
These are generated stand-ins for the creator's tablet artwork, drawn at
~2x display size in the approved palette (docs/visual_direction/).
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, value_noise, INK, SS

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Palette (docs/visual_direction/README.md, sampled + greens for living grass)
OLIVE_D, OLIVE, KHAKI, STRAW, STRAW2, GREYGREEN = map(hexc, ["#52502C", "#7A733F", "#998A57", "#CFB88D", "#B3A177", "#827D68"])
WOOD, WOOD_L, WOOD_M, RUST, RUST_D, STONE = map(hexc, ["#7B5538", "#C69464", "#BF8354", "#954C33", "#6A372C", "#61615E"])
GRASS, GRASS_L, GRASS_D, LEAF, LEAF_D, LEAF_L = map(hexc, ["#6F7A3C", "#93984E", "#4E5A2C", "#667538", "#3F4A25", "#9AA052"])
AMBER = hexc("#F2B347")
STEEL = hexc("#4D5246")
CONCRETE = hexc("#8C877C")
PAINT = hexc("#C9BC9A")
SLATE = hexc("#4F4A42")
GLASS = hexc("#2A302E")


def out(rel):
    assert "overrides" not in rel
    p = os.path.join(ROOT, "assets", "templates", rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def grass_fringe(c, x0, x1, y, density=0.5, h=(10, 22), colors=None, seed_shift=0):
    colors = colors or [GRASS_D, GRASS, GRASS_L, OLIVE]
    x = x0
    while x < x1:
        hh = c.rng.uniform(*h)
        col = c.rng.choice(colors)
        lean = c.rng.uniform(-6, 6)
        c.ink([(x, y), (x + lean * 0.5, y - hh * 0.6), (x + lean, y - hh)], width=c.rng.uniform(1.6, 2.6),
              color=col, wobble=0.3, alpha=245, seg=4)
        x += c.rng.uniform(2, 6) / max(density, 0.05)


def tuft(c, cx, by, w, h, colors=None, n=None):
    """Loose clump of tapered blades with irregular heights (not a solid mat)."""
    colors = colors or [GRASS_D, GRASS, GRASS_L, OLIVE, KHAKI]
    n = n or max(5, int(w / 6))
    for i in range(n):
        x = cx + c.rng.gauss(0, w / 5)
        x = min(max(x, cx - w / 2), cx + w / 2)
        hh = h * c.rng.uniform(0.35, 1.0) * (1 - 0.6 * abs(x - cx) / (w / 2))
        lean = (x - cx) * 0.45 + c.rng.uniform(-6, 6)
        col = c.rng.choice(colors)
        wid = c.rng.uniform(1.7, 2.7)
        c.ink([(x, by), (x + lean * 0.35, by - hh * 0.5)], width=wid, color=col, wobble=0.2, seg=4)
        c.ink([(x + lean * 0.35, by - hh * 0.5), (x + lean, by - hh)], width=wid * 0.6, color=col, wobble=0.2, seg=4)


def fade_base(c, rows=10):
    """Fade the bottom rows so plant bases melt into the ground texture."""
    a = np.asarray(c.img).copy()
    H = a.shape[0]
    r = rows * SS
    ramp = np.linspace(1.0, 0.35, r)[:, None]
    a[H - r:, :, 3] = (a[H - r:, :, 3] * ramp).astype(np.uint8)
    c.img = Image.fromarray(a, "RGBA")


# ------------------------------------------------------------------ farmhouse
def farmhouse():
    W, H = 880, 820
    c = Canvas(W, H, seed=11)
    base = 790
    c.soft_shadow((60, base - 40, 860, base + 24), alpha=110, blur=14)
    fx0, fx1, ftop = 120, 760, 470          # facade
    # facade boards
    facade = [(fx0, ftop), (fx1, ftop), (fx1, base), (fx0, base)]
    m = c.fill(facade, PAINT, tex=0.22, cell=40, light=(-0.6, 0, 0.25))
    for y in range(ftop + 18, base, 22):
        c.ink([(fx0 + 4, y), (fx1 - 4, y + c.rng.uniform(-1.5, 1.5))], width=1.1, alpha=110, wobble=0.6)
    # weathering: grime streaks from the top + peeling patches
    for _ in range(14):
        x = c.rng.uniform(fx0 + 10, fx1 - 10)
        c.ink([(x, ftop + 4), (x + c.rng.uniform(-3, 3), ftop + c.rng.uniform(40, 140))],
              width=c.rng.uniform(3, 7), color=GREYGREEN, alpha=70, wobble=1.5)
    c.hatch(c.mask([(fx0, ftop), (fx1, ftop), (fx1, ftop + 46), (fx0, ftop + 46)]), spacing=5, angle=-35, alpha=70)
    c.hatch(c.mask([(fx1 - 90, ftop), (fx1, ftop), (fx1, base), (fx1 - 60, base)]), spacing=6, angle=-60, alpha=55)
    c.ink_poly(facade, width=3.2)
    # stone foundation
    found = [(fx0 - 6, base - 34), (fx1 + 6, base - 34), (fx1 + 6, base), (fx0 - 6, base)]
    c.fill(found, STONE, tex=0.3, cell=10)
    for x in range(fx0, fx1, 34):
        c.ink([(x + c.rng.uniform(-4, 4), base - 33), (x + c.rng.uniform(-4, 4), base - 2)], width=1.2, alpha=150)
    c.ink([(fx0 - 6, base - 17), (fx1 + 6, base - 17)], width=1.0, alpha=120)
    c.ink_poly(found, width=2.6)
    # roof (front slope seen from above), overhanging the facade
    rx0, rx1, rtop = 70, 810, 110
    roof = [(rx0 + 70, rtop), (rx1 - 70, rtop), (rx1, ftop + 20), (rx0, ftop + 20)]
    rm = c.fill(roof, SLATE, tex=0.25, cell=30, light=(-0.4, -0.8, 0.35))
    # shingle rows
    for i, y in enumerate(range(rtop + 22, ftop + 20, 24)):
        t = (y - rtop) / (ftop + 20 - rtop)
        xl = rx0 + 70 - 70 * t; xr = rx1 - 70 + 70 * t
        c.ink([(xl + 4, y), (xr - 4, y + c.rng.uniform(-2, 2))], width=1.4, alpha=150)
        off = (i % 2) * 14
        x = xl + 10 + off
        while x < xr - 10:
            c.ink([(x, y), (x + c.rng.uniform(-1, 1), y - 20)], width=1.0, alpha=95, seg=10)
            x += 28
    # missing shingles / moss
    for _ in range(9):
        hx = c.rng.uniform(rx0 + 120, rx1 - 120); hy = c.rng.uniform(rtop + 40, ftop - 30)
        hole = c.blob(hx, hy, c.rng.uniform(12, 26), c.rng.uniform(7, 12), n=9)
        c.fill(hole, hexc("#2C2722"), tex=0.2)
        c.ink_poly(hole, width=1.4, alpha=200)
    for _ in range(7):
        mx = c.rng.uniform(rx0 + 90, rx1 - 90); my = c.rng.uniform(rtop + 30, ftop)
        mb = c.blob(mx, my, c.rng.uniform(18, 40), c.rng.uniform(8, 14), n=12, irregular=0.35)
        c.fill(mb, mix(LEAF, OLIVE, 0.4), tex=0.35, cell=6)
    c.hatch(c.mask(roof), spacing=7, angle=-20, alpha=45)
    c.ink_poly(roof, width=3.4)
    c.ink([(rx0 + 70, rtop), (rx1 - 70, rtop)], width=4.5)  # ridge
    # chimney
    ch = [(600, 40), (660, 40), (660, 190), (600, 200)]
    c.fill(ch, RUST, tex=0.3, cell=8, light=(-1, 0, 0.3))
    for y in range(52, 195, 16):
        c.ink([(601, y), (659, y)], width=1.0, alpha=140)
    c.ink_poly(ch, width=2.6)
    c.fill([(592, 30), (668, 30), (668, 44), (592, 44)], STONE)
    c.ink_poly([(592, 30), (668, 30), (668, 44), (592, 44)], width=2.2)
    # windows: (x, broken, boarded)
    def window(x, y, w, h, broken=False, boarded=False):
        frame = [(x - 8, y - 8), (x + w + 8, y - 8), (x + w + 8, y + h + 10), (x - 8, y + h + 10)]
        c.fill(frame, mix(PAINT, WOOD_L, 0.4), tex=0.2)
        glass = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
        c.fill(glass, GLASS, tex=0.25, light=(1, 1, 0.5))
        if broken:
            sh = [(x + w * 0.2, y), (x + w * 0.55, y + h * 0.45), (x + w * 0.35, y + h * 0.8), (x + w * 0.7, y + h)]
            c.ink(sh, width=1.4, color=hexc("#9FA59A"), alpha=200)
            c.ink([(x + w, y + h * 0.3), (x + w * 0.6, y + h * 0.5)], width=1.2, color=hexc("#9FA59A"), alpha=180)
        else:
            c.ink([(x + 6, y + h - 8), (x + w * 0.4, y + 8)], width=2.2, color=hexc("#6F7772"), alpha=140)
        c.ink([(x + w / 2, y), (x + w / 2, y + h)], width=2.4, color=mix(PAINT, WOOD_L, 0.4), alpha=255)
        c.ink([(x, y + h / 2), (x + w, y + h / 2)], width=2.4, color=mix(PAINT, WOOD_L, 0.4), alpha=255)
        c.ink_poly(glass, width=2.0)
        c.ink_poly(frame, width=2.4)
        if boarded:
            for i, yy in enumerate([y + h * 0.2, y + h * 0.65]):
                b = [(x - 16, yy - 9 + i * 6), (x + w + 16, yy - 3 - i * 4), (x + w + 16, yy + 9 - i * 4), (x - 16, yy + 5 + i * 6)]
                c.fill(b, WOOD_M, tex=0.3, cell=6)
                c.ink_poly(b, width=1.8)
    window(170, 560, 90, 120, broken=True)
    window(300, 560, 90, 120, boarded=True)
    window(560, 560, 90, 120)
    window(680, 575, 54, 100, broken=True)
    # porch roof + posts (door sits at x≈460, handled by DoorView sprite)
    pr = [(390, 505), (590, 505), (615, 560), (365, 560)]
    c.fill(pr, mix(SLATE, RUST_D, 0.3), tex=0.3, light=(0, -1, 0.3))
    c.ink_poly(pr, width=2.6)
    for px in (378, 600):
        post = [(px - 6, 560), (px + 6, 560), (px + 6, base - 30), (px - 6, base - 30)]
        c.fill(post, WOOD_L, tex=0.3)
        c.ink_poly(post, width=2.0)
    # porch steps
    st = [(400, base - 34), (560, base - 34), (572, base + 4), (388, base + 4)]
    c.fill(st, mix(WOOD, STONE, 0.4), tex=0.35)
    c.ink([(394, base - 15), (566, base - 15)], width=1.6)
    c.ink_poly(st, width=2.4)
    # door opening frame (dark recess drawn here so open door shows interior)
    dfr = [(420, 590), (500, 590), (500, base - 34), (420, base - 34)]
    c.fill(dfr, hexc("#1E1B17"), tex=0.2)
    c.ink_poly(dfr, width=2.4)
    # ivy climbing the left side
    for i in range(60):
        x = fx0 + c.rng.uniform(-10, 110) * (1 - i / 80)
        y = base - 40 - c.rng.uniform(0, 1) ** 0.7 * 300
        lb = c.blob(x, y, c.rng.uniform(8, 16), c.rng.uniform(6, 12), n=8, irregular=0.4)
        c.fill(lb, c.rng.choice([LEAF, LEAF_D, LEAF_L, OLIVE]), tex=0.25, cell=4)
        c.ink_poly(lb, width=1.1, alpha=170)
    c.ink([(fx0 + 20, base - 30), (fx0 + 40, base - 160), (fx0 + 25, base - 290)], width=2.2, color=WOOD, alpha=200)
    # base grass and weeds
    grass_fringe(c, 40, 850, base + 6, density=0.55, h=(12, 34))
    for x in (90, 250, 700, 820):
        tuft(c, x, base + 8, 50, 46)
    return c.save(out("world/buildings/template_farmhouse.png"))


# ------------------------------------------------------------------ house door
def house_door(open_):
    # Matches the door opening in the farmhouse art (80 x 166 source px).
    W, H = 80, 166
    c = Canvas(W, H, seed=21 + open_)
    d = [(3, 3), (77, 3), (77, H - 3), (3, H - 3)]
    if open_:
        c.fill(d, hexc("#16130F"), tex=0.15)
        c.hatch(c.mask(d), spacing=4, angle=-60, alpha=70)
        leaf = [(3, 3), (22, 10), (22, H - 8), (3, H - 3)]
        c.fill(leaf, mix(RUST_D, WOOD, 0.4), tex=0.25, light=(1, 0, 0.3))
        c.ink_poly(leaf, width=1.8)
        c.ink_poly(d, width=2.2)
    else:
        c.fill(d, mix(RUST_D, WOOD, 0.45), tex=0.3, cell=8, light=(-1, -0.5, 0.3))
        for x in (24, 44, 60):
            c.ink([(x, 8), (x, H - 8)], width=1.1, alpha=120)
        for box in ([(12, 14), (68, 14), (68, 72), (12, 72)], [(12, 88), (68, 88), (68, H - 14), (12, H - 14)]):
            c.ink_poly(box, width=1.6, alpha=170)
        c.ellipse_fill((58, 82, 66, 90), hexc("#B59A5A"))
        for _ in range(6):  # peeling paint flakes
            px_, py_ = c.rng.uniform(10, 70), c.rng.uniform(10, H - 10)
            c.fill(c.blob(px_, py_, c.rng.uniform(2, 5), c.rng.uniform(3, 7), n=8, irregular=0.4), PAINT, tex=0.1)
        c.ink_poly(d, width=2.4)
    return c.save(out(f"world/doors/template_house_door_{'open' if open_ else 'closed'}.png"))


# ------------------------------------------------------------------ fence & gate
def post(c, x, top, bottom, w=12):
    p = [(x - w / 2, top), (x + w / 2, top + 2), (x + w / 2, bottom), (x - w / 2, bottom)]
    c.fill(p, mix(WOOD, GREYGREEN, 0.35), tex=0.35, cell=6, light=(-1, 0, 0.3))
    c.ink_poly(p, width=2.0)


def rail(c, x0, x1, y, h=10, broken=False):
    if broken:
        mid = (x0 + x1) / 2
        r1 = [(x0, y), (mid - 6, y + 2), (mid - 2, y + h + 6), (x0, y + h)]
        c.fill(r1, mix(WOOD_L, GREYGREEN, 0.4), tex=0.3); c.ink_poly(r1, width=1.8)
        r2 = [(mid + 10, y + 26), (x1, y + 2), (x1, y + h + 2), (mid + 12, y + 36)]
        c.fill(r2, mix(WOOD_L, GREYGREEN, 0.4), tex=0.3); c.ink_poly(r2, width=1.8)
        return
    r = [(x0, y + c.rng.uniform(-1, 1)), (x1, y + c.rng.uniform(-1, 1)), (x1, y + h), (x0, y + h)]
    c.fill(r, mix(WOOD_L, GREYGREEN, 0.4), tex=0.3, cell=8, light=(0, -1, 0.3))
    for _ in range(3):
        xx = c.rng.uniform(x0 + 6, x1 - 6)
        c.ink([(xx, y + 2), (xx + c.rng.uniform(6, 16), y + h - 2)], width=0.9, alpha=110)
    c.ink_poly(r, width=1.8)


def fence_h(variant):
    W, H = 256, 112
    c = Canvas(W, H, seed=31 + variant)
    c.soft_shadow((0, 96, 256, 112), alpha=70, blur=4)
    rail(c, 0, 256, 34, broken=False)
    rail(c, 0, 256, 66, broken=(variant == 1))
    post(c, 10, 18, 104)
    post(c, 138, 20, 104)
    grass_fringe(c, 0, 256, 108, density=0.45, h=(8, 26))
    return c.save(out(f"world/fences/template_fence_h_{'a' if variant == 0 else 'b'}.png"))


def fence_v():
    W, H = 48, 256
    c = Canvas(W, H, seed=37)
    c.soft_shadow((10, 230, 44, 252), alpha=60, blur=4)
    # rails seen end-on recede upward: two long thin rails
    for x in (18, 30):
        r = [(x - 3, 8), (x + 3, 8), (x + 3, 236), (x - 3, 236)]
        c.fill(r, mix(WOOD_L, GREYGREEN, 0.4), tex=0.3)
        c.ink_poly(r, width=1.5)
    post(c, 24, 0, 40, w=14)
    post(c, 24, 120, 170, w=14)
    post(c, 24, 200, 246, w=14)
    grass_fringe(c, 6, 44, 250, density=0.6, h=(8, 20))
    return c.save(out("world/fences/template_fence_v.png"))


def gate(open_):
    W, H = 256, 120
    c = Canvas(W, H, seed=41 + open_)
    c.soft_shadow((0, 102, 256, 120), alpha=70, blur=4)
    if open_:
        # gate swung toward the viewer, hinged on the left post: foreshortened
        g = [(16, 30), (64, 52), (64, 118), (16, 104)]
        c.fill(g, mix(WOOD_L, GREYGREEN, 0.3), tex=0.3, light=(1, 0, 0.3))
        for t in (0.25, 0.75):
            c.ink([(16, 30 + 74 * t), (64, 52 + 66 * t)], width=2.0)
        c.ink([(16, 104), (64, 52)], width=2.4)
        c.ink_poly(g, width=2.2)
    else:
        for y in (34, 58, 82):
            rail(c, 20, 236, y, h=10)
        c.ink([(24, 92), (232, 38)], width=3.2, color=mix(WOOD, INK, 0.3))  # brace
        b = [(24, 92), (30, 96), (236, 42), (230, 36)]
        c.fill(b, mix(WOOD_L, GREYGREEN, 0.3), tex=0.3); c.ink_poly(b, width=1.6)
        c.ellipse_fill((222, 56, 236, 70), hexc("#7D6E58"))
    post(c, 12, 14, 112, w=16)
    post(c, 244, 14, 112, w=16)
    grass_fringe(c, 0, 30, 116, density=0.5); grass_fringe(c, 226, 256, 116, density=0.5)
    return c.save(out(f"world/doors/template_gate_{'open' if open_ else 'closed'}.png"))


# ------------------------------------------------------------------ shed
def shed():
    W, H = 400, 380
    c = Canvas(W, H, seed=51)
    base = 356
    c.soft_shadow((20, base - 20, 392, base + 16), alpha=100, blur=10)
    fx0, fx1, ftop = 50, 350, 200
    f = [(fx0, ftop), (fx1, ftop), (fx1, base), (fx0, base)]
    c.fill(f, mix(WOOD, GREYGREEN, 0.25), tex=0.3, cell=10, light=(-1, 0, 0.25))
    x = fx0 + 18
    while x < fx1:
        c.ink([(x, ftop + 4), (x + c.rng.uniform(-1.5, 1.5), base - 2)], width=1.3, alpha=150)
        x += c.rng.uniform(18, 26)
    c.hatch(c.mask([(fx0, ftop), (fx1, ftop), (fx1, ftop + 40), (fx0, ftop + 40)]), spacing=5, alpha=70)
    # door ajar
    d = [(170, 250), (240, 250), (240, base), (170, base)]
    c.fill(d, hexc("#1A1714"), tex=0.2)
    leaf = [(240, 250), (262, 256), (262, base + 2), (240, base)]
    c.fill(leaf, mix(WOOD, GREYGREEN, 0.4), tex=0.3); c.ink_poly(leaf, width=1.8)
    c.ink_poly(d, width=2.2)
    c.ink_poly(f, width=3.0)
    # corrugated rusty roof
    roof = [(30, 70), (370, 70), (390, 218), (10, 218)]
    c.fill(roof, mix(RUST, STONE, 0.35), tex=0.35, cell=14, light=(-0.5, -1, 0.35))
    for i in range(0, 380, 16):
        t = i / 380
        c.ink([(30 + 340 * t, 72), (10 + 380 * t, 216)], width=1.2, alpha=120, seg=10)
    for _ in range(10):
        bx, by = c.rng.uniform(40, 360), c.rng.uniform(90, 200)
        c.fill(c.blob(bx, by, c.rng.uniform(8, 22), c.rng.uniform(6, 14), n=9), RUST_D, tex=0.4, cell=4)
    c.ink_poly(roof, width=3.0)
    # window (small, dirty)
    w = [(80, 240), (130, 240), (130, 285), (80, 285)]
    c.fill(w, GLASS, tex=0.3); c.ink([(105, 240), (105, 285)], width=2, color=WOOD_L); c.ink_poly(w, width=2)
    # leaning tools / plank
    c.ink([(300, base - 4), (322, 236)], width=5, color=WOOD_L); c.ink([(300, base - 4), (322, 236)], width=1.2)
    grass_fringe(c, 20, 390, base + 6, density=0.6, h=(12, 32))
    tuft(c, 40, base + 8, 46, 40); tuft(c, 360, base + 8, 40, 36)
    return c.save(out("world/buildings/template_shed.png"))


# ------------------------------------------------------------------ trees & plants
def canopy(c, cx, cy, rx, ry, palette, clusters=22, seed_y=0):
    """Clustered leaf masses: dark underside, mid body, light top-left, scalloped ink edges."""
    dark, mid, light = palette
    pts = []
    for i in range(int(clusters * 1.8)):
        a = c.rng.uniform(0, 6.283); r = c.rng.uniform(0, 1) ** 0.55
        pts.append((cx + math.cos(a) * rx * r * 0.82, cy + math.sin(a) * ry * r * 0.8, c.rng.uniform(0.2, 0.34)))
    pts.sort(key=lambda p: p[1])
    shadow_mass = scallop(c, cx, cy + ry * 0.08, rx * 0.97, ry * 0.9, lobes=15)
    c.fill(shadow_mass, mix(dark, INK, 0.25), tex=0.3, cell=10)
    for x, y, s_ in pts:
        b = scallop(c, x, y, rx * s_, ry * s_ * 0.85)
        t = (y - (cy - ry)) / (2 * ry)
        side = (x - cx) / rx
        k = min(1, max(0, t * 1.25 + side * 0.35 - 0.1))
        col = mix(light, mid, k) if k < 0.6 else mix(mid, dark, (k - 0.6) * 1.6)
        m = c.fill(b, col, tex=0.22, cell=6, light=(-0.6, -0.9, 0.35))
        if k > 0.55:
            c.hatch(m, spacing=4, angle=-55, alpha=55)
        c.ink(b[int(len(b) * 0.05):int(len(b) * 0.62)], width=1.3, alpha=150, seg=4)
    full = c.mask(ellipse=(cx - rx * 0.9, cy - ry * 0.9, cx + rx * 0.9, cy + ry * 0.7))
    c.speckle(full, int(rx * ry / 90), light, size=(1.5, 3.5), alpha=(110, 200))
    n_ = len(shadow_mass)
    c.ink(shadow_mass[int(n_ * 0.05):int(n_ * 0.5)], width=2.0, alpha=190, seg=4)


def scallop(c, cx, cy, rx, ry, lobes=None):
    """Leaf-cluster outline made of small rounded lobes."""
    lobes = lobes or c.rng.randint(6, 9)
    pts = []
    ph = c.rng.uniform(0, 6.28)
    for i in range(lobes * 6):
        a = i / (lobes * 6) * 6.283
        bump = abs(math.sin((a + ph) * lobes / 2)) * 0.18
        r = 0.88 + bump + c.rng.uniform(-0.03, 0.03)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    return pts


def tree_oak(variant=0):
    W, H = 600, 720
    c = Canvas(W, H, seed=61 + variant)
    base = 690
    c.soft_shadow((150, base - 40, 520, base + 26), alpha=110, blur=16)
    # trunk + roots
    tr = [(272, base), (258, 500), (246, 400), (300, 380), (352, 400), (340, 500), (330, base)]
    c.fill(tr, mix(WOOD, STONE, 0.35), tex=0.35, cell=8, light=(-1, 0, 0.4))
    c.hatch(c.mask([(305, 380), (352, 400), (340, 500), (330, base), (305, base)]), spacing=5, angle=-80, alpha=90)
    for _ in range(9):
        x = c.rng.uniform(262, 338)
        c.ink([(x, base - 6), (x + c.rng.uniform(-6, 6), c.rng.uniform(420, 600))], width=1.2, alpha=120)
    c.ink_poly(tr, width=2.8)
    for dx in (-40, 46):
        root = [(300 + dx * 0.3, base - 20), (300 + dx, base + 4), (300 + dx * 0.2, base + 2)]
        c.fill(root, mix(WOOD, STONE, 0.35)); c.ink(root, width=2.2)
    # branches into canopy
    for (x0, y0, x1, y1) in [(290, 420, 190, 300), (310, 410, 420, 280), (300, 400, 305, 230)]:
        c.ink([(x0, y0), ((x0 + x1) / 2 + c.rng.uniform(-10, 10), (y0 + y1) / 2), (x1, y1)], width=9, color=mix(WOOD, STONE, 0.35))
        c.ink([(x0, y0), ((x0 + x1) / 2, (y0 + y1) / 2), (x1, y1)], width=1.6)
    canopy(c, 300, 260, 270, 220, (LEAF_D, LEAF, LEAF_L), clusters=26 if variant == 0 else 20)
    tuft(c, 250, base + 6, 70, 40); tuft(c, 360, base + 6, 60, 36)
    return c.save(out(f"env/trees/template_oak_{'a' if variant == 0 else 'b'}.png"))


def tree_birch():
    W, H = 340, 620
    c = Canvas(W, H, seed=71)
    base = 596
    c.soft_shadow((90, base - 24, 300, base + 18), alpha=90, blur=12)
    tr = [(160, base), (156, 200), (170, 120), (184, 200), (182, base)]
    c.fill(tr, hexc("#D9D3C2"), tex=0.15, light=(-1, 0, 0.3))
    for _ in range(18):
        y = c.rng.uniform(150, base - 10)
        c.ink([(158, y), (158 + c.rng.uniform(8, 22), y + c.rng.uniform(-2, 2))], width=c.rng.uniform(1.5, 3.5), alpha=220)
    c.ink_poly(tr, width=2.2)
    c.ink([(170, 300), (110, 230)], width=4, color=hexc("#D9D3C2")); c.ink([(170, 300), (110, 230)], width=1.2)
    canopy(c, 170, 200, 140, 170, (mix(LEAF_D, OLIVE, 0.3), mix(LEAF, KHAKI, 0.25), mix(LEAF_L, STRAW, 0.25)), clusters=18)
    tuft(c, 170, base + 4, 60, 34)
    return c.save(out("env/trees/template_birch.png"))


def shrub(variant):
    W, H = (220, 160) if variant == 0 else (180, 140)
    c = Canvas(W, H, seed=81 + variant)
    base = H - 14
    c.soft_shadow((14, base - 18, W - 10, base + 10), alpha=90, blur=8)
    canopy(c, W / 2, base - H * 0.32, W * 0.44, H * 0.34,
           (LEAF_D, mix(LEAF, OLIVE, 0.3 * variant), LEAF_L), clusters=12)
    if variant == 1:  # pink wildflower shrub (moodboard)
        for _ in range(26):
            x, y = c.rng.uniform(30, W - 30), c.rng.uniform(base - H * 0.6, base - 10)
            r = c.rng.uniform(2.5, 4.5)
            c.ellipse_fill((x - r, y - r, x + r, y + r), c.rng.choice([hexc("#D79AA6"), hexc("#E8C9C9"), hexc("#C77D8E")]), tex=0.1)
    tuft(c, W / 2, base + 4, W * 0.8, 30)
    return c.save(out(f"env/plants/template_shrub_{'a' if variant == 0 else 'b'}.png"))


def tall_grass(variant):
    W, H = 160, 100
    c = Canvas(W, H, seed=91 + variant)
    cols = [GRASS_D, GRASS, GRASS_L, KHAKI, STRAW2] if variant else [GRASS_D, GRASS, GRASS_L, OLIVE]
    for k in range(3):  # three loose clumps
        tuft(c, W * (0.28 + 0.22 * k) + c.rng.uniform(-8, 8), H - 6, W * 0.42, H * c.rng.uniform(0.6, 0.9), colors=cols, n=15)
    fade_base(c, 8)
    if variant == 2:
        for _ in range(12):
            x, y = c.rng.uniform(20, W - 20), c.rng.uniform(20, H - 30)
            c.ellipse_fill((x - 3, y - 3, x + 3, y + 3), c.rng.choice([hexc("#E9E2C8"), hexc("#D79AA6"), hexc("#E3C15A")]))
    return c.save(out(f"env/plants/template_grass_{'abc'[variant]}.png"))


# ------------------------------------------------------------------ props
def car():
    W, H = 460, 240
    c = Canvas(W, H, seed=101)
    base = 214
    c.soft_shadow((20, base - 26, 450, base + 14), alpha=120, blur=10)
    body = [(24, 150), (60, 120), (130, 112), (170, 66), (300, 62), (350, 112), (430, 122), (446, 150), (440, 190), (30, 192)]
    paint = mix(RUST, STONE, 0.3)
    m = c.fill(body, paint, tex=0.3, cell=16, light=(-0.4, -1, 0.4))
    for _ in range(12):  # rust patches
        bx, by = c.rng.uniform(50, 420), c.rng.uniform(120, 185)
        c.fill(c.blob(bx, by, c.rng.uniform(8, 26), c.rng.uniform(5, 14), n=10, irregular=0.4), RUST_D, tex=0.45, cell=4)
    c.hatch(c.mask([(24, 165), (446, 165), (440, 192), (30, 192)]), spacing=5, angle=-60, alpha=80)
    # windows
    for win in ([(182, 76), (236, 74), (236, 114), (150, 116)], [(246, 74), (294, 74), (336, 114), (246, 114)]):
        c.fill(win, GLASS, tex=0.25, light=(1, 1, 0.4))
        c.ink_poly(win, width=2.0)
    c.ink([(262, 80), (290, 108), (275, 95), (300, 84)], width=1.2, color=hexc("#9FA59A"))  # crack
    c.ink([(240, 118), (240, 186)], width=1.6, alpha=170)   # door line
    c.ink([(140, 118), (140, 186)], width=1.4, alpha=150)
    c.ink([(350, 120), (350, 186)], width=1.4, alpha=150)
    c.ink_poly(body, width=3.0)
    # bumpers & lights
    c.fill([(430, 150), (450, 150), (450, 170), (430, 170)], STONE); c.ink_poly([(430, 150), (450, 150), (450, 170), (430, 170)], width=1.6)
    c.ellipse_fill((418, 128, 438, 144), hexc("#CBBE8E")); c.ink_poly(c.blob(428, 136, 10, 8, n=10, irregular=0), width=1.5)
    # flat tyres
    for wx in (110, 360):
        c.ellipse_fill((wx - 40, 158, wx + 40, 222), hexc("#2A2724"), tex=0.2)
        c.ink_poly(c.blob(wx, 194, 40, 28, n=16, irregular=0.03), width=2.6)
        c.ellipse_fill((wx - 16, 178, wx + 16, 206), STONE)
        c.ink_poly(c.blob(wx, 192, 16, 13, n=12, irregular=0.05), width=1.6)
    # vines over the hood, grass at the wheels
    for i in range(26):
        x = c.rng.uniform(30, 150); y = c.rng.uniform(112, 175)
        lb = c.blob(x, y, c.rng.uniform(6, 12), c.rng.uniform(5, 9), n=8, irregular=0.4)
        c.fill(lb, c.rng.choice([LEAF, LEAF_D, LEAF_L]), tex=0.25, cell=4); c.ink_poly(lb, width=1.0, alpha=160)
    grass_fringe(c, 20, 450, base + 8, density=0.7, h=(10, 36))
    tuft(c, 110, base + 10, 70, 48); tuft(c, 360, base + 10, 70, 44)
    return c.save(out("props/vehicles/template_sedan.png"))


def bunker_hatch():
    W, H = 460, 320
    c = Canvas(W, H, seed=111)
    base = 292
    c.soft_shadow((20, base - 40, 450, base + 18), alpha=110, blur=12)
    # grassy earth mound
    mound = c.blob(230, 210, 210, 92, n=18, irregular=0.08)
    m = c.fill(mound, mix(GRASS, OLIVE, 0.35), tex=0.3, cell=14, light=(-0.6, -1, 0.35))
    c.hatch(c.mask([(20, 230), (450, 230), (450, 310), (20, 310)]), spacing=6, alpha=60)
    c.ink(mound[1:10], width=2.4, alpha=200)
    # concrete bulkhead frame (slanted, facing the viewer)
    frame = [(130, 120), (330, 120), (356, 262), (104, 262)]
    c.fill(frame, CONCRETE, tex=0.3, cell=10, light=(-1, -0.6, 0.3))
    for _ in range(8):  # stains & cracks
        x = c.rng.uniform(120, 340)
        c.ink([(x, 124), (x + c.rng.uniform(-6, 6), c.rng.uniform(150, 255))], width=c.rng.uniform(2, 6), color=GREYGREEN, alpha=80, wobble=1.4)
    c.ink([(150, 140), (170, 170), (160, 190)], width=1.3)
    c.ink_poly(frame, width=3.0)
    # steel hatch doors
    hatch = [(150, 136), (310, 136), (330, 250), (130, 250)]
    c.fill(hatch, STEEL, tex=0.3, cell=12, light=(-0.6, -1, 0.4))
    c.ink([(230, 136), (230, 250)], width=2.4)
    for _ in range(10):
        x = c.rng.uniform(140, 320)
        c.ink([(x, 140), (x + c.rng.uniform(-3, 3), c.rng.uniform(170, 245))], width=c.rng.uniform(1.5, 4), color=RUST, alpha=110, wobble=1.2)
    for (x, y) in [(160, 146), (300, 146), (146, 238), (316, 238), (214, 146), (246, 146)]:
        c.ellipse_fill((x - 3, y - 3, x + 3, y + 3), hexc("#2A2C27"))
    # wheel handle
    c.ink_poly(c.blob(230, 196, 26, 17, n=16, irregular=0.02), width=3.4, color=hexc("#2F322C"))
    c.ink([(204, 196), (256, 196)], width=2.4, color=hexc("#2F322C")); c.ink([(230, 179), (230, 213)], width=2.4, color=hexc("#2F322C"))
    c.ink_poly(hatch, width=2.8)
    # vent pipe + warm practical lamp (human refuge)
    pipe = [(366, 70), (380, 70), (382, 200), (364, 200)]
    c.fill(pipe, STONE, tex=0.3); c.ink_poly(pipe, width=2.2)
    c.fill([(356, 58), (390, 58), (392, 74), (354, 74)], STONE); c.ink_poly([(356, 58), (390, 58), (392, 74), (354, 74)], width=2)
    glow = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(glow).ellipse(((116 - 40) * SS, (100 - 40) * SS, (116 + 40) * SS, (100 + 40) * SS), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(14 * SS))
    gl = Image.new("RGBA", c.img.size, AMBER[:3] + (0,)); gl.putalpha(glow)
    c.img = Image.alpha_composite(c.img, gl)
    c.ink([(116, 120), (116, 106)], width=2)
    c.ellipse_fill((106, 88, 126, 108), hexc("#F6C25E"), tex=0.1)
    c.ink_poly(c.blob(116, 98, 10, 10, n=10, irregular=0), width=1.8)
    # sandbags
    for i, (x, y) in enumerate([(60, 236), (92, 248), (124, 262), (338, 262), (370, 248), (398, 236), (76, 222), (384, 222)]):
        sb = c.blob(x, y, 24, 12, n=12, irregular=0.08)
        c.fill(sb, mix(STRAW2, KHAKI, 0.5), tex=0.25, light=(0, -1, 0.3)); c.ink_poly(sb, width=1.8)
    grass_fringe(c, 30, 440, base + 4, density=0.6, h=(10, 30))
    tuft(c, 50, base, 60, 44); tuft(c, 410, base, 60, 40)
    return c.save(out("props/bunker/template_bunker_hatch.png"))


def suitcase():
    W, H = 120, 84
    c = Canvas(W, H, seed=121)
    c.soft_shadow((6, 62, 116, 82), alpha=90, blur=4)
    body = [(14, 40), (86, 34), (100, 70), (24, 76)]
    c.fill(body, mix(WOOD, RUST_D, 0.4), tex=0.3, light=(0, -1, 0.3)); c.ink_poly(body, width=2.2)
    lid = [(14, 40), (86, 34), (74, 10), (8, 18)]
    c.fill(lid, mix(WOOD, RUST_D, 0.25), tex=0.3); c.ink_poly(lid, width=2)
    for col, pts in [(hexc("#8FA3A8"), [(30, 50), (70, 44), (108, 64), (60, 74)]), (hexc("#C9B98E"), [(84, 60), (114, 56), (116, 74), (90, 78)])]:
        c.fill(pts, col, tex=0.2); c.ink_poly(pts, width=1.6)
    tuft(c, 100, 80, 30, 18)
    return c.save(out("props/clutter/template_suitcase.png"))


def wheelbarrow():
    W, H = 180, 120
    c = Canvas(W, H, seed=131)
    c.soft_shadow((10, 96, 170, 118), alpha=90, blur=5)
    tub = [(20, 70), (40, 30), (150, 26), (166, 64), (120, 96), (40, 96)]
    c.fill(tub, mix(STEEL, RUST, 0.45), tex=0.35, cell=8, light=(-1, -0.5, 0.35))
    c.hatch(c.mask([(20, 70), (166, 64), (120, 96), (40, 96)]), spacing=5, alpha=80)
    c.ink_poly(tub, width=2.4)
    c.ink([(150, 30), (176, 12)], width=3.5, color=WOOD); c.ink([(40, 34), (14, 14)], width=3.5, color=WOOD)
    c.ellipse_fill((70, 84, 100, 114), hexc("#2A2724")); c.ink_poly(c.blob(85, 99, 15, 15, n=12, irregular=0.02), width=2)
    tuft(c, 40, 114, 40, 26); tuft(c, 150, 112, 40, 22)
    return c.save(out("props/clutter/template_wheelbarrow.png"))


def sign():
    W, H = 140, 180
    c = Canvas(W, H, seed=141)
    c.soft_shadow((40, 160, 110, 178), alpha=80, blur=4)
    post(c, 70, 60, 172, w=12)
    board = [(10, 24), (130, 18), (128, 84), (14, 90)]
    c.fill(board, mix(WOOD_L, GREYGREEN, 0.3), tex=0.3, cell=8)
    c.ink([(12, 52), (128, 48)], width=1.0, alpha=110)
    c.ink_poly(board, width=2.2)
    # hand-painted letters, roughened
    txt = Image.new("L", c.img.size, 0)
    try:
        f = ImageFont.truetype("DejaVuSans-Bold.ttf", 23 * SS)
    except OSError:
        f = ImageFont.load_default()
    d = ImageDraw.Draw(txt)
    d.text((22 * SS, 28 * SS), "GONE", font=f, fill=255)
    d.text((22 * SS, 56 * SS), "NORTH", font=f, fill=255)
    txt = txt.rotate(2, center=(70 * SS, 55 * SS)).filter(ImageFilter.GaussianBlur(0.8 * SS))
    arr = np.asarray(txt, dtype=np.float32)
    n = value_noise(txt.size[0], txt.size[1], 6, 5)
    arr = np.where(arr * (0.6 + n) > 120, 230, 0).astype(np.uint8)
    lay = Image.new("RGBA", c.img.size, RUST_D[:3] + (0,)); lay.putalpha(Image.fromarray(arr))
    c.img = Image.alpha_composite(c.img, lay)
    tuft(c, 70, 176, 50, 30)
    return c.save(out("props/clutter/template_sign_gone_north.png"))


def barrel():
    W, H = 84, 116
    c = Canvas(W, H, seed=151)
    c.soft_shadow((8, 96, 80, 114), alpha=90, blur=4)
    b = [(12, 20), (72, 20), (76, 100), (8, 100)]
    c.fill(b, mix(RUST, STEEL, 0.4), tex=0.35, cell=8, light=(-1, 0, 0.4))
    for y in (40, 78):
        c.ink([(10, y), (74, y)], width=2.0)
    c.ellipse_fill((12, 12, 72, 30), mix(RUST_D, STEEL, 0.5)); c.ink_poly(c.blob(42, 21, 30, 9, n=14, irregular=0), width=2)
    c.ink_poly(b, width=2.2)
    tuft(c, 42, 108, 60, 26)
    return c.save(out("props/clutter/template_barrel.png"))


# ------------------------------------------------------------------ characters
def survivor(view):
    W, H = 104, 168
    c = Canvas(W, H, seed=161 + ["down", "up", "side"].index(view))
    base = 160
    c.soft_shadow((22, base - 12, 82, base + 6), alpha=110, blur=4)
    jacket = hexc("#5E6436"); jacket_d = hexc("#454A28")
    trousers = hexc("#4A4238"); boots = hexc("#2E2721"); skin = hexc("#C9A27E"); hair = hexc("#4A3524")
    pack = mix(WOOD, KHAKI, 0.35)
    if view == "side":
        # legs
        for x, ofs in ((44, -2), (56, 2)):
            leg = [(x - 7, 104), (x + 7, 104), (x + 8 + ofs, base - 8), (x - 6 + ofs, base - 8)]
            c.fill(leg, trousers, tex=0.2); c.ink_poly(leg, width=1.8)
            c.fill([(x - 8 + ofs, base - 12), (x + 14 + ofs, base - 12), (x + 14 + ofs, base), (x - 8 + ofs, base)], boots); c.ink_poly([(x - 8 + ofs, base - 12), (x + 14 + ofs, base - 12), (x + 14 + ofs, base), (x - 8 + ofs, base)], width=1.6)
        # backpack behind (left)
        bp = [(14, 52), (40, 48), (42, 108), (16, 112)]
        c.fill(bp, pack, tex=0.3, light=(-1, -1, 0.3)); c.ink_poly(bp, width=2)
        torso = [(34, 50), (70, 50), (74, 110), (34, 112)]
        c.fill(torso, jacket, tex=0.25, light=(1, -1, 0.3)); c.ink_poly(torso, width=2.2)
        arm = [(52, 58), (64, 58), (68, 100), (56, 102)]
        c.fill(arm, jacket_d, tex=0.2); c.ink_poly(arm, width=1.8)
        head = c.blob(56, 34, 17, 19, n=16, irregular=0.04)
        c.fill(head, skin, tex=0.15, light=(1, -1, 0.3)); c.ink_poly(head, width=2)
        c.fill([(38, 16), (72, 18), (70, 30), (40, 34)], hair, tex=0.3); c.ink([(38, 18), (72, 20)], width=1.6)
        c.ellipse_fill((64, 30, 69, 35), INK)
        c.fill([(40, 44), (66, 46), (64, 58), (42, 56)], hexc("#5C3B2E"))  # beard/scarf
    else:
        for x in (40, 62):
            leg = [(x - 9, 104), (x + 9, 104), (x + 8, base - 10), (x - 8, base - 10)]
            c.fill(leg, trousers, tex=0.2, light=(-1, 0, 0.2)); c.ink_poly(leg, width=1.8)
            bt = [(x - 10, base - 14), (x + 10, base - 14), (x + 11, base), (x - 11, base)]
            c.fill(bt, boots); c.ink_poly(bt, width=1.6)
        for x0, sgn in ((22, -1), (82, 1)):
            arm = [(x0 - 2 * sgn, 54), (x0 + 6 * sgn, 52), (x0 + 12 * sgn, 70), (x0 + 11 * sgn, 100), (x0 + 3 * sgn, 104), (x0 - 1 * sgn, 76)]
            c.fill(arm, jacket_d, tex=0.2); c.ink_poly(arm, width=1.8)
            c.ellipse_fill((x0 + 7 * sgn - 6, 98, x0 + 7 * sgn + 6, 110), skin)
        torso = [(30, 54), (40, 48), (64, 48), (74, 54), (80, 80), (79, 112), (25, 112), (24, 80)]
        c.fill(torso, jacket, tex=0.25, light=(-0.6, -1, 0.3)); c.ink_poly(torso, width=2.2)
        c.ink([(52, 56), (52, 110)], width=1.2, alpha=140)
        if view == "up":
            bp = [(28, 50), (76, 50), (80, 106), (24, 108)]
            c.fill(bp, pack, tex=0.3, light=(-1, -1, 0.3)); c.ink_poly(bp, width=2.2)
            c.fill([(32, 74), (72, 74), (72, 96), (32, 96)], mix(pack, INK, 0.15)); c.ink_poly([(32, 74), (72, 74), (72, 96), (32, 96)], width=1.6)
            c.ink([(30, 110), (74, 110)], width=5, color=hexc("#8B8F80"))  # bedroll
            head = c.blob(52, 32, 19, 20, n=16, irregular=0.04)
            c.fill(head, hair, tex=0.3, light=(-1, -1, 0.3)); c.ink_poly(head, width=2)
        else:
            for x in (34, 70):
                c.ink([(x, 54), (x + (4 if x < 50 else -4), 108)], width=3.2, color=mix(pack, INK, 0.2))
            c.fill([(44, 70), (60, 70), (60, 84), (44, 84)], mix(jacket, INK, 0.25))  # pocket
            head = c.blob(52, 32, 19, 20, n=16, irregular=0.04)
            c.fill(head, skin, tex=0.15, light=(-1, -1, 0.3)); c.ink_poly(head, width=2)
            c.fill([(33, 12), (71, 12), (72, 26), (60, 22), (44, 22), (32, 28)], hair, tex=0.3)
            c.ink([(33, 14), (71, 14)], width=1.5)
            c.ellipse_fill((43, 30, 48, 35), INK); c.ellipse_fill((56, 30, 61, 35), INK)
            c.fill([(38, 42), (66, 42), (62, 54), (42, 54)], hexc("#5C3B2E"), tex=0.3)  # beard
            c.ink([(38, 42), (42, 54), (62, 54), (66, 42)], width=1.4)
    return c.save(out(f"characters/player/template_survivor_{view}.png"))


# ------------------------------------------------------------------ ground tiles
def tile_from_noise(size, base, dark, light, seed, cell, strokes=None):
    n = value_noise(size, size, cell, seed, octaves=4, wrap=True)
    n2 = value_noise(size, size, cell // 4, seed + 1, octaves=2, wrap=True)
    g = np.random.default_rng(seed).random((size, size)).astype(np.float32)
    t = np.clip(n * 0.8 + n2 * 0.3 - 0.05, 0, 1)
    arr = np.zeros((size, size, 3), dtype=np.float32)
    for i in range(3):
        arr[..., i] = dark[i] * (1 - t) + light[i] * t
        arr[..., i] *= 0.94 + 0.12 * g
        arr[..., i] = arr[..., i] * 0.6 + base[i] * 0.4
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    if strokes:
        strokes(img)
    return img


def wrap_draw(img, fn):
    """Draw with wrap-around so tiles stay seamless."""
    s = img.size[0]
    for ox in (-s, 0, s):
        for oy in (-s, 0, s):
            fn(ImageDraw.Draw(img), ox, oy)


def grass_tile():
    S = 512
    rng = random.Random(171)
    blades = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(5, 13), rng.uniform(-4, 4),
               rng.choice([GRASS_D, GRASS_L, OLIVE, mix(GRASS_L, STRAW, 0.4)])) for _ in range(1500)]
    def strokes(img):
        def fn(d, ox, oy):
            for x, y, h, lean, col in blades:
                d.line([(x + ox, y + oy), (x + lean + ox, y - h + oy)], fill=col[:3] + (150,), width=2)
        wrap_draw(img, fn)
        flowers = [(rng.uniform(0, S), rng.uniform(0, S), rng.choice([hexc("#E9E2C8"), hexc("#D79AA6"), hexc("#E3C15A")])) for _ in range(30)]
        def fl(d, ox, oy):
            for x, y, col in flowers:
                d.ellipse((x - 2 + ox, y - 2 + oy, x + 2 + ox, y + 2 + oy), fill=col[:3] + (220,))
        wrap_draw(img, fl)
    img = tile_from_noise(S, GRASS, GRASS_D, mix(GRASS_L, STRAW, 0.25), 172, 128, strokes)
    img.save(out("env/ground/template_grass_tile.png"), optimize=True)


def dirt_tile():
    S = 512
    rng = random.Random(181)
    pebbles = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1.5, 4), rng.choice([STONE, KHAKI, WOOD])) for _ in range(260)]
    def strokes(img):
        def fn(d, ox, oy):
            for x, y, r, col in pebbles:
                d.ellipse((x - r + ox, y - r * 0.7 + oy, x + r + ox, y + r * 0.7 + oy), fill=col[:3] + (200,), outline=INK[:3] + (110,))
        wrap_draw(img, fn)
        tufts = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(40)]
        def tf(d, ox, oy):
            for x, y in tufts:
                for k in range(5):
                    d.line([(x + ox + k * 2 - 4, y + oy), (x + ox + k * 3 - 6, y + oy - rng.uniform(5, 11))], fill=GRASS[:3] + (180,), width=2)
        wrap_draw(img, tf)
    img = tile_from_noise(S, mix(WOOD, KHAKI, 0.5), mix(WOOD, INK, 0.25), mix(KHAKI, STRAW, 0.3), 182, 96, strokes)
    img.save(out("env/ground/template_dirt_tile.png"), optimize=True)


def asphalt_tile():
    S = 256
    rng = random.Random(191)
    def strokes(img):
        cracks = []
        for _ in range(7):
            x, y = rng.uniform(0, S), rng.uniform(0, S)
            pts = [(x, y)]
            for _ in range(rng.randint(4, 9)):
                x += rng.uniform(-18, 18); y += rng.uniform(-18, 18); pts.append((x, y))
            cracks.append(pts)
        def fn(d, ox, oy):
            for pts in cracks:
                d.line([(px + ox, py + oy) for px, py in pts], fill=INK[:3] + (170,), width=2)
                for px, py in pts[1::2]:
                    d.line([(px + ox, py + oy), (px + ox + rng.uniform(-3, 3), py + oy - rng.uniform(3, 8))], fill=GRASS[:3] + (200,), width=2)
        wrap_draw(img, fn)
    img = tile_from_noise(S, hexc("#5F5B52"), hexc("#46433D"), hexc("#7A756A"), 192, 64, strokes)
    img.save(out("env/ground/template_asphalt_tile.png"), optimize=True)


def paper_grain():
    S = 256
    n = value_noise(S, S, 8, 201, octaves=3, wrap=True)
    g = np.random.default_rng(202).random((S, S)).astype(np.float32)
    v = np.clip(128 + (n - 0.5) * 70 + (g - 0.5) * 60, 0, 255).astype(np.uint8)
    Image.fromarray(v, "L").convert("RGBA").save(out("fx/template_paper_grain.png"), optimize=True)


def drift():
    c = Canvas(24, 24, seed=211)
    c.ellipse_fill((8, 8, 16, 16), hexc("#F2EBD3", 230), tex=0.05)
    for a in range(6):
        ang = a / 6 * 6.283
        c.ink([(12, 12), (12 + math.cos(ang) * 10, 12 + math.sin(ang) * 10)], width=0.8, color=hexc("#F2EBD3"), alpha=170)
    c.save(out("fx/template_drift_seed.png"))


if __name__ == "__main__":
    jobs = [farmhouse, lambda: house_door(False), lambda: house_door(True), lambda: fence_h(0), lambda: fence_h(1),
            fence_v, lambda: gate(False), lambda: gate(True), shed, lambda: tree_oak(0), lambda: tree_oak(1),
            tree_birch, lambda: shrub(0), lambda: shrub(1), lambda: tall_grass(0), lambda: tall_grass(1), lambda: tall_grass(2),
            car, bunker_hatch, suitcase, wheelbarrow, sign, barrel,
            lambda: survivor("down"), lambda: survivor("up"), lambda: survivor("side"),
            grass_tile, dirt_tile, asphalt_tile, paper_grain, drift]
    only = sys.argv[1:]
    for j in jobs:
        name = getattr(j, "__name__", "lambda")
        j()
    print("homestead art generated")
