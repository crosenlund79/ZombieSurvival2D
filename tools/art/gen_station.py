#!/usr/bin/env python3
"""Iteration 008 placeholder art: the ruined rural service station (shop, canopy with pumps,
workshop garage, tyre pile, price sign, workshop locker), plus the survivor figure (I009, a
recoloured copy of the player template so the creator can replace it separately).
Writes templates and assets/manifest/visual_station.json. Run from the repository root."""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK
from gen_homestead import out, ROOT, STEEL, RUST, RUST_D, STONE, WOOD, WOOD_L, CONCRETE, PAINT, SLATE, GLASS, GRASS_D

ENTRIES = []
TEAL = hexc("#346773"); CREAM = hexc("#CFB88D"); OLIVE = hexc("#5A6142"); LEAF = hexc("#667538"); LEAF_L = hexc("#9AA052")


def entry(aid, name, rel, display, source, pivot, kind="visual"):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": list(display),
                    "source_size": list(source), "pivot": list(pivot), "transparency": "required", "directions": "none",
                    "complexity": "moderate", "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_station.py) - replace with tablet art."})


def vines(c, x0, x1, y, n=6):
    for i in range(n):
        x = c.rng.uniform(x0, x1)
        pts = [(x + c.rng.uniform(-4, 4), y - k * c.rng.uniform(10, 16)) for k in range(c.rng.randint(3, 7))]
        c.ink(pts, width=2.6, color=LEAF)
        for (px, py) in pts[1:]:
            c.fill(c.blob(px + c.rng.uniform(-6, 6), py, 6, 4, n=8, irregular=0.3), LEAF_L if c.rng.random() < 0.5 else LEAF, tex=0.2)


def shop():
    W, H = 600, 440
    c = Canvas(W, H, seed=1501)
    base = 420
    c.soft_shadow((20, base - 30, 580, base + 16), alpha=110, blur=10)
    front = [(40, 170), (560, 170), (560, base), (40, base)]
    c.fill(front, mix(PAINT, CONCRETE, 0.4), tex=0.45, cell=14, light=(-1, -1, 0.3)); c.ink_poly(front, width=3)
    roof = [(20, 170), (580, 170), (560, 110), (40, 110)]
    c.fill(roof, SLATE, tex=0.4); c.ink_poly(roof, width=2.6)
    fascia = [(30, 150), (570, 150), (570, 196), (30, 196)]
    c.fill(fascia, TEAL, tex=0.35); c.ink_poly(fascia, width=2.4)
    for i, ch in enumerate("FUEL · STORE"):
        if ch.strip():
            c.ink([(150 + i * 26, 160), (150 + i * 26, 186)], width=5, color=CREAM, alpha=200)
    for x0 in (70, 330):
        win = [(x0, 230), (x0 + 200, 230), (x0 + 200, 330), (x0, 330)]
        c.fill(win, GLASS, tex=0.2); c.ink_poly(win, width=2.4)
        c.ink([(x0 + 20, 240), (x0 + 120, 320)], width=2, color=mix(GLASS, CREAM, 0.5), alpha=150)  # crack
        c.ink([(x0 + 140, 236), (x0 + 60, 300)], width=1.6, color=mix(GLASS, CREAM, 0.4), alpha=140)
    door = [(276, 250), (324, 250), (324, base), (276, base)]
    c.fill(door, hexc("#1C1916"), tex=0.2); c.ink_poly(door, width=2.4)
    for y in (300, 350):  # boards
        c.ink([(60, y), (290, y + 8)], width=9, color=WOOD); c.ink([(60, y), (290, y + 8)], width=1.4)
    for _ in range(14):
        c.fill(c.blob(c.rng.uniform(50, 550), c.rng.uniform(200, 400), c.rng.uniform(6, 18), c.rng.uniform(4, 10), n=8, irregular=0.5),
               mix(RUST, CONCRETE, 0.6), tex=0.3)
    vines(c, 40, 120, base, 5); vines(c, 480, 560, base, 4)
    c.save(out("world/station/template_shop.png"))
    entry("world.station_shop", "Service station shop", "world/station/template_shop.png", (300, 220), (W, H), (0.5, 0.955))


