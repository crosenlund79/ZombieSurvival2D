#!/usr/bin/env python3
"""Iteration 014 E: an inventory icon for every catalogue item, plus held art for
the new melee weapons.

Icons: 64 x 64 source, shown at 32 x 32 in the inventory, one per item id
(asset "icon.<id>"), drawn from the icon spec in tools/build_catalogue.py
(shape, colour, accent). Templates: assets/templates/ui/icons/template_<id>.png,
manifest assets/manifest/visual_item_icons.json. Replace any icon with
assets/overrides/ui/icons/<id>.png (same size, transparent background).

Held art: 40 x 120, barrel/blade up, grip at the bottom (pivot 0.5, 0.9), like
gen_tools.py / gen_firearms.py. Manifest assets/manifest/visual_melee_014.json.
Usage: python3 tools/build_catalogue.py && python3 tools/art/gen_item_icons.py
"""
import json, math, os, sys, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
from inkkit import Canvas, hexc, mix  # noqa: E402
import build_catalogue  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
TPL = os.path.join(ROOT, "assets", "templates")
STEEL, STEEL_D = hexc("#5E6467"), hexc("#2C3033")
WOOD = hexc("#6A4A30")


def P(c, pts, col, ink=1.4):
    c.fill(pts, col, tex=0.2, light=(-1, -1, 0.35))
    c.ink_poly(pts, width=ink)


def E(c, box, col, ink=1.4):
    c.ellipse_fill(box, col, light=(-1, -1, 0.35))
    x0, y0, x1, y1 = box
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    c.ink([(cx + rx * math.cos(t / 20 * math.tau), cy + ry * math.sin(t / 20 * math.tau)) for t in range(21)], width=ink)


def R(c, x0, y0, x1, y1, col, ink=1.4):
    P(c, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, ink)


def L(c, pts, w=1.2, a=200):
    c.ink(pts, width=w, alpha=a)


def rot(pts, ang, cx=32, cy=32):
    s, co = math.sin(ang), math.cos(ang)
    return [(cx + (x - cx) * co - (y - cy) * s, cy + (x - cx) * s + (y - cy) * co) for x, y in pts]


# ---------------------------------------------------------------- shapes (64 x 64)
def can(c, a, b):
    R(c, 18, 14, 46, 52, a); R(c, 18, 24, 46, 42, b, ink=1.0); E(c, (18, 10, 46, 18), mix(b, hexc("#FFFFFF"), 0.3))
def bottle(c, a, b):
    P(c, [(24, 22), (40, 22), (42, 30), (42, 56), (22, 56), (22, 30)], a); R(c, 28, 8, 36, 22, b); R(c, 22, 34, 42, 46, mix(b, a, 0.3), ink=1.0)
def canister(c, a, b):
    E(c, (14, 16, 50, 58), a); R(c, 27, 6, 37, 18, b)
def jerrycan(c, a, b):
    P(c, [(14, 14), (44, 14), (50, 22), (50, 58), (14, 58)], a); R(c, 42, 6, 50, 16, b); L(c, [(20, 24), (44, 52)], 1.6); L(c, [(44, 24), (20, 52)], 1.6)
def oilcan(c, a, b):
    P(c, [(14, 30), (40, 30), (40, 56), (14, 56)], a); P(c, [(38, 34), (56, 20), (58, 24), (40, 40)], b); P(c, [(20, 22), (34, 22), (38, 30), (16, 30)], b)
def jar(c, a, b):
    R(c, 18, 18, 46, 56, a); R(c, 20, 10, 44, 18, b)
def pack(c, a, b):
    P(c, [(14, 14), (50, 14), (52, 54), (12, 54)], a); R(c, 14, 26, 50, 38, b, ink=1.0)
def box(c, a, b):
    P(c, [(10, 22), (32, 12), (54, 22), (54, 46), (32, 56), (10, 46)], a); L(c, [(10, 22), (32, 32), (54, 22)]); L(c, [(32, 32), (32, 56)]); R(c, 28, 16, 36, 24, b, ink=0.8)
def bar(c, a, b):
    P(c, rot([(8, 24), (56, 24), (56, 40), (8, 40)], -0.35), a); P(c, rot([(30, 24), (56, 24), (56, 40), (30, 40)], -0.35), b)
