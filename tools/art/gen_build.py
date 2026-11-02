#!/usr/bin/env python3
"""Iteration 006 placeholder art: player-built structures, steel hatch, tractor wreck.
Writes templates plus assets/manifest/visual_build.json. Run from the repository root:
python3 tools/art/gen_build.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK
from gen_homestead import out, ROOT, STEEL, RUST, RUST_D, STONE, WOOD, WOOD_L, WOOD_M, CONCRETE, GRASS_D
from gen_bunker import PLANK, PLANK_D, floor_patch

ENTRIES = []
METAL = hexc("#6C6C6B"); METAL_L = hexc("#A29791"); CEM = hexc("#9A958A"); CEM_D = hexc("#6E6A62")
LEAF = hexc("#7A8A3C"); LEAF_L = hexc("#A3B04E"); POT = hexc("#B58B57"); WATER = hexc("#4F8C9A")
OLIVE = hexc("#5A6142")


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": list(pivot),
                    "transparency": "required", "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_build.py) - replace with tablet art."})


def planks(c, x0, y0, x1, y1, color, n=3, vertical=False, seed_shift=0):
    if vertical:
        w = (x1 - x0) / n
        for i in range(n):
            a = x0 + i * w
            p = [(a + 1, y0 + c.rng.uniform(-2, 2)), (a + w - 1, y0 + c.rng.uniform(-2, 2)), (a + w - 1, y1), (a + 1, y1)]
            c.fill(p, mix(color, INK, c.rng.uniform(0, 0.15)), tex=0.35, light=(-1, -1, 0.3)); c.ink_poly(p, width=1.8)
    else:
        h = (y1 - y0) / n
        for i in range(n):
            b = y0 + i * h
            p = [(x0 + c.rng.uniform(-3, 3), b + 1), (x1 + c.rng.uniform(-3, 3), b + 1), (x1, b + h - 1), (x0, b + h - 1)]
            c.fill(p, mix(color, INK, c.rng.uniform(0, 0.15)), tex=0.35, light=(-1, -1, 0.3)); c.ink_poly(p, width=1.8)


def nails(c, pts):
    for x, y in pts:
        c.ellipse_fill((x - 2, y - 2, x + 2, y + 2), STEEL)


def barricade(tier):
    W, H = 128, 88
    c = Canvas(W, H, seed=1100 + tier)
    base = 82
    c.soft_shadow((4, base - 10, 124, base + 6), alpha=90, blur=5)
    if tier == 0:
        for x in (14, 64, 112):  # posts
            post = [(x - 6, 14), (x + 6, 12), (x + 6, base), (x - 6, base)]
            c.fill(post, WOOD, tex=0.4); c.ink_poly(post, width=2)
        for y0, tilt in ((22, 6), (44, -5), (62, 4)):
            p = [(2, y0 + tilt), (126, y0 - tilt), (126, y0 - tilt + 14), (2, y0 + tilt + 14)]
            c.fill(p, mix(WOOD_L, WOOD, c.rng.uniform(0.2, 0.6)), tex=0.4, light=(-1, -1, 0.3)); c.ink_poly(p, width=2)
            nails(c, [(14, y0 + 7 + tilt * 0.8), (64, y0 + 7), (112, y0 + 7 - tilt * 0.8)])
    elif tier == 1:
        planks(c, 4, 18, 124, base, WOOD, n=3)
        for x0, x1, y0, y1, col in ((8, 62, 14, 52, METAL), (58, 122, 26, 70, mix(METAL, RUST, 0.45)), (18, 70, 50, 80, METAL_L)):
            p = [(x0, y0), (x1, y0 + 2), (x1 - 2, y1), (x0 + 2, y1 - 2)]
            c.fill(p, col, tex=0.3, cell=10, light=(-1, -1, 0.35)); c.ink_poly(p, width=2.2)
            nails(c, [(x0 + 5, y0 + 5), (x1 - 6, y0 + 6), (x0 + 6, y1 - 6), (x1 - 6, y1 - 6)])
            c.fill(c.blob((x0 + x1) / 2, y1 - 6, 8, 3, n=8, irregular=0.5), RUST, tex=0.3)
    else:
        for i, (x0, x1) in enumerate(((2, 66), (62, 126))):
            blk = [(x0, 16), (x1, 14), (x1, base), (x0, base)]
            c.fill(blk, mix(CEM, CEM_D, 0.2 * i), tex=0.45, cell=8, light=(-1, -1, 0.35)); c.ink_poly(blk, width=2.4)
            top = [(x0, 16), (x1, 14), (x1 - 6, 6), (x0 + 6, 8)]
            c.fill(top, mix(CEM, hexc("#D7D1C2"), 0.3), tex=0.3); c.ink_poly(top, width=1.8)
            for _ in range(5):
                x, y = c.rng.uniform(x0 + 6, x1 - 6), c.rng.uniform(24, base - 8)
                c.ink([(x, y), (x + c.rng.uniform(-8, 8), y + c.rng.uniform(4, 10))], width=1.2, alpha=120)
        c.ink([(24, 40), (104, 38)], width=3, color=mix(RUST, STEEL, 0.4))
    names = ["wood", "metal", "concrete"]
    rel = f"world/build/template_barricade_{names[tier]}.png"
    c.save(out(rel))
    entry(f"build.barricade_{names[tier]}", f"Barricade - {names[tier]}", rel, (64, 44), (W, H), (0.5, 0.93))


def wall(tier):
    """A bunker wall block that fills one 64 px excavation cell (3/4 view)."""
    W, H = 128, 168
    c = Canvas(W, H, seed=1110 + tier)
    base = 160
    c.soft_shadow((2, base - 12, 126, base + 6), alpha=110, blur=5)
    top = [(2, 40), (126, 40), (120, 8), (8, 8)]
    front = [(2, 40), (126, 40), (126, base), (2, base)]
    if tier == 0:
        c.fill(front, PLANK_D, tex=0.3); planks(c, 4, 42, 124, base - 2, PLANK, n=4, vertical=True)
        c.fill(top, mix(PLANK, hexc("#D9B98A"), 0.3), tex=0.3)
        c.ink([(2, 80), (126, 80)], width=6, color=PLANK_D); c.ink([(2, 130), (126, 130)], width=6, color=PLANK_D)
    elif tier == 1:
        c.fill(front, mix(METAL, STEEL, 0.3), tex=0.3, cell=10, light=(-1, -1, 0.3))
        for y in (70, 104, 138):
            c.ink([(4, y), (124, y)], width=2, color=mix(STEEL, INK, 0.5))
        nails(c, [(12, 52), (116, 52), (12, 150), (116, 150), (64, 52), (64, 150)])
        c.fill(top, mix(METAL_L, METAL, 0.4), tex=0.3)
        for _ in range(4):
            c.fill(c.blob(c.rng.uniform(16, 112), c.rng.uniform(60, 150), 10, 4, n=8, irregular=0.5), RUST, tex=0.3)
    else:
        c.fill(front, CEM, tex=0.45, cell=8, light=(-1, -1, 0.35))
        for y in (80, 120):
            c.ink([(4, y), (124, y)], width=1.6, alpha=150)
        c.ink([(64, 40), (64, 80)], width=1.6, alpha=150); c.ink([(34, 80), (34, 120)], width=1.6, alpha=150); c.ink([(94, 120), (94, base)], width=1.6, alpha=150)
        c.fill(top, mix(CEM, hexc("#D7D1C2"), 0.35), tex=0.3)
    c.ink_poly(front, width=2.6); c.ink_poly(top, width=2.2)
    names = ["wood", "metal", "concrete"]
    rel = f"world/build/template_wall_{names[tier]}.png"
    c.save(out(rel))
    entry(f"build.wall_{names[tier]}", f"Bunker wall - {names[tier]}", rel, (64, 84), (W, H), (0.5, 0.96))


def door(open_):
    W, H = 128, 168
    c = Canvas(W, H, seed=1120 + open_)
    base = 160
    c.soft_shadow((2, base - 12, 126, base + 6), alpha=100, blur=5)
    frame_l = [(2, 10), (16, 10), (16, base), (2, base)]
    frame_r = [(112, 10), (126, 10), (126, base), (112, base)]
    lintel = [(2, 4), (126, 4), (126, 20), (2, 20)]
    for p in (frame_l, frame_r, lintel):
        c.fill(p, PLANK_D, tex=0.35); c.ink_poly(p, width=2.2)
    if open_:
        hole = [(16, 20), (112, 20), (112, base), (16, base)]
        c.fill(hole, hexc("#1A1612", 120), tex=0.1)
        leaf = [(112, 20), (124, 26), (124, base + 2), (112, base)]
        c.fill(leaf, mix(METAL, PLANK, 0.4), tex=0.3); c.ink_poly(leaf, width=2)
    else:
        leaf = [(16, 20), (112, 20), (112, base), (16, base)]
        c.fill(leaf, PLANK, tex=0.3); planks(c, 18, 22, 110, base - 2, PLANK, n=3, vertical=True)
        for y in (46, 120):
            band = [(16, y), (112, y), (112, y + 12), (16, y + 12)]
            c.fill(band, mix(METAL, STEEL, 0.3), tex=0.25); c.ink_poly(band, width=1.8)
            nails(c, [(24, y + 6), (64, y + 6), (104, y + 6)])
        c.ink([(96, 86), (104, 86)], width=4, color=STEEL)
    rel = f"world/build/template_door_{'open' if open_ else 'closed'}.png"
    c.save(out(rel))
    entry(f"build.door_{'open' if open_ else 'closed'}", f"Reinforced door - {'open' if open_ else 'closed'}", rel, (64, 84), (W, H), (0.5, 0.96))


def spikes(worn):
    W, H = 120, 88
    c = Canvas(W, H, seed=1130 + worn)
    base = 80
    board = [(6, 30), (114, 30), (118, base), (2, base)]
    c.fill(board, mix(WOOD, GRASS_D, 0.2), tex=0.4); c.ink_poly(board, width=2)
    for row, y in enumerate((44, 60, 76)):
        for i in range(6):
            x = 14 + i * 18 + (row % 2) * 8
            h = (8 if worn else 20) + c.rng.uniform(-3, 3)
            tip = (x + c.rng.uniform(-3, 3), y - h) if not worn else (x + c.rng.uniform(-8, 8), y - h)
            sp = [(x - 4, y), (x + 4, y), tip]
            c.fill(sp, mix(METAL_L, RUST, 0.6 if worn else 0.25), tex=0.2); c.ink_poly(sp, width=1.4)
    if worn:
        c.fill(c.blob(60, 56, 30, 8, n=10, irregular=0.4), hexc("#5A4030", 120), tex=0.3)
    rel = f"world/build/template_spike_trap{'_worn' if worn else ''}.png"
    c.save(out(rel))
    entry(f"build.spike_trap{'_worn' if worn else ''}", "Spike trap" + (" - worn" if worn else ""), rel, (60, 44), (W, H), (0.5, 0.91))


def crate():
    W, H = 104, 92
    c = Canvas(W, H, seed=1140)
    base = 86
    c.soft_shadow((4, base - 10, 100, base + 6), alpha=90, blur=5)
    front = [(6, 30), (90, 30), (90, base), (6, base)]
    top = [(6, 30), (90, 30), (100, 14), (16, 14)]
    side = [(90, 30), (100, 14), (100, base - 14), (90, base)]
    c.fill(front, PLANK, tex=0.35); planks(c, 8, 32, 88, base - 2, PLANK, n=3)
    c.fill(top, mix(PLANK, hexc("#D9B98A"), 0.35), tex=0.3); c.fill(side, PLANK_D, tex=0.3)
    c.ink([(6, 30), (90, base)], width=4, color=PLANK_D); c.ink([(90, 30), (6, base)], width=4, color=PLANK_D)
    for p in (front, top, side):
        c.ink_poly(p, width=2.2)
    rel = "world/build/template_crate.png"
    c.save(out(rel))
    entry("build.crate", "Storage crate", rel, (52, 46), (W, H), (0.5, 0.93))


def workbench():
    W, H = 180, 132
    c = Canvas(W, H, seed=1150)
    base = 124
    c.soft_shadow((6, base - 12, 174, base + 6), alpha=100, blur=5)
    for x in (16, 156):
        leg = [(x - 6, 60), (x + 6, 60), (x + 6, base), (x - 6, base)]
        c.fill(leg, PLANK_D, tex=0.3); c.ink_poly(leg, width=2)
    c.ink([(16, 100), (156, 100)], width=6, color=PLANK_D)
    topf = [(4, 48), (176, 48), (176, 64), (4, 64)]
    topt = [(4, 48), (176, 48), (168, 30), (12, 30)]
    c.fill(topt, mix(PLANK, hexc("#D9B98A"), 0.3), tex=0.35); c.fill(topf, PLANK, tex=0.3)
    c.ink_poly(topt, width=2.2); c.ink_poly(topf, width=2.2)
    vise = [(130, 18), (160, 18), (160, 34), (130, 34)]
    c.fill(vise, mix(STEEL, OLIVE, 0.4), tex=0.2); c.ink_poly(vise, width=1.8)
    c.ink([(30, 38), (70, 28)], width=4, color=STEEL); c.ink([(66, 26), (74, 32)], width=7, color=WOOD)  # saw/hammer
    c.ellipse_fill((92, 32, 104, 40), mix(RUST, STEEL, 0.3))
    c.ellipse_fill((106, 34, 116, 41), mix(RUST, STEEL, 0.5))
    for x in (40, 80, 120):
        c.ink([(x, 72), (x + 10, 96)], width=3, color=STEEL, alpha=200)  # hanging tools
    rel = "world/build/template_workbench.png"
    c.save(out(rel))
    entry("build.workbench", "Workbench", rel, (90, 66), (W, H), (0.5, 0.94))


def planter(stage):
    W, H = 180, 120
    c = Canvas(W, H, seed=1160 + stage)
    base = 112
    c.soft_shadow((6, base - 10, 174, base + 6), alpha=100, blur=5)
    box = [(8, 62), (172, 62), (168, base), (12, base)]
    c.fill(box, PLANK, tex=0.35); planks(c, 10, 64, 170, base - 2, PLANK, n=2)
    soil = [(12, 56), (168, 56), (172, 64), (8, 64)]
    c.fill(soil, hexc("#3E3226"), tex=0.4)
    c.ink_poly(box, width=2.2)
    c.ink([(10, 8), (10, 58)], width=3, color=STEEL); c.ink([(170, 8), (170, 58)], width=3, color=STEEL)
    lamp = [(14, 6), (166, 6), (166, 16), (14, 16)]
    c.fill(lamp, mix(STEEL, OLIVE, 0.3), tex=0.2); c.ink_poly(lamp, width=1.8)
    c.fill([(24, 16), (156, 16), (156, 20), (24, 20)], hexc("#C9A0D8", 200), tex=0.1)
    if stage >= 1:
        for i in range(6):
            x = 22 + i * 27
            h = 18 if stage == 1 else 34
            c.ink([(x, 58), (x, 58 - h)], width=2.4, color=LEAF)
            for k in range(2 if stage == 1 else 4):
                yy = 58 - h * (k + 1) / (5 if stage == 1 else 5)
                c.fill(c.blob(x + (8 if k % 2 else -8), yy, 7, 4, n=8, irregular=0.2), LEAF_L if k % 2 else LEAF, tex=0.2)
    if stage == 2:
        for i in range(5):
            x = 34 + i * 27
            c.fill(c.blob(x, 60, 7, 6, n=10, irregular=0.2), POT, tex=0.3); c.ink_poly(c.blob(x, 60, 7, 6, n=10, irregular=0.2), width=1.2)
    names = ["empty", "growing", "ripe"]
    rel = f"world/build/template_planter_{names[stage]}.png"
    c.save(out(rel))
    entry(f"build.planter_{names[stage]}", f"Hydroponic planter - {names[stage]}", rel, (90, 60), (W, H), (0.5, 0.93))


def collector(full):
    W, H = 112, 160
    c = Canvas(W, H, seed=1170 + full)
    base = 152
    c.soft_shadow((6, base - 10, 106, base + 6), alpha=100, blur=5)
    barrel = [(22, 70), (90, 70), (92, base), (20, base)]
    c.fill(barrel, mix(OLIVE, STEEL, 0.4), tex=0.3, light=(-1, 0, 0.35)); c.ink_poly(barrel, width=2.2)
    for y in (88, 128):
        c.ink([(21, y), (91, y)], width=3, color=mix(STEEL, INK, 0.4))
    funnel = [(4, 30), (108, 30), (78, 70), (34, 70)]
    c.fill(funnel, mix(METAL_L, METAL, 0.3), tex=0.25); c.ink_poly(funnel, width=2)
    c.ink([(10, 30), (14, 8)], width=3, color=WOOD); c.ink([(102, 30), (98, 8)], width=3, color=WOOD)
    if full:
        c.fill([(10, 32), (102, 32), (98, 40), (14, 40)], WATER, tex=0.15)
    tap = [(90, 130), (102, 130), (102, 136), (90, 136)]
    c.fill(tap, STEEL); c.ink_poly(tap, width=1.4)
    rel = f"world/build/template_rain_collector{'_full' if full else ''}.png"
    c.save(out(rel))
    entry(f"build.rain_collector{'_full' if full else ''}", "Rain collector" + (" - water ready" if full else ""), rel, (56, 80), (W, H), (0.5, 0.95))


def pile():
    W, H = 80, 56
    c = Canvas(W, H, seed=1180)
    base = 50
    c.soft_shadow((6, base - 8, 74, base + 4), alpha=80, blur=4)
    sack = c.blob(32, 34, 20, 15, n=12, irregular=0.15)
    c.fill(sack, hexc("#9C8A64"), tex=0.4); c.ink_poly(sack, width=2)
    c.ink([(26, 20), (36, 22)], width=3, color=hexc("#5A4A34"))
    box = [(46, 28), (72, 28), (72, 48), (46, 48)]
    c.fill(box, PLANK, tex=0.3); c.ink_poly(box, width=1.8)
    rel = "world/build/template_pile.png"
    c.save(out(rel))
    entry("build.pile", "Dropped items", rel, (40, 28), (W, H), (0.5, 0.9))


def steel_hatch(open_):
    W, H = 280, 280 if open_ else 220
    c = Canvas(W, H, seed=1190 + open_)
    base_y = H - 20
    floor_patch(c, 20, base_y - 170, 260, base_y)
    frame = [(56, base_y - 142), (224, base_y - 142), (230, base_y - 18), (50, base_y - 18)]
    c.fill(frame, CEM_D, tex=0.35); c.ink_poly(frame, width=2.6)
    if open_:
        holep = [(74, base_y - 128), (206, base_y - 128), (210, base_y - 32), (70, base_y - 32)]
        c.fill(holep, hexc("#100D0B"), tex=0.15)
        for y in range(int(base_y - 116), int(base_y - 30), 22):
            c.ink([(110, y), (170, y)], width=4, color=mix(METAL_L, INK, (y - (base_y - 116)) / 140))
        c.ink([(110, base_y - 128), (106, base_y - 32)], width=4, color=METAL_L); c.ink([(170, base_y - 128), (174, base_y - 32)], width=4, color=METAL_L)
        c.ink_poly(holep, width=2)
        lid = [(64, base_y - 140), (216, base_y - 140), (206, base_y - 250), (74, base_y - 250)]
        c.fill(lid, mix(METAL, OLIVE, 0.3), tex=0.3, cell=10, light=(0, -1, 0.35))
        for y in (base_y - 170, base_y - 220):
            c.ink([(72, y), (210, y)], width=4, color=mix(STEEL, INK, 0.4))
        nails(c, [(80, base_y - 150), (200, base_y - 150), (86, base_y - 240), (194, base_y - 240)])
        c.ink_poly(lid, width=2.6)
    else:
        lid = [(66, base_y - 134), (214, base_y - 134), (220, base_y - 26), (60, base_y - 26)]
        c.fill(lid, mix(METAL, OLIVE, 0.3), tex=0.3, cell=10, light=(-1, -1, 0.35))
        for x in (100, 140, 180):
            c.ink([(x, base_y - 132), (x + 1, base_y - 28)], width=2, color=mix(STEEL, INK, 0.4))
        nails(c, [(76, base_y - 124), (204, base_y - 124), (70, base_y - 36), (210, base_y - 36), (140, base_y - 124), (140, base_y - 36)])
        c.ellipse_fill((120, base_y - 100, 160, base_y - 60), mix(STEEL, RUST, 0.3)); c.ink_poly(c.blob(140, base_y - 80, 20, 20, n=16, irregular=0), width=3)
        c.ink([(128, base_y - 80), (152, base_y - 80)], width=5, color=INK)
        c.ink_poly(lid, width=2.6)
    rel = f"world/shelter/template_hatch_steel_{'open' if open_ else 'closed'}.png"
    c.save(out(rel))
    entry(f"world.hatch_steel_{'open' if open_ else 'closed'}", "Steel floor hatch - " + ("open" if open_ else "closed"),
          rel, (140, 140) if open_ else (140, 110), (W, H), (0.5, 0.643) if open_ else (0.5, 0.545))


def tractor():
    W, H = 400, 260
    c = Canvas(W, H, seed=1200)
    base = 246
    c.soft_shadow((20, base - 26, 380, base + 10), alpha=110, blur=8)
    for _ in range(14):
        x = c.rng.uniform(20, 380)
        c.ink([(x, base), (x + c.rng.uniform(-10, 10), base - c.rng.uniform(16, 44))], width=2, color=GRASS_D, alpha=200)
    body = [(110, 120), (300, 116), (318, 196), (100, 200)]
    c.fill(body, mix(RUST, hexc("#8C4334"), 0.4), tex=0.45, light=(-1, -1, 0.35)); c.ink_poly(body, width=2.6)
    hood = [(200, 92), (330, 96), (340, 150), (210, 150)]
    c.fill(hood, mix(RUST, RUST_D, 0.3), tex=0.45); c.ink_poly(hood, width=2.4)
    cab = [(116, 40), (190, 40), (196, 122), (110, 124)]
    c.ink_poly(cab, width=3, color=STEEL)
    c.ink([(152, 40), (150, 122)], width=2.4, color=STEEL)
    c.ink([(320, 96), (322, 60)], width=7, color=STEEL)
    for cx, cy, r in ((150, 200, 50), (310, 214, 32)):
        c.ellipse_fill((cx - r, cy - r, cx + r, cy + r), hexc("#2C2A26"), tex=0.3)
        c.ink_poly(c.blob(cx, cy, r, r, n=20, irregular=0.03), width=2.6)
        c.ellipse_fill((cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45), mix(RUST, STEEL, 0.4))
    for _ in range(10):
        c.fill(c.blob(c.rng.uniform(120, 320), c.rng.uniform(110, 190), c.rng.uniform(6, 14), c.rng.uniform(4, 8), n=8, irregular=0.4), RUST_D, tex=0.3)
    vine = [(260 + i * 6, 150 + (i % 3) * 8) for i in range(10)]
    c.ink(vine, width=3, color=LEAF)
    rel = "props/template_tractor.png"
    c.save(out(rel))
    entry("prop.tractor", "Rusting tractor (scrap metal)", rel, (200, 130), (W, H), (0.5, 0.95))


if __name__ == "__main__":
    for t in range(3):
        barricade(t); wall(t)
    door(False); door(True); spikes(False); spikes(True); crate(); workbench()
    for st in range(3):
        planter(st)
    collector(False); collector(True); pile(); steel_hatch(False); steel_hatch(True); tractor()
    path = os.path.join(ROOT, "assets", "manifest", "visual_build.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "build", "assets": ENTRIES}, f, indent="\t")
        f.write("\n")
    print(f"build art generated: {len(ENTRIES)} assets")
