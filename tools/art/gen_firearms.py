#!/usr/bin/env python3
"""Iteration 014: held art for the firearms (handgun, revolver, shotgun, hunting
rifle, military rifle). Same convention as the melee weapons (gen_tools.py):
40 x 120 source, drawn barrel-up with the grip at the bottom (pivot 0.5, 0.9),
so PlayerAvatar holds and turns them like any other hand item.

Writes templates under assets/templates/items/ and adds the entries to
assets/manifest/visual_firearms.json. Replaceable (overrides/items/<name>.png).
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
STEEL, STEEL_D, STEEL_L = hexc("#4A4F52"), hexc("#2C3033"), hexc("#7A8083")
WOOD, WOOD_D = hexc("#6A4A30"), hexc("#43301F")
NEW = []


def save(c, name, label, W=40, H=120):
    rel = f"items/template_{name}.png"
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    c.save(p, winter=False)
    NEW.append({"id": "item." + name, "name": label + " (held)", "template": "res://assets/templates/" + rel,
                "display_size": [W // 2, H // 2], "source_size": [W, H], "pivot": [0.5, 0.9], "transparency": "required",
                "directions": "none", "complexity": "simple", "status": "READY",
                "notes": "Generated placeholder (tools/art/gen_firearms.py) - replace with tablet art."})


def pf(c, pts, col, ink=1.6, light=(-1, -1, 0.4)):
    c.fill(pts, col, tex=0.25, light=light)
    c.ink_poly(pts, width=ink)


def handgun():
    c = Canvas(40, 120, seed=1501)
    pf(c, [(14, 112), (26, 112), (28, 74), (16, 72)], STEEL_D)          # grip
    pf(c, [(12, 76), (30, 76), (28, 30), (14, 30)], STEEL)              # slide / frame
    pf(c, [(16, 30), (26, 30), (25, 16), (17, 16)], STEEL_D)            # barrel end
    c.ink([(22, 76), (26, 88)], width=1.4)                              # trigger guard
    save(c, "handgun", "Handgun")


def revolver():
    c = Canvas(40, 120, seed=1502)
    pf(c, [(14, 112), (26, 112), (27, 80), (15, 78)], WOOD)
    pf(c, [(11, 80), (29, 80), (29, 56), (11, 56)], STEEL)              # cylinder
    for y in (62, 70):
        c.ink([(13, y), (27, y)], width=1.0, alpha=150)
    pf(c, [(17, 56), (23, 56), (23, 12), (17, 12)], STEEL_D)            # long barrel
    save(c, "revolver", "Revolver")


def long_gun(name, label, stock, barrel_col, mag=False, pump=False):
    c = Canvas(40, 120, seed=1503 + len(name))
    pf(c, [(12, 116), (28, 116), (26, 84), (16, 84)], stock)            # stock
    pf(c, [(15, 86), (25, 86), (24, 50), (16, 50)], barrel_col)         # receiver
    pf(c, [(18, 50), (22, 50), (22, 2), (18, 2)], STEEL_D)              # barrel
    if mag:
        pf(c, [(24, 72), (32, 74), (30, 92), (24, 90)], STEEL_D)
    if pump:
        pf(c, [(15, 46), (25, 46), (25, 30), (15, 30)], WOOD)
    save(c, name, label)


if __name__ == "__main__":
    handgun()
    revolver()
    long_gun("shotgun", "Shotgun", WOOD, STEEL, pump=True)
    long_gun("hunting_rifle", "Hunting rifle", WOOD, STEEL)
    long_gun("military_rifle", "Military rifle", mix(STEEL_D, hexc("#3F4A36"), 0.5), STEEL_D, mag=True)
    with open(os.path.join(ROOT, "assets", "manifest", "visual_firearms.json"), "w") as f:
        json.dump({"kind": "visual", "category": "firearms", "assets": NEW}, f, indent="\t"); f.write("\n")
    print("firearm art generated:", len(NEW))