def meat(c, a, b):
    E(c, (10, 16, 50, 50), a); E(c, (22, 26, 34, 36), b, ink=0.8); R(c, 44, 36, 56, 42, hexc("#E6E1D2"))
def roll(c, a, b):
    E(c, (12, 14, 52, 50), a); E(c, (26, 26, 38, 38), mix(a, b, 0.4)); L(c, [(32, 50), (50, 58)], 2.0)
def cloth(c, a, b):
    P(c, [(10, 20), (30, 12), (54, 18), (50, 44), (28, 54), (12, 46)], a); L(c, [(18, 26), (44, 22)], 1.0, 150); L(c, [(18, 38), (44, 34)], 1.0, 150); E(c, (36, 36, 44, 44), b, ink=0.6)
def kit(c, a, b):
    R(c, 10, 18, 54, 52, a); R(c, 24, 12, 40, 18, a, ink=1.2); R(c, 28, 26, 36, 44, b, ink=0.6); R(c, 23, 31, 41, 39, b, ink=0.6)
def pills(c, a, b):
    R(c, 20, 18, 44, 54, a); R(c, 18, 10, 46, 18, b); R(c, 20, 28, 44, 40, hexc("#E6E1D2"), ink=0.8)
def syringe(c, a, b):
    pts = [(10, 28), (42, 28), (42, 36), (10, 36)]
    P(c, rot(pts, -0.6), a); P(c, rot([(42, 31), (56, 31), (56, 33), (42, 33)], -0.6), b); P(c, rot([(4, 24), (10, 24), (10, 40), (4, 40)], -0.6), b)
def matchbox(c, a, b):
    R(c, 10, 22, 54, 46, a); R(c, 10, 30, 54, 38, b, ink=0.8)
def lighter(c, a, b):
    R(c, 20, 20, 44, 56, a); R(c, 20, 12, 44, 20, b); E(c, (28, 2, 36, 14), hexc("#E39A3A"), ink=0.6)
def cube(c, a, b):
    P(c, [(14, 24), (32, 16), (50, 24), (50, 44), (32, 52), (14, 44)], a); L(c, [(14, 24), (32, 32), (50, 24)]); L(c, [(32, 32), (32, 52)])
def lumps(c, a, b):
    for x, y, r in ((22, 38, 10), (40, 40, 9), (32, 26, 9)):
        E(c, (x - r, y - r, x + r, y + r), a if r > 9 else b)
def logs(c, a, b):
    for y in (40, 26):
        R(c, 10, y, 50, y + 12, a); E(c, (46, y, 56, y + 12), b)
def plank(c, a, b):
    P(c, rot([(6, 26), (58, 26), (58, 38), (6, 38)], -0.4), a); L(c, rot([(10, 32), (54, 32)], -0.4), 0.8, 120)
def coat(c, a, b):
    P(c, [(22, 10), (42, 10), (54, 20), (52, 40), (46, 36), (46, 56), (18, 56), (18, 36), (12, 40), (10, 20)], a); L(c, [(32, 14), (32, 56)]); R(c, 26, 8, 38, 14, b)
def gloves(c, a, b):
    P(c, [(16, 52), (16, 24), (20, 14), (24, 24), (26, 12), (30, 24), (32, 14), (36, 26), (40, 22), (42, 30), (38, 52)], a); R(c, 16, 46, 38, 54, b)
def hat(c, a, b):
    P(c, [(14, 44), (16, 24), (32, 14), (48, 24), (50, 44)], a); R(c, 12, 40, 52, 50, b); E(c, (28, 6, 36, 14), b)
def scarf(c, a, b):
    P(c, [(10, 18), (54, 18), (54, 28), (10, 28)], a); P(c, [(36, 28), (46, 28), (48, 56), (38, 56)], a); L(c, [(14, 23), (50, 23)], 1.0, 140); R(c, 38, 50, 48, 56, b)
def boots(c, a, b):
    P(c, [(16, 10), (32, 10), (32, 40), (54, 44), (54, 54), (16, 54)], a); R(c, 16, 50, 54, 56, b)
def socks(c, a, b):
    P(c, [(18, 8), (34, 8), (34, 40), (50, 46), (48, 56), (22, 54), (18, 44)], a); R(c, 18, 8, 34, 16, b)
