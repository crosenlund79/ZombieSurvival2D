#!/usr/bin/env python3
"""Iteration 003 milestone C placeholder art: generator, purifier, storage locker, lamp.
Run from the repository root: python3 tools/art/gen_infra.py"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, SS
from gen_homestead import out, STEEL, RUST, RUST_D, STONE, AMBER, WOOD, WOOD_L, KHAKI
from gen_bunker import PLANK, PLANK_D, CONC, board

OLIVE_MIL = hexc("#5A6142"); YELLOW = hexc("#C9A23A"); TANK = hexc("#7E8A86"); WATER = hexc("#4F8C9A")


def glow(c, cx, cy, r, color, alpha=150):
    g = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(g).ellipse(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS), fill=alpha)
    g = g.filter(ImageFilter.GaussianBlur(r * 0.4 * SS))
    lay = Image.new("RGBA", c.img.size, color[:3] + (0,)); lay.putalpha(g)
    c.img = Image.alpha_composite(c.img, lay)


def generator(on):
    W, H = 240, 200
    c = Canvas(W, H, seed=801 + on)
    base = 186
    c.soft_shadow((14, base - 16, 230, base + 10), alpha=110, blur=6)
    frame = [(24, 70), (216, 70), (220, base - 6), (20, base - 6)]
    c.fill(frame, OLIVE_MIL, tex=0.3, cell=10, light=(-1, -1, 0.35)); c.ink_poly(frame, width=2.6)
    tank = [(40, 40), (180, 40), (186, 74), (34, 74)]
    c.fill(tank, mix(RUST, OLIVE_MIL, 0.5), tex=0.35, light=(-1, -1, 0.4)); c.ink_poly(tank, width=2.2)
    c.ellipse_fill((150, 46, 168, 60), STONE); c.ink_poly(c.blob(159, 53, 9, 7, n=10, irregular=0), width=1.6)
    eng = [(40, 90), (150, 90), (150, base - 20), (40, base - 20)]
    c.fill(eng, mix(STEEL, INK, 0.2), tex=0.3); c.ink_poly(eng, width=2)
    for y in range(98, base - 24, 10):
        c.ink([(48, y), (142, y)], width=1.6, color=mix(STEEL, INK, 0.45))
    panel = [(160, 92), (206, 92), (206, 150), (160, 150)]
    c.fill(panel, mix(STEEL, KHAKI, 0.3), tex=0.2); c.ink_poly(panel, width=1.8)
    c.ellipse_fill((170, 100, 186, 116), hexc("#2C2A26")); c.ink([(178, 108), (184, 102)], width=2, color=YELLOW)
    lamp = hexc("#7CCB5A") if on else hexc("#4A3A30")
    c.ellipse_fill((190, 124, 202, 136), lamp)
    if on:
        glow(c, 196, 130, 14, (124, 203, 90))
        for x in (52, 80):  # exhaust puffs
            c.fill(c.blob(x, 30, 12, 9, n=10, irregular=0.3), hexc("#9C9A92", 150), tex=0.2)
    c.ink([(20, base - 6), (14, base)], width=5, color=INK); c.ink([(220, base - 6), (226, base)], width=5, color=INK)
    c.save(out(f"world/machines/template_generator_{'on' if on else 'off'}.png"))


def purifier(on):
    W, H = 180, 260
    c = Canvas(W, H, seed=811 + on)
    base = 248
    c.soft_shadow((20, base - 14, 170, base + 8), alpha=100, blur=6)
    tank = [(36, 40), (128, 40), (132, 180), (32, 180)]
    c.fill(tank, TANK, tex=0.25, cell=12, light=(-1, 0, 0.4)); c.ink_poly(tank, width=2.4)
    win = [(52, 70), (76, 70), (76, 168), (52, 168)]
    c.fill(win, hexc("#2C3434"), tex=0.2)
    lvl = 120 if on else 150
    c.fill([(53, lvl), (75, lvl), (75, 167), (53, 167)], mix(WATER, KHAKI, 0.2), tex=0.15)
    c.ink_poly(win, width=1.6)
    for y in (60, 120, 172):
        c.ink([(32, y), (132, y)], width=3, color=mix(STEEL, INK, 0.3))
    filt = [(132, 90), (162, 90), (162, 200), (132, 200)]
    c.fill(filt, mix(KHAKI, STEEL, 0.4), tex=0.3); c.ink_poly(filt, width=1.8)
    c.ink([(162, 190), (170, 196), (170, 214)], width=4, color=STEEL)
    can = [(120, 214), (164, 214), (162, base - 4), (122, base - 4)]
    c.fill(can, hexc("#C9D3D0"), tex=0.15); c.ink_poly(can, width=1.6)
    c.fill([(30, 180), (134, 180), (138, base - 4), (26, base - 4)], mix(STEEL, INK, 0.2), tex=0.3)
    c.ink_poly([(30, 180), (134, 180), (138, base - 4), (26, base - 4)], width=2)
    funnel = [(40, 22), (90, 22), (72, 40), (58, 40)]
    c.fill(funnel, STEEL); c.ink_poly(funnel, width=1.6)
    light = hexc("#59C0C2") if on else hexc("#3A3530")
    c.ellipse_fill((96, 140, 110, 154), light)
    if on:
        glow(c, 103, 147, 14, (89, 192, 194))
        for i in range(5):
            c.ellipse_fill((58 + i * 3, 126 + i * 7, 62 + i * 3, 130 + i * 7), hexc("#D8E6E2", 200))
    c.save(out(f"world/machines/template_purifier_{'on' if on else 'off'}.png"))


def locker():
    W, H = 200, 280
    c = Canvas(W, H, seed=821)
    base = 268
    c.soft_shadow((14, base - 14, 190, base + 8), alpha=100, blur=6)
    body = [(24, 30), (176, 30), (178, base - 4), (22, base - 4)]
    c.fill(body, mix(OLIVE_MIL, STEEL, 0.4), tex=0.3, cell=10, light=(-1, -1, 0.3)); c.ink_poly(body, width=2.4)
    c.ink([(100, 34), (100, base - 8)], width=2)
    for x0 in (30, 106):
        for y in range(46, 80, 8):
            c.ink([(x0 + 14, y), (x0 + 50, y)], width=1.6, color=mix(STEEL, INK, 0.5))
        c.ink([(x0 + 60 if x0 < 100 else x0 + 6, 140), (x0 + 60 if x0 < 100 else x0 + 6, 170)], width=4, color=STONE)
    c.fill([(30, 200), (94, 200), (94, 222), (30, 222)], hexc("#D6C9A2"), tex=0.1)
    c.ink_poly([(30, 200), (94, 200), (94, 222), (30, 222)], width=1.2)
    for _ in range(6):
        x, y = c.rng.uniform(30, 170), c.rng.uniform(40, base - 20)
        c.fill(c.blob(x, y, c.rng.uniform(4, 9), c.rng.uniform(3, 6), n=8, irregular=0.4), RUST, tex=0.3)
    c.save(out("world/machines/template_storage_locker.png"))


def lamp(on):
    W, H = 80, 120
    c = Canvas(W, H, seed=831 + on)
    c.ink([(40, 0), (40, 54)], width=2.4, color=INK)
    shade = [(22, 54), (58, 54), (66, 74), (14, 74)]
    c.fill(shade, mix(STEEL, OLIVE_MIL, 0.4), tex=0.2); c.ink_poly(shade, width=1.8)
    bulb = hexc("#FFF2C2") if on else hexc("#6E6656")
    c.ellipse_fill((32, 70, 48, 86), bulb); c.ink_poly(c.blob(40, 78, 8, 8, n=10, irregular=0), width=1.4)
    if on:
        glow(c, 40, 84, 30, (255, 236, 180), 180)
    c.save(out(f"world/machines/template_lamp_{'on' if on else 'off'}.png"))


if __name__ == "__main__":
    generator(False); generator(True); purifier(False); purifier(True); locker(); lamp(False); lamp(True)
    print("infrastructure art generated")
