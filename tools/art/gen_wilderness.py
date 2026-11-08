#!/usr/bin/env python3
"""Iteration 015 A/B: wilderness and timber-cabin art for the larger world.

Log cabins in varied forms (a small hunting cabin, a cabin with a porch, a large
two-storey timber house, a weathered log home, a ruined cabin, a workshop shed,
a woodland lean-to, an outhouse), and wilderness dressing (rocks, a fallen tree,
woodpiles, a road sign, a power pole, a hunting stand, a snow-buried car, a radio
mast, broken fence pieces, a bicycle, barrels, a porch bench, a rusted stove).

Same "dirty ink" winter style and helpers as gen_winter.py. Writes templates under
assets/templates/env/wild/ and assets/templates/world/cabins/ and the manifest
assets/manifest/visual_wilderness.json. Every picture is replaceable with
assets/overrides/<same path without template_>.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix  # noqa: E402
import gen_winter as gw  # noqa: E402
from gen_winter import (pf, snow_band, drift, icicles, logs_wall, frosted_window, SNOW, SNOW_SH, SNOW_D, CHAR, ASH, ASH_L,  # noqa: E402
                        TIMBER_D, TIMBER, TIMBER_M, TIMBER_L, RUST_D, RUST, STEEL_D, STEEL, PINE_D, PINE, GLASS_D)
from gen_homestead import out, ROOT  # noqa: E402

ENTRIES = []


def entry(aid, name, rel, display, source, pivot):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": list(display),
                    "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_wilderness.py) - replace with tablet art."})


def save(c, rel, aid, label, W, H, base):
    c.save(out(rel), winter=False)
    entry(aid, label, rel, (W // 2, H // 2), (W, H), (0.5, base / H))


# ---------------------------------------------------------------- cabins
def roof_gable(c, x0, x1, top, eave, peak_inset, col, snow=True, holes=0):
    roof = [(x0 + peak_inset, top), (x1 - peak_inset, top), (x1, eave), (x0, eave)]
    pf(c, roof, col, tex=0.3, cell=10, ink=3.0)
    for x in range(int(x0) + 10, int(x1), 20):
        c.ink([(x, eave - 4), (x + 2, eave + 12)], width=0.9, alpha=140)
    if snow:
        pts = [(x0 + peak_inset + 4, top - 8)] + [(x0 + peak_inset + (x1 - x0 - 2 * peak_inset) * k / 8, top - 10 - c.rng.uniform(0, 6)) for k in range(1, 8)] + \
              [(x1 - peak_inset - 4, top - 8), (x1 - 4, eave - 4)] + [(x1 - (x1 - x0) * k / 12, eave + c.rng.uniform(-2, 8)) for k in range(1, 12)] + [(x0 + 4, eave - 4)]
        m = c.fill(pts, SNOW, tex=0.12, cell=14, light=(-0.6, -1, 0.35))
        c.shade(m, 0.6, 1, 6, 50, reach=0.45)
        c.ink(pts, width=2.0, alpha=200, seg=4)
    for _ in range(holes):  # broken roof: dark gaps and a sagging line
        x = c.rng.uniform(x0 + peak_inset + 20, x1 - peak_inset - 60)
        y = c.rng.uniform(top + 20, eave - 40)
        hole = c.blob(x, y, c.rng.uniform(22, 44), c.rng.uniform(10, 18), n=12, irregular=0.45)
        pf(c, hole, CHAR, tex=0.2, ink=1.8)
        for k in range(4):
            c.ink([(x - 30 + k * 16, y - 12), (x - 20 + k * 16, y + 14)], width=2.2, color=TIMBER_D)
    icicles(c, x0 + 20, x1 - 20, eave + 12, int((x1 - x0) / 22), (5, 18))


def door(c, x, y, w, h, open_=False):
    frame = [(x - 6, y - 6), (x + w + 6, y - 6), (x + w + 6, y + h), (x - 6, y + h)]
    pf(c, frame, TIMBER_D, tex=0.3, ink=2.0)
    pf(c, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], CHAR if open_ else mix(TIMBER, TIMBER_D, 0.5), tex=0.35, ink=1.8)
    if not open_:
        for k in range(1, 4):
            c.ink([(x + w * k / 4, y + 4), (x + w * k / 4, y + h - 4)], width=0.9, alpha=150)
        c.ellipse_fill((x + w - 14, y + h * 0.55, x + w - 6, y + h * 0.55 + 8), STEEL_D)


def chimney(c, x, top, bottom, stone=True):
    if stone:
        body = [(x, top), (x + 46, top), (x + 50, bottom), (x - 4, bottom)]
        pf(c, body, ASH, tex=0.45, cell=6, ink=2.2, shade=(1, 0, 3.5, 90))
        for y in range(int(top) + 14, int(bottom), 16):
            c.ink([(x, y), (x + 46, y)], width=0.8, alpha=130)
        c.fill(c.blob(x + 23, top - 2, 30, 8, n=12, irregular=0.2), SNOW, tex=0.1)
    else:
        pipe = [(x, top), (x + 24, top), (x + 24, bottom), (x, bottom)]
        pf(c, pipe, mix(STEEL_D, RUST_D, 0.4), tex=0.35, ink=2.0, shade=(1, 0, 3.5, 90))
        pf(c, [(x - 8, top - 10), (x + 32, top - 10), (x + 28, top), (x - 4, top)], STEEL_D, ink=1.8)


def porch(c, x0, x1, y_roof, base, posts=2):
    pr = [(x0 + 10, y_roof), (x1 - 10, y_roof), (x1 + 6, y_roof + 40), (x0 - 6, y_roof + 40)]
    pf(c, pr, mix(TIMBER_D, CHAR, 0.25), tex=0.35, ink=2.4, shade=(0, 1, 4, 80))
    snow_band(c, [(x0, y_roof), ((x0 + x1) / 2, y_roof - 4), (x1, y_roof)], 14)
    icicles(c, x0, x1, y_roof + 40, int((x1 - x0) / 24), (4, 12))
    for k in range(posts):
        px = x0 + 12 + (x1 - x0 - 24) * k / max(1, posts - 1)
        pf(c, [(px - 7, y_roof + 40), (px + 7, y_roof + 40), (px + 8, base - 18), (px - 8, base - 18)], TIMBER_M, tex=0.35, ink=1.8)
    deck = [(x0 - 10, base - 22), (x1 + 10, base - 22), (x1 + 10, base - 8), (x0 - 10, base - 8)]
    pf(c, deck, TIMBER, tex=0.4, ink=2.0)
    for k in range(3):  # steps
        st = [((x0 + x1) / 2 - 40 - k * 4, base - 8 + k * 6), ((x0 + x1) / 2 + 40 + k * 4, base - 8 + k * 6),
              ((x0 + x1) / 2 + 40 + k * 4, base - 2 + k * 6), ((x0 + x1) / 2 - 40 - k * 4, base - 2 + k * 6)]
        pf(c, st, TIMBER_M, tex=0.4, ink=1.4)


def cabin(name, label, W=600, H=520, fw=440, wall_h=170, roof_h=170, *, porch_=False, storey2=False, ruin=False, seed=1,
          chimney_kind="stone", windows=((0.2, False), (0.78, True)), door_at=0.5, woodpile=False, door_open=False):
    c = Canvas(W, H, seed=seed)
    base = H - 26
    c.soft_shadow((W * 0.08, base - 30, W * 0.92, base + 20), alpha=130, blur=12)
    fx0 = (W - fw) / 2
    fx1 = fx0 + fw
    ftop = base - 24 - wall_h - (wall_h * 0.85 if storey2 else 0)
    pf(c, [(fx0 - 12, base - 24), (fx1 + 12, base - 24), (fx1 + 12, base), (fx0 - 12, base)], ASH, tex=0.35, cell=6, ink=2.0)
    logs_wall(c, fx0, fx1, ftop, base - 24, h=24 if fw > 380 else 20)
    c.shade(c.mask([(fx1 - fw * 0.25, ftop), (fx1, ftop), (fx1, base), (fx1 - fw * 0.18, base)]), 1, 0, 5, 70, cross=True, reach=1.0)
    roof_gable(c, fx0 - 34, fx1 + 34, ftop - roof_h, ftop + 18, fw * 0.22, mix(TIMBER_D, CHAR, 0.4), holes=3 if ruin else 0)
    if chimney_kind:
        chimney(c, fx1 - fw * 0.3, ftop - roof_h - 30, ftop - roof_h * 0.35, stone=chimney_kind == "stone")
    win_y = base - 24 - wall_h * 0.72
    for (fxp, boarded) in windows:
        wx = fx0 + fw * fxp - 34
        frosted_window(c, wx, win_y, 68, 58, boarded=boarded, dark=ruin)
        if storey2:
            frosted_window(c, wx, win_y - wall_h * 0.85, 60, 50, boarded=not boarded, dark=ruin)
    dw, dh = 70, 116
    dx = fx0 + fw * door_at - dw / 2
    door(c, dx, base - 24 - dh, dw, dh, open_=door_open or ruin)
    if porch_:
        porch(c, dx - 70, dx + dw + 70, base - 24 - dh - 40, base)
    if ruin:  # scattered logs from the collapsed corner, half buried in snow
        for k in range(4):
            lg = [(fx1 - 140 + k * 30, base - 30 - k * 14), (fx1 + 30 + k * 6, base - 52 - k * 10), (fx1 + 34 + k * 6, base - 34 - k * 10), (fx1 - 136 + k * 30, base - 12 - k * 14)]
            pf(c, lg, TIMBER_M, tex=0.35, ink=1.8)
    if woodpile:
        stack(c, fx0 - 8, base - 6, 3)
    drift(c, W * 0.25, base + 6, W * 0.2, 14)
    drift(c, W * 0.75, base + 8, W * 0.18, 12)
    save(c, f"world/cabins/template_{name}.png", f"world.{name}", label, W, H, base)


def stack(c, x, base, rows):
    for r in range(rows):
        for k in range(5 - r):
            cx = x + 16 + k * 26 + r * 13
            cy = base - 12 - r * 22
            e = c.blob(cx, cy, 13, 11, n=10, irregular=0.08)
            pf(c, e, TIMBER_L, tex=0.25, ink=1.3)
            c.ink_poly(c.blob(cx, cy, 5, 4, n=8, irregular=0.1), width=0.6, alpha=120)
    snow_band(c, [(x + 4, base - 12 - rows * 22 + 8), (x + 70, base - 18 - rows * 22 + 8), (x + 136, base - 12 - rows * 22 + 22)], 10)


def lean_to():
    W, H = 360, 260
    c = Canvas(W, H, seed=2101)
    base = H - 20
    c.soft_shadow((30, base - 20, 330, base + 12), alpha=110, blur=8)
    roof = [(40, base - 150), (330, base - 110), (330, base - 96), (40, base - 136)]
    for x in range(48, 330, 22):
        pf(c, [(x, base - 150 + (x - 40) * 0.14), (x + 20, base - 148 + (x - 40) * 0.14), (x + 20, base - 4), (x, base - 4)] if False else
           [(x, base - 146 + (x - 40) * 0.14), (x + 18, base - 144 + (x - 40) * 0.14), (x + 22, base - 132 + (x - 40) * 0.14), (x + 4, base - 134 + (x - 40) * 0.14)], TIMBER, tex=0.3, ink=1.4)
    pf(c, roof, mix(PINE_D, TIMBER_D, 0.5), tex=0.35, ink=2.2)
    snow_band(c, [(40, base - 152), (180, base - 134), (330, base - 112)], 14)
    for px in (50, 320):
        pf(c, [(px - 7, base - 140 + (px - 40) * 0.14), (px + 7, base - 140 + (px - 40) * 0.14), (px + 8, base), (px - 8, base)], TIMBER_M, tex=0.35, ink=1.8)
    pf(c, [(80, base - 30), (290, base - 30), (300, base - 6), (70, base - 6)], mix(STEEL, CHAR, 0.4), tex=0.3, ink=1.6)  # tarp floor
    ring = c.blob(190, base + 4, 30, 9, n=12, irregular=0.2)
    pf(c, ring, ASH, tex=0.4, ink=1.6)
    c.fill(c.blob(190, base + 2, 16, 5, n=10, irregular=0.2), CHAR)
    drift(c, 300, base + 6, 50, 10)
    save(c, "world/cabins/template_lean_to.png", "world.lean_to", "Woodland lean-to", W, H, base)


def outhouse():
    W, H = 140, 260
    c = Canvas(W, H, seed=2102)
    base = H - 14
    pf(c, [(24, 70), (116, 70), (116, base), (24, base)], mix(TIMBER, TIMBER_D, 0.3), tex=0.4, ink=2.2)
    for x in range(34, 116, 14):
        c.ink([(x, 72), (x, base - 2)], width=0.8, alpha=140)
    pf(c, [(14, 70), (126, 54), (126, 64), (14, 80)], TIMBER_D, ink=2.0)
    snow_band(c, [(14, 70), (70, 60), (126, 54)], 12)
    c.ink_poly(c.blob(70, 110, 8, 12, n=10, irregular=0.05), width=1.6)  # the moon cut-out
    drift(c, 70, base + 4, 56, 10)
    save(c, "world/cabins/template_outhouse.png", "world.outhouse", "Outhouse", W, H, base)


# ---------------------------------------------------------------- dressing
def rock(variant):
    W, H = (200, 140) if variant != "c" else (320, 200)
    c = Canvas(W, H, seed=2200 + ord(variant))
    base = H - 14
    c.soft_shadow((20, base - 16, W - 20, base + 8), alpha=110, blur=8)
    n = 2 if variant == "a" else (1 if variant == "b" else 4)
    for k in range(n):
        cx = W * (0.5 if n == 1 else 0.25 + 0.5 * k / max(1, n - 1)) + c.rng.uniform(-10, 10)
        rx = W * (0.36 if n == 1 else 0.22) * c.rng.uniform(0.8, 1.1)
        ry = H * 0.32 * c.rng.uniform(0.7, 1.1)
        b = c.blob(cx, base - ry * 0.9, rx, ry, n=10, irregular=0.28)
        pf(c, b, mix(ASH, CHAR, c.rng.uniform(0.1, 0.4)), tex=0.45, cell=7, ink=2.2, shade=(1, 0.4, 4, 90))
        cap = c.blob(cx - rx * 0.1, base - ry * 1.6, rx * 0.7, ry * 0.35, n=10, irregular=0.3)
        c.fill(cap, SNOW, tex=0.1)
        c.ink([(cx - rx * 0.4, base - ry), (cx + rx * 0.1, base - ry * 0.7)], width=1.0, alpha=140)
    drift(c, W * 0.5, base + 4, W * 0.4, 10)
    save(c, f"env/wild/template_rock_{variant}.png", f"env.rock_{variant}", f"Rock outcrop {variant}", W, H, base)


def fallen_tree():
    W, H = 420, 140
    c = Canvas(W, H, seed=2210)
    base = H - 16
    c.soft_shadow((30, base - 14, 400, base + 8), alpha=100, blur=8)
    trunk = [(30, base - 48), (380, base - 30), (384, base - 6), (34, base - 18)]
    pf(c, trunk, TIMBER_D, tex=0.45, cell=6, ink=2.2, shade=(0, 1, 4, 80))
    for x in range(60, 370, 40):
        c.ink([(x, base - 44 + (x - 30) * 0.05), (x + 22, base - 38 + (x - 30) * 0.05)], width=0.9, alpha=150)
    root = c.blob(26, base - 34, 34, 40, n=14, irregular=0.5)
    pf(c, root, mix(TIMBER_D, CHAR, 0.4), tex=0.4, ink=2.0)
    for ang in (-1.2, -0.6, 0.0, 0.5):
        c.ink([(380, base - 20), (380 + 30 * math.cos(ang), base - 20 + 30 * math.sin(ang))], width=2.4, color=TIMBER_D)
    snow_band(c, [(36, base - 50), (200, base - 42), (380, base - 32)], 12)
    drift(c, 200, base + 4, 170, 10)
    save(c, "env/wild/template_fallen_tree.png", "env.fallen_tree", "Fallen tree", W, H, base)


def woodpile():
    W, H = 220, 150
    c = Canvas(W, H, seed=2211)
    base = H - 12
    c.soft_shadow((20, base - 14, 200, base + 8), alpha=100, blur=6)
    stack(c, 30, base, 4)
    drift(c, 110, base + 4, 90, 8)
    save(c, "env/wild/template_woodpile.png", "env.woodpile", "Woodpile", W, H, base)


def road_sign():
    W, H = 200, 220
    c = Canvas(W, H, seed=2212)
    base = H - 10
    for px in (60, 140):
        pf(c, [(px - 5, 60), (px + 5, 60), (px + 6, base), (px - 6, base)], TIMBER_M, tex=0.35, ink=1.6)
    board = [(20, 40), (180, 34), (184, 100), (24, 106)]
    pf(c, board, mix(hexc("#3E5848"), CHAR, 0.2), tex=0.35, ink=2.2)
    for y in (58, 78):
        c.ink([(40, y), (164, y - 3)], width=3.0, color=hexc("#C9C3B0"), alpha=200)
    snow_band(c, [(20, 40), (100, 35), (180, 34)], 10)
    drift(c, 100, base + 4, 70, 8)
    save(c, "env/wild/template_road_sign.png", "env.road_sign", "Road sign (blank board)", W, H, base)


def power_pole():
    W, H = 160, 440
    c = Canvas(W, H, seed=2213)
    base = H - 10
    pf(c, [(74, 40), (86, 40), (90, base), (70, base)], mix(TIMBER_D, CHAR, 0.3), tex=0.4, ink=2.0)
    pf(c, [(10, 70), (150, 66), (150, 80), (10, 84)], TIMBER_D, tex=0.4, ink=1.8)
    for x in (24, 60, 100, 136):
        c.ellipse_fill((x - 5, 58, x + 5, 70), hexc("#7E8A90"))
    snow_band(c, [(10, 68), (80, 64), (150, 64)], 6)
    drift(c, 80, base + 4, 30, 6)
    save(c, "env/wild/template_power_pole.png", "env.power_pole", "Power pole", W, H, base)


def hunting_stand():
    W, H = 220, 460
    c = Canvas(W, H, seed=2214)
    base = H - 10
    for (a, b) in ((40, 80), (180, 140)):
        pf(c, [(a - 6, base), (a + 6, base), (b + 6, 150), (b - 6, 150)], TIMBER_M, tex=0.35, ink=1.6)
    for y in range(200, base, 50):
        c.ink([(52, y), (168, y)], width=3.0, color=TIMBER)
    box = [(50, 60), (170, 60), (176, 160), (44, 160)]
    pf(c, box, mix(TIMBER, TIMBER_D, 0.4), tex=0.35, ink=2.2)
    pf(c, [(70, 90), (150, 90), (150, 120), (70, 120)], GLASS_D, tex=0.1, ink=1.6)
    pf(c, [(36, 60), (184, 60), (170, 34), (50, 34)], TIMBER_D, ink=2.0)
    snow_band(c, [(40, 36), (110, 30), (182, 36)], 10)
    drift(c, 110, base + 4, 90, 8)
    save(c, "env/wild/template_hunting_stand.png", "env.hunting_stand", "Hunting stand", W, H, base)


def buried_car():
    W, H = 460, 240
    c = Canvas(W, H, seed=2215)
    base = H - 16
    c.soft_shadow((40, base - 20, 420, base + 10), alpha=120, blur=8)
    body = [(60, base - 70), (400, base - 70), (410, base - 24), (50, base - 24)]
    pf(c, body, mix(hexc("#5A3E36"), ASH, 0.3), tex=0.35, ink=2.4)
    cab = [(130, base - 70), (160, base - 130), (310, base - 130), (340, base - 70)]
    pf(c, cab, mix(hexc("#5A3E36"), ASH, 0.3), tex=0.35, ink=2.4)
    for x0 in (172, 250):
        pf(c, [(x0, base - 118), (x0 + 66, base - 118), (x0 + 70, base - 78), (x0 - 4, base - 78)], GLASS_D, tex=0.1, ink=1.6)
    snow_band(c, [(160, base - 132), (235, base - 140), (310, base - 132)], 22)
    big = [(30, base - 30), (110, base - 60), (220, base - 44), (330, base - 64), (430, base - 34), (440, base), (20, base)]
    m = c.fill(big, SNOW, tex=0.12, light=(-0.6, -1, 0.3))
    c.shade(m, 0.6, 1, 6, 45, reach=0.5)
    c.ink(big[:5], width=1.8, alpha=180)
    save(c, "env/wild/template_buried_car.png", "env.buried_car", "Snow-buried car", W, H, base)


def radio_mast():
    W, H = 200, 700
    c = Canvas(W, H, seed=2216)
    base = H - 10
    for s in (-1, 1):
        c.ink([(100 + s * 70, base), (100 + s * 8, 40)], width=4, color=STEEL_D)
    for y in range(80, base, 60):
        w = 8 + (y - 40) / (base - 40) * 62
        c.ink([(100 - w, y), (100 + w, y + 50)], width=2, color=STEEL_D, alpha=200)
        c.ink([(100 + w, y), (100 - w, y + 50)], width=2, color=STEEL_D, alpha=200)
    c.ellipse_fill((92, 26, 108, 42), hexc("#8A2A22"))
    drift(c, 100, base + 4, 90, 10)
    save(c, "env/wild/template_radio_mast.png", "env.radio_mast", "Radio mast", W, H, base)


def small_prop(name, label, W, H, draw):
    c = Canvas(W, H, seed=2300 + len(name))
    base = H - 10
    draw(c, W, H, base)
    save(c, f"env/wild/template_{name}.png", f"env.{name}", label, W, H, base)


def d_fence_broken(c, W, H, base):
    for k, x in enumerate(range(20, W - 20, 50)):
        lean = c.rng.uniform(-10, 14)
        pf(c, [(x - 6, base - 90), (x + 6, base - 90), (x + 6 + lean * 0.2, base), (x - 6, base)], TIMBER_M, tex=0.35, ink=1.6)
    for y in (base - 70, base - 36):
        pts = [(20, y + c.rng.uniform(-4, 4)), (W * 0.45, y + c.rng.uniform(-6, 6))]
        c.ink(pts, width=6, color=TIMBER)
        c.ink(pts, width=1.0, alpha=180)
    c.ink([(W * 0.6, base - 60), (W - 20, base - 14)], width=6, color=TIMBER)  # a fallen rail
    drift(c, W / 2, base + 4, W * 0.45, 8)


def d_bicycle(c, W, H, base):
    for cx in (50, 150):
        c.ink_poly(c.blob(cx, base - 34, 30, 30, n=20, irregular=0.02), width=3.0, color=STEEL_D)
    c.ink([(50, base - 34), (96, base - 70), (150, base - 34), (100, base - 34), (50, base - 34)], width=3.4, color=RUST)
    c.ink([(96, base - 70), (90, base - 86)], width=3, color=STEEL_D)
    c.ink([(140, base - 76), (150, base - 34)], width=3, color=RUST)
    drift(c, 100, base + 2, 90, 10)


def d_barrels(c, W, H, base):
    for k, cx in enumerate((50, 108)):
        b = [(cx - 26, base - 70), (cx + 26, base - 70), (cx + 24, base), (cx - 24, base)]
        pf(c, b, mix(RUST, STEEL_D, 0.3 + 0.2 * k), tex=0.4, ink=2.0, shade=(1, 0, 3.5, 80))
        for y in (base - 52, base - 20):
            c.ink([(cx - 25, y), (cx + 25, y)], width=1.2, alpha=180)
        c.fill(c.blob(cx, base - 72, 26, 6, n=10, irregular=0.2), SNOW, tex=0.1)
    drift(c, 80, base + 4, 70, 8)


def d_bench(c, W, H, base):
    pf(c, [(20, base - 46), (W - 20, base - 46), (W - 20, base - 36), (20, base - 36)], TIMBER, tex=0.4, ink=1.6)
    pf(c, [(24, base - 86), (W - 24, base - 86), (W - 24, base - 70), (24, base - 70)], TIMBER, tex=0.4, ink=1.6)
    for x in (30, W - 40):
        pf(c, [(x, base - 86), (x + 10, base - 86), (x + 10, base), (x, base)], TIMBER_D, ink=1.4)
    snow_band(c, [(20, base - 48), (W / 2, base - 52), (W - 20, base - 48)], 8)


def d_crates(c, W, H, base):
    for (x, y, s) in ((20, base, 70), (96, base, 60), (52, base - 66, 56)):
        bx = [(x, y - s), (x + s, y - s), (x + s, y), (x, y)]
        pf(c, bx, mix(TIMBER, TIMBER_D, 0.3), tex=0.4, ink=1.8)
        c.ink([(x, y - s), (x + s, y)], width=1.2, alpha=150)
        c.fill(c.blob(x + s / 2, y - s - 2, s / 2, 5, n=8, irregular=0.2), SNOW, tex=0.1)
    drift(c, W / 2, base + 4, W * 0.4, 8)


def d_stove(c, W, H, base):
    pf(c, [(30, base - 80), (W - 30, base - 80), (W - 30, base - 12), (30, base - 12)], mix(STEEL_D, RUST_D, 0.5), tex=0.4, ink=2.0)
    pf(c, [(48, base - 64), (W - 48, base - 64), (W - 48, base - 30), (48, base - 30)], CHAR, ink=1.4)
    pf(c, [(W - 60, base - 150), (W - 44, base - 150), (W - 44, base - 80), (W - 60, base - 80)], STEEL_D, ink=1.4)
    for x in (36, W - 44):
        pf(c, [(x, base - 12), (x + 8, base - 12), (x + 8, base), (x, base)], CHAR, ink=1.0)
    snow_band(c, [(30, base - 82), (W / 2, base - 86), (W - 30, base - 82)], 8)


def d_belongings(c, W, H, base):
    pf(c, [(20, base - 30), (90, base - 34), (92, base - 4), (22, base - 2)], mix(hexc("#5A4A3A"), ASH, 0.2), tex=0.4, ink=1.6)  # suitcase
    c.ink([(44, base - 34), (52, base - 44), (62, base - 34)], width=2.0)
    pf(c, [(110, base - 16), (170, base - 22), (176, base - 2), (114, base)], hexc("#7E3A2C"), tex=0.4, ink=1.4)  # a red coat in the snow
    c.ink([(120, base - 10), (166, base - 14)], width=0.8, alpha=150)
    drift(c, 100, base + 4, 90, 8)


def d_sign_wood(c, W, H, base):
    pf(c, [(W / 2 - 5, 60), (W / 2 + 5, 60), (W / 2 + 6, base), (W / 2 - 6, base)], TIMBER_M, ink=1.4)
    pf(c, [(14, 30), (W - 14, 26), (W - 10, 76), (18, 80)], TIMBER, tex=0.4, ink=2.0)
    c.ink([(30, 46), (W - 40, 43)], width=3.0, color=CHAR, alpha=200)
    c.ink([(34, 62), (W - 60, 60)], width=3.0, color=hexc("#8A1C18"), alpha=200)
    snow_band(c, [(14, 30), (W / 2, 26), (W - 14, 26)], 8)
    drift(c, W / 2, base + 2, 40, 6)


if __name__ == "__main__":
    cabin("cabin_small", "Small hunting cabin", W=520, H=440, fw=340, wall_h=150, roof_h=140, seed=2001, windows=((0.22, False),))
    cabin("cabin_porch", "Log cabin with porch", W=640, H=520, fw=460, wall_h=170, roof_h=170, porch_=True, seed=2002, woodpile=True)
    cabin("cabin_large", "Large two-storey timber house", W=720, H=660, fw=540, wall_h=170, roof_h=180, storey2=True, seed=2003,
          windows=((0.16, False), (0.84, False)), door_at=0.5)
    cabin("cabin_weathered", "Weathered log home", W=620, H=500, fw=460, wall_h=160, roof_h=150, seed=2004, chimney_kind="pipe",
          windows=((0.2, True), (0.8, True)), door_at=0.62)
    cabin("cabin_ruin", "Ruined cabin", W=600, H=480, fw=420, wall_h=150, roof_h=150, ruin=True, seed=2005, chimney_kind="stone")
    cabin("cabin_workshop", "Timber workshop shed", W=560, H=420, fw=420, wall_h=140, roof_h=110, seed=2006, chimney_kind="pipe",
          windows=((0.18, False),), door_at=0.6, door_open=True, woodpile=True)
    lean_to()
    outhouse()
    for v in ("a", "b", "c"):
        rock(v)
    fallen_tree()
    woodpile()
    road_sign()
    power_pole()
    hunting_stand()
    buried_car()
    radio_mast()
    small_prop("fence_broken", "Broken fence", 300, 140, d_fence_broken)
    small_prop("bicycle", "Abandoned bicycle", 200, 120, d_bicycle)
    small_prop("barrels", "Barrels", 160, 110, d_barrels)
    small_prop("bench", "Porch bench", 180, 110, d_bench)
    small_prop("crates", "Stacked crates", 180, 150, d_crates)
    small_prop("stove_rusted", "Rusted stove left outside", 160, 180, d_stove)
    small_prop("belongings", "Abandoned belongings", 200, 70, d_belongings)
    small_prop("sign_wood", "Hand-painted wooden sign", 160, 160, d_sign_wood)
    with open(os.path.join(ROOT, "assets", "manifest", "visual_wilderness.json"), "w") as f:
        json.dump({"kind": "visual", "category": "wilderness", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("wilderness art:", len(ENTRIES))