def trousers(c, a, b):
    P(c, [(16, 8), (48, 8), (52, 56), (38, 56), (32, 24), (26, 56), (12, 56)], a); R(c, 16, 8, 48, 14, b)
def goggles(c, a, b):
    R(c, 6, 28, 58, 34, a, ink=1.0); E(c, (10, 22, 30, 40), b); E(c, (34, 22, 54, 40), b)
def mask(c, a, b):
    P(c, [(14, 24), (50, 24), (46, 44), (32, 50), (18, 44)], a); L(c, [(14, 26), (6, 20)]); L(c, [(50, 26), (58, 20)])
def gasmask(c, a, b):
    E(c, (14, 10, 50, 50), a); E(c, (18, 20, 30, 30), b); E(c, (34, 20, 46, 30), b); E(c, (24, 42, 40, 58), STEEL)
def backpack(c, a, b):
    P(c, [(16, 14), (48, 14), (52, 56), (12, 56)], a); R(c, 20, 34, 44, 50, b); P(c, [(24, 6), (40, 6), (40, 14), (24, 14)], b)
def knife(c, a, b):
    P(c, rot([(28, 4), (36, 10), (36, 40), (28, 40)], 0.6), a); P(c, rot([(27, 40), (37, 40), (37, 60), (27, 60)], 0.6), b)
def bat(c, a, b):
    P(c, rot([(26, 4), (38, 4), (36, 46), (34, 60), (30, 60), (28, 46)], 0.6), a); R(c, 28, 56, 36, 60, b)
def axe(c, a, b):
    P(c, rot([(30, 6), (34, 6), (34, 60), (30, 60)], 0.5), b); P(c, rot([(34, 8), (54, 4), (56, 24), (34, 20)], 0.5), a)
def crowbar(c, a, b):
    P(c, rot([(30, 10), (34, 10), (34, 58), (30, 58)], 0.5), a); P(c, rot([(30, 10), (22, 6), (20, 10), (30, 14)], 0.5), b)
def hammer(c, a, b):
    P(c, rot([(30, 18), (34, 18), (34, 60), (30, 60)], 0.5), b); P(c, rot([(18, 8), (46, 8), (46, 18), (18, 18)], 0.5), a)
def shovel(c, a, b):
    P(c, rot([(30, 4), (34, 4), (34, 40), (30, 40)], 0.5), a); P(c, rot([(22, 38), (42, 38), (40, 58), (32, 62), (24, 58)], 0.5), b)
def pickaxe(c, a, b):
    P(c, rot([(30, 12), (34, 12), (34, 60), (30, 60)], 0.4), a); P(c, rot([(8, 18), (32, 8), (56, 18), (32, 13)], 0.4), b)
def stick(c, a, b):
    P(c, rot([(30, 2), (34, 10), (34, 60), (30, 60)], 0.6), a)
def pipe(c, a, b):
    P(c, rot([(28, 4), (36, 4), (36, 60), (28, 60)], 0.6), a); P(c, rot([(26, 4), (38, 4), (38, 10), (26, 10)], 0.6), b)
def gun_short(c, a, b):
    P(c, [(8, 20), (54, 20), (54, 30), (8, 30)], a); P(c, [(12, 30), (26, 30), (22, 54), (10, 54)], b); L(c, [(26, 30), (30, 40), (22, 40)])
def gun_long(c, a, b):
    P(c, [(4, 26), (44, 26), (44, 32), (4, 32)], a); P(c, [(30, 26), (52, 24), (60, 38), (40, 40)], b); L(c, [(36, 32), (36, 40)])
def ammo(c, a, b):
    for x in (16, 28, 40):
        R(c, x, 26, x + 8, 54, a, ink=1.0); P(c, [(x, 26), (x + 8, 26), (x + 4, 14)], b, ink=1.0)
def shells(c, a, b):
    for x in (14, 28, 42):
        R(c, x, 16, x + 10, 46, a, ink=1.0); R(c, x, 46, x + 10, 54, b, ink=1.0)
def magazine(c, a, b):
    P(c, [(24, 10), (40, 10), (44, 56), (28, 56)], a); P(c, [(26, 4), (36, 4), (36, 10), (26, 10)], b)