def canopy():
    W, H = 560, 380
    c = Canvas(W, H, seed=1502)
    base = 360
    c.soft_shadow((30, base - 20, 530, base + 14), alpha=90, blur=10)
    for x in (80, 480):
        post = [(x - 10, 110), (x + 10, 110), (x + 10, base), (x - 10, base)]
        c.fill(post, mix(CONCRETE, STEEL, 0.4), tex=0.3); c.ink_poly(post, width=2.2)
    top = [(20, 60), (540, 60), (540, 116), (20, 116)]
    c.fill(top, mix(CREAM, CONCRETE, 0.5), tex=0.4); c.ink_poly(top, width=2.6)
    c.fill([(20, 96), (540, 96), (540, 116), (20, 116)], TEAL, tex=0.3)
    sag = [(300, 116), (360, 116), (350, 150), (310, 140)]
    c.fill(sag, mix(CREAM, RUST, 0.4), tex=0.3); c.ink_poly(sag, width=2)  # torn panel hanging
    for x in (200, 360):
        island = [(x - 50, base - 30), (x + 50, base - 30), (x + 50, base - 10), (x - 50, base - 10)]
        c.fill(island, CONCRETE, tex=0.3); c.ink_poly(island, width=2)
        pump = [(x - 22, base - 120), (x + 22, base - 120), (x + 24, base - 30), (x - 24, base - 30)]
        c.fill(pump, mix(hexc("#A23A2E"), RUST, 0.4), tex=0.35, light=(-1, -1, 0.3)); c.ink_poly(pump, width=2.2)
        c.fill([(x - 14, base - 108), (x + 14, base - 108), (x + 14, base - 86), (x - 14, base - 86)], GLASS, tex=0.2)
        c.ink([(x + 24, base - 90), (x + 36, base - 70), (x + 32, base - 40)], width=3, color=INK)  # hose
    vines(c, 60, 100, base, 3)
    c.save(out("world/station/template_canopy.png"))
    entry("world.station_canopy", "Fuel canopy with pumps", "world/station/template_canopy.png", (280, 190), (W, H), (0.5, 0.947))


def workshop():
    W, H = 560, 420
    c = Canvas(W, H, seed=1503)
    base = 400
    c.soft_shadow((20, base - 26, 540, base + 14), alpha=110, blur=10)
    body = [(40, 140), (520, 140), (520, base), (40, base)]
    c.fill(body, mix(STEEL, OLIVE, 0.3), tex=0.4, cell=12, light=(-1, -1, 0.3)); c.ink_poly(body, width=3)
    for x in range(60, 520, 28):
        c.ink([(x, 146), (x, base - 4)], width=1.4, color=mix(STEEL, INK, 0.45), alpha=160)
    roof = [(24, 140), (536, 140), (500, 80), (60, 80)]
    c.fill(roof, mix(RUST, STEEL, 0.4), tex=0.45); c.ink_poly(roof, width=2.6)
    door = [(150, 220), (380, 220), (380, base), (150, base)]
    c.fill(door, mix(CONCRETE, STEEL, 0.3), tex=0.3); c.ink_poly(door, width=2.4)
    for y in range(232, base, 18):
        c.ink([(152, y), (378, y)], width=1.6, color=mix(STEEL, INK, 0.5))
    gap = [(150, base - 46), (380, base - 40), (380, base), (150, base)]
    c.fill(gap, hexc("#141210"), tex=0.1)  # roller door jammed half-open
    c.fill([(420, 220), (490, 220), (490, 290), (420, 290)], GLASS, tex=0.2); c.ink_poly([(420, 220), (490, 220), (490, 290), (420, 290)], width=2)
    for _ in range(10):
        c.fill(c.blob(c.rng.uniform(60, 510), c.rng.uniform(150, 380), c.rng.uniform(8, 20), c.rng.uniform(5, 10), n=8, irregular=0.5), RUST_D, tex=0.3)
    vines(c, 40, 140, base, 6)
    c.save(out("world/station/template_workshop.png"))
    entry("world.station_workshop", "Workshop garage", "world/station/template_workshop.png", (280, 210), (W, H), (0.5, 0.952))


