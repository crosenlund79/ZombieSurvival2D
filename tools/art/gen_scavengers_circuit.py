#!/usr/bin/env python3
"""Red Thaw — The Scavenger's Circuit (iteration 013) generated template art.

Interiors for Ashgrove, all in the surface's 3/4 top-down view and the shared
dirty-ink style: back walls (shop plaster, garage block, wallpaper, bare
planks), floor tiles (worn linoleum, concrete, carpet), store fixtures (aisle
shelves full / sparse / empty, checkout counter, glass freezer, clothes racks,
display tables, tool pegboard, metal shelving, pharmacy counter, medicine
cabinet, tool chest, car lift), household furniture (sofa, armchair, dresser,
fridge, kitchen counter, bookshelf, laid table with an abandoned meal,
barricades), partitions for back rooms, and searchable-container art with an
opened / emptied variant. Plus the wood stove (bunker improvement) in top-down
and side view and the stovepipe item.

Writes templates under assets/templates/ and assets/manifest/visual_circuit.json.
Never touches creator overrides. Run from the repository root.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, value_noise  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []

WOOD, WOOD_D, WOOD_L = hexc("#6E5640"), hexc("#46362A"), hexc("#8E7458")
METAL, METAL_D, METAL_L = hexc("#6A7073"), hexc("#41474A"), hexc("#8E9496")
PAINT_G, PAINT_C, PAINT_R = hexc("#71806F"), hexc("#B8B09A"), hexc("#7A3A2C")
CLOTH_B, CLOTH_P, CLOTH_O = hexc("#4F6670"), hexc("#6E4B63"), hexc("#8A7448")
DARK = hexc("#1C1916")
FOOD = [hexc("#A0703A"), hexc("#8A9A55"), hexc("#B5582F"), hexc("#C9B98A"), hexc("#6F8EA0")]


def out(rel):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_scavengers_circuit.py) - replace with tablet art."})


def pf(c, pts, col, tex=0.3, cell=8, ink=2.0, light=(-1, -1, 0.3)):
    m = c.fill(pts, col, tex=tex, cell=cell, light=light)
    if ink:
        c.ink_poly(pts, width=ink)
    return m


def box(c, x0, y0, x1, y1, col, depth=24, ink=2.2, top_col=None):
    """A 3/4-view block: lit top face of `depth`, darker front face below it."""
    top = [(x0, y0), (x1, y0), (x1, y0 + depth), (x0, y0 + depth)]
    front = [(x0, y0 + depth), (x1, y0 + depth), (x1, y1), (x0, y1)]
    pf(c, front, col, ink=ink)
    pf(c, top, top_col or mix(col, hexc("#E8E0CC"), 0.22), ink=ink, tex=0.25)
    return front


def shadow(c, W, base, x0=None, x1=None, a=95):
    c.soft_shadow((x0 if x0 is not None else W * 0.08, base - 14, x1 if x1 is not None else W * 0.92, base + 8), alpha=a, blur=8)


def sprite(aid, label, rel, W, H, base, draw, display=None):
    c = Canvas(W, H, seed=15000 + len(aid) * 17 + sum(map(ord, aid)) % 997)
    draw(c, W, H, base)
    c.save(out(rel), winter=False)
    entry(aid, label, rel, display or (W // 2, H // 2), (W, H), (0.5, base / H))


# ------------------------------------------------------------------ walls and floors
def back_wall(kind):
    W, H = 2200, 440
    c = Canvas(W, H, seed=16000 + len(kind))
    base = H - 40
    if kind == "shop":
        pf(c, [(0, 0), (W, 0), (W, base), (0, base)], mix(PAINT_C, PAINT_G, 0.35), tex=0.3, cell=14, ink=0)
        pf(c, [(0, base - 90), (W, base - 90), (W, base), (0, base)], mix(PAINT_G, DARK, 0.25), tex=0.3, ink=0)
        c.ink([(0, base - 90), (W, base - 90)], width=2.2)
        for x in range(160, W, 520):  # pale rectangles where signs hung
            pf(c, [(x, 70), (x + 240, 70), (x + 240, 150), (x, 150)], mix(PAINT_C, hexc("#F0E8D4"), 0.4), tex=0.15, ink=1.0)
            c.ink([(x + 20, 110), (x + 220, 108)], width=1.0, alpha=80)
        for _ in range(9):  # water stains
            x = c.rng.uniform(0, W)
            c.ink([(x, 0), (x + c.rng.uniform(-6, 6), c.rng.uniform(60, 220))], width=c.rng.uniform(8, 22), color=hexc("#7A6E58"), alpha=60, wobble=1.6)
    elif kind == "garage":
        pf(c, [(0, 0), (W, 0), (W, base), (0, base)], hexc("#6E6B66"), tex=0.25, cell=10, ink=0)
        y = 18
        row = 0
        while y < base:
            c.ink([(0, y), (W, y)], width=1.2, alpha=120, seg=12)
            off = 0 if row % 2 == 0 else 60
            for x in range(off, W, 120):
                c.ink([(x, y - 34), (x, y)], width=1.0, alpha=100, seg=6)
            y += 34
            row += 1
        for _ in range(7):
            x = c.rng.uniform(0, W)
            c.ink([(x, 120), (x + 30, base)], width=c.rng.uniform(10, 26), color=hexc("#3A3530"), alpha=70, wobble=1.4)
    elif kind == "house":
        pf(c, [(0, 0), (W, 0), (W, base), (0, base)], hexc("#8C7D62"), tex=0.3, cell=12, ink=0)
        for x in range(0, W, 46):  # wallpaper stripes
            c.ink([(x, 0), (x, base - 70)], width=6, color=hexc("#7A6A50"), alpha=80, wobble=0.6)
        for _ in range(6):  # peeling patches
            x, y = c.rng.uniform(40, W - 80), c.rng.uniform(40, 200)
            b = c.blob(x, y, c.rng.uniform(30, 60), c.rng.uniform(20, 40), n=12, irregular=0.4)
            c.fill(b, hexc("#5E5444"), tex=0.4)
            c.ink_poly(b, width=1.2, alpha=150)
        pf(c, [(0, base - 70), (W, base - 70), (W, base), (0, base)], WOOD, tex=0.3, ink=0)
        c.ink([(0, base - 70), (W, base - 70)], width=2.2)
        for x in range(300, W, 700):  # frames: one picture missing, a pale square
            pf(c, [(x, 80), (x + 110, 80), (x + 110, 170), (x, 170)], WOOD_D, ink=1.6)
            pf(c, [(x + 10, 90), (x + 100, 90), (x + 100, 160), (x + 10, 160)], hexc("#3E3A32"), ink=0)
            pf(c, [(x + 260, 90), (x + 360, 90), (x + 360, 170), (x + 260, 170)], hexc("#A0927A"), tex=0.1, ink=0.8)
    else:  # bare planks (back rooms)
        x = 0
        while x < W:
            w = c.rng.uniform(70, 110)
            pf(c, [(x, 0), (x + w, 0), (x + w, base), (x, base)], mix(WOOD, DARK, c.rng.uniform(0.1, 0.35)), tex=0.35, cell=8, ink=1.2)
            x += w
    pf(c, [(0, base), (W, base), (W, H), (0, H)], mix(DARK, WOOD_D, 0.4), tex=0.3, ink=0)
    c.ink([(0, base), (W, base)], width=3.0)
    rel = f"world/interior/template_wall_{kind}.png"
    c.save(out(rel), winter=False)
    entry(f"int.wall_{kind}", f"Interior back wall ({kind})", rel, (W // 2, H // 2), (W, H), (0.5, 1.0))


def floor_tile(kind):
    n = 256
    rng = np.random.default_rng(len(kind) * 11)
    nz = value_noise(n, n, 32, int(rng.integers(1 << 20)), octaves=4, wrap=True)
    fine = value_noise(n, n, 6, int(rng.integers(1 << 20)), octaves=2, wrap=True)
    if kind == "linoleum":
        yy, xx = np.mgrid[0:n, 0:n]
        check = ((xx // 64 + yy // 64) % 2).astype(np.float32)
        a, b = np.array([176, 168, 150]), np.array([96, 102, 98])
        base = a[None, None, :] * (1 - check[..., None]) + b[None, None, :] * check[..., None]
        shade = 0.8 + (nz - 0.5) * 0.35 + (fine - 0.5) * 0.12
    elif kind == "concrete":
        base = np.array([104, 102, 96])[None, None, :] * np.ones((n, n, 1))
        shade = 0.85 + (nz - 0.5) * 0.4 + (fine - 0.5) * 0.15
    else:  # carpet
        base = np.array([92, 66, 60])[None, None, :] * np.ones((n, n, 1))
        shade = 0.85 + (nz - 0.5) * 0.3 + (fine - 0.5) * 0.25
    rgb = np.clip(base * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, np.full((n, n), 255, np.uint8)]), "RGBA")
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(len(kind) * 5)
    if kind == "linoleum":
        for v in range(0, n, 64):
            d.line((0, v, n, v), fill=(40, 36, 30, 110), width=1)
            d.line((v, 0, v, n), fill=(40, 36, 30, 110), width=1)
    for _ in range(14):  # scuffs, cracks, stains
        x, y = r.uniform(0, n), r.uniform(0, n)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.line((x + ox, y + oy, x + ox + r.uniform(-30, 30), y + oy + r.uniform(-12, 12)), fill=(30, 26, 22, 90), width=1)
    rel = f"world/interior/template_floor_{kind}.png"
    img.save(out(rel))
    entry(f"int.floor_{kind}", f"Interior floor ({kind}, seamless tile)", rel, (256, 256), (256, 256), (0, 0), "Generated seamless tile.")


# ------------------------------------------------------------------ store fixtures
def gondola(stock):
    def d(c, W, H, base):
        shadow(c, W, base)
        pf(c, [(20, 40), (W - 20, 40), (W - 20, base - 4), (20, base - 4)], METAL_D, ink=2.2)
        for k, y in enumerate((70, 130, 190)):
            box(c, 26, y, W - 26, y + 18, METAL_L, depth=8, ink=1.4)
            if stock == "empty":
                if k == 1:
                    pf(c, [(W * 0.6, y - 16), (W * 0.6 + 18, y - 16), (W * 0.6 + 18, y), (W * 0.6, y)], FOOD[0], ink=1.0)
                continue
            x = 34
            while x < W - 50:
                if stock == "full" or c.rng.random() < 0.3:
                    h = c.rng.uniform(22, 40)
                    w = c.rng.uniform(16, 28)
                    pf(c, [(x, y - h), (x + w, y - h), (x + w, y), (x, y)], c.rng.choice(FOOD), tex=0.3, ink=1.0)
                x += c.rng.uniform(20, 36)
        if stock == "empty":  # something knocked to the floor
            pf(c, [(W * 0.3, base - 14), (W * 0.3 + 22, base - 18), (W * 0.3 + 26, base - 6), (W * 0.3 + 4, base - 2)], FOOD[2], ink=1.0)
    return d


def checkout(c, W, H, base):
    shadow(c, W, base)
    box(c, 20, 60, W - 20, base - 4, mix(PAINT_R, WOOD_D, 0.4), depth=34)
    box(c, W - 130, 30, W - 50, 70, METAL_D, depth=14, ink=1.6)  # till, drawer hanging open
    pf(c, [(W - 128, 84), (W - 52, 84), (W - 46, 100), (W - 122, 100)], METAL_L, ink=1.4)
    pf(c, [(40, 50), (W - 160, 50), (W - 160, 60), (40, 60)], DARK, ink=1.0)  # conveyor


def freezer(opened):
    def d(c, W, H, base):
        shadow(c, W, base)
        box(c, 16, 50, W - 16, base - 4, hexc("#B9BDB6"), depth=50, top_col=hexc("#5E7A84"))
        for x in range(36, W - 20, (W - 40) // 3):
            c.ink([(x, 56), (x, 96)], width=1.6)
        if opened:
            pf(c, [(W * 0.36, 30), (W * 0.62, 26), (W * 0.62, 56), (W * 0.36, 60)], hexc("#7C949A"), ink=1.6)
        for _ in range(5):
            x = c.rng.uniform(30, W - 50)
            c.ink([(x, 60), (x + 30, 90)], width=1.0, color=hexc("#D8E4E8"), alpha=150)
    return d


def clothes_rack(state):
    def d(c, W, H, base):
        shadow(c, W, base, a=70)
        for x in (24, W - 24):
            c.ink([(x, 40), (x, base - 6)], width=5, color=METAL_D)
        c.ink([(16, 40), (W - 16, 40)], width=5, color=METAL_D)
        n = 7 if state == "full" else 2
        for i in range(n):
            x = 40 + i * (W - 80) / max(1, n - 1) if n > 1 else W / 2
            c.ink([(x, 40), (x, 50)], width=1.4)
            coat = [(x - 16, 50), (x + 16, 50), (x + 20, 140), (x - 20, 140)]
            pf(c, coat, c.rng.choice([CLOTH_B, CLOTH_P, CLOTH_O]), ink=1.4, tex=0.35)
        if state == "empty":
            for i in range(4):
                x = 60 + i * 40
                c.ink([(x - 10, 46), (x, 40), (x + 10, 46)], width=1.4, color=METAL_D)
    return d


def display_table(c, W, H, base):
    shadow(c, W, base)
    box(c, 16, 50, W - 16, base - 6, WOOD, depth=34)
    for i in range(4):
        x = 34 + i * 54
        pf(c, [(x, 40), (x + 40, 40), (x + 40, 58), (x, 58)], c.rng.choice([CLOTH_B, CLOTH_P, CLOTH_O]), ink=1.2)


def pegboard(c, W, H, base):
    pf(c, [(10, 10), (W - 10, 10), (W - 10, base - 4), (10, base - 4)], hexc("#8A7A5A"), ink=2.2, cell=6)
    for y in range(24, base - 10, 14):
        for x in range(20, W - 16, 14):
            c.ellipse_fill((x - 1.4, y - 1.4, x + 1.4, y + 1.4), hexc("#3A3226"))
    for x0 in (40, 110, 170, 260, 330):  # outlines where tools hung, a few still there
        c.ink([(x0, 40), (x0 + 8, 110)], width=1.0, color=hexc("#F0E6CC"), alpha=140)
    c.ink([(110, 40), (118, 110)], width=6, color=METAL_D)
    c.ink([(260, 50), (300, 50)], width=5, color=PAINT_R)


def metal_shelf(state):
    def d(c, W, H, base):
        shadow(c, W, base)
        for x in (18, W - 18):
            c.ink([(x, 20), (x, base - 4)], width=6, color=METAL_D)
        for y in (50, 120, 190, base - 16):
            box(c, 14, y, W - 14, y + 12, METAL, depth=6, ink=1.4)
        if state != "empty":
            for y in (50, 120, 190):
                for x in range(26, W - 60, 48):
                    if state == "full" or c.rng.random() < 0.35:
                        box(c, x, y - 34, x + 40, y, c.rng.choice([hexc("#7A6A4A"), hexc("#5A6A72"), PAINT_R]), depth=8, ink=1.2)
    return d


def pharm_counter(c, W, H, base):
    shadow(c, W, base)
    box(c, 14, 60, W - 14, base - 4, hexc("#C8C6BC"), depth=36)
    pf(c, [(W / 2 - 12, 80), (W / 2 + 12, 80), (W / 2 + 12, 120), (W / 2 - 12, 120)], hexc("#4E8A6C"), ink=0)
    pf(c, [(W / 2 - 24, 92), (W / 2 + 24, 92), (W / 2 + 24, 108), (W / 2 - 24, 108)], hexc("#4E8A6C"), ink=0)
    for x in (40, 90):
        pf(c, [(x, 40), (x + 30, 40), (x + 30, 62), (x, 62)], hexc("#E8E4D8"), ink=1.0)


def med_cabinet(opened):
    def d(c, W, H, base):
        shadow(c, W, base, a=70)
        box(c, 14, 20, W - 14, base - 4, hexc("#D8D6CC"), depth=14)
        if opened:
            pf(c, [(W - 18, 40), (W + 0, 46), (W + 0, base - 20), (W - 18, base - 14)], hexc("#E0DED4"), ink=1.4)
            pf(c, [(20, 40), (W - 20, 40), (W - 20, base - 12), (20, base - 12)], hexc("#3A3834"), ink=1.2)
            for y in (80, 130):
                c.ink([(22, y), (W - 22, y)], width=2, color=hexc("#9A988E"))
        else:
            c.ink([(W / 2, 36), (W / 2, base - 12)], width=1.6)
            pf(c, [(W / 2 - 6, 60), (W / 2 + 6, 60), (W / 2 + 6, 84), (W / 2 - 6, 84)], hexc("#A82C24"), ink=0)
            pf(c, [(W / 2 - 14, 66), (W / 2 + 14, 66), (W / 2 + 14, 78), (W / 2 - 14, 78)], hexc("#A82C24"), ink=0)
    return d


def tool_chest(opened):
    def d(c, W, H, base):
        shadow(c, W, base)
        box(c, 12, 40, W - 12, base - 12, hexc("#8E2E22"), depth=18)
        for y in range(70, base - 20, 22):
            c.ink([(16, y), (W - 16, y)], width=1.4)
            c.ink([(W / 2 - 14, y + 10), (W / 2 + 14, y + 10)], width=2.4, color=METAL_L)
        if opened:
            pf(c, [(16, 74), (W - 16, 74), (W - 10, 96), (10, 96)], hexc("#A23A2C"), ink=1.6)
            pf(c, [(22, 78), (W - 22, 78), (W - 22, 88), (22, 88)], DARK, ink=0)
        for x in (24, W - 24):
            c.ellipse_fill((x - 7, base - 16, x + 7, base - 2), DARK)
    return d


def car_lift(c, W, H, base):
    shadow(c, W, base)
    for x in (30, W - 30):
        box(c, x - 14, 30, x + 14, base - 4, hexc("#B5822E"), depth=10)
    box(c, 40, base - 70, W - 40, base - 56, METAL_D, depth=8)
    pf(c, [(60, base - 40), (W - 60, base - 40), (W - 60, base - 30), (60, base - 30)], hexc("#2A2620"), ink=0)  # oil stain


def locker(opened):
    def d(c, W, H, base):
        shadow(c, W, base, a=70)
        box(c, 10, 14, W - 10, base - 4, hexc("#4E5A4A"), depth=12)
        for y in (40, 52, 64):
            c.ink([(20, y), (W - 26, y)], width=1.2, alpha=160)
        if opened:
            pf(c, [(W - 14, 30), (W + 2, 36), (W + 2, base - 14), (W - 14, base - 8)], hexc("#5E6A5A"), ink=1.4)
            pf(c, [(16, 30), (W - 16, 30), (W - 16, base - 10), (16, base - 10)], DARK, ink=1.0)
        else:
            c.ellipse_fill((W - 22, H * 0.45, W - 16, H * 0.45 + 8), METAL_L)
    return d


def crate(opened):
    def d(c, W, H, base):
        shadow(c, W, base)
        box(c, 12, 30, W - 12, base - 4, WOOD, depth=22)
        c.ink([(14, 54), (W - 14, base - 6)], width=2.0)
        c.ink([(14, base - 6), (W - 14, 54)], width=2.0)
        if opened:
            pf(c, [(12, 30), (W - 12, 30), (W - 2, 10), (22, 10)], WOOD_L, ink=1.6)
            pf(c, [(16, 32), (W - 16, 32), (W - 16, 50), (16, 50)], DARK, ink=0)
    return d


def boxes(c, W, H, base):
    shadow(c, W, base)
    box(c, 10, 40, 90, base - 4, hexc("#A08660"), depth=16)
    box(c, 70, 20, 150, base - 30, hexc("#B09670"), depth=16)
    c.ink([(20, 60), (80, 60)], width=1.0, alpha=120)


# ------------------------------------------------------------------ household
def sofa(c, W, H, base):
    shadow(c, W, base)
    box(c, 14, 30, W - 14, base - 6, hexc("#5C4A3E"), depth=30)
    box(c, 28, 66, W - 28, base - 14, hexc("#6E5848"), depth=18)
    pf(c, [(W * 0.55, 70), (W * 0.75, 66), (W * 0.78, 84), (W * 0.56, 88)], CLOTH_O, ink=1.2)  # a folded blanket


def armchair(c, W, H, base):
    shadow(c, W, base)
    box(c, 14, 30, W - 14, base - 6, hexc("#6A5040"), depth=26)
    box(c, 26, 64, W - 26, base - 14, hexc("#7A5E4C"), depth=14)


def dresser(opened):
    def d(c, W, H, base):
        shadow(c, W, base)
        box(c, 12, 30, W - 12, base - 6, WOOD, depth=18)
        for y in range(62, base - 14, 30):
            c.ink([(18, y), (W - 18, y)], width=1.4)
            c.ellipse_fill((W / 2 - 4, y + 12, W / 2 + 4, y + 18), hexc("#B59A5A"))
        if opened:
            pf(c, [(16, 92), (W - 16, 92), (W - 8, 112), (8, 112)], WOOD_L, ink=1.6)
            pf(c, [(20, 96), (W - 20, 96), (W - 20, 104), (20, 104)], DARK, ink=0)
    return d


def home_fridge(opened):
    def d(c, W, H, base):
        shadow(c, W, base, a=70)
        box(c, 10, 10, W - 10, base - 4, hexc("#D2CEC0"), depth=12)
        c.ink([(14, H * 0.38), (W - 14, H * 0.38)], width=1.4)
        if opened:
            pf(c, [(W - 14, 24), (W + 2, 30), (W + 2, base - 10), (W - 14, base - 4)], hexc("#DCD8CA"), ink=1.4)
            pf(c, [(16, 26), (W - 16, 26), (W - 16, base - 8), (16, base - 8)], hexc("#2A2A26"), ink=1.0)
            for y in (60, 110, 160):
                c.ink([(18, y), (W - 18, y)], width=1.6, color=hexc("#8E8C84"))
        else:
            c.ink([(W - 20, 30), (W - 20, 60)], width=3, color=METAL_D)
    return d


def kitchen_counter(c, W, H, base):
    shadow(c, W, base)
    box(c, 12, 46, W - 12, base - 4, hexc("#7A6E5A"), depth=30, top_col=hexc("#A49C88"))
    pf(c, [(W * 0.55, 52), (W * 0.8, 52), (W * 0.8, 70), (W * 0.55, 70)], METAL_D, ink=1.4)  # sink
    for x in (30, 70):  # dirty dishes
        c.ellipse_fill((x, 50, x + 26, 62), hexc("#D8D2C2"))


def bookshelf(c, W, H, base):
    shadow(c, W, base, a=70)
    box(c, 10, 14, W - 10, base - 4, WOOD_D, depth=12)
    for y in (60, 110, 160, 210):
        c.ink([(16, y), (W - 16, y)], width=2.0)
        x = 18
        while x < W - 30:
            if c.rng.random() < 0.6:
                w = c.rng.uniform(6, 12)
                pf(c, [(x, y - c.rng.uniform(24, 36)), (x + w, y - 32), (x + w, y), (x, y)], c.rng.choice([CLOTH_B, PAINT_R, CLOTH_O, WOOD_L]), ink=0.8)
            x += c.rng.uniform(8, 16)


def meal_table(c, W, H, base):
    shadow(c, W, base)
    box(c, 20, 40, W - 20, base - 30, WOOD, depth=40)
    for x in (30, W - 30):
        c.ink([(x, 80), (x, base - 4)], width=6, color=WOOD_D)
    for x, y in ((60, 54), (150, 52), (110, 66)):  # three plates, food left to freeze
        c.ellipse_fill((x, y, x + 34, y + 14), hexc("#D8D2C2"))
        c.ellipse_fill((x + 8, y + 3, x + 22, y + 10), hexc("#7A5A3A"))
    pf(c, [(200, 46), (214, 46), (214, 66), (200, 66)], hexc("#8E9A9E"), ink=1.0)  # a cup
    c.ink([(184, 70), (206, 72)], width=1.4)  # a spoon


def barricade(c, W, H, base):
    shadow(c, W, base)
    box(c, 20, 60, 140, base - 4, WOOD_D, depth=24)  # an upturned table
    for k in range(5):
        y = 30 + k * 18
        c.ink([(60 + k * 6, y), (W - 20, y + 20)], width=9, color=mix(WOOD, DARK, 0.2))
        c.ink([(60 + k * 6, y), (W - 20, y + 20)], width=1.4)
    box(c, W - 110, 40, W - 30, base - 8, hexc("#5C4A3E"), depth=18)  # a chair jammed in


def partition(c, W, H, base):
    pf(c, [(0, 0), (W, 0), (W, base - 30), (0, base - 30)], mix(PAINT_C, PAINT_G, 0.3), tex=0.3, ink=2.2)
    pf(c, [(0, base - 30), (W, base - 30), (W, base), (0, base)], mix(DARK, WOOD_D, 0.4), tex=0.3, ink=2.0)
    pf(c, [(0, -2), (W, -2), (W, 14), (0, 14)], WOOD_D, ink=1.6)


def garage_shelf(state):
    return metal_shelf(state)


# ------------------------------------------------------------------ bunker improvement: wood stove
def stove_top(c, W, H, base):
    shadow(c, W, base)
    box(c, 20, 70, W - 20, base - 6, hexc("#2E2C2A"), depth=26, top_col=hexc("#4A4642"))
    pf(c, [(W / 2 - 30, 116), (W / 2 + 30, 116), (W / 2 + 30, 150), (W / 2 - 30, 150)], hexc("#E07A2A"), ink=1.6)
    for x in range(W // 2 - 26, W // 2 + 28, 10):
        c.ink([(x, 118), (x, 148)], width=2, color=hexc("#2E2C2A"))
    box(c, W / 2 - 14, 4, W / 2 + 14, 80, hexc("#3A3836"), depth=8, ink=1.8)  # pipe
    c.ellipse_fill((W / 2 - 26, 134, W / 2 + 26, 166), hexc("#F0A050"), )


def stove_side(c, W, H, base):
    pf(c, [(W / 2 - 13, 0), (W / 2 + 13, 0), (W / 2 + 13, base - 150), (W / 2 - 13, base - 150)], hexc("#3A3836"), ink=1.8)
    for y in range(40, base - 160, 120):
        pf(c, [(W / 2 - 17, y), (W / 2 + 17, y), (W / 2 + 17, y + 10), (W / 2 - 17, y + 10)], hexc("#2A2826"), ink=1.2)
    body = [(30, base - 150), (W - 30, base - 150), (W - 26, base - 18), (26, base - 18)]
    pf(c, body, hexc("#2E2C2A"), ink=2.4)
    pf(c, [(W / 2 - 36, base - 110), (W / 2 + 36, base - 110), (W / 2 + 36, base - 50), (W / 2 - 36, base - 50)], hexc("#E07A2A"), ink=1.8)
    for x in range(W // 2 - 30, W // 2 + 34, 12):
        c.ink([(x, base - 108), (x, base - 52)], width=2.4, color=hexc("#2E2C2A"))
    for x in (40, W - 40):
        c.ink([(x, base - 18), (x - 4, base - 2)], width=6, color=hexc("#2A2826"))
    pf(c, [(20, base - 160), (W - 20, base - 160), (W - 20, base - 146), (20, base - 146)], hexc("#4A4642"), ink=1.6)


def stovepipe_item(c, W, H, base):
    pf(c, [(10, 14), (W - 20, 14), (W - 20, H - 14), (10, H - 14)], hexc("#3A3836"), ink=1.8)
    c.ellipse_fill((W - 30, 12, W - 8, H - 12), hexc("#5A5652"))
    c.ink_poly(c.blob(W - 19, H / 2, 11, (H - 24) / 2, n=12, irregular=0.03), width=1.6)
    for x in (30, 60):
        c.ink([(x, 14), (x, H - 14)], width=1.2, alpha=150)


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_circuit.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "circuit", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("scavenger's circuit art generated:", len(ENTRIES))


if __name__ == "__main__":
    for k in ("shop", "garage", "house", "planks"):
        back_wall(k)
    for k in ("linoleum", "concrete", "carpet"):
        floor_tile(k)
    I = "world/interior/"
    for st in ("full", "sparse", "empty"):
        sprite(f"int.gondola_{st}", f"Store aisle shelf ({st})", f"{I}template_gondola_{st}.png", 460, 280, 266, gondola(st))
    sprite("int.checkout", "Checkout counter", f"{I}template_checkout.png", 420, 220, 208, checkout)
    sprite("int.freezer", "Glass-top freezer", f"{I}template_freezer.png", 360, 240, 228, freezer(False))
    sprite("int.freezer_open", "Glass-top freezer (lid up, emptied)", f"{I}template_freezer_open.png", 360, 240, 228, freezer(True))
    for st in ("full", "empty"):
        sprite(f"int.clothes_rack_{st}", f"Clothes rack ({st})", f"{I}template_clothes_rack_{st}.png", 320, 240, 230, clothes_rack(st))
    sprite("int.display_table", "Display table with folded clothes", f"{I}template_display_table.png", 300, 160, 150, display_table)
    sprite("int.pegboard", "Tool pegboard (most tools gone)", f"{I}template_pegboard.png", 400, 240, 236, pegboard)
    for st in ("full", "empty"):
        sprite(f"int.metal_shelf_{st}", f"Metal shelving with bins ({st})", f"{I}template_metal_shelf_{st}.png", 360, 300, 290, metal_shelf(st))
    sprite("int.pharm_counter", "Pharmacy counter", f"{I}template_pharm_counter.png", 440, 220, 208, pharm_counter)
    sprite("int.med_cabinet", "Medicine cabinet", f"{I}template_med_cabinet.png", 180, 260, 250, med_cabinet(False))
    sprite("int.med_cabinet_open", "Medicine cabinet (open, emptied)", f"{I}template_med_cabinet_open.png", 180, 260, 250, med_cabinet(True))
    sprite("int.tool_chest", "Rolling tool chest", f"{I}template_tool_chest.png", 180, 220, 210, tool_chest(False))
    sprite("int.tool_chest_open", "Rolling tool chest (drawer open)", f"{I}template_tool_chest_open.png", 180, 220, 210, tool_chest(True))
    sprite("int.car_lift", "Car lift (posts and arms)", f"{I}template_car_lift.png", 520, 200, 190, car_lift)
    sprite("int.locker", "Metal locker", f"{I}template_locker.png", 140, 300, 290, locker(False))
    sprite("int.locker_open", "Metal locker (open)", f"{I}template_locker_open.png", 140, 300, 290, locker(True))
    sprite("int.crate", "Wooden crate", f"{I}template_crate.png", 200, 160, 152, crate(False))
    sprite("int.crate_open", "Wooden crate (lid off)", f"{I}template_crate_open.png", 200, 160, 152, crate(True))
    sprite("int.boxes", "Cardboard boxes", f"{I}template_boxes.png", 160, 140, 132, boxes)
    sprite("int.sofa", "Sofa", f"{I}template_sofa.png", 360, 180, 170, sofa)
    sprite("int.armchair", "Armchair", f"{I}template_armchair.png", 180, 170, 160, armchair)
    sprite("int.dresser", "Chest of drawers", f"{I}template_dresser.png", 240, 220, 210, dresser(False))
    sprite("int.dresser_open", "Chest of drawers (drawer pulled out)", f"{I}template_dresser_open.png", 240, 220, 210, dresser(True))
    sprite("int.home_fridge", "Kitchen fridge", f"{I}template_home_fridge.png", 160, 300, 290, home_fridge(False))
    sprite("int.home_fridge_open", "Kitchen fridge (open, emptied)", f"{I}template_home_fridge_open.png", 160, 300, 290, home_fridge(True))
    sprite("int.kitchen_counter", "Kitchen counter with sink", f"{I}template_kitchen_counter.png", 400, 220, 208, kitchen_counter)
    sprite("int.bookshelf", "Bookshelf", f"{I}template_bookshelf.png", 220, 300, 290, bookshelf)
    sprite("int.meal_table", "Table laid for a meal nobody finished", f"{I}template_meal_table.png", 300, 220, 210, meal_table)
    sprite("int.barricade", "Improvised barricade (table, planks, chair)", f"{I}template_barricade.png", 320, 200, 190, barricade)
    sprite("int.partition", "Interior partition wall", f"{I}template_partition.png", 400, 300, 300, partition)
    sprite("build.stove", "Wood stove (bunker improvement, top-down)", "build/template_stove.png", 200, 240, 230, stove_top)
    sprite("side.stove", "Side view: wood stove with its pipe through the ceiling", "side/template_stove.png", 200, 520, 512, stove_side)
    sprite("item.stovepipe", "Stovepipe (item)", "items/template_stovepipe.png", 120, 60, 30, stovepipe_item)
    write_manifest()