def oil(c, a, b):
    oilcan(c, a, b)
def gear(c, a, b):
    pts = []
    for i in range(16):
        r = 22 if i % 2 == 0 else 16
        t = i / 16 * math.tau
        pts.append((32 + r * math.cos(t), 32 + r * math.sin(t)))
    P(c, pts, a); E(c, (26, 26, 38, 38), b)
def stone(c, a, b):
    P(c, [(8, 34), (20, 22), (50, 20), (58, 32), (46, 44), (14, 44)], a); L(c, [(14, 34), (52, 30)], 0.8, 120)
def scrap(c, a, b):
    P(c, [(8, 40), (20, 18), (34, 26), (50, 12), (56, 36), (36, 50), (18, 52)], a); L(c, [(22, 26), (40, 44)], 1.0, 150); E(c, (36, 22, 44, 30), b, ink=0.6)
def sheet(c, a, b):
    P(c, [(8, 20), (48, 14), (56, 42), (16, 50)], a); L(c, [(14, 26), (50, 20)], 0.8, 120)
def coil(c, a, b):
    E(c, (10, 12, 54, 52), a); E(c, (22, 24, 42, 40), mix(a, hexc("#000000"), 0.25)); L(c, [(46, 46), (58, 58)], 2.0)
def tape(c, a, b):
    E(c, (10, 12, 54, 52), a); E(c, (22, 24, 42, 40), (0, 0, 0, 0)); L(c, [(32, 52), (52, 54)], 3.0, 220)
def tube(c, a, b):
    P(c, rot([(12, 26), (46, 24), (46, 40), (12, 38)], -0.3), a); P(c, rot([(46, 28), (56, 30), (56, 34), (46, 36)], -0.3), b)
def sack(c, a, b):
    P(c, [(18, 16), (46, 16), (54, 56), (10, 56)], a); P(c, [(18, 16), (46, 16), (40, 8), (24, 8)], b)
def nails(c, a, b):
    for i, x in enumerate((14, 24, 34, 44)):
        P(c, rot([(x, 16), (x + 4, 16), (x + 4, 50), (x + 2, 56), (x, 50)], 0.15 * (i - 1.5), x + 2, 36), a, ink=1.0)
        R(c, x - 2, 12, x + 6, 16, b, ink=0.8)
def spring(c, a, b):
    L(c, [(14 + (i % 2) * 36, 10 + i * 4.4) for i in range(11)], 2.6, 230)
def battery(c, a, b):
    R(c, 18, 12, 46, 56, a); R(c, 26, 6, 38, 12, b); R(c, 18, 40, 46, 56, b, ink=1.0)
def chip(c, a, b):
    R(c, 10, 14, 54, 50, a)
    for x in (16, 26, 36, 46):
        L(c, [(x, 14), (x, 6)], 1.4); L(c, [(x, 50), (x, 58)], 1.4)
    R(c, 24, 24, 40, 40, b, ink=0.8)
def radio(c, a, b):
    R(c, 10, 20, 54, 54, a); E(c, (16, 28, 34, 46), b); L(c, [(44, 20), (52, 4)], 1.6)
def key(c, a, b):
    E(c, (8, 22, 28, 42), a); R(c, 26, 29, 56, 35, a, ink=1.0); R(c, 46, 35, 50, 42, a, ink=0.8)
def spool(c, a, b):
    R(c, 18, 16, 46, 48, a); R(c, 14, 10, 50, 16, b); R(c, 14, 48, 50, 54, b)
def lantern(c, a, b):
    R(c, 18, 18, 46, 52, a); E(c, (22, 22, 42, 46), hexc("#E3C46A")); P(c, [(22, 12), (42, 12), (46, 18), (18, 18)], b); L(c, [(24, 12), (32, 4), (40, 12)])
def book(c, a, b):
    P(c, [(14, 10), (48, 10), (50, 56), (16, 56)], a); R(c, 14, 10, 20, 56, b, ink=1.0); R(c, 26, 18, 44, 24, b, ink=0.6)
def flashlight(c, a, b):
    P(c, rot([(10, 26), (40, 26), (40, 38), (10, 38)], -0.4), a); P(c, rot([(40, 22), (54, 18), (54, 46), (40, 42)], -0.4), b)
