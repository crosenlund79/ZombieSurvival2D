#!/usr/bin/env python3
"""Red Thaw — Shadows & Depth (iteration 012) generated template art.

* Thawed-blood marks: three small, irregular, refrozen crimson drops (never pools).
* The side-view (cross-section) bunker set: earth layers, rock, rooms, timber
  supports and scaffolding, concrete slabs, ladders, the hatch shaft, and
  side-view furniture and equipment (storage locker, generator, purifier, lamp,
  bedroll, workbench, crates, planter, stockpile) drawn at side-view
  proportions rather than reusing the top-down sprites.

Writes templates under assets/templates/ and assets/manifest/visual_depth.json.
Never touches creator overrides. Run from the repository root.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, value_noise, SS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []


def out(rel):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_shadows_depth.py) - replace with tablet art."})


# ------------------------------------------------------------------ thawed blood
def blood_drop(variant):
    W, H = 40, 30
    c = Canvas(W, H, seed=13000 + variant)
    dark = hexc("#5E0F0D")
    red = hexc("#8C1A16")
    cx, cy = W / 2, H / 2 + 2
    main = c.blob(cx, cy, 7 + variant * 1.5, 4.5 + variant, n=12, irregular=0.35)
    c.fill(main, red, tex=0.35, cell=3)
    c.fill(c.blob(cx - 1, cy - 1, 3.5, 2.2, n=8, irregular=0.3), dark, tex=0.3, cell=2)
    for k in range(2 + variant):  # a few satellite specks
        a = c.rng.uniform(0, math.tau)
        r = c.rng.uniform(9, 14)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.6
        s = c.rng.uniform(1.0, 2.2)
        c.ellipse_fill((x - s, y - s * 0.7, x + s, y + s * 0.7), red)
    c.ink_poly(main, width=0.9, alpha=110, color=hexc("#3A0907"))
    rel = f"fx/template_blood_drop_{'abc'[variant]}.png"
    c.save(out(rel), finish=False, winter=False)
    entry(f"fx.blood_drop_{'abc'[variant]}", f"Thawed-blood mark {'abc'[variant]} (small, refrozen)", rel, (16, 12), (W, H), (0.5, 0.5),
          "Generated (tools/art/gen_shadows_depth.py). Keep it small and irregular: a drop, never a pool.")


# ------------------------------------------------------------------ side-view bunker (cross-section)
EARTH, EARTH_D, EARTH_L = hexc("#4A3A2C"), hexc("#33271D"), hexc("#6B5640")
CLAY = hexc("#7A5A3E")
ROCK, ROCK_D = hexc("#5B5A55"), hexc("#3B3A36")
WALL, WALL_D = hexc("#2E241C"), hexc("#1E1712")
TIMBER, TIMBER_D, TIMBER_L = hexc("#7A5E40"), hexc("#4E3A26"), hexc("#9A7A55")
CONC, CONC_D = hexc("#8A877F"), hexc("#5E5B55")
STEEL, STEEL_D = hexc("#5E6467"), hexc("#3A3E40")
WARM = hexc("#E8C27A")


def pf(c, pts, col, tex=0.3, cell=8, ink=2.0, light=(-1, -1, 0.3)):
    m = c.fill(pts, col, tex=tex, cell=cell, light=light)
    if ink:
        c.ink_poly(pts, width=ink)
    return m


def tile(name, aid, label, base, kind, size=256):
    """Seamless tile: value-noise strata, stones, roots or planks, inked lightly."""
    n = size
    rng = np.random.default_rng(len(name) * 97)
    nz = value_noise(n, n, 24, int(rng.integers(1 << 20)), octaves=4, wrap=True)
    fine = value_noise(n, n, 6, int(rng.integers(1 << 20)), octaves=2, wrap=True)
    b = np.array(base[:3], dtype=np.float32)
    yy = np.arange(n)[:, None].repeat(n, 1)
    if kind == "earth":   # horizontal strata
        strata = 0.5 + 0.5 * np.sin(yy / n * math.tau * 4 + nz * 3.0)
        shade = 0.82 + 0.25 * strata + (fine - 0.5) * 0.18
    elif kind == "rock":
        shade = 0.75 + (nz - 0.5) * 0.5 + (fine - 0.5) * 0.2
    elif kind == "wall":  # packed earth back wall with pick marks
        shade = 0.85 + (nz - 0.5) * 0.3 + (fine - 0.5) * 0.15
    else:                 # concrete
        shade = 0.92 + (nz - 0.5) * 0.12 + (fine - 0.5) * 0.08
    rgb = np.clip(b[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, np.full((n, n), 255, np.uint8)]), "RGBA")
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(len(name) * 31)
    for _ in range(26 if kind == "earth" else 12):
        x, y = r.uniform(0, n), r.uniform(0, n)
        if kind in ("earth", "rock"):
            rr = r.uniform(3, 9 if kind == "earth" else 18)
            col = tuple(int(v) for v in (np.array(ROCK[:3]) * r.uniform(0.7, 1.1)))
            for ox in (-n, 0, n):
                for oy in (-n, 0, n):
                    d.ellipse((x - rr + ox, y - rr * 0.7 + oy, x + rr + ox, y + rr * 0.7 + oy), fill=col + (255,), outline=(30, 24, 18, 200))
        elif kind == "wall":
            for ox in (-n, 0, n):
                d.line((x + ox, y, x + ox + r.uniform(-8, 8), y + r.uniform(8, 20)), fill=(20, 15, 11, 150), width=2)
        else:
            for ox in (-n, 0, n):
                d.line((x + ox, y, x + ox + r.uniform(10, 40), y + r.uniform(-3, 3)), fill=(60, 58, 54, 120), width=1)
    if kind == "earth":  # thin roots
        for _ in range(5):
            x0, y0 = r.uniform(0, n), r.uniform(0, n)
            pts = [(x0 + k * 6 + r.uniform(-3, 3), y0 + k * 9) for k in range(6)]
            d.line(pts, fill=(96, 72, 46, 200), width=2)
    if kind == "concrete":  # formwork seams
        for yv in (0, n // 2):
            d.line((0, yv, n, yv), fill=(70, 68, 64, 160), width=2)
        for xv in (0, n // 2):
            d.line((xv, 0, xv, n), fill=(70, 68, 64, 110), width=1)
    rel = f"side/template_{name}.png"
    img.save(out(rel))
    entry(aid, label, rel, (size, size), (size, size), (0, 0), "Generated seamless tile (tools/art/gen_shadows_depth.py).")


def strip(name, aid, label, kind, W=256, H=28):
    c = Canvas(W, H, seed=13500 + len(name))
    if kind == "boards":
        pf(c, [(0, 4), (W, 4), (W, H), (0, H)], TIMBER, ink=0)
        for x in range(0, W, 64):
            c.ink([(x, 4), (x, H)], width=1.4, alpha=170)
        c.ink([(0, 4), (W, 4)], width=2.2)
        c.ink([(0, H - 1), (W, H - 1)], width=1.4, alpha=150)
        for _ in range(10):
            x = c.rng.uniform(0, W)
            c.ink([(x, 10), (x + 14, 12)], width=0.8, alpha=110)
    elif kind == "beam":
        pf(c, [(0, 0), (W, 0), (W, H - 6), (0, H - 6)], TIMBER_D, ink=0)
        c.ink([(0, H - 6), (W, H - 6)], width=2.2)
        for x in range(32, W, 128):
            c.fill([(x - 4, H - 6), (x + 4, H - 6), (x + 3, H - 2), (x - 3, H - 2)], STEEL_D)
    else:  # concrete slab
        pf(c, [(0, 2), (W, 2), (W, H), (0, H)], CONC, ink=0)
        c.ink([(0, 2), (W, 2)], width=2.4)
        for x in range(0, W, 128):
            c.ink([(x, 2), (x, H)], width=1.0, alpha=120)
    rel = f"side/template_{name}.png"
    c.save(out(rel), finish=False, winter=False)
    entry(aid, label, rel, (W, H), (W, H), (0, 0), "Generated tileable strip (tools/art/gen_shadows_depth.py).")


def sprite(name, aid, label, W, H, pivot, draw):
    c = Canvas(W, H, seed=14000 + len(name) * 13)
    draw(c, W, H)
    rel = f"side/template_{name}.png"
    c.save(out(rel), winter=False)
    entry(aid, label, rel, (W // 2, H // 2), (W, H), pivot)


def d_ladder(c, W, H):
    for x in (18, W - 18):
        pf(c, [(x - 5, 0), (x + 5, 0), (x + 5, H), (x - 5, H)], TIMBER, ink=1.8)
    for y in range(24, H, 34):
        pf(c, [(18, y), (W - 18, y), (W - 18, y + 7), (18, y + 7)], TIMBER_L, ink=1.4)


def d_hatch(c, W, H):
    pf(c, [(6, 18), (W - 6, 18), (W - 6, 40), (6, 40)], CONC_D, ink=2.2)
    pf(c, [(W / 2 - 46, 22), (W / 2 + 46, 22), (W / 2 + 46, 36), (W / 2 - 46, 36)], hexc("#141210"), ink=1.8)
    for x in (W / 2 - 30, W / 2 + 30):
        pf(c, [(x - 5, 26), (x + 5, 26), (x + 5, H), (x - 5, H)], TIMBER, ink=1.4)
    for y in (60, 92):
        pf(c, [(W / 2 - 30, y), (W / 2 + 30, y), (W / 2 + 30, y + 7), (W / 2 - 30, y + 7)], TIMBER_L, ink=1.2)


def d_scaffold(stage):
    def d(c, W, H):
        col = TIMBER if stage != "exposed" else TIMBER_D
        alpha_posts = stage != "exposed"
        if stage == "exposed":  # a marked spot: chalk lines and a single stake
            c.ink([(W / 2, H - 4), (W / 2, H - 70)], width=5, color=TIMBER_D)
            for k in range(4):
                c.ink([(10, H - 10 - k * 3), (W - 10, H - 10 - k * 3)], width=1.0, color=hexc("#D8D2C4"), alpha=160)
            return
        top = 8 if stage == "done" else H * 0.45
        for x in (14, W - 14):
            pf(c, [(x - 7, top), (x + 7, top), (x + 7, H), (x - 7, H)], col, ink=2.0)
        if stage == "done":
            pf(c, [(2, 6), (W - 2, 6), (W - 2, 22), (2, 22)], TIMBER_D, ink=2.0)  # header beam
            for y0 in range(40, H - 20, 80):  # cross braces
                c.ink([(14, y0), (W - 14, y0 + 70)], width=5, color=TIMBER_L)
                c.ink([(14, y0), (W - 14, y0 + 70)], width=1.4)
        else:
            c.ink([(14, H - 30), (W - 14, H - 50)], width=4, color=TIMBER_L)
    return d


def d_storage(c, W, H):
    pf(c, [(10, 10), (W - 10, 10), (W - 10, H - 4), (10, H - 4)], hexc("#4E5A4A"), ink=2.4)
    c.ink([(W / 2, 14), (W / 2, H - 8)], width=1.8)
    for x in (W / 2 - 12, W / 2 + 12):
        pf(c, [(x - 3, H / 2 - 10), (x + 3, H / 2 - 10), (x + 3, H / 2 + 10), (x - 3, H / 2 + 10)], STEEL, ink=1.0)
    for y in (24, 36):
        for x0 in (18, W / 2 + 8):
            c.ink([(x0, y), (x0 + 22, y)], width=1.2, alpha=170)
    c.fill([(16, H - 50), (W / 2 - 6, H - 50), (W / 2 - 6, H - 30), (16, H - 30)], hexc("#C9C0A8"))


def d_generator(on):
    def d(c, W, H):
        pf(c, [(14, 30), (W - 14, 30), (W - 14, H - 14), (14, H - 14)], hexc("#7A3A28"), ink=2.4)
        pf(c, [(8, H - 16), (W - 8, H - 16), (W - 8, H - 4), (8, H - 4)], STEEL_D, ink=1.8)
        pf(c, [(W - 40, 14), (W - 26, 14), (W - 26, 34), (W - 40, 34)], STEEL_D, ink=1.6)  # exhaust
        for y in range(44, H - 24, 10):
            c.ink([(24, y), (W / 2 - 8, y)], width=1.6, alpha=170)
        pf(c, [(W / 2 + 8, 46), (W - 24, 46), (W - 24, 74), (W / 2 + 8, 74)], hexc("#1F1C18"), ink=1.4)
        c.ellipse_fill((W - 34, 52, W - 26, 60), hexc("#E85A3A") if on else hexc("#3A2A22"))
    return d


def d_purifier(on):
    def d(c, W, H):
        pf(c, [(16, 18), (W - 16, 18), (W - 16, H - 8), (16, H - 8)], hexc("#5A7078"), ink=2.2)
        pf(c, [(26, 30), (W - 26, 30), (W - 26, H * 0.6), (26, H * 0.6)], hexc("#9FC4CF") if on else hexc("#3E5056"), ink=1.6)
        c.ink([(W / 2, 4), (W / 2, 18)], width=4, color=STEEL_D)
        c.ink([(W - 16, H * 0.75), (W - 2, H * 0.75)], width=4, color=STEEL_D)
    return d


def d_lamp(on):
    def d(c, W, H):
        c.ink([(W / 2, 0), (W / 2, H * 0.5)], width=2.0, color=hexc("#1F1C18"))
        shade = [(W / 2 - 18, H * 0.5), (W / 2 + 18, H * 0.5), (W / 2 + 26, H * 0.75), (W / 2 - 26, H * 0.75)]
        pf(c, shade, hexc("#4F5A4C"), ink=1.8)
        c.ellipse_fill((W / 2 - 9, H * 0.72, W / 2 + 9, H * 0.86), WARM if on else hexc("#3A3530"))
    return d


def d_bedroll(c, W, H):
    pf(c, [(6, H - 18), (W - 6, H - 18), (W - 6, H - 4), (6, H - 4)], TIMBER_D, ink=1.8)  # pallet
    pf(c, [(14, H - 34), (W - 20, H - 32), (W - 18, H - 18), (12, H - 18)], hexc("#6E3A2E"), ink=1.8)
    pf(c, [(W - 46, H - 40), (W - 14, H - 38), (W - 14, H - 26), (W - 48, H - 28)], hexc("#B8AE98"), ink=1.4)


def d_pile(level):
    def d(c, W, H):
        pf(c, [(8, H - 10), (W - 8, H - 10), (W - 8, H - 4), (8, H - 4)], TIMBER_D, ink=1.4)
        logs = {"empty": 0, "small": 3, "medium": 7, "large": 12}[level]
        k = 0
        for row in range(4):
            for i in range(4 - row):
                if k >= logs:
                    break
                x = 22 + i * 30 + row * 15
                y = H - 22 - row * 22
                c.ellipse_fill((x - 13, y - 11, x + 13, y + 11), TIMBER)
                c.ink_poly(c.blob(x, y, 13, 11, n=12, irregular=0.05), width=1.6)
                c.ellipse_fill((x - 5, y - 4, x + 5, y + 4), TIMBER_L)
                k += 1
    return d


def d_wall(mat):
    def d(c, W, H):
        if mat == "wood":
            for x in range(8, W - 8, 16):
                pf(c, [(x, 10), (x + 15, 10), (x + 15, H - 4), (x, H - 4)], TIMBER, ink=1.4, cell=5)
            for y in (36, H - 40):
                pf(c, [(4, y), (W - 4, y), (W - 4, y + 10), (4, y + 10)], TIMBER_D, ink=1.4)
        elif mat == "metal":
            pf(c, [(6, 8), (W - 6, 8), (W - 6, H - 4), (6, H - 4)], STEEL, ink=2.2)
            for y in range(24, H - 10, 28):
                for x in (14, W - 14):
                    c.ellipse_fill((x - 2, y - 2, x + 2, y + 2), STEEL_D)
        else:
            pf(c, [(4, 6), (W - 4, 6), (W - 4, H - 4), (4, H - 4)], CONC, ink=2.4, cell=6)
            c.ink([(4, H / 2), (W - 4, H / 2)], width=1.2, alpha=140)
    return d


def d_door(opened):
    def d(c, W, H):
        pf(c, [(4, 6), (W - 4, 6), (W - 4, H - 4), (4, H - 4)], TIMBER_D, ink=2.2)
        if opened:
            pf(c, [(W - 18, 10), (W - 6, 6), (W - 6, H - 4), (W - 18, H - 8)], TIMBER, ink=1.6)
            pf(c, [(10, 12), (W - 20, 12), (W - 20, H - 6), (10, H - 6)], hexc("#141210"), ink=1.0)
        else:
            pf(c, [(10, 12), (W - 10, 12), (W - 10, H - 6), (10, H - 6)], TIMBER, ink=1.6, cell=5)
            c.ellipse_fill((W - 18, H / 2, W - 12, H / 2 + 6), STEEL)
    return d


def d_crate(c, W, H):
    pf(c, [(6, 10), (W - 6, 10), (W - 6, H - 4), (6, H - 4)], TIMBER, ink=2.2, cell=5)
    c.ink([(6, 10), (W - 6, H - 4)], width=2.0)
    c.ink([(6, H - 4), (W - 6, 10)], width=2.0)


def d_workbench(c, W, H):
    pf(c, [(4, 22), (W - 4, 22), (W - 4, 34), (4, 34)], TIMBER, ink=2.0)
    for x in (14, W - 14):
        pf(c, [(x - 5, 34), (x + 5, 34), (x + 5, H - 4), (x - 5, H - 4)], TIMBER_D, ink=1.6)
    c.ink([(20, 20), (60, 6)], width=4, color=STEEL_D)  # saw
    pf(c, [(W - 60, 10), (W - 40, 10), (W - 40, 22), (W - 60, 22)], hexc("#7A3A28"), ink=1.4)


def d_planter(stage):
    def d(c, W, H):
        pf(c, [(6, H - 30), (W - 6, H - 30), (W - 10, H - 4), (10, H - 4)], hexc("#3E4A40"), ink=2.0)
        pf(c, [(10, H - 30), (W - 10, H - 30), (W - 10, H - 24), (10, H - 24)], EARTH_D, ink=0)
        if stage != "empty":
            n = 6
            for i in range(n):
                x = 18 + i * (W - 36) / (n - 1)
                h = 18 if stage == "growing" else 34
                c.ink([(x, H - 30), (x, H - 30 - h)], width=2.2, color=hexc("#5E7A3E"))
                c.ellipse_fill((x - 6, H - 30 - h - 4, x + 6, H - 30 - h + 4), hexc("#6E8E44"))
                if stage == "ripe":
                    c.ellipse_fill((x - 5, H - 30 - 6, x + 5, H - 30 + 2), hexc("#B59A5E"))
        c.ellipse_fill((W / 2 - 30, 2, W / 2 + 30, 12), hexc("#B4A6E8"))  # grow light
        c.ink([(W / 2, 12), (W / 2, H - 30)], width=1.2, alpha=120)
    return d


def side_art():
    tile("earth", "side.earth", "Side view: earth strata (tile)", EARTH, "earth")
    tile("rock", "side.rock", "Side view: bedrock around the shaft (tile)", ROCK, "rock")
    tile("backwall", "side.backwall", "Side view: dug room back wall (tile)", WALL, "wall")
    tile("concrete_wall", "side.concrete_wall", "Side view: concrete room wall (tile)", CONC_D, "concrete")
    strip("floorboards", "side.floorboards", "Side view: timber floorboards (strip)", "boards")
    strip("beam", "side.beam", "Side view: ceiling beam (strip)", "beam", H=20)
    strip("concrete_slab", "side.concrete_slab", "Side view: reinforced concrete floor slab (strip)", "slab")
    sprite("ladder", "side.ladder", "Side view: ladder up the shaft", 96, 520, (0.5, 1.0), d_ladder)
    sprite("hatch_down", "side.hatch_down", "Side view: floor hatch with a ladder down", 240, 140, (0.5, 0.22), d_hatch)
    for st in ("exposed", "building", "done"):
        sprite(f"scaffold_{st}", f"side.scaffold_{st}", f"Side view: timber support / scaffolding ({st})", 128, 520, (0.5, 1.0), d_scaffold(st))
    sprite("storage", "side.storage", "Side view: storage locker", 180, 240, (0.5, 0.98), d_storage)
    sprite("generator_off", "side.generator_off", "Side view: generator (off)", 220, 160, (0.5, 0.98), d_generator(False))
    sprite("generator_on", "side.generator_on", "Side view: generator (running)", 220, 160, (0.5, 0.98), d_generator(True))
    sprite("purifier_off", "side.purifier_off", "Side view: water purifier (idle)", 140, 220, (0.5, 0.98), d_purifier(False))
    sprite("purifier_on", "side.purifier_on", "Side view: water purifier (working)", 140, 220, (0.5, 0.98), d_purifier(True))
    sprite("lamp_off", "side.lamp_off", "Side view: hanging lamp (off)", 60, 120, (0.5, 0.0), d_lamp(False))
    sprite("lamp_on", "side.lamp_on", "Side view: hanging lamp (on)", 60, 120, (0.5, 0.0), d_lamp(True))
    sprite("bedroll", "side.bedroll", "Side view: bedroll on a pallet", 240, 60, (0.5, 0.95), d_bedroll)
    for lv in ("empty", "small", "medium", "large"):
        sprite(f"timber_{lv}", f"side.timber_{lv}", f"Side view: timber pile ({lv})", 160, 110, (0.5, 0.97), d_pile(lv))
    for m in ("wood", "metal", "concrete"):
        sprite(f"wall_{m}", f"side.wall_{m}", f"Side view: {m} wall / barricade", 128, 240, (0.5, 0.98), d_wall(m))
    sprite("door_closed", "side.door_closed", "Side view: door (closed)", 100, 220, (0.5, 0.98), d_door(False))
    sprite("door_open", "side.door_open", "Side view: door (open)", 100, 220, (0.5, 0.98), d_door(True))
    sprite("crate", "side.crate", "Side view: storage crate", 120, 88, (0.5, 0.95), d_crate)
    sprite("workbench", "side.workbench", "Side view: workbench", 200, 120, (0.5, 0.97), d_workbench)
    for st in ("empty", "growing", "ripe"):
        sprite(f"planter_{st}", f"side.planter_{st}", f"Side view: hydroponic planter ({st})", 200, 120, (0.5, 0.97), d_planter(st))


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_depth.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "depth", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("shadows & depth art generated:", len(ENTRIES))


if __name__ == "__main__":
    for v in range(3):
        blood_drop(v)
    side_art()
    write_manifest()
