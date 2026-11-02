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


# ---------------------------------------------------------------- milestone B
from gen_homestead import tile_from_noise, wrap_draw
from gen_bunker import EARTH, EARTH_D, EARTH_L, CLAY, PLANK, PLANK_D, board
import random as _random


def earth_mass_tile():
    S = 256
    rng = _random.Random(701)
    stones = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(3, 9)) for _ in range(60)]
    def strokes(img):
        def fn(d, ox, oy):
            for x, y, r in stones:
                d.ellipse((x - r + ox, y - r * 0.7 + oy, x + r + ox, y + r * 0.7 + oy), fill=mix(STONE, EARTH, 0.5)[:3] + (190,), outline=INK[:3] + (120,))
            for i in range(0, S, 22):
                d.line([(ox, i + oy + rng.uniform(-3, 3)), (S + ox, i + oy + rng.uniform(-3, 3))], fill=EARTH_D[:3] + (60,), width=2)
        wrap_draw(img, fn)
    img = tile_from_noise(S, mix(EARTH_D, INK, 0.25), mix(EARTH_D, INK, 0.45), EARTH, 702, 64, strokes)
    img.save(out("bunker/earth/template_earth_mass_tile.png"), optimize=True)


def earth_face_tile():
    W, H = 256, 128
    c = Canvas(W, H, seed=711)
    c.fill([(0, 0), (W, 0), (W, H), (0, H)], EARTH, tex=0.35, cell=20, light=(0, -1, 0.4))
    for k, y in enumerate((18, 46, 80, 104)):
        pts = [(x, y + 6 * math.sin(x / 40.0 + k)) for x in range(0, W + 1, 32)]
        c.fill(pts + [(W, y + 22), (0, y + 22)], [EARTH_L, CLAY, EARTH_D, EARTH][k], tex=0.35, cell=10)
        c.ink(pts, width=1.2, alpha=110)
    for _ in range(14):
        x, y, r = c.rng.uniform(0, W), c.rng.uniform(10, H - 14), c.rng.uniform(4, 10)
        st = c.blob(x, y, r, r * 0.7, n=10, irregular=0.2)
        c.fill(st, mix(STONE, CLAY, 0.4), tex=0.2, light=(-1, -1, 0.4)); c.ink_poly(st, width=1.2)
    for _ in range(6):
        x = c.rng.uniform(0, W); pts = [(x, 0)]
        for _ in range(3):
            x += c.rng.uniform(-8, 8); pts.append((x, pts[-1][1] + c.rng.uniform(10, 18)))
        c.ink(pts, width=c.rng.uniform(2, 4), color=mix(WOOD, EARTH_D, 0.4))
    c.hatch(c.mask([(0, H - 26), (W, H - 26), (W, H), (0, H)]), spacing=5, alpha=80)
    img = c.img.resize((W, H), Image.LANCZOS)
    # make horizontally seamless by cross-fading the edges
    a = np.asarray(img).astype(np.float32)
    w = 24
    for i in range(w):
        t = i / w
        a[:, i] = a[:, i] * t + a[:, W - w + i] * (1 - t)
    Image.fromarray(a.astype(np.uint8), "RGBA").crop((0, 0, W - w, H)).resize((W, H), Image.LANCZOS).save(out("bunker/earth/template_earth_face_tile.png"), optimize=True)


def support_post(done):
    W, H = 180, 300
    c = Canvas(W, H, seed=721 + done)
    base = 290
    c.soft_shadow((20, base - 12, 160, base + 8), alpha=90, blur=5)
    for x in (34, 146):
        if not done and x == 146:
            c.ink([(150, base), (110, 120)], width=22, color=PLANK); c.ink([(150, base), (110, 120)], width=1.6)
            continue
        board(c, [(x - 12, 60), (x + 12, 60), (x + 12, base), (x - 12, base)], PLANK, grain=2)
    if done:
        board(c, [(10, 40), (170, 40), (170, 66), (10, 66)], PLANK_D, grain=2)
        for x in (34, 146):
            c.ink([(x + (22 if x < 90 else -22), 66), (x, 110)], width=8, color=PLANK_D)
    else:
        loose = c.blob(90, base - 8, 70, 12, n=14, irregular=0.2)
        c.fill(loose, EARTH, tex=0.4); c.ink_poly(loose, width=1.4)
    c.save(out(f"bunker/earth/template_support_post{'' if done else '_building'}.png"))


if __name__ == "__main__" and "milestone_b" in sys.argv:
    earth_mass_tile(); earth_face_tile(); support_post(True); support_post(False)
    print("milestone B art generated")