def glowstick(c, a, b):
    P(c, rot([(28, 6), (36, 6), (36, 58), (28, 58)], 0.5), a); P(c, rot([(28, 6), (36, 6), (36, 12), (28, 12)], 0.5), b)
def flare(c, a, b):
    P(c, rot([(28, 14), (36, 14), (36, 60), (28, 60)], 0.4), a); E(c, (24, 2, 40, 18), hexc("#E39A3A"), ink=0.8); R(c, 28, 48, 36, 54, b, ink=0.8)
def compass(c, a, b):
    E(c, (10, 10, 54, 54), a); E(c, (16, 16, 48, 48), hexc("#E6E1D2")); P(c, [(32, 18), (36, 32), (32, 46), (28, 32)], b, ink=0.8)
def map(c, a, b):
    P(c, [(8, 14), (24, 10), (40, 14), (56, 10), (56, 50), (40, 54), (24, 50), (8, 54)], a); L(c, [(24, 10), (24, 50)], 0.8, 150); L(c, [(40, 14), (40, 54)], 0.8, 150); L(c, [(14, 40), (30, 26), (48, 34)], 1.4, 220)
def binoculars(c, a, b):
    R(c, 12, 18, 28, 50, a); R(c, 36, 18, 52, 50, a); R(c, 26, 26, 38, 34, b); E(c, (12, 44, 28, 56), b); E(c, (36, 44, 52, 56), b)
def padlock(c, a, b):
    R(c, 14, 28, 50, 56, a); L(c, [(20, 28), (20, 16), (32, 8), (44, 16), (44, 28)], 3.0, 230); E(c, (28, 36, 36, 44), b, ink=0.6)
def keycard(c, a, b):
    R(c, 8, 16, 56, 48, a); R(c, 8, 22, 56, 28, b, ink=0.6); R(c, 14, 34, 26, 44, hexc("#D9C38A"), ink=0.6)
def note(c, a, b):
    P(c, [(14, 8), (44, 8), (52, 16), (52, 56), (14, 56)], hexc("#E6E1D2"))
    for y in (20, 28, 36, 44):
        L(c, [(20, y), (46, y)], 0.8, 150)
def canteen(c, a, b):
    E(c, (12, 16, 52, 58), a); R(c, 28, 6, 36, 16, b); L(c, [(14, 36), (50, 36)], 1.2)
def thermos(c, a, b):
    R(c, 20, 14, 44, 58, a); R(c, 18, 6, 46, 14, b); R(c, 20, 30, 44, 36, b, ink=0.8)
def hook(c, a, b):
    L(c, [(36, 6), (36, 40), (30, 52), (20, 48), (18, 38)], 3.0, 230); R(c, 32, 4, 40, 10, b, ink=0.8)
def needle(c, a, b):
    L(c, rot([(10, 32), (54, 32)], -0.7), 2.4, 230); E(c, (44, 10, 52, 18), (0, 0, 0, 0), ink=1.0); L(c, [(14, 52), (30, 48), (40, 56)], 1.0, 160)
def whistle(c, a, b):
    P(c, [(10, 24), (40, 24), (40, 30), (54, 30), (54, 44), (10, 44)], a); E(c, (40, 30, 54, 44), b)
def blanket(c, a, b):
    P(c, [(8, 16), (56, 12), (54, 48), (10, 54)], a); L(c, [(12, 26), (54, 22)], 1.0, 130); L(c, [(12, 38), (54, 34)], 1.0, 130); R(c, 8, 46, 54, 52, b, ink=0.8)
def cleats(c, a, b):
    R(c, 12, 22, 52, 40, a); L(c, [(14, 40), (18, 50), (22, 40), (26, 50), (30, 40), (34, 50), (38, 40), (42, 50), (46, 40), (50, 50)], 1.6)
def stove(c, a, b):
    R(c, 12, 30, 52, 52, a); E(c, (20, 18, 44, 32), b); E(c, (26, 8, 38, 20), hexc("#5A9AD9"), ink=0.6)
def pouch(c, a, b):
    P(c, [(14, 20), (50, 20), (48, 54), (16, 54)], a); P(c, [(14, 20), (50, 20), (44, 34), (20, 34)], b)
