#!/usr/bin/env python3
"""Iteration 003 placeholder art: zombie (down/up/side, lunge, dead), club,
club rack. Run from the repository root: python3 tools/art/gen_survival.py
Never touches assets/overrides/."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, SS
from gen_homestead import out, tuft, WOOD, WOOD_L, WOOD_M, RUST, RUST_D, STONE, STRAW2, KHAKI, GREYGREEN, OLIVE_D, PAINT

SKIN = hexc("#8E9A7A"); SKIN_D = hexc("#5F6B52"); CLOTH = hexc("#5A5048"); CLOTH2 = hexc("#6E6352")
BLOOD = hexc("#5E2A22"); EYE = hexc("#D9D2A8")


def limb(c, pts, col, w=12):
    c.ink(pts, width=w + 3, color=INK, alpha=255, wobble=0.4)
    c.ink(pts, width=w, color=col, alpha=255, wobble=0.4)


def zombie(view, lunge=False):
    W, H = 110, 172
    c = Canvas(W, H, seed=601 + ["down", "up", "side"].index(view) + (10 if lunge else 0))
    base = 164
    c.soft_shadow((24, base - 12, 88, base + 6), alpha=110, blur=4)
    lean = 10 if lunge else 0
    if view == "side":
        for x, ofs in ((46, -6), (60, 6)):
            leg = [(x - 7, 106), (x + 7, 106), (x + 6 + ofs, base - 8), (x - 6 + ofs, base - 8)]
            c.fill(leg, CLOTH, tex=0.3); c.ink_poly(leg, width=1.8)
            c.fill([(x - 8 + ofs, base - 12), (x + 12 + ofs, base - 12), (x + 12 + ofs, base), (x - 8 + ofs, base)], hexc("#2E2721"))
        torso = [(36 + lean, 54), (70 + lean, 56), (74, 110), (38, 112)]
        c.fill(torso, CLOTH2, tex=0.35, light=(1, -1, 0.3)); c.ink_poly(torso, width=2.2)
        c.fill(c.blob(56 + lean, 84, 8, 10, n=8, irregular=0.4), BLOOD, tex=0.3)
        # arms reaching forward
        limb(c, [(60 + lean, 62), (84 + lean * 1.4, 70), (104, 72 - lean)], SKIN_D, 9)
        limb(c, [(52 + lean, 64), (78 + lean * 1.4, 76), (98, 80 - lean)], SKIN, 9)
        head = c.blob(62 + lean * 1.3, 38, 16, 18, n=14, irregular=0.08)
        c.fill(head, SKIN, tex=0.25, light=(1, -1, 0.3)); c.ink_poly(head, width=2)
        c.ellipse_fill((70 + lean * 1.3, 32, 76 + lean * 1.3, 38), EYE)
        c.ink([(56 + lean, 26), (70 + lean, 22)], width=3, color=hexc("#3A3026"))
    else:
        for x, dy in ((40, 0), (62, 6)):
            leg = [(x - 9, 106), (x + 9, 106), (x + 8, base - 10 - dy), (x - 8, base - 10 - dy)]
            c.fill(leg, CLOTH, tex=0.3); c.ink_poly(leg, width=1.8)
            c.fill([(x - 10, base - 14 - dy), (x + 10, base - 14 - dy), (x + 11, base - dy), (x - 11, base - dy)], hexc("#2E2721"))
        torso = [(28, 56), (40, 50), (66, 52), (78, 60), (80, 112), (26, 112)]
        c.fill(torso, CLOTH2, tex=0.35, light=(-0.6, -1, 0.3)); c.ink_poly(torso, width=2.2)
        # torn shirt + wound
        c.ink([(40, 80), (52, 96), (46, 110)], width=2, color=SKIN_D)
        c.fill(c.blob(62, 78, 8, 7, n=8, irregular=0.4), BLOOD, tex=0.3)
        if view == "down":
            reach = 14 + lean
            limb(c, [(30, 60), (22, 90 - reach), (26, 104 - reach * 1.6)], SKIN, 9)
            limb(c, [(76, 60), (86, 88 - reach), (80, 102 - reach * 1.6)], SKIN_D, 9)
            head = c.blob(54, 34, 18, 20, n=14, irregular=0.08)
            c.fill(head, SKIN, tex=0.25, light=(-1, -1, 0.3)); c.ink_poly(head, width=2)
            for ex in (46, 60):
                c.ellipse_fill((ex - 3, 30, ex + 3, 36), EYE)
                c.ellipse_fill((ex - 1, 32, ex + 1, 34), INK)
            c.ink([(46, 44), (52, 46), (60, 44)], width=2, color=BLOOD)
            c.ink([(38, 18), (50, 14), (64, 18)], width=4, color=hexc("#3A3026"))
        else:
            limb(c, [(30, 60), (24, 96)], SKIN_D, 9)
            limb(c, [(76, 60), (84, 96)], SKIN_D, 9)
            head = c.blob(54, 34, 18, 20, n=14, irregular=0.08)
            c.fill(head, hexc("#3A3026"), tex=0.3, light=(-1, -1, 0.3)); c.ink_poly(head, width=2)
            c.fill(c.blob(60, 40, 6, 5, n=8, irregular=0.3), SKIN_D)
    if lunge:
        glow = Image.new("L", c.img.size, 0)
        ImageDraw.Draw(glow).ellipse((20 * SS, 20 * SS, 100 * SS, 120 * SS), fill=60)
        glow = glow.filter(ImageFilter.GaussianBlur(10 * SS))
        gl = Image.new("RGBA", c.img.size, (150, 40, 30, 0)); gl.putalpha(glow)
        c.img = Image.alpha_composite(c.img, gl)
    name = f"zombie_{view}" + ("_lunge" if lunge else "")
    c.save(out(f"characters/zombie/template_{name}.png"))


def zombie_dead():
    W, H = 190, 90
    c = Canvas(W, H, seed=631)
    c.soft_shadow((10, 50, 184, 86), alpha=110, blur=5)
    c.fill(c.blob(110, 70, 34, 10, n=12, irregular=0.4), BLOOD, tex=0.4)
    body = [(40, 44), (130, 40), (134, 66), (42, 70)]
    c.fill(body, CLOTH2, tex=0.35); c.ink_poly(body, width=2)
    for y in (48, 62):
        limb(c, [(130, y), (170, y + 4)], CLOTH, 10)
    limb(c, [(70, 44), (60, 22)], SKIN, 8)
    head = c.blob(26, 56, 16, 14, n=12, irregular=0.08)
    c.fill(head, SKIN, tex=0.25); c.ink_poly(head, width=2)
    c.save(out("characters/zombie/template_zombie_dead.png"))


def club():
    W, H = 40, 120
    c = Canvas(W, H, seed=641)
    shaft = [(16, 108), (24, 108), (28, 30), (12, 30)]
    c.fill(shaft, WOOD_L, tex=0.3, light=(-1, 0, 0.3)); c.ink_poly(shaft, width=1.8)
    knob = c.blob(20, 24, 13, 20, n=14, irregular=0.12)
    c.fill(knob, WOOD, tex=0.35, light=(-1, -1, 0.3)); c.ink_poly(knob, width=2)
    for y in (18, 30):
        c.ink([(10, y), (30, y + 3)], width=2.4, color=hexc("#6C6A62"))  # nails/wire
    c.ink([(16, 100), (24, 100)], width=4, color=hexc("#3A3026"))
    c.save(out("items/template_club.png"))


def club_rack():
    W, H = 120, 200
    c = Canvas(W, H, seed=651)
    base = 186
    c.soft_shadow((14, base - 12, 108, base + 10), alpha=90, blur=5)
    for x in (30, 90):
        c.ink([(x, base), (x, 60)], width=7, color=WOOD); c.ink([(x, base), (x, 60)], width=1.2)
    c.ink([(22, 70), (98, 70)], width=7, color=WOOD); c.ink([(22, 120), (98, 120)], width=7, color=WOOD)
    for x, a in ((52, -0.12), (72, 0.1)):
        L = 110
        x2 = x + math.sin(a) * L
        c.ink([(x, base - 6), (x2, base - 6 - L)], width=7, color=WOOD_L)
        c.ink_poly(c.blob(x2, base - 6 - L, 9, 14, n=12, irregular=0.12), width=1.8)
        c.fill(c.blob(x2, base - 6 - L, 9, 14, n=12, irregular=0.12), WOOD, tex=0.3)
    c.save(out("items/template_club_rack.png"))


if __name__ == "__main__":
    for v in ("down", "up", "side"):
        zombie(v)
    zombie("down", True); zombie("side", True)
    zombie_dead(); club(); club_rack()
    print("survival art (milestone A) generated")
