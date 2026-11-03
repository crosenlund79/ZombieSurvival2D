#!/usr/bin/env python3
"""Generates iteration-002 placeholder illustrations (templates): farmhouse
interior, shelter hatch stages, timber piles, tree stump, earthen bunker level,
timber supports, ladders, concrete test level, map paper.

Run from the repository root:  python3 tools/art/gen_bunker.py
Never touches assets/overrides/.
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, value_noise, INK, SS
from gen_homestead import (out, tuft, grass_fringe, post, rail, tile_from_noise, wrap_draw, canopy, scallop,
                           OLIVE_D, OLIVE, KHAKI, STRAW, STRAW2, GREYGREEN, WOOD, WOOD_L, WOOD_M, RUST, RUST_D,
                           STONE, GRASS, GRASS_L, GRASS_D, LEAF, LEAF_D, LEAF_L, AMBER, STEEL, CONCRETE, PAINT, SLATE, GLASS)

EARTH = hexc("#6B5034"); EARTH_D = hexc("#3E2D1E"); EARTH_L = hexc("#8C6C48"); CLAY = hexc("#9A7650")
PLANK = hexc("#8C7458"); PLANK_D = hexc("#5F4B38"); CONC = hexc("#8F8B82"); CONC_D = hexc("#5F5C56")


def board(c, pts, col=PLANK, grain=3):
    m = c.fill(pts, col, tex=0.28, cell=8, light=(-0.6, -1, 0.3))
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    for _ in range(grain):
        y = c.rng.uniform(min(ys) + 3, max(ys) - 3)
        c.ink([(min(xs) + 4, y), (max(xs) - 4, y + c.rng.uniform(-1.5, 1.5))], width=0.9, alpha=90)
    c.ink_poly(pts, width=1.8)
    return m


def log_end(c, x, y, r):
    c.ellipse_fill((x - r, y - r * 0.9, x + r, y + r * 0.9), WOOD_L, tex=0.2)
    c.ink_poly(c.blob(x, y, r, r * 0.9, n=14, irregular=0.03), width=1.6)
    c.ink_poly(c.blob(x, y, r * 0.55, r * 0.5, n=12, irregular=0.05), width=0.9, alpha=150)


# ------------------------------------------------------------------ interior
def interior_floor():
    S = 256
    rng = random.Random(301)
    def strokes(img):
        d = ImageDraw.Draw(img)
        for y in range(0, S, 32):
            d.line([(0, y), (S, y)], fill=INK[:3] + (150,), width=2)
            off = rng.randint(0, 120)
            for x in (off, off + 128):
                d.line([(x % S, y), (x % S, y + 32)], fill=INK[:3] + (120,), width=2)
        for _ in range(60):
            x, y = rng.uniform(0, S), rng.uniform(0, S)
            d.line([(x, y), (x + rng.uniform(10, 40), y + rng.uniform(-1, 1))], fill=PLANK_D[:3] + (90,), width=1)
    img = tile_from_noise(S, PLANK, PLANK_D, mix(PLANK, STRAW, 0.3), 302, 64, strokes)
    img.save(out("world/interior/template_floor_planks_tile.png"), optimize=True)


def interior_wall():
    W, H = 1520, 440
    c = Canvas(W, H, seed=311)
    wall = [(0, 0), (W, 0), (W, H), (0, H)]
    c.fill(wall, mix(PAINT, GREYGREEN, 0.35), tex=0.25, cell=40, light=(0, -1, 0.25))
    for x in range(0, W, 46):  # faded wallpaper stripes
        c.ink([(x, 6), (x + c.rng.uniform(-2, 2), H - 60)], width=6, color=mix(PAINT, STRAW2, 0.4), alpha=70, wobble=0.6)
    for _ in range(9):  # water stains / peeling
        x = c.rng.uniform(40, W - 40)
        c.ink([(x, 0), (x + c.rng.uniform(-6, 6), c.rng.uniform(60, 220))], width=c.rng.uniform(10, 22), color=mix(GREYGREEN, STRAW2, 0.3), alpha=55, wobble=1.6)
    # skirting board
    sk = [(0, H - 46), (W, H - 46), (W, H), (0, H)]
    board(c, sk, PLANK_D, grain=2)
    # windows with daylight
    for wx in (300, 1120):
        fr = [(wx - 10, 90), (wx + 190, 90), (wx + 190, 300), (wx - 10, 300)]
        c.fill(fr, mix(PAINT, WOOD_L, 0.4), tex=0.2)
        gl = [(wx, 100), (wx + 180, 100), (wx + 180, 290), (wx, 290)]
        c.fill(gl, hexc("#B7C2A6"), tex=0.15, light=(-1, -1, 0.4))
        for _ in range(5):
            x0 = c.rng.uniform(wx + 10, wx + 160)
            c.ink([(x0, 104), (x0 + 30, 280)], width=8, color=hexc("#DDE3CC"), alpha=60, wobble=0.3)
        c.ink([(wx + 90, 100), (wx + 90, 290)], width=4, color=mix(PAINT, WOOD_L, 0.4))
        c.ink([(wx, 195), (wx + 180, 195)], width=4, color=mix(PAINT, WOOD_L, 0.4))
        c.ink_poly(gl, width=2); c.ink_poly(fr, width=2.4)
        # torn curtain
        cur = [(wx - 16, 84), (wx + 30, 84), (wx + 18, 260), (wx - 22, 300)]
        c.fill(cur, mix(RUST, PAINT, 0.45), tex=0.3); c.ink_poly(cur, width=1.6)
    # picture frame (askew) and shelf
    pf = [(700, 120), (800, 112), (808, 200), (706, 208)]
    c.fill(pf, mix(WOOD, INK, 0.2)); c.ink_poly(pf, width=2.2)
    c.fill([(716, 128), (792, 122), (796, 190), (720, 196)], mix(STRAW2, GREYGREEN, 0.5), tex=0.3)
    sh = [(860, 200), (1040, 200), (1040, 214), (860, 214)]
    board(c, sh, PLANK_D, grain=1)
    for i, col in enumerate([RUST, CONC, STRAW2, GLASS]):
        x = 880 + i * 40
        c.fill([(x, 160), (x + 24, 160), (x + 26, 200), (x - 2, 200)], col, tex=0.2)
        c.ink_poly([(x, 160), (x + 24, 160), (x + 26, 200), (x - 2, 200)], width=1.4)
    # ivy crept in through a crack
    for i in range(30):
        x = W - 60 + c.rng.uniform(-40, 40); y = c.rng.uniform(10, 260)
        lb = c.blob(x, y, c.rng.uniform(6, 12), c.rng.uniform(5, 9), n=8, irregular=0.4)
        c.fill(lb, c.rng.choice([LEAF, LEAF_D, LEAF_L]), tex=0.25, cell=4); c.ink_poly(lb, width=1.0, alpha=160)
    c.ink([(0, H - 1), (W, H - 1)], width=3)
    c.save(out("world/interior/template_back_wall.png"))


def furniture_table():
    W, H = 300, 220
    c = Canvas(W, H, seed=321)
    c.soft_shadow((20, 170, 290, 214), alpha=90, blur=8)
    top = [(30, 70), (270, 70), (290, 120), (10, 120)]
    board(c, top, PLANK, grain=4)
    c.fill([(10, 120), (290, 120), (290, 134), (10, 134)], PLANK_D); c.ink_poly([(10, 120), (290, 120), (290, 134), (10, 134)], width=1.6)
    for x in (24, 266):
        leg = [(x - 7, 134), (x + 7, 134), (x + 6, 200), (x - 6, 200)]
        c.fill(leg, PLANK_D); c.ink_poly(leg, width=1.6)
    # overturned chair + plates
    ch = [(200, 150), (250, 140), (262, 196), (212, 206)]
    c.fill(ch, PLANK, tex=0.3); c.ink_poly(ch, width=1.6)
    c.ink([(250, 140), (280, 110)], width=4, color=PLANK_D); c.ink([(262, 196), (292, 170)], width=4, color=PLANK_D)
    for (x, y) in [(90, 92), (150, 88)]:
        c.ellipse_fill((x - 20, y - 8, x + 20, y + 8), hexc("#D9D3C2")); c.ink_poly(c.blob(x, y, 20, 8, n=12, irregular=0), width=1.4)
    c.save(out("world/interior/template_table.png"))


def furniture_bed():
    W, H = 400, 260
    c = Canvas(W, H, seed=331)
    c.soft_shadow((20, 210, 390, 254), alpha=90, blur=8)
    frame = [(20, 90), (380, 90), (390, 210), (10, 210)]
    board(c, frame, PLANK_D, grain=2)
    matt = [(30, 80), (370, 80), (378, 170), (22, 170)]
    c.fill(matt, mix(STRAW2, PAINT, 0.4), tex=0.3, cell=10, light=(-1, -1, 0.3)); c.ink_poly(matt, width=2)
    blanket = [(120, 74), (372, 82), (380, 176), (140, 186), (110, 130)]
    c.fill(blanket, mix(RUST, PAINT, 0.35), tex=0.3, light=(-0.5, -1, 0.3)); c.ink_poly(blanket, width=2)
    c.hatch(c.mask(blanket), spacing=6, alpha=60)
    pil = c.blob(70, 100, 36, 18, n=14, irregular=0.05)
    c.fill(pil, PAINT, tex=0.15); c.ink_poly(pil, width=1.8)
    head = [(14, 30), (40, 30), (40, 210), (14, 210)]
    board(c, head, PLANK_D, grain=1)
    c.save(out("world/interior/template_bed.png"))


def furniture_cupboard():
    W, H = 220, 320
    c = Canvas(W, H, seed=341)
    c.soft_shadow((10, 290, 210, 316), alpha=90, blur=6)
    body = [(20, 20), (200, 20), (204, 300), (16, 300)]
    board(c, body, mix(PLANK, GREYGREEN, 0.25), grain=2)
    for (x0, x1) in [(30, 106), (114, 190)]:
        d = [(x0, 36), (x1, 36), (x1, 200), (x0, 200)]
        c.ink_poly(d, width=1.6, alpha=170)
        c.ellipse_fill(((x0 + x1) / 2 - 4 + (12 if x0 < 100 else -12), 116, (x0 + x1) / 2 + 4 + (12 if x0 < 100 else -12), 124), hexc("#B59A5A"))
    # one door hanging open
    od = [(190, 36), (214, 44), (214, 196), (190, 200)]
    c.fill(od, mix(PLANK, GREYGREEN, 0.25), tex=0.3); c.ink_poly(od, width=1.6)
    c.fill([(116, 40), (188, 40), (188, 196), (116, 196)], hexc("#2A241C"), tex=0.2)
    for y in (90, 150):
        c.ink([(118, y), (186, y)], width=2, color=PLANK_D)
    for (x, y) in [(130, 86), (160, 84), (140, 146)]:
        c.fill([(x, y - 22), (x + 14, y - 22), (x + 14, y), (x, y)], c.rng.choice([RUST, STRAW2, CONC]), tex=0.2)
    for y in (220, 262):
        drw = [(30, y), (190, y), (190, y + 34), (30, y + 34)]
        c.ink_poly(drw, width=1.6, alpha=170)
    c.save(out("world/interior/template_cupboard.png"))


def furniture_stove():
    W, H = 200, 260
    c = Canvas(W, H, seed=351)
    c.soft_shadow((10, 230, 190, 256), alpha=90, blur=6)
    body = [(30, 90), (170, 90), (176, 236), (24, 236)]
    c.fill(body, mix(STEEL, INK, 0.25), tex=0.3, cell=8, light=(-1, -1, 0.35)); c.ink_poly(body, width=2.2)
    c.fill([(60, 150), (140, 150), (140, 210), (60, 210)], hexc("#1E1B17")); c.ink_poly([(60, 150), (140, 150), (140, 210), (60, 210)], width=1.8)
    pipe = [(120, 0), (140, 0), (140, 90), (120, 90)]
    c.fill(pipe, mix(STEEL, RUST, 0.3), tex=0.3); c.ink_poly(pipe, width=1.8)
    c.fill([(22, 82), (178, 82), (178, 94), (22, 94)], mix(STEEL, INK, 0.4)); c.ink_poly([(22, 82), (178, 82), (178, 94), (22, 94)], width=1.6)
    c.save(out("world/interior/template_stove.png"))


def rug():
    W, H = 440, 260
    c = Canvas(W, H, seed=361)
    r = c.blob(W / 2, H / 2, 200, 110, n=24, irregular=0.03)
    c.fill(r, mix(RUST, STRAW2, 0.3), tex=0.3, cell=10)
    inner = c.blob(W / 2, H / 2, 160, 80, n=24, irregular=0.03)
    c.ink_poly(inner, width=2, color=mix(RUST_D, INK, 0.3), alpha=160)
    c.hatch(c.mask(r), spacing=7, angle=30, alpha=40)
    c.ink_poly(r, width=2.2)
    c.save(out("world/interior/template_rug.png"))


def exit_mat():
    W, H = 240, 110
    c = Canvas(W, H, seed=371)
    glow = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(glow).polygon([(40 * SS, 110 * SS), (200 * SS, 110 * SS), (170 * SS, 20 * SS), (70 * SS, 20 * SS)], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(12 * SS))
    gl = Image.new("RGBA", c.img.size, (246, 232, 190, 0)); gl.putalpha(glow)
    c.img = Image.alpha_composite(c.img, gl)
    m = [(70, 50), (170, 50), (180, 96), (60, 96)]
    c.fill(m, mix(STRAW2, WOOD, 0.4), tex=0.35, cell=4); c.hatch(c.mask(m), spacing=4, angle=0, alpha=70); c.ink_poly(m, width=1.8)
    c.save(out("world/interior/template_exit_mat.png"))


# ------------------------------------------------------------------ shelter hatch stages
def floor_patch(c, x0, y0, x1, y1):
    for y in range(int(y0), int(y1), 22):
        board(c, [(x0, y), (x1, y), (x1, min(y + 20, y1)), (x0, min(y + 20, y1))], PLANK, grain=1)


def shelter_marked():
    W, H = 280, 200
    c = Canvas(W, H, seed=381)
    floor_patch(c, 20, 30, 260, 190)
    # chalk outline + X
    rect = [(70, 60), (210, 60), (210, 160), (70, 160)]
    c.ink(rect + [rect[0]], width=3, color=hexc("#E8E2D0"), alpha=210, wobble=1.4)
    c.ink([(90, 80), (190, 140)], width=2.5, color=hexc("#E8E2D0"), alpha=180)
    c.ink([(190, 80), (90, 140)], width=2.5, color=hexc("#E8E2D0"), alpha=180)
    # crowbar
    c.ink([(40, 170), (130, 186)], width=5, color=mix(STEEL, RUST, 0.4)); c.ink([(40, 170), (32, 160)], width=5, color=mix(STEEL, RUST, 0.4))
    c.save(out("world/shelter/template_site_marked.png"))


def shelter_digging():
    W, H = 320, 240
    c = Canvas(W, H, seed=391)
    floor_patch(c, 20, 40, 300, 230)
    hole = c.blob(160, 140, 90, 56, n=18, irregular=0.08)
    c.fill(hole, EARTH_D, tex=0.3, cell=6, light=(1, 1, 0.4)); c.hatch(c.mask(hole), spacing=4, alpha=80); c.ink_poly(hole, width=2.4)
    # pulled-up boards
    for i, (x, y, a) in enumerate([(40, 60, 0.2), (250, 70, -0.3), (60, 200, 0.1)]):
        L = 90
        dx, dy = math.cos(a) * L / 2, math.sin(a) * L / 2
        board(c, [(x - dx, y - dy - 8), (x + dx, y + dy - 8), (x + dx, y + dy + 8), (x - dx, y - dy + 8)], PLANK, grain=1)
    pile = c.blob(260, 190, 50, 30, n=14, irregular=0.2)
    c.fill(pile, EARTH, tex=0.4, cell=5, light=(-1, -1, 0.4)); c.ink_poly(pile, width=2)
    c.ink([(250, 40), (200, 160)], width=4, color=WOOD_L); c.ink([(200, 160), (186, 186)], width=9, color=mix(STEEL, INK, 0.2))
    c.save(out("world/shelter/template_site_digging.png"))


def hatch(open_):
    W, H = 280, 280 if open_ else 220
    c = Canvas(W, H, seed=401 + open_)
    base_y = H - 20
    floor_patch(c, 20, base_y - 170, 260, base_y)
    frame = [(60, base_y - 140), (220, base_y - 140), (226, base_y - 20), (54, base_y - 20)]
    c.fill(frame, PLANK_D, tex=0.3); c.ink_poly(frame, width=2.4)
    if open_:
        holep = [(74, base_y - 128), (206, base_y - 128), (210, base_y - 32), (70, base_y - 32)]
        c.fill(holep, hexc("#120F0C"), tex=0.15)
        for y in range(int(base_y - 116), int(base_y - 30), 22):  # ladder rungs into the dark
            c.ink([(110, y), (170, y)], width=4, color=mix(WOOD_L, INK, (y - (base_y - 116)) / 140))
        c.ink([(110, base_y - 128), (106, base_y - 32)], width=4, color=WOOD_L); c.ink([(170, base_y - 128), (174, base_y - 32)], width=4, color=WOOD_L)
        c.ink_poly(holep, width=2)
        lid = [(64, base_y - 140), (216, base_y - 140), (206, base_y - 250), (74, base_y - 250)]
        for i in range(4):
            t0, t1 = i / 4, (i + 1) / 4
            bx0 = 64 + (74 - 64) * 0 ; 
        c.fill(lid, PLANK, tex=0.3, light=(0, -1, 0.3))
        for x in (102, 140, 178):
            c.ink([(x, base_y - 140), (x + (x - 140) * -0.05, base_y - 250)], width=1.2, alpha=140)
        c.ink([(70, base_y - 200), (212, base_y - 200)], width=5, color=PLANK_D)
        c.ink_poly(lid, width=2.4)
    else:
        lid = [(68, base_y - 134), (212, base_y - 134), (218, base_y - 26), (62, base_y - 26)]
        c.fill(lid, PLANK, tex=0.3, light=(-1, -1, 0.3))
        for x in (104, 140, 176):
            c.ink([(x, base_y - 132), (x + 1, base_y - 28)], width=1.4, alpha=150)
        c.ink([(64, base_y - 100), (216, base_y - 100)], width=5, color=PLANK_D)
        c.ink([(64, base_y - 60), (216, base_y - 60)], width=5, color=PLANK_D)
        c.ink_poly(c.blob(140, base_y - 80, 14, 9, n=14, irregular=0), width=3, color=mix(STEEL, RUST, 0.4))
        c.ink_poly(lid, width=2.4)
    c.save(out(f"world/shelter/template_hatch_{'open' if open_ else 'closed'}.png"))


def timber_pile(level):
    W, H = 300, 180
    c = Canvas(W, H, seed=411 + level)
    base = 160
    c.soft_shadow((20, base - 20, 290, base + 14), alpha=80, blur=6)
    # two ground bearers
    for y in (base - 6,):
        c.ink([(40, y), (260, y)], width=7, color=PLANK_D)
    n = [0, 3, 7, 12][level]
    rows = [(5, base - 22), (4, base - 52), (3, base - 82)]
    k = 0
    for count, y in rows:
        for i in range(count):
            if k >= n:
                break
            x = 150 - (count - 1) * 22 + i * 44
            log_end(c, x, y, 21)
            k += 1
    if level == 0:
        c.ink([(60, base - 12), (240, base - 14)], width=2, alpha=120)
    tuft(c, 30, base + 8, 30, 18, colors=[EARTH, EARTH_L, KHAKI]) if level else None
    c.save(out(f"world/shelter/template_timber_pile_{['empty', 'small', 'medium', 'large'][level]}.png"))


def stump():
    W, H = 180, 120
    c = Canvas(W, H, seed=421)
    base = 104
    c.soft_shadow((20, base - 16, 170, base + 12), alpha=90, blur=6)
    body = [(52, 60), (128, 60), (134, base), (46, base)]
    c.fill(body, mix(WOOD, STONE, 0.35), tex=0.35, cell=6, light=(-1, 0, 0.3)); c.ink_poly(body, width=2)
    top = c.blob(90, 60, 40, 16, n=16, irregular=0.06)
    c.fill(top, WOOD_L, tex=0.2); c.ink_poly(top, width=2)
    for r in (26, 14):
        c.ink_poly(c.blob(90, 60, r, r * 0.4, n=14, irregular=0.05), width=0.9, alpha=150)
    for _ in range(8):  # chips
        x, y = c.rng.uniform(20, 160), c.rng.uniform(base - 6, base + 6)
        c.fill([(x, y), (x + 8, y - 2), (x + 6, y + 3)], WOOD_L)
    tuft(c, 40, base + 8, 40, 22); tuft(c, 140, base + 8, 40, 20)
    c.save(out("env/trees/template_stump.png"))


# ------------------------------------------------------------------ underground: earth
def earth_floor():
    S = 256
    rng = random.Random(431)
    stones = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(2, 6)) for _ in range(90)]
    roots = [[(rng.uniform(0, S), rng.uniform(0, S))] for _ in range(3)]
    for r in roots:
        x, y = r[0]
        for _ in range(5):
            x += rng.uniform(-14, 14); y += rng.uniform(4, 14); r.append((x, y))
    def strokes(img):
        def fn(d, ox, oy):
            for x, y, rr in stones:
                d.ellipse((x - rr + ox, y - rr * 0.7 + oy, x + rr + ox, y + rr * 0.7 + oy), fill=CLAY[:3] + (200,), outline=INK[:3] + (120,))
            for r in roots:
                d.line([(px + ox, py + oy) for px, py in r], fill=EARTH_D[:3] + (80,), width=2)
        wrap_draw(img, fn)
    img = tile_from_noise(S, EARTH, EARTH_D, EARTH_L, 432, 64, strokes)
    img.save(out("bunker/earth/template_earth_floor_tile.png"), optimize=True)


def earth_wall(W=2000, H=480, seed=441, concrete=False):
    c = Canvas(W, H, seed=seed)
    top = [(0, 0), (W, 0), (W, H), (0, H)]
    if concrete:
        c.fill(top, CONC, tex=0.25, cell=50, light=(0, -1, 0.3))
        for y in range(60, H, 90):  # formwork lines
            c.ink([(0, y), (W, y + c.rng.uniform(-2, 2))], width=1.6, alpha=110)
        for x in range(0, W, 240):
            c.ink([(x, 0), (x, H)], width=1.2, alpha=80)
            for y in range(30, H, 90):
                c.ellipse_fill((x + 120 - 4, y - 4, x + 120 + 4, y + 4), CONC_D)
        for _ in range(16):
            x = c.rng.uniform(20, W - 20)
            c.ink([(x, 0), (x + c.rng.uniform(-6, 6), c.rng.uniform(80, 300))], width=c.rng.uniform(10, 22), color=CONC_D, alpha=28, wobble=1.4)
        c.fill([(0, H - 40), (W, H - 40), (W, H), (0, H)], CONC_D, tex=0.3)
    else:
        c.fill(top, EARTH, tex=0.35, cell=30, light=(0, -1, 0.35))
        # soil strata
        for k, y in enumerate((70, 150, 260, 360)):
            pts = [(x, y + 14 * math.sin(x / 140.0 + k) + c.rng.uniform(-3, 3)) for x in range(0, W + 1, 40)]
            band = pts + [(W, y + 50), (0, y + 50)]
            c.fill(band, [EARTH_L, CLAY, EARTH_D, EARTH][k], tex=0.35, cell=12)
            c.ink(pts, width=1.4, alpha=120)
        for _ in range(70):  # stones
            x, y, r = c.rng.uniform(0, W), c.rng.uniform(20, H - 30), c.rng.uniform(5, 16)
            st = c.blob(x, y, r, r * 0.7, n=10, irregular=0.2)
            c.fill(st, mix(STONE, CLAY, c.rng.uniform(0.1, 0.6)), tex=0.2, light=(-1, -1, 0.4)); c.ink_poly(st, width=1.4)
        for _ in range(16):  # roots hanging from the top
            x = c.rng.uniform(0, W); pts = [(x, 0)]
            for _ in range(c.rng.randint(4, 8)):
                x += c.rng.uniform(-14, 14); pts.append((x, pts[-1][1] + c.rng.uniform(12, 26)))
            c.ink(pts, width=c.rng.uniform(2.5, 5), color=mix(WOOD, EARTH_D, 0.4))
        for _ in range(40):  # shovel marks
            x, y = c.rng.uniform(0, W), c.rng.uniform(40, H - 60)
            c.ink([(x, y), (x + c.rng.uniform(-6, 6), y + c.rng.uniform(16, 34))], width=3, color=EARTH_D, alpha=110)
        c.hatch(c.mask([(0, 0), (W, 0), (W, 70), (0, 70)]), spacing=5, alpha=90)
        c.fill([(0, H - 30), (W, H - 30), (W, H), (0, H)], EARTH_D, tex=0.35)
    c.ink([(0, H - 1), (W, H - 1)], width=3)
    c.save(out("bunker/concrete/template_concrete_wall.png" if concrete else "bunker/earth/template_earth_wall.png"))


def ladder_up():
    W, H = 180, 480
    c = Canvas(W, H, seed=451)
    # light shaft from the hatch above
    glow = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(glow).polygon([(50 * SS, 0), (130 * SS, 0), (160 * SS, 470 * SS), (20 * SS, 470 * SS)], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(14 * SS))
    gl = Image.new("RGBA", c.img.size, (240, 220, 170, 0)); gl.putalpha(glow)
    c.img = Image.alpha_composite(c.img, gl)
    c.fill([(40, 0), (140, 0), (136, 30), (44, 30)], hexc("#1A1612"), tex=0.2)
    c.ink_poly([(40, 0), (140, 0), (136, 30), (44, 30)], width=2)
    for x0, x1 in ((58, 54), (122, 126)):
        c.ink([(x0, 10), (x1, H - 12)], width=9, color=PLANK); c.ink([(x0, 10), (x1, H - 12)], width=1.6)
    for y in range(40, H - 20, 46):
        c.ink([(58, y), (122, y)], width=7, color=PLANK_D); c.ink([(58, y + 4), (122, y + 4)], width=1.2, alpha=150)
    c.soft_shadow((40, H - 26, 140, H - 2), alpha=90, blur=5)
    c.save(out("bunker/common/template_ladder_up.png"))


def ladder_down_concrete():
    W, H = 300, 200
    c = Canvas(W, H, seed=461)
    slab = [(20, 30), (280, 30), (290, 180), (10, 180)]
    c.fill(slab, CONC, tex=0.3, cell=12, light=(-1, -1, 0.3))
    for _ in range(5):
        x = c.rng.uniform(30, 270); c.ink([(x, 34), (x + c.rng.uniform(-20, 20), c.rng.uniform(80, 176))], width=1.2, alpha=110)
    c.ink_poly(slab, width=2.4)
    hole = [(100, 60), (200, 60), (206, 150), (94, 150)]
    c.fill(hole, hexc("#0F0D0B"), tex=0.1)
    for y in range(72, 150, 20):
        c.ink([(128, y), (172, y)], width=4, color=mix(PLANK, INK, (y - 72) / 90))
    c.ink([(128, 60), (126, 150)], width=4, color=PLANK); c.ink([(172, 60), (174, 150)], width=4, color=PLANK)
    c.ink_poly(hole, width=2.2)
    for (x, y) in [(40, 50), (260, 50), (40, 160), (260, 160)]:
        c.ellipse_fill((x - 4, y - 4, x + 4, y + 4), CONC_D)
    c.save(out("bunker/common/template_ladder_down_slab.png"))


def support(stage):
    W, H = 360, 420
    c = Canvas(W, H, seed=471 + stage)
    base = 400
    if stage == 0:  # exposed: crumbling earth bulge, chalk frame outline, stakes
        bulge = c.blob(180, 260, 150, 150, n=22, irregular=0.12)
        c.fill(bulge, EARTH_L, tex=0.4, cell=10, light=(-1, -1, 0.4)); c.ink_poly(bulge, width=2.2)
        c.hatch(c.mask(bulge), spacing=6, angle=-60, alpha=80)
        for _ in range(14):
            x, y = c.rng.uniform(70, 290), c.rng.uniform(180, 380)
            st = c.blob(x, y, c.rng.uniform(4, 10), c.rng.uniform(3, 7), n=8, irregular=0.2)
            c.fill(st, CLAY, tex=0.2); c.ink_poly(st, width=1)
        loose = c.blob(180, base - 10, 120, 18, n=16, irregular=0.2)
        c.fill(loose, EARTH, tex=0.4); c.ink_poly(loose, width=1.6)
        for x in (70, 290):
            c.ink([(x, base), (x - 2, 150)], width=2.6, color=hexc("#E8E2D0"), alpha=170, wobble=1.6)
        c.ink([(70, 150), (290, 150)], width=2.6, color=hexc("#E8E2D0"), alpha=170, wobble=1.6)
        for x in (70, 290):
            c.ink([(x, base + 4), (x, base - 40)], width=5, color=WOOD_L)
    else:
        if stage == 2:
            # boards behind the frame, holding the earth back
            for y in range(150, base - 20, 34):
                board(c, [(66, y), (294, y + c.rng.uniform(-3, 3)), (294, y + 30), (66, y + 30)], mix(PLANK, EARTH, 0.25), grain=1)
        posts = [(70, 150, base), (290, 150, base)]
        for i, (x, t, b) in enumerate(posts):
            if stage == 1 and i == 1:
                # second post still leaning, waiting to be stood up
                c.ink([(300, base), (230, 200)], width=26, color=PLANK); c.ink([(300, base), (230, 200)], width=1.8)
                continue
            p = [(x - 14, t), (x + 14, t), (x + 14, b), (x - 14, b)]
            board(c, p, PLANK, grain=2)
        if stage == 2:
            hd = [(40, 126), (320, 126), (320, 156), (40, 156)]
            board(c, hd, PLANK_D, grain=2)
            for x in (70, 290):  # braces
                c.ink([(x + (24 if x < 180 else -24), 156), (x, 200)], width=8, color=PLANK_D)
        else:
            for i in range(3):
                pl = [(120 + i * 18, base - 4), (130 + i * 18, base - 4), (180 + i * 22, base - 170), (170 + i * 22, base - 170)]
                c.fill(pl, PLANK, tex=0.3); c.ink_poly(pl, width=1.4)
            loose = c.blob(180, base - 10, 120, 16, n=16, irregular=0.2)
            c.fill(loose, EARTH, tex=0.4); c.ink_poly(loose, width=1.4)
    c.soft_shadow((40, base - 10, 320, base + 14), alpha=70, blur=6)
    c.save(out(f"bunker/earth/template_support_{['exposed', 'building', 'done'][stage]}.png"))


def lantern():
    W, H = 80, 180
    c = Canvas(W, H, seed=481)
    post(c, 40, 30, 172, w=10)
    c.ink([(40, 34), (64, 34), (64, 50)], width=3, color=STEEL)
    glow = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(glow).ellipse(((64 - 30) * SS, (74 - 30) * SS, (64 + 30) * SS, (74 + 30) * SS), fill=170)
    glow = glow.filter(ImageFilter.GaussianBlur(10 * SS))
    gl = Image.new("RGBA", c.img.size, AMBER[:3] + (0,)); gl.putalpha(glow)
    c.img = Image.alpha_composite(c.img, gl)
    body = [(54, 52), (74, 52), (76, 92), (52, 92)]
    c.fill(body, hexc("#F6C25E"), tex=0.1); c.ink_poly(body, width=1.8)
    c.fill([(50, 48), (78, 48), (74, 54), (54, 54)], STEEL); c.fill([(50, 92), (78, 92), (78, 98), (50, 98)], STEEL)
    c.save(out("bunker/common/template_lantern.png"))


def tools():
    W, H = 200, 160
    c = Canvas(W, H, seed=491)
    base = 146
    c.soft_shadow((20, base - 12, 190, base + 10), alpha=80, blur=5)
    bucket = [(110, 80), (170, 80), (162, base), (118, base)]
    c.fill(bucket, mix(STEEL, RUST, 0.3), tex=0.3, light=(-1, 0, 0.3)); c.ink_poly(bucket, width=2)
    c.ellipse_fill((110, 72, 170, 88), EARTH, tex=0.3); c.ink_poly(c.blob(140, 80, 30, 8, n=14, irregular=0), width=1.6)
    c.ink([(40, base), (96, 20)], width=6, color=WOOD_L); c.ink([(40, base), (96, 20)], width=1.2)
    blade = [(26, base - 30), (54, base - 22), (46, base + 4), (22, base - 2)]
    c.fill(blade, mix(STEEL, INK, 0.2)); c.ink_poly(blade, width=1.8)
    c.save(out("bunker/common/template_tools.png"))


def concrete_floor():
    S = 256
    rng = random.Random(501)
    def strokes(img):
        d = ImageDraw.Draw(img)
        for x in (0, 128):
            d.line([(x, 0), (x, S)], fill=CONC_D[:3] + (150,), width=2)
        for y in (0, 128):
            d.line([(0, y), (S, y)], fill=CONC_D[:3] + (150,), width=2)
        for _ in range(40):
            x, y = rng.uniform(0, S), rng.uniform(0, S)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=CONC_D[:3] + (110,))
    img = tile_from_noise(S, CONC, CONC_D, mix(CONC, STRAW, 0.2), 502, 64, strokes)
    img.save(out("bunker/concrete/template_concrete_floor_tile.png"), optimize=True)


def map_paper():
    S = 512
    n = value_noise(S, S, 64, 511, octaves=4, wrap=True)
    g = np.random.default_rng(512).random((S, S)).astype(np.float32)
    base = np.array([226, 214, 186], dtype=np.float32)
    arr = np.zeros((S, S, 3), dtype=np.float32)
    for i in range(3):
        arr[..., i] = base[i] * (0.9 + 0.12 * n + 0.04 * (g - 0.5))
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").save(out("ui/template_map_paper.png"), optimize=True)


if __name__ == "__main__":
    jobs = [interior_floor, interior_wall, furniture_table, furniture_bed, furniture_cupboard, furniture_stove, rug,
            exit_mat, shelter_marked, shelter_digging, lambda: hatch(False), lambda: hatch(True)]
    jobs += [lambda i=i: timber_pile(i) for i in range(4)]
    jobs += [stump, earth_floor, earth_wall, lambda: earth_wall(1800, 480, 445, True), ladder_up, ladder_down_concrete]
    jobs += [lambda i=i: support(i) for i in range(3)] + [lantern, tools, concrete_floor, map_paper]
    for job in jobs:
        job()
    print("bunker art generated")
