#!/usr/bin/env python3
"""Iteration 007 placeholder art: held tools/weapons (machete, hatchet, felling axe).
Appends entries to assets/manifest/visual_items.json. Run from the repository root."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK
from gen_homestead import out, ROOT, WOOD, WOOD_L, STEEL, RUST
BLADE = hexc("#A9A49A"); BLADE_D = hexc("#6C6C6B")
NEW = []


def entry(aid, name, rel):
    NEW.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": [20, 60],
                "source_size": [40, 120], "pivot": [0.5, 0.9], "transparency": "required", "directions": "none",
                "complexity": "simple", "status": "READY", "notes": "Generated placeholder (tools/art/gen_tools.py) - replace with tablet art."})


def handle(c, top=40):
    shaft = [(17, 112), (23, 112), (24, top), (16, top)]
    c.fill(shaft, WOOD_L, tex=0.3, light=(-1, 0, 0.3)); c.ink_poly(shaft, width=1.6)
    c.ink([(16, 102), (24, 102)], width=4, color=hexc("#3A3026"))


def machete():
    c = Canvas(40, 120, seed=1401)
    grip = [(16, 112), (24, 112), (24, 80), (16, 80)]
    c.fill(grip, hexc("#3A3026"), tex=0.2); c.ink_poly(grip, width=1.6)
    c.ink([(10, 80), (30, 80)], width=4, color=STEEL)
    blade = [(15, 78), (25, 78), (30, 20), (22, 6), (14, 22)]
    c.fill(blade, BLADE, tex=0.25, light=(-1, -1, 0.4)); c.ink_poly(blade, width=1.8)
    c.ink([(18, 74), (21, 14)], width=1.2, color=BLADE_D)
    c.fill(c.blob(26, 50, 3, 6, n=8, irregular=0.4), RUST, tex=0.3)
    c.save(out("items/template_machete.png")); entry("item.machete", "Machete (held)", "items/template_machete.png")


def hatchet():
    c = Canvas(40, 120, seed=1402)
    handle(c, 24)
    head = [(10, 18), (26, 16), (36, 10), (38, 34), (26, 30), (10, 30)]
    c.fill(head, BLADE_D, tex=0.3, light=(-1, -1, 0.4)); c.ink_poly(head, width=1.8)
    c.ink([(36, 10), (38, 34)], width=2, color=BLADE)
    c.save(out("items/template_hatchet.png")); entry("item.hatchet", "Hatchet (held)", "items/template_hatchet.png")


def felling_axe():
    c = Canvas(40, 120, seed=1403)
    handle(c, 14)
    head = [(4, 8), (20, 6), (30, 0), (38, 4), (38, 30), (30, 34), (20, 24), (4, 22)]
    c.fill(head, mix(BLADE_D, hexc("#5A6142"), 0.3), tex=0.3, light=(-1, -1, 0.4)); c.ink_poly(head, width=2)
    c.ink([(38, 4), (38, 30)], width=2.4, color=BLADE)
    c.ink([(6, 10), (6, 20)], width=3, color=hexc("#A23A2E"))
    c.save(out("items/template_felling_axe.png")); entry("item.felling_axe", "Felling axe (held)", "items/template_felling_axe.png")


if __name__ == "__main__":
    machete(); hatchet(); felling_axe()
    path = os.path.join(ROOT, "assets", "manifest", "visual_items.json")
    d = json.load(open(path))
    ids = {a["id"] for a in d["assets"]}
    d["assets"] += [a for a in NEW if a["id"] not in ids]
    with open(path, "w") as f:
        json.dump(d, f, indent="\t"); f.write("\n")
    print("tool art generated:", len(NEW))