def screwdriver(c, a, b):
    P(c, rot([(30, 4), (34, 4), (34, 36), (30, 36)], 0.6), a); P(c, rot([(26, 36), (38, 36), (38, 60), (26, 60)], 0.6), b)
def wrench(c, a, b):
    P(c, rot([(29, 16), (35, 16), (35, 60), (29, 60)], 0.6), a); P(c, rot([(22, 4), (42, 4), (42, 18), (36, 18), (36, 10), (28, 10), (28, 18), (22, 18)], 0.6), a)
def pliers(c, a, b):
    P(c, rot([(28, 4), (32, 4), (30, 30), (22, 60), (18, 58)], 0.2), a); P(c, rot([(32, 4), (36, 4), (42, 58), (38, 60), (32, 30)], 0.2), a)
    P(c, rot([(20, 40), (26, 40), (20, 60), (16, 58)], 0.2), b); P(c, rot([(38, 40), (44, 40), (46, 58), (42, 60)], 0.2), b)
def saw(c, a, b):
    P(c, [(6, 26), (46, 20), (46, 40), (6, 36)], a)
    L(c, [(6 + i * 4, 36 + (i % 2) * 3) for i in range(11)], 1.0, 180); P(c, [(44, 16), (60, 16), (60, 44), (44, 44)], b)
def photo(c, a, b):
    R(c, 12, 12, 52, 52, hexc("#E6E1D2")); R(c, 16, 16, 48, 42, a, ink=0.8)
def cards(c, a, b):
    P(c, rot([(18, 12), (42, 12), (42, 50), (18, 50)], -0.25), hexc("#E6E1D2")); P(c, rot([(22, 14), (46, 14), (46, 52), (22, 52)], 0.15), hexc("#E6E1D2")); E(c, (30, 26, 38, 34), b, ink=0.6)
def watch(c, a, b):
    R(c, 26, 4, 38, 60, b); E(c, (16, 16, 48, 48), a); E(c, (20, 20, 44, 44), hexc("#E6E1D2")); L(c, [(32, 32), (32, 24)]); L(c, [(32, 32), (38, 34)])
def ring(c, a, b):
    E(c, (14, 22, 50, 58), hexc("#C9A86A")); E(c, (20, 28, 44, 52), (0, 0, 0, 0)); E(c, (26, 10, 38, 22), hexc("#9AC2D8"))
def toy(c, a, b):
    E(c, (18, 22, 46, 54), a); E(c, (22, 8, 42, 28), a); E(c, (16, 6, 24, 14), a); E(c, (40, 6, 48, 14), a)
def brush(c, a, b):
    P(c, rot([(30, 18), (34, 18), (34, 60), (30, 60)], 0.6), hexc("#7EA6C2")); P(c, rot([(28, 4), (36, 4), (36, 18), (28, 18)], 0.6), hexc("#E6E1D2"))
def coins(c, a, b):
    for x, y in ((22, 40), (40, 40), (31, 26)):
        E(c, (x - 10, y - 10, x + 10, y + 10), hexc("#C9A86A"))
def pen(c, a, b):
    P(c, rot([(29, 6), (35, 6), (35, 52), (32, 60), (29, 52)], 0.6), hexc("#3F5B6A"))
def candle(c, a, b):
    R(c, 24, 22, 40, 58, hexc("#E6E1D2")); E(c, (28, 6, 36, 20), hexc("#E39A3A"), ink=0.6)
def stick_default(c, a, b):
    box(c, a, b)


SHAPES = {k: v for k, v in globals().items() if callable(v) and k not in ("P", "E", "R", "L", "rot", "Canvas", "hexc", "mix")}


def icon(i, spec):
    shape, a, b = spec
    c = Canvas(64, 64, seed=zlib.crc32(i.encode()) % 100000 + 7)
    fn = SHAPES.get(shape, box)
    fn(c, hexc(a), hexc(b))
    rel = f"ui/icons/template_{i}.png"
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    c.save(p, winter=False)
    return {"id": "icon." + i, "name": i.replace("_", " ").capitalize() + " (inventory icon)", "template": "res://assets/templates/" + rel,
            "display_size": [32, 32], "source_size": [64, 64], "pivot": [0.5, 0.5], "transparency": "required", "directions": "none",
            "complexity": "simple", "status": "READY", "notes": "Generated placeholder (tools/art/gen_item_icons.py) - replace via assets/overrides/ui/icons/" + i + ".png."}