def tyres():
    W, H = 140, 100
    c = Canvas(W, H, seed=1504)
    base = 92
    c.soft_shadow((10, base - 10, 130, base + 6), alpha=90, blur=4)
    for cx, cy in ((44, 70), (96, 70), (70, 40)):
        c.ellipse_fill((cx - 30, cy - 20, cx + 30, cy + 20), hexc("#2A2724"), tex=0.3)
        c.ink_poly(c.blob(cx, cy, 30, 20, n=18, irregular=0.03), width=2)
        c.ellipse_fill((cx - 12, cy - 8, cx + 12, cy + 8), hexc("#3E3A34"))
    c.save(out("world/station/template_tyres.png"))
    entry("world.station_tyres", "Tyre pile", "world/station/template_tyres.png", (70, 50), (W, H), (0.5, 0.92))


def sign():
    W, H = 140, 320
    c = Canvas(W, H, seed=1505)
    base = 310
    c.ink([(70, base), (70, 120)], width=10, color=STEEL); c.ink([(70, base), (70, 120)], width=1.6)
    board = [(10, 20), (130, 20), (130, 130), (10, 130)]
    c.fill(board, mix(CREAM, CONCRETE, 0.3), tex=0.4); c.ink_poly(board, width=2.6)
    c.fill([(10, 20), (130, 20), (130, 50), (10, 50)], TEAL, tex=0.3)
    for y in (70, 96):
        c.ink([(24, y), (116, y)], width=6, color=INK, alpha=170)
    c.fill(c.blob(100, 110, 18, 10, n=10, irregular=0.4), RUST, tex=0.3)
    vines(c, 60, 80, base, 2)
    c.save(out("world/station/template_sign.png"))
    entry("world.station_sign", "Price sign", "world/station/template_sign.png", (70, 160), (W, H), (0.5, 0.97))


def locker():
    W, H = 120, 200
    c = Canvas(W, H, seed=1506)
    base = 192
    c.soft_shadow((10, base - 10, 110, base + 6), alpha=90, blur=4)
    body = [(14, 24), (106, 24), (106, base - 2), (14, base - 2)]
    c.fill(body, mix(hexc("#A23A2E"), STEEL, 0.45), tex=0.35, light=(-1, -1, 0.3)); c.ink_poly(body, width=2.4)
    for y in (70, 120, 160):
        c.ink([(16, y), (104, y)], width=2, color=INK, alpha=180)
        c.ink([(52, y - 10), (68, y - 10)], width=4, color=STEEL)
    c.save(out("world/station/template_tool_locker.png"))
    entry("world.station_locker", "Workshop tool locker", "world/station/template_tool_locker.png", (60, 100), (W, H), (0.5, 0.96))


def survivor():
    """Recoloured copies of the player figure for the survivor (separately replaceable)."""
    src_dir = os.path.join(ROOT, "assets", "templates", "characters", "player")
    man = json.load(open(os.path.join(ROOT, "assets", "manifest", "visual_characters.json")))
    for a in man["assets"]:
        if not a["id"].startswith("char.player"):
            continue
        src = os.path.join(ROOT, a["template"].replace("res://", ""))
        if not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGBA")
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, al = px[x, y]
                if al and g > r * 0.9 and g > b * 1.05 and r < 150:  # olive jacket -> faded teal-blue
                    px[x, y] = (int(r * 0.7), int(g * 0.85), min(255, int(b * 1.5 + 30)), al)
        name = os.path.basename(src).replace("template_survivor", "template_npc").replace("template_", "template_npc_") if "survivor" not in os.path.basename(src) else os.path.basename(src).replace("template_survivor", "template_npc")
        rel = "characters/survivor/" + name
        im.save(out(rel))
        e = dict(a)
        e["id"] = a["id"].replace("char.player", "char.npc")
        e["name"] = "Survivor (Mara) - " + a.get("name", "")
        e["template"] = "res://assets/templates/" + rel
        e["notes"] = "Recoloured placeholder of the player figure (tools/art/gen_station.py) - replace with tablet art."
        ENTRIES.append(e)


if __name__ == "__main__":
    shop(); canopy(); workshop(); tyres(); sign(); locker(); survivor()
    path = os.path.join(ROOT, "assets", "manifest", "visual_station.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "station", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("station art generated:", len(ENTRIES))
