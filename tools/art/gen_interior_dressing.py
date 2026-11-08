#!/usr/bin/env python3
"""Iteration 015 B: side-view interior dressing — the things that make a room
look lived in, abandoned and searched through.

Wall pieces (hang on the back wall): picture frames, a stopped clock, coat hooks
with coats, a calendar, posters, a pegboard of tools, shelves of jars, curtains
for windows, cracks, water stains and cobwebs. Ceiling: a hanging lamp (a light
source), exposed pipes. Floor: rugs, a side table with a lamp, chairs (one
knocked over), boots, bottles, a pile of books, debris, a dead pot plant, a
radiator, a cash register, a mannequin, a boot rack, a coat rail, crates of
stock. All front-facing for the cross-section view.

Writes templates under assets/templates/side/dress/ and the manifest
assets/manifest/visual_interior_dressing.json (asset ids "side.<name>").
Replaceable: assets/overrides/side/dress/<name>.png.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []
TIMBER, TIMBER_D, TIMBER_L = hexc("#7A5E40"), hexc("#4E3A26"), hexc("#9A7A55")
STEEL, STEEL_D = hexc("#5E6467"), hexc("#3A3E40")
CLOTH_R, CLOTH_B, CLOTH_G = hexc("#7E3A2C"), hexc("#3F5B6A"), hexc("#55604A")
PAPER = hexc("#D8D0BC")
WARM = hexc("#E8C27A")
CHAR = hexc("#1E1C1B")


def pf(c, pts, col, tex=0.3, ink=1.8, light=(-1, -1, 0.3)):
    m = c.fill(pts, col, tex=tex, light=light)
    if ink:
        c.ink_poly(pts, width=ink)
    return m


def R(c, x0, y0, x1, y1, col, ink=1.8):
    return pf(c, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, ink=ink)


def sprite(name, label, W, H, draw, pivot=(0.5, 1.0)):
    c = Canvas(W, H, seed=3100 + len(name) * 7)
    draw(c, W, H)
    rel = f"side/dress/template_{name}.png"
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    c.save(p, winter=False)
    ENTRIES.append({"id": "side." + name, "name": label, "template": "res://assets/templates/" + rel,
                    "display_size": [W // 2, H // 2], "source_size": [W, H], "pivot": list(pivot), "transparency": "required",
                    "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_interior_dressing.py) - replace with tablet art."})


# ---------------------------------------------------------------- wall
def d_frame(c, W, H, col=CLOTH_B):
    R(c, 6, 6, W - 6, H - 6, TIMBER_D)
    R(c, 16, 16, W - 16, H - 16, mix(col, PAPER, 0.35), ink=1.2)
    c.ink([(20, H - 30), (W * 0.4, H * 0.5), (W * 0.6, H * 0.62), (W - 20, H * 0.4)], width=1.6, alpha=170)
    c.ink([(W / 2, 0), (W / 2 - 18, 6)], width=1.0); c.ink([(W / 2, 0), (W / 2 + 18, 6)], width=1.0)


def d_frame_tilt(c, W, H):
    pts = [(14, 20), (W - 6, 8), (W - 14, H - 10), (6, H - 2)]
    pf(c, pts, TIMBER_D)
    pf(c, [(24, 28), (W - 18, 18), (W - 24, H - 20), (16, H - 12)], mix(CLOTH_G, PAPER, 0.4), ink=1.2)
    c.ink([(30, 40), (W - 30, H - 30)], width=1.2, alpha=180)  # cracked glass


def d_clock(c, W, H):
    c.ellipse_fill((8, 8, W - 8, H - 8), TIMBER)
    c.ink_poly([(W / 2 + (W / 2 - 8) * math.cos(t / 20 * math.tau), H / 2 + (H / 2 - 8) * math.sin(t / 20 * math.tau)) for t in range(21)], width=2.0)
    c.ellipse_fill((18, 18, W - 18, H - 18), PAPER)
    c.ink([(W / 2, H / 2), (W / 2, 26)], width=2.4); c.ink([(W / 2, H / 2), (W / 2 + 16, H / 2 + 8)], width=2.0)


def d_coat_hooks(c, W, H):
    R(c, 6, 10, W - 6, 26, TIMBER_D)
    for k, (x, col) in enumerate(((40, CLOTH_R), (100, CLOTH_B), (160, CLOTH_G))):
        c.ink([(x, 26), (x, 36)], width=3)
        pf(c, [(x - 22, 40), (x + 22, 40), (x + 30, H - 10 - k * 8), (x - 30, H - 10 - k * 8)], col)
        c.ink([(x, 44), (x, H - 30 - k * 8)], width=1.0, alpha=150)


def d_calendar(c, W, H):
    R(c, 10, 6, W - 10, H - 6, PAPER, ink=1.4)
    R(c, 10, 6, W - 10, 40, CLOTH_R, ink=1.2)
    for r in range(4):
        for k in range(5):
            c.ink([(22 + k * 18, 56 + r * 20), (32 + k * 18, 56 + r * 20)], width=1.0, alpha=140)
    c.ink([(20, 56), (W - 20, H - 20)], width=2.0, color=CLOTH_R, alpha=200)  # crossed off


def d_poster(c, W, H, col=hexc("#B5543A")):
    pf(c, [(8, 10), (W - 6, 6), (W - 10, H - 6), (10, H - 10)], mix(PAPER, col, 0.25), ink=1.4)
    R(c, 22, 22, W - 22, H * 0.55, col, ink=1.0)
    for y in (H * 0.66, H * 0.74, H * 0.82):
        c.ink([(24, y), (W - 26, y)], width=2.4, alpha=170)
    pf(c, [(W - 40, H - 30), (W - 6, H - 6), (W - 30, H - 6)], mix(PAPER, CHAR, 0.2), ink=1.0)  # torn corner


def d_pegboard(c, W, H):
    R(c, 6, 6, W - 6, H - 6, hexc("#9A8A6A"))
    for x in range(20, W - 10, 18):
        for y in range(20, H - 10, 18):
            c.ellipse_fill((x - 1.5, y - 1.5, x + 1.5, y + 1.5), CHAR)
    c.ink([(40, 30), (40, 100)], width=4, color=STEEL_D); R(c, 30, 20, 50, 34, STEEL, ink=1.0)
    c.ink([(90, 26), (110, 110)], width=4, color=TIMBER); R(c, 98, 20, 130, 34, STEEL_D, ink=1.0)
    c.ink_poly([(160 + 22 * math.cos(t / 12 * math.tau), 70 + 22 * math.sin(t / 12 * math.tau)) for t in range(13)], width=3, color=STEEL_D)


def d_jar_shelf(c, W, H):
    R(c, 6, H - 22, W - 6, H - 10, TIMBER)
    for k in range(6):
        x = 20 + k * (W - 40) / 6
        col = [hexc("#9A7A3A"), hexc("#7E3A2C"), hexc("#55604A")][k % 3]
        if k == 4:
            continue  # gone
        R(c, x, H - 60, x + 24, H - 22, mix(col, PAPER, 0.25), ink=1.2)
        R(c, x - 2, H - 66, x + 26, H - 58, STEEL_D, ink=1.0)


def d_curtains(c, W, H):
    for s in (0, 1):
        x0 = 4 if s == 0 else W - 48
        pf(c, [(x0, 8), (x0 + 44, 8), (x0 + 36 + (6 if s else -6), H - 6), (x0 - 2, H - 6)], mix(CLOTH_R, hexc("#5A4A3A"), 0.4))
        for k in range(3):
            c.ink([(x0 + 10 + k * 11, 12), (x0 + 8 + k * 11, H - 10)], width=1.0, alpha=140)
    c.ink([(0, 8), (W, 8)], width=3, color=TIMBER_D)


def d_crack(c, W, H):
    pts = [(W * 0.5, 0), (W * 0.46, H * 0.2), (W * 0.58, H * 0.4), (W * 0.4, H * 0.62), (W * 0.52, H * 0.82), (W * 0.44, H)]
    c.ink(pts, width=2.4, alpha=210)
    c.ink([pts[2], (W * 0.8, H * 0.46)], width=1.4, alpha=180)
    c.ink([pts[3], (W * 0.18, H * 0.7)], width=1.2, alpha=160)


def d_stain(c, W, H):
    b = c.blob(W / 2, H * 0.4, W * 0.4, H * 0.35, n=18, irregular=0.35)
    c.fill(b, (90, 78, 58, 90), tex=0.4)
    c.ink(b, width=1.2, alpha=80)
    for k in range(4):
        x = W * (0.3 + 0.12 * k)
        c.ink([(x, H * 0.6), (x + 2, H * (0.8 + 0.05 * k))], width=1.6, color=(90, 78, 58, 255), alpha=90)


def d_cobweb(c, W, H):
    for k in range(6):
        a = k / 5 * math.pi / 2
        c.ink([(0, 0), (W * math.cos(a), H * math.sin(a))], width=0.9, color=hexc("#D8D8D2"), alpha=150)
    for r in (0.3, 0.55, 0.8):
        c.ink([(W * r * math.cos(k / 5 * math.pi / 2), H * r * math.sin(k / 5 * math.pi / 2)) for k in range(6)], width=0.8,
              color=hexc("#D8D8D2"), alpha=130)


# ---------------------------------------------------------------- ceiling
def d_lamp_hanging(c, W, H):
    c.ink([(W / 2, 0), (W / 2, H * 0.55)], width=2.0)
    pf(c, [(W / 2 - 34, H * 0.55), (W / 2 + 34, H * 0.55), (W / 2 + 14, H * 0.38), (W / 2 - 14, H * 0.38)], mix(STEEL, CLOTH_G, 0.4))
    c.ellipse_fill((W / 2 - 12, H * 0.55, W / 2 + 12, H * 0.55 + 18), WARM)


def d_pipes(c, W, H):
    for y, col in ((14, STEEL), (36, mix(STEEL_D, hexc("#73392A"), 0.4))):
        R(c, 0, y, W, y + 14, col, ink=1.4)
        for x in range(30, W, 90):
            R(c, x, y - 4, x + 10, y + 18, STEEL_D, ink=1.0)


# ---------------------------------------------------------------- floor
def d_rug(c, W, H):
    pf(c, [(6, H - 18), (W - 6, H - 22), (W - 2, H - 4), (2, H - 2)], mix(CLOTH_R, hexc("#5A4A3A"), 0.3), ink=1.4)
    c.ink([(10, H - 12), (W - 10, H - 14)], width=1.0, color=WARM, alpha=140)


def d_side_table_lamp(c, W, H):
    R(c, 20, H - 70, W - 20, H - 60, TIMBER)
    for x in (26, W - 34):
        R(c, x, H - 60, x + 8, H, TIMBER_D, ink=1.2)
    R(c, W / 2 - 4, H - 110, W / 2 + 4, H - 70, STEEL_D, ink=1.0)
    pf(c, [(W / 2 - 30, H - 110), (W / 2 + 30, H - 110), (W / 2 + 18, H - 150), (W / 2 - 18, H - 150)], mix(PAPER, WARM, 0.4))


def d_chair(c, W, H, fallen=False):
    if fallen:
        R(c, 10, H - 30, W - 10, H - 20, TIMBER)
        R(c, W - 20, H - 80, W - 10, H - 20, TIMBER_D)
        for x in (16, W * 0.45):
            c.ink([(x, H - 20), (x - 18, H - 4)], width=5, color=TIMBER_D)
        return
    R(c, 14, H - 60, W - 14, H - 50, TIMBER)
    R(c, W - 24, H - 130, W - 14, H - 50, TIMBER_D)
    for x in (16, W - 24):
        R(c, x, H - 50, x + 8, H, TIMBER_D, ink=1.2)


def d_boots(c, W, H):
    for x in (10, 52):
        pf(c, [(x, H - 50), (x + 22, H - 50), (x + 24, H - 18), (x + 40, H - 14), (x + 40, H - 2), (x, H - 2)], hexc("#3A2E26"), ink=1.4)


def d_bottles(c, W, H):
    for k, (x, col, fall) in enumerate(((10, hexc("#4F6A3A"), False), (34, hexc("#8A6A2A"), False), (58, hexc("#4F6A3A"), True))):
        if fall:
            pf(c, [(x, H - 16), (x + 40, H - 18), (x + 40, H - 4), (x, H - 2)], col, ink=1.2)
        else:
            pf(c, [(x + 4, H - 40), (x + 16, H - 40), (x + 18, H - 2), (x + 2, H - 2)], col, ink=1.2)
            R(c, x + 7, H - 52, x + 13, H - 40, col, ink=1.0)


def d_books(c, W, H):
    for k in range(5):
        col = [CLOTH_R, CLOTH_B, CLOTH_G, hexc("#8A7A52"), hexc("#5A4A3A")][k]
        y = H - 2 - k * 12
        dx = (k % 2) * 8
        R(c, 10 + dx, y - 12, W - 14 + dx * 0.5, y, col, ink=1.2)
    pf(c, [(W - 30, H - 4), (W, H - 30), (W - 2, H - 20), (W - 26, H)], PAPER, ink=1.0)


def d_debris(c, W, H):
    for k in range(9):
        x = 10 + (k * 37) % (W - 30)
        h = 6 + (k * 13) % 14
        pf(c, [(x, H - 2), (x + 10 + (k % 3) * 8, H - 2 - h), (x + 26, H - 2)], [TIMBER, PAPER, STEEL_D, hexc("#8A877F")][k % 4], ink=1.0)
    c.ink([(4, H - 1), (W - 4, H - 1)], width=1.0, alpha=120)


def d_plant_dead(c, W, H):
    pf(c, [(W / 2 - 22, H - 40), (W / 2 + 22, H - 40), (W / 2 + 16, H - 2), (W / 2 - 16, H - 2)], hexc("#8A4A32"))
    for a in (-0.9, -0.4, 0.2, 0.7):
        c.ink([(W / 2, H - 40), (W / 2 + 40 * math.sin(a), H - 40 - 50 * math.cos(a)), (W / 2 + 50 * math.sin(a * 1.3), H - 60 - 30 * math.cos(a))],
              width=1.6, color=hexc("#6A5A3A"))


def d_radiator(c, W, H):
    R(c, 8, H - 70, W - 8, H - 10, mix(STEEL, PAPER, 0.2))
    for x in range(18, W - 10, 14):
        c.ink([(x, H - 66), (x, H - 14)], width=1.4, alpha=170)
    for x in (12, W - 20):
        R(c, x, H - 10, x + 8, H, STEEL_D, ink=1.0)


def d_register(c, W, H):
    pf(c, [(10, H - 40), (W - 10, H - 40), (W - 4, H - 2), (4, H - 2)], STEEL_D)
    pf(c, [(20, H - 70), (W - 30, H - 70), (W - 26, H - 40), (24, H - 40)], STEEL)
    R(c, 28, H - 66, W - 40, H - 52, hexc("#3A4A3A"), ink=1.0)


def d_mannequin(c, W, H):
    c.ellipse_fill((W / 2 - 16, 8, W / 2 + 16, 40), mix(PAPER, TIMBER_L, 0.3))
    pf(c, [(W / 2 - 34, 46), (W / 2 + 34, 46), (W / 2 + 26, 150), (W / 2 - 26, 150)], CLOTH_B)
    c.ink([(W / 2 - 34, 60), (W / 2 - 46, 140)], width=10, color=CLOTH_B)
    R(c, W / 2 - 4, 150, W / 2 + 4, H - 10, STEEL_D, ink=1.0)
    R(c, W / 2 - 30, H - 12, W / 2 + 30, H - 2, STEEL_D, ink=1.0)


def d_boot_rack(c, W, H):
    for y in (H - 6, H - 60, H - 114):
        R(c, 8, y - 8, W - 8, y, TIMBER)
        for k in range(4 if y != H - 114 else 2):
            x = 18 + k * (W - 36) / 4
            pf(c, [(x, y - 40), (x + 18, y - 40), (x + 20, y - 18), (x + 34, y - 14), (x + 34, y - 8), (x, y - 8)], [hexc("#3A2E26"), hexc("#5A4A3A"), CLOTH_R][k % 3], ink=1.2)
    for x in (8, W - 16):
        R(c, x, 20, x + 8, H, TIMBER_D, ink=1.2)


def d_coat_rail(c, W, H, full=True):
    R(c, 10, 20, W - 10, 28, STEEL_D, ink=1.2)
    for x in (16, W - 24):
        R(c, x, 28, x + 8, H, STEEL_D, ink=1.2)
    if full:
        for k in range(6):
            x = 30 + k * (W - 60) / 6
            col = [CLOTH_R, CLOTH_B, CLOTH_G, hexc("#5A4A3A"), CLOTH_B, hexc("#7A6A55")][k]
            pf(c, [(x - 14, 34), (x + 14, 34), (x + 18, H - 40 - (k % 2) * 20), (x - 18, H - 40 - (k % 2) * 20)], col)
    else:
        for k in range(3):
            c.ink([(40 + k * 50, 28), (34 + k * 50, 46), (46 + k * 50, 46)], width=1.6)  # empty hangers


def d_stock_crates(c, W, H):
    for (x, y, s) in ((10, H - 2, 80), (96, H - 2, 70), (40, H - 82, 66)):
        pf(c, [(x, y - s), (x + s, y - s), (x + s, y), (x, y)], mix(TIMBER, TIMBER_D, 0.3))
        c.ink([(x + 8, y - s / 2), (x + s - 8, y - s / 2)], width=1.0, alpha=160)
        R(c, x + s * 0.25, y - s * 0.8, x + s * 0.75, y - s * 0.6, PAPER, ink=0.8)


def d_counter(c, W, H):
    R(c, 6, H - 90, W - 6, H - 76, TIMBER_L)
    R(c, 12, H - 76, W - 12, H, TIMBER)
    for x in range(40, W - 20, 80):
        c.ink([(x, H - 70), (x, H - 8)], width=1.0, alpha=140)


def d_shelf_goods(c, W, H):
    for y in (H - 8, H - 80, H - 152):
        R(c, 8, y - 8, W - 8, y, STEEL)
    for x in (8, W - 16):
        R(c, x, 10, x + 8, H, STEEL_D, ink=1.2)
    for k, y in enumerate((H - 16, H - 88, H - 160)):
        for j in range(5):
            if (j + k) % 3 == 2:
                continue  # picked over
            x = 22 + j * (W - 44) / 5
            R(c, x, y - 40 + (j % 2) * 8, x + 26, y, [CLOTH_B, CLOTH_G, hexc("#8A7A52"), CLOTH_R][(j + k) % 4], ink=1.0)


SPEC = [
    ("frame", "Picture frame", 120, 100, d_frame), ("frame_tilt", "Tilted picture frame (cracked)", 120, 100, d_frame_tilt),
    ("clock", "Stopped wall clock", 90, 90, d_clock), ("coat_hooks", "Coat hooks with coats", 200, 200, d_coat_hooks),
    ("calendar", "Calendar, days crossed off", 120, 150, d_calendar), ("poster", "Torn poster", 130, 180, d_poster),
    ("pegboard", "Pegboard with tools", 220, 140, d_pegboard), ("jar_shelf", "Shelf of jars", 220, 90, d_jar_shelf),
    ("curtains", "Curtains", 150, 150, d_curtains), ("crack", "Wall crack", 120, 200, d_crack), ("stain", "Water stain", 160, 160, d_stain),
    ("cobweb", "Cobweb (corner)", 90, 90, d_cobweb), ("lamp_hanging", "Hanging ceiling lamp", 110, 160, d_lamp_hanging),
    ("pipes", "Exposed pipes", 400, 60, d_pipes), ("rug", "Rug", 260, 36, d_rug), ("side_table_lamp", "Side table with lamp", 120, 160, d_side_table_lamp),
    ("chair", "Chair", 90, 140, d_chair), ("chair_fallen", "Knocked-over chair", 140, 90, lambda c, W, H: d_chair(c, W, H, True)),
    ("boots", "Pair of boots", 100, 60, d_boots), ("bottles", "Bottles on the floor", 110, 60, d_bottles), ("books", "Pile of books", 130, 70, d_books),
    ("debris", "Debris on the floor", 220, 40, d_debris), ("plant_dead", "Dead pot plant", 110, 120, d_plant_dead), ("radiator", "Radiator", 160, 90, d_radiator),
    ("register", "Cash register", 120, 80, d_register), ("mannequin", "Mannequin", 120, 240, d_mannequin), ("boot_rack", "Boot rack", 180, 200, d_boot_rack),
    ("coat_rail", "Coat rail (full)", 220, 220, d_coat_rail), ("coat_rail_empty", "Coat rail (picked over)", 220, 220, lambda c, W, H: d_coat_rail(c, W, H, False)),
    ("stock_crates", "Crates of stock", 190, 170, d_stock_crates), ("counter", "Shop counter", 320, 110, d_counter),
    ("shelf_goods", "Shelf of goods (picked over)", 200, 230, d_shelf_goods),
]
HANG = {"lamp_hanging", "pipes"}

if __name__ == "__main__":
    for name, label, W, H, fn in SPEC:
        sprite(name, label, W, H, fn, pivot=(0.5, 0.0) if name in HANG else (0.5, 1.0))
    with open(os.path.join(ROOT, "assets", "manifest", "visual_interior_dressing.json"), "w") as f:
        json.dump({"kind": "visual", "category": "interior_dressing", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("interior dressing:", len(ENTRIES))