# ---------------------------------------------------------------- held melee art (40 x 120)
def held(name, label, head, haft, kind):
    c = Canvas(40, 120, seed=1601 + len(name))
    if kind == "blade":
        P(c, [(16, 112), (24, 112), (24, 80), (16, 80)], haft); P(c, [(13, 80), (27, 80), (27, 76), (13, 76)], STEEL_D)
        P(c, [(16, 76), (24, 76), (23, 30 if name == "kitchen_knife" else 22), (16, 34 if name == "kitchen_knife" else 28)], head)
    elif kind == "bat":
        P(c, [(17, 114), (23, 114), (25, 60), (27, 8), (13, 8), (15, 60)], haft)
    elif kind == "stick":
        P(c, [(17, 114), (23, 114), (22, 14), (20, 4), (18, 14)], haft)
    elif kind == "pipe":
        P(c, [(16, 114), (24, 114), (24, 6), (16, 6)], head); P(c, [(14, 6), (26, 6), (26, 14), (14, 14)], STEEL_D)
    else:
        P(c, [(18, 114), (22, 114), (22, 14), (18, 14)], haft)
        if kind == "axe":
            P(c, [(22, 14), (36, 8), (36, 40), (22, 32)], head)
        elif kind == "hammer":
            P(c, [(8, 8), (32, 8), (32, 20), (8, 20)], head)
        elif kind == "crowbar":
            P(c, [(17, 114), (23, 114), (23, 14), (17, 14)], head); P(c, [(17, 14), (8, 6), (10, 2), (23, 10)], head)
        elif kind == "shovel":
            P(c, [(8, 8), (32, 8), (30, 40), (20, 46), (10, 40)], head)
        elif kind == "pick":
            P(c, [(2, 22), (20, 8), (38, 22), (20, 16)], head)
    rel = f"items/template_{name}.png"
    p = os.path.join(TPL, rel)
    c.save(p, winter=False)
    return {"id": "item." + name, "name": label + " (held)", "template": "res://assets/templates/" + rel, "display_size": [20, 60],
            "source_size": [40, 120], "pivot": [0.5, 0.9], "transparency": "required", "directions": "none", "complexity": "simple",
            "status": "READY", "notes": "Generated placeholder (tools/art/gen_item_icons.py) - replace with tablet art."}


HELD = [("kitchen_knife", "Kitchen knife", "#A9A49A", "#3A3026", "blade"), ("hunting_knife", "Hunting knife", "#8A8478", "#6A4A30", "blade"),
        ("baseball_bat", "Baseball bat", "#9A7A55", "#9A7A55", "bat"), ("crowbar", "Crowbar", "#5E6467", "#5E6467", "crowbar"),
        ("hammer", "Hammer", "#5E6467", "#6A4A30", "hammer"), ("fire_axe", "Fire axe", "#A9A49A", "#7E2A22", "axe"),
        ("shovel", "Shovel", "#5E6467", "#6A4A30", "shovel"), ("pickaxe", "Pickaxe", "#5E6467", "#6A4A30", "pick"),
        ("sharpened_stick", "Sharpened stick", "#7A5E40", "#7A5E40", "stick"), ("metal_pipe", "Metal pipe", "#5E6467", "#5E6467", "pipe"),
        ("ice_pick", "Ice pick", "#3F5B6A", "#3F5B6A", "pick")]


if __name__ == "__main__":
    icons = [icon(i, spec) for (i, _cat, _en, _da, _den, _dda, _wt, _st, _m, spec) in build_catalogue.C]
    with open(os.path.join(ROOT, "assets", "manifest", "visual_item_icons.json"), "w") as f:
        json.dump({"kind": "visual", "category": "item_icons", "assets": icons}, f, indent="\t"); f.write("\n")
    held_assets = [held(n, l, hexc(h), hexc(w), k) for n, l, h, w, k in HELD]
    with open(os.path.join(ROOT, "assets", "manifest", "visual_melee_014.json"), "w") as f:
        json.dump({"kind": "visual", "category": "melee_014", "assets": held_assets}, f, indent="\t"); f.write("\n")
    print("item icons:", len(icons), "held weapons:", len(held_assets))
