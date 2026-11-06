#!/usr/bin/env python3
"""Red Thaw — side-view building interiors (iteration 014, The Five Settlements).

Ordinary buildings (the hunter's cabin, houses, shops, the multi-storey block)
and the mine are shown as cross-sections, like the bunker. This draws what
they need: interior wall coverings (log wall, wallpaper, shop paint, brick,
office plaster, mine rock face), exterior wall materials seen in section (logs,
siding, brick, concrete), floor and ceiling strips (linoleum, concrete,
plaster), windows (lit / boarded), the front door, a staircase flight, the
floor trapdoor stages of the cabin's shelter hatch, and a few side-view
furniture pieces that only make sense from the side.

Writes templates under assets/templates/side/ and
assets/manifest/visual_side_interiors.json. Never touches creator overrides.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, value_noise  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []

TIMBER, TIMBER_D, TIMBER_L = hexc("#7A5E40"), hexc("#4E3A26"), hexc("#9A7A55")
STEEL, STEEL_D = hexc("#5E6467"), hexc("#3A3E40")
CONC, CONC_D = hexc("#8A877F"), hexc("#5E5B55")
PANE = hexc("#B9C6CF")
WARM = hexc("#E8C27A")


def out(rel):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_side_interiors.py) - replace with tablet art."})


def pf(c, pts, col, tex=0.3, cell=8, ink=2.0, light=(-1, -1, 0.3)):
    m = c.fill(pts, col, tex=tex, cell=cell, light=light)
    if ink:
        c.ink_poly(pts, width=ink)
    return m


# ------------------------------------------------------------------ seamless tiles
def tile(name, label, base, kind, size=256):
    n = size
    rng = np.random.default_rng(len(name) * 131 + 7)
    nz = value_noise(n, n, 24, int(rng.integers(1 << 20)), octaves=4, wrap=True)
    fine = value_noise(n, n, 6, int(rng.integers(1 << 20)), octaves=2, wrap=True)
    b = np.array(base[:3], dtype=np.float32)
    yy, xx = np.mgrid[0:n, 0:n]
    shade = 0.86 + (nz - 0.5) * 0.25 + (fine - 0.5) * 0.12
    if kind == "logs":       # stacked round logs, horizontal
        band = (yy % 32) / 32.0
        shade = shade * (0.78 + 0.32 * np.sin(band * math.pi))
    elif kind == "siding":   # lap siding boards
        band = (yy % 24) / 24.0
        shade = shade * (0.82 + 0.22 * band)
    elif kind == "brick":
        row = yy // 16
        off = (row % 2) * 24
        mortar = ((yy % 16) < 2) | (((xx + off) % 48) < 2)
        shade = np.where(mortar, 1.25, shade * (0.85 + 0.15 * ((row * 7 + (xx + off) // 48 * 3) % 5) / 5.0))
    elif kind == "wallpaper":  # faded vertical stripes with a small motif
        stripe = ((xx // 16) % 2) * 0.06
        shade = shade * (0.92 + stripe)
    elif kind == "panel":    # shop wall: paint above, tiles below
        tiles = (yy > n * 0.55) & (((yy % 32) < 2) | ((xx % 32) < 2))
        shade = np.where(tiles, shade * 0.7, shade * np.where(yy > n * 0.55, 1.04, 0.96))
    elif kind == "plaster":
        shade = 0.9 + (nz - 0.5) * 0.18 + (fine - 0.5) * 0.08
    elif kind == "minerock":
        shade = 0.7 + (nz - 0.5) * 0.55 + (fine - 0.5) * 0.25
    rgb = np.clip(b[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, np.full((n, n), 255, np.uint8)]), "RGBA")
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(len(name) * 17)
    if kind == "logs":
        for y in range(0, n, 32):
            d.line((0, y, n, y), fill=(28, 20, 14, 200), width=2)
        for _ in range(6):
            x, y = r.uniform(0, n), r.integers(0, n // 32) * 32 + 16
            for ox in (-n, 0, n):
                d.ellipse((x + ox - 5, y - 4, x + ox + 5, y + 4), outline=(40, 28, 18, 180), width=1)
    elif kind == "siding":
        for y in range(0, n, 24):
            d.line((0, y, n, y), fill=(30, 26, 22, 190), width=2)
    elif kind == "wallpaper":
        for yv in range(8, n, 32):
            for xv in range(8, n, 32):
                d.ellipse((xv - 2, yv - 2, xv + 2, yv + 2), fill=tuple(int(v * 0.7) for v in base[:3]) + (180,))
        for _ in range(5):  # water stains
            x, y = r.uniform(0, n), r.uniform(0, n * 0.4)
            for ox in (-n, 0, n):
                d.line((x + ox, y, x + ox + r.uniform(-3, 3), y + r.uniform(30, 80)), fill=(70, 58, 40, 70), width=6)
    elif kind in ("plaster", "panel"):
        for _ in range(6):
            x, y = r.uniform(0, n), r.uniform(0, n)
            for ox in (-n, 0, n):
                d.line((x + ox, y, x + ox + r.uniform(-20, 20), y + r.uniform(6, 24)), fill=(40, 38, 34, 110), width=1)
    elif kind == "minerock":
        for _ in range(14):
            x, y, rr = r.uniform(0, n), r.uniform(0, n), r.uniform(4, 14)
            for ox in (-n, 0, n):
                d.ellipse((x - rr + ox, y - rr * 0.7, x + rr + ox, y + rr * 0.7), outline=(26, 24, 22, 190), width=2)
    rel = f"side/template_{name}.png"
    img.save(out(rel))
    entry("side." + name, label, rel, (size, size), (size, size), (0, 0), "Generated seamless tile (tools/art/gen_side_interiors.py).")


def strip(name, label, kind, W=256, H=24):
    c = Canvas(W, H, seed=21000 + len(name))
    if kind == "linoleum":
        pf(c, [(0, 3), (W, 3), (W, H), (0, H)], hexc("#7E7F74"), ink=0)
        for x in range(0, W, 32):
            c.ink([(x, 3), (x, H)], width=1.0, alpha=120)
        c.ink([(0, 3), (W, 3)], width=2.2)
    elif kind == "concrete":
        pf(c, [(0, 3), (W, 3), (W, H), (0, H)], CONC_D, ink=0)
        c.ink([(0, 3), (W, 3)], width=2.4)
    elif kind == "plaster":  # ceiling
        pf(c, [(0, 0), (W, 0), (W, H - 6), (0, H - 6)], hexc("#8D8676"), ink=0)
        c.ink([(0, H - 6), (W, H - 6)], width=2.0)
    elif kind == "rail":  # mine-cart rail on the floor
        pf(c, [(0, 8), (W, 8), (W, H), (0, H)], hexc("#3E342A"), ink=0)
        for x in range(8, W, 32):
            pf(c, [(x, 10), (x + 18, 10), (x + 18, 16), (x, 16)], TIMBER_D, ink=1.0)
        c.ink([(0, 9), (W, 9)], width=2.6, color=STEEL_D)
    rel = f"side/template_{name}.png"
    c.save(out(rel), finish=False, winter=False)
    entry("side." + name, label, rel, (W, H), (W, H), (0, 0), "Generated tileable strip (tools/art/gen_side_interiors.py).")


def sprite(name, label, W, H, pivot, draw, display=None):
    c = Canvas(W, H, seed=22000 + len(name) * 13)
    draw(c, W, H)
    rel = f"side/template_{name}.png"
    c.save(out(rel), winter=False)
    entry("side." + name, label, rel, display or (W // 2, H // 2), (W, H), pivot)


# ------------------------------------------------------------------ sprites
def d_window(boarded):
    def d(c, W, H):
        pf(c, [(6, 6), (W - 6, 6), (W - 6, H - 6), (6, H - 6)], TIMBER_D, ink=2.4)
        pf(c, [(16, 16), (W - 16, 16), (W - 16, H - 16), (16, H - 16)], PANE if not boarded else hexc("#1A1714"), ink=1.6, tex=0.15)
        c.ink([(W / 2, 16), (W / 2, H - 16)], width=2.2)
        c.ink([(16, H / 2), (W - 16, H / 2)], width=2.2)
        if boarded:
            for y in (H * 0.3, H * 0.55, H * 0.78):
                pf(c, [(2, y - 9), (W - 2, y - 14), (W - 2, y + 2), (2, y + 7)], TIMBER, ink=1.8, cell=5)
        else:
            c.ink([(22, H - 26), (W / 2 - 8, 24)], width=1.0, alpha=120, color=hexc("#FFFFFF"))
    return d


def d_door_ext(c, W, H):
    pf(c, [(4, 4), (W - 4, 4), (W - 4, H - 2), (4, H - 2)], TIMBER_D, ink=2.4)
    pf(c, [(14, 14), (W - 14, 14), (W - 14, H - 4), (14, H - 4)], TIMBER, ink=1.8, cell=5)
    for y in (H * 0.25, H * 0.6):
        pf(c, [(22, y), (W - 22, y), (W - 22, y + H * 0.25), (22, y + H * 0.25)], TIMBER_L, ink=1.2)
    c.ellipse_fill((W - 30, H * 0.52, W - 20, H * 0.52 + 10), STEEL)
    pf(c, [(0, H - 10), (W, H - 10), (W, H), (0, H)], hexc("#DCE3E8"), ink=0, tex=0.1)  # snow at the threshold


def d_stairs(c, W, H):
    steps = 10
    sw, sh = (W - 20) / steps, (H - 12) / steps
    for i in range(steps):
        x0 = 10 + i * sw
        y1 = H - 6 - i * sh
        pf(c, [(x0, y1 - sh), (x0 + sw + 2, y1 - sh), (x0 + sw + 2, H - 6), (x0, H - 6)], TIMBER if i % 2 else TIMBER_L, ink=1.4, cell=5)
    c.ink([(10, H - 6), (W - 10, 6)], width=2.6)
    for i in range(0, steps + 1, 2):  # banister posts
        x = 10 + i * sw
        y = H - 6 - i * sh
        c.ink([(x, y - sh), (x, y - sh - 46)], width=2.0)
    c.ink([(10, H - 6 - sh - 46), (W - 10, 6 - sh - 46 + 6)], width=3.0)


def d_trapdoor(stage):
    def d(c, W, H):
        base = H - 18
        pf(c, [(0, base), (W, base), (W, H), (0, H)], TIMBER_D, ink=1.6, cell=5)  # floor section
        if stage == "marked":
            for x in range(18, W - 18, 22):
                c.ink([(x, base - 4), (x + 12, base - 4)], width=2.2, color=hexc("#D9D2C0"))
        elif stage == "digging":
            pf(c, [(W * 0.25, base), (W * 0.75, base), (W * 0.7, H), (W * 0.3, H)], hexc("#141210"), ink=1.4)
            c.blob(W * 0.82, base - 10, 22, 12)
            pf(c, [(W * 0.68, base - 4), (W * 0.96, base - 4), (W * 0.9, base - 24), (W * 0.74, base - 22)], hexc("#4A3A2C"), ink=1.6)
        elif stage in ("closed", "steel_closed"):
            col = STEEL if stage.startswith("steel") else TIMBER
            pf(c, [(W * 0.2, base - 8), (W * 0.8, base - 8), (W * 0.8, base + 2), (W * 0.2, base + 2)], col, ink=2.0)
            c.ellipse_fill((W / 2 - 6, base - 16, W / 2 + 6, base - 8), STEEL_D)
        else:  # open: the lid stands up, a dark slot in the floor
            col = STEEL if stage.startswith("steel") else TIMBER
            pf(c, [(W * 0.25, base), (W * 0.75, base), (W * 0.75, H), (W * 0.25, H)], hexc("#141210"), ink=1.4)
            pf(c, [(W * 0.72, base), (W * 0.82, base), (W * 0.9, base - H * 0.62), (W * 0.8, base - H * 0.64)], col, ink=2.0)
    return d


def d_mine_cart(c, W, H):
    pf(c, [(14, 30), (W - 14, 30), (W - 26, H - 26), (26, H - 26)], STEEL, ink=2.4)
    c.blob(W / 2, 32, W * 0.34, 14)
    pf(c, [(W * 0.2, 22), (W * 0.8, 22), (W * 0.7, 40), (W * 0.3, 40)], hexc("#3B3A36"), ink=1.6)
    for x in (W * 0.3, W * 0.7):
        c.ellipse_fill((x - 14, H - 34, x + 14, H - 6), STEEL_D)


def d_mine_beam(c, W, H):
    for x in (10, W - 10):
        pf(c, [(x - 9, 14), (x + 9, 14), (x + 9, H), (x - 9, H)], TIMBER, ink=2.0, cell=5)
    pf(c, [(0, 0), (W, 0), (W, 22), (0, 22)], TIMBER_D, ink=2.0, cell=5)


def d_rubble(c, W, H):
    for i in range(9):
        x = 14 + (i * 37) % (W - 28)
        y = H - 12 - (i % 3) * 22
        rr = 18 + (i * 5) % 14
        pf(c, [(x - rr, y), (x - rr * 0.4, y - rr), (x + rr * 0.6, y - rr * 0.8), (x + rr, y)], hexc("#5B5A55"), ink=1.8)
    pf(c, [(W * 0.15, H - 70), (W * 0.85, H - 120), (W * 0.88, H - 106), (W * 0.18, H - 56)], TIMBER_D, ink=2.0, cell=5)


def d_ore(c, W, H):
    pf(c, [(8, H), (W * 0.3, 18), (W * 0.7, 8), (W - 8, H)], hexc("#4A4642"), ink=2.2)
    for i in range(7):
        x, y = 24 + (i * 29) % (W - 48), 30 + (i * 23) % (H - 50)
        c.ellipse_fill((x - 6, y - 4, x + 6, y + 4), hexc("#9A8A62"))


def d_lamp_post(c, W, H):  # a miner's wall lamp on a bracket
    pf(c, [(W / 2 - 4, 10), (W / 2 + 4, 10), (W / 2 + 4, H), (W / 2 - 4, H)], STEEL_D, ink=1.4)
    pf(c, [(W / 2 - 14, 20), (W / 2 + 14, 20), (W / 2 + 10, 50), (W / 2 - 10, 50)], WARM, ink=1.8)


def generate():
    tile("wall_cabin", "Side view: log wall inside the hunter's cabin (tile)", hexc("#6A4E34"), "logs")
    tile("wall_house", "Side view: faded wallpaper (tile)", hexc("#7C7462"), "wallpaper")
    tile("wall_house_b", "Side view: faded green wallpaper (tile)", hexc("#5E6A58"), "wallpaper")
    tile("wall_shop", "Side view: shop wall, paint over tiles (tile)", hexc("#7A8078"), "panel")
    tile("wall_brick_in", "Side view: bare brick inside a workshop (tile)", hexc("#6E4A3A"), "brick")
    tile("wall_office", "Side view: office plaster (tile)", hexc("#837E70"), "plaster")
    tile("wall_mine", "Side view: mine rock face (tile)", hexc("#4E4943"), "minerock")
    tile("ext_logs", "Side view: cabin log wall in section (tile)", hexc("#4E3A26"), "logs")
    tile("ext_siding", "Side view: house siding in section (tile)", hexc("#5A5E60"), "siding")
    tile("ext_brick", "Side view: brick wall in section (tile)", hexc("#5A3A2E"), "brick")
    tile("ext_concrete", "Side view: concrete wall in section (tile)", hexc("#6A6862"), "plaster")
    strip("floor_linoleum", "Side view: linoleum floor (strip)", "linoleum")
    strip("floor_concrete", "Side view: concrete floor (strip)", "concrete")
    strip("ceiling", "Side view: plaster ceiling (strip)", "plaster", H=16)
    strip("rail", "Side view: mine-cart rails (strip)", "rail", H=24)
    sprite("window", "Side view: window (daylight)", 160, 180, (0.5, 0.5), d_window(False), (80, 90))
    sprite("window_boarded", "Side view: boarded-up window", 160, 180, (0.5, 0.5), d_window(True), (80, 90))
    sprite("door_ext", "Side view: front door", 120, 300, (0.5, 1.0), d_door_ext, (60, 150))
    sprite("stairs", "Side view: staircase, one storey", 260, 400, (0.5, 1.0), d_stairs, (130, 200))
    for st in ("marked", "digging", "closed", "open", "steel_closed", "steel_open"):
        sprite(f"trapdoor_{st}", f"Side view: floor trapdoor ({st.replace('_', ' ')})", 240, 160, (0.5, 0.89), d_trapdoor(st), (120, 80))
    sprite("mine_cart", "Side view: mine cart", 220, 160, (0.5, 0.96), d_mine_cart, (110, 80))
    sprite("mine_beam", "Side view: mine timber set", 160, 320, (0.5, 1.0), d_mine_beam, (80, 160))
    sprite("rubble", "Side view: collapsed passage (rubble)", 260, 320, (0.5, 1.0), d_rubble, (130, 160))
    sprite("ore", "Side view: mineral vein", 180, 140, (0.5, 1.0), d_ore, (90, 70))
    sprite("mine_lamp", "Side view: miner's wall lamp", 60, 120, (0.5, 1.0), d_lamp_post, (30, 60))


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_side_interiors.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "side_interiors", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("side interior art generated:", len(ENTRIES))


if __name__ == "__main__":
    generate()
    write_manifest()
