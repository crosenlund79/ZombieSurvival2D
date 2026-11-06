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


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_depth.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "depth", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("shadows & depth art generated:", len(ENTRIES))


if __name__ == "__main__":
    for v in range(3):
        blood_drop(v)
    write_manifest()
