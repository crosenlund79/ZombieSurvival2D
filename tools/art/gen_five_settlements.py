#!/usr/bin/env python3
"""Red Thaw — The Five Settlements (iteration 014): outdoor art for the four new towns.

* A parametric building facade (top-down 3/4 like the Ashgrove storefronts):
  material (brick, clapboard, corrugated steel, concrete, logs), storeys, roof
  (flat parapet, gable, shed), painted sign, doors (single, double, roll-up bay),
  window grid (frosted, dark, boarded), awning, chimney, extras (red cross,
  police band, clock, steeple). Every building of the new towns is one call.
* Landmarks and dressing: lighthouse, dock crane, frozen trawler, shipping
  containers, bollards, fish crates, mine headframe, mine adit, ore hopper, slag
  heap, water tower, fuel tanks, substation, church, war memorial.
* Icebergs and floes (drifting across the harbor channel) and ground tiles:
  open dark water, sea ice, pier planks, rail track.

Writes templates under assets/templates/world/settlements/ and the manifest
assets/manifest/visual_settlements.json. Never touches creator overrides.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, value_noise, SS  # noqa: E402
import gen_winter as gw  # noqa: E402
from gen_world_awakens import paint_text  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []

BRICK = hexc("#6A4334")
BRICK_D = hexc("#4E3026")
CONCRETE = hexc("#7C7A74")
CORR = hexc("#5D676B")
CORR_R = hexc("#6E4A38")
NAVY = hexc("#2F3F4E")
RED = hexc("#7E2A22")
SEA = hexc("#1C2A33")
WATER_L = hexc("#2C3E48")
ICE_L = hexc("#D7E2E7")
ICE_M = hexc("#A9BEC8")
ICE_D = hexc("#7E97A3")


def out(rel):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_five_settlements.py) - replace with tablet art."})


def save(c, name, label, W, H, base, display=None):
    rel = f"world/settlements/template_{name}.png"
    c.save(out(rel), winter=False)
    entry("set." + name, label, rel, display or (W // 2, H // 2), (W, H), (0.5, base / H))


# ------------------------------------------------------------------ materials
def wall(c, x0, x1, y0, y1, mat, col):
    if mat == "clap":
        return gw.clapboard(c, x0, x1, y0, y1, col, board=18)
    m = c.fill([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, tex=0.35, cell=8, light=(-1, -1, 0.3))
    if mat == "brick":
        y, row = y0 + 14, 0
        while y < y1:
            c.ink([(x0, y), (x1, y)], width=0.9, alpha=90, seg=10)
            off = 0 if row % 2 == 0 else 22
            for x in range(int(x0) + off, int(x1), 44):
                c.ink([(x, y - 14), (x, y)], width=0.8, alpha=70, seg=6)
            y += 14
            row += 1
    elif mat == "corr":
        for x in range(int(x0) + 6, int(x1), 12):
            c.ink([(x, y0), (x, y1)], width=1.0, alpha=110, seg=8)
        for _ in range(8):
            b = c.blob(c.rng.uniform(x0 + 20, x1 - 20), c.rng.uniform(y0 + 20, y1 - 20), c.rng.uniform(10, 40), c.rng.uniform(6, 16), n=9, irregular=0.4)
            c.fill(b, mix(gw.RUST, col, 0.4), tex=0.35)
    elif mat == "concrete":
        for y in range(int(y0) + 60, int(y1), 60):
            c.ink([(x0, y), (x1, y)], width=0.9, alpha=80, seg=10)
        for x in range(int(x0) + 120, int(x1), 120):
            c.ink([(x, y0), (x, y1)], width=0.8, alpha=60, seg=8)
    elif mat == "logs":
        gw.logs_wall(c, x0, x1, y0, y1)
    c.grime(m, 0.45)
    return m


def facade(name, label, *, w=640, storeys=1, mat="brick", col=BRICK, roof="flat", sign=None, sign_col=None,
           door="single", windows=3, boarded=0.3, awning=None, chimney=False, extras=(), roof_col=None):
    sh = 150  # upper storey height (source px)
    g_sh = 250 if awning else (200 if sign else 160)  # the ground floor carries the sign and awning
    fx0, fx1 = 60, 60 + w
    top_space = 150 if roof == "gable" else 80
    if "steeple" in extras:
        top_space += 220
    ftop = top_space + 30
    base = ftop + (storeys - 1) * sh + g_sh + 30
    W, H = fx1 + 60, base + 30
    c = Canvas(W, H, seed=40000 + sum(map(ord, name)))
    c.soft_shadow((fx0 - 40, base - 26, fx1 + 40, base + 18), alpha=135, blur=12)
    wall(c, fx0, fx1, ftop, base - 16, mat, col)
    c.shade(c.mask([(fx1 - 90, ftop), (fx1, ftop), (fx1, base), (fx1 - 60, base)]), 1, 0, 5, 70, reach=1.0)
    c.ink_poly([(fx0, ftop), (fx1, ftop), (fx1, base - 16), (fx0, base - 16)], width=3.0)
    rc = roof_col or mix(gw.CHAR_L, gw.RUST_D, 0.3)
    mid = (fx0 + fx1) / 2
    if roof == "gable":
        r = [(mid, ftop - 130), (fx1 + 30, ftop + 10), (fx0 - 30, ftop + 10)]
        gw.pf(c, r, rc, tex=0.35, ink=3.0)
        snow = [(mid, ftop - 140), (fx1 + 26, ftop), (fx1 - 30, ftop + 8), (mid, ftop - 100), (fx0 + 30, ftop + 8), (fx0 - 26, ftop)]
        m = c.fill(snow, gw.SNOW, tex=0.12, light=(-1, -1, 0.3)); c.shade(m, 1, 0.5, 5, 60, reach=0.5)
        gw.icicles(c, fx0 - 20, fx1 + 20, ftop + 10, 18)
    elif roof == "shed":
        r = [(fx0 - 20, ftop - 50), (fx1 + 20, ftop - 10), (fx1 + 20, ftop + 8), (fx0 - 20, ftop + 8)]
        gw.pf(c, r, rc, tex=0.35, ink=2.8)
        gw.snow_band(c, [(fx0 - 20, ftop - 50), (mid, ftop - 32), (fx1 + 20, ftop - 12)], 16)
    else:
        par = [(fx0 - 14, ftop - 30), (fx1 + 14, ftop - 30), (fx1 + 14, ftop + 6), (fx0 - 14, ftop + 6)]
        gw.pf(c, par, mix(col, gw.CHAR_L, 0.35), tex=0.3, ink=2.6)
        gw.snow_band(c, [(fx0 - 14, ftop - 30), (mid, ftop - 34), (fx1 + 14, ftop - 30)], 16)
        gw.icicles(c, fx0, fx1, ftop + 6, max(8, w // 30))
    if chimney:
        cx = fx1 - 90
        gw.pf(c, [(cx, ftop - 110), (cx + 34, ftop - 110), (cx + 34, ftop - 20), (cx, ftop - 20)], BRICK_D, ink=2.0)
        gw.snow_band(c, [(cx - 4, ftop - 110), (cx + 38, ftop - 110)], 8)
    if "steeple" in extras:
        sx0, sx1 = mid - 50, mid + 50
        gw.pf(c, [(sx0, ftop - 120), (sx1, ftop - 120), (sx1, ftop + 10), (sx0, ftop + 10)], col, ink=2.6)
        gw.pf(c, [(mid, ftop - 330), (sx1 + 14, ftop - 120), (sx0 - 14, ftop - 120)], rc, ink=2.8)
        c.ink([(mid, ftop - 380), (mid, ftop - 330)], width=3.0)
        c.ink([(mid - 18, ftop - 360), (mid + 18, ftop - 360)], width=3.0)
        gw.frosted_window(c, mid - 16, ftop - 96, 32, 56, dark=True)
    if "clock" in extras:
        gw.pf(c, [(mid - 50, ftop - 100), (mid + 50, ftop - 100), (mid + 50, ftop - 20), (mid - 50, ftop - 20)], col, ink=2.4)
        c.ellipse_fill((mid - 30, ftop - 90, mid + 30, ftop - 30), hexc("#D8D2C0"))
        c.ink([(mid, ftop - 60), (mid, ftop - 82)], width=2.4)
        c.ink([(mid, ftop - 60), (mid + 16, ftop - 54)], width=2.4)
        gw.snow_band(c, [(mid - 52, ftop - 100), (mid + 52, ftop - 100)], 8)
    # sign
    if sign:
        sy = ftop + 16
        sb = [(fx0 + 50, sy), (fx1 - 50, sy), (fx1 - 50, sy + 52), (fx0 + 50, sy + 52)]
        gw.pf(c, sb, sign_col or mix(gw.CHAR_L, gw.TIMBER_D, 0.5), tex=0.3, ink=2.4)
        paint_text(c, sign, (fx0 + 64, sy + 6, fx1 - 64, sy + 46), mix(gw.SNOW_L, hexc("#D9C38A"), 0.35))
        gw.snow_band(c, [(fx0 + 50, sy - 2), (fx1 - 50, sy - 2)], 6)
    if "police" in extras:
        band = [(fx0, ftop + 76), (fx1, ftop + 76), (fx1, ftop + 92), (fx0, ftop + 92)]
        c.fill(band, NAVY, tex=0.2)
    # windows: upper storeys from the top down, then the ground floor (beside the door)
    gy = base - 16
    wh = 70
    for s in range(storeys):
        ground = s == storeys - 1
        wy = (gy - 120) if ground else (ftop + (90 if sign else 30) + s * sh)
        for k in range(windows):
            wx = fx0 + 40 + (w - 80 - 70) * (k / max(1, windows - 1)) if windows > 1 else mid - 35
            if ground and door != "none" and abs(wx + 35 - mid) < (170 if door == "bay" else 110):
                continue
            gw.frosted_window(c, wx, wy, 70, wh, boarded=c.rng.random() < boarded, dark=c.rng.random() < 0.4)
    if door == "single":
        gw.blocked_door(c, mid - 38, gy - 120, 76, 120) if c.rng.random() < 0.3 else gw.pf(c, [(mid - 38, gy - 120), (mid + 38, gy - 120), (mid + 38, gy), (mid - 38, gy)], gw.TIMBER_D, ink=2.4)
    elif door == "double":
        for dx in (-70, 0):
            gw.pf(c, [(mid + dx, gy - 130), (mid + dx + 70, gy - 130), (mid + dx + 70, gy), (mid + dx, gy)], mix(gw.GLASS_D, gw.TIMBER_D, 0.4), ink=2.2)
    elif door == "bay":
        bx0, bx1 = mid - 150, mid + 150
        gw.pf(c, [(bx0, gy - 190), (bx1, gy - 190), (bx1, gy), (bx0, gy)], gw.STEEL, ink=2.6)
        yy = gy - 190
        while yy < gy:
            c.ink([(bx0 + 4, yy), (bx1 - 4, yy)], width=1.0, alpha=120, seg=8)
            yy += 18
        gw.drift(c, mid, gy + 2, 120, 26)
    if awning:
        a1, a2 = awning
        aw = [(fx0 + 20, gy - 175), (fx1 - 20, gy - 175), (fx1 - 4, gy - 135), (fx0 + 4, gy - 135)]
        c.fill(aw, a2, tex=0.3)
        for k in range(12):
            if k % 2 == 0:
                x0 = fx0 + 20 + (w - 40) * k / 12
                x1 = fx0 + 20 + (w - 40) * (k + 1) / 12
                c.fill([(x0, gy - 175), (x1, gy - 175), (x1 + 2, gy - 135), (x0 + 2, gy - 135)], a1, tex=0.3)
        c.ink_poly(aw, width=2.2)
        gw.snow_band(c, [(fx0 + 20, gy - 177), (fx1 - 20, gy - 177)], 8)
    if "cross" in extras:
        cx, cy = fx1 - 80, ftop + 50
        c.fill([(cx - 22, cy - 8), (cx + 22, cy - 8), (cx + 22, cy + 8), (cx - 22, cy + 8)], RED)
        c.fill([(cx - 8, cy - 22), (cx + 8, cy - 22), (cx + 8, cy + 22), (cx - 8, cy + 22)], RED)
    found = [(fx0 - 8, base - 18), (fx1 + 8, base - 18), (fx1 + 8, base), (fx0 - 8, base)]
    gw.pf(c, found, gw.ASH, tex=0.35, ink=2.0)
    for dx in range(fx0 - 30, fx1 + 50, 110):
        gw.drift(c, dx + c.rng.uniform(-10, 10), base + 4, c.rng.uniform(40, 80), c.rng.uniform(12, 26))
    save(c, name, label, W, H, base)
    return (W // 2, H // 2), w // 2


# ------------------------------------------------------------------ landmarks and dressing
def lighthouse():
    W, H, base = 260, 700, 680
    c = Canvas(W, H, seed=41001)
    c.soft_shadow((70, base - 20, 190, base + 10), alpha=130, blur=10)
    body = [(96, 170), (164, 170), (188, base - 10), (72, base - 10)]
    gw.pf(c, body, hexc("#C9C3B6"), tex=0.3, ink=3.0, shade=(1, 0, 5, 80))
    for k, y in enumerate(range(230, base - 40, 110)):
        band = [(96 - (y - 170) * 0.045, y), (164 + (y - 170) * 0.045, y), (164 + (y + 40 - 170) * 0.045, y + 40), (96 - (y + 40 - 170) * 0.045, y + 40)]
        c.fill(band, RED, tex=0.3)
    gw.pf(c, [(86, 120), (174, 120), (174, 172), (86, 172)], gw.STEEL_D, ink=2.4)
    gw.pf(c, [(100, 128), (160, 128), (160, 166), (100, 166)], hexc("#3A3A30"), ink=1.6)
    gw.pf(c, [(80, 104), (180, 104), (130, 60)], gw.CHAR_L, ink=2.4)
    gw.snow_band(c, [(80, 104), (130, 62), (180, 104)], 10)
    gw.drift(c, 130, base, 110, 30)
    save(c, "lighthouse", "Harbor lighthouse (dark)", W, H, base)


def crane():
    W, H, base = 520, 640, 620
    c = Canvas(W, H, seed=41002)
    c.soft_shadow((150, base - 20, 370, base + 10), alpha=130, blur=10)
    for lx in (180, 330):
        gw.pf(c, [(lx, 240), (lx + 16, 240), (lx + 26, base - 10), (lx - 10, base - 10)], hexc("#8A6A2E"), ink=2.2)
    for y in range(280, base - 20, 70):
        c.ink([(184, y), (340, y + 50)], width=2.0)
        c.ink([(340, y), (184, y + 50)], width=2.0)
    gw.pf(c, [(150, 200), (360, 200), (360, 250), (150, 250)], hexc("#8A6A2E"), ink=2.6)
    gw.pf(c, [(40, 190), (500, 150), (504, 168), (44, 210)], hexc("#9A7A3A"), ink=2.6)
    c.ink([(70, 196), (70, 330)], width=1.6)
    gw.pf(c, [(58, 330), (82, 330), (82, 352), (58, 352)], gw.STEEL_D, ink=1.6)
    gw.snow_band(c, [(40, 188), (270, 170), (500, 148)], 10)
    save(c, "crane", "Dock crane (frozen in place)", W, H, base)


def trawler():
    W, H, base = 760, 420, 380
    c = Canvas(W, H, seed=41003)
    hull = [(40, 240), (720, 220), (680, base - 10), (100, base - 6)]
    gw.pf(c, hull, mix(NAVY, gw.RUST, 0.25), tex=0.4, ink=3.0, shade=(1, 0.3, 5, 80))
    c.fill([(52, 252), (708, 234), (704, 250), (54, 268)], RED, tex=0.3)
    gw.pf(c, [(380, 120), (560, 120), (560, 230), (380, 236)], hexc("#C8C2B4"), ink=2.6)
    for wx in (400, 450, 500):
        gw.frosted_window(c, wx, 140, 34, 30, dark=True)
    c.ink([(250, 60), (250, 236)], width=4.0)
    c.ink([(250, 70), (120, 236)], width=1.4)
    c.ink([(250, 70), (380, 230)], width=1.4)
    gw.snow_band(c, [(40, 236), (380, 226), (720, 216)], 18)
    gw.snow_band(c, [(380, 118), (560, 118)], 12)
    ice = [(0, base - 30), (W, base - 40), (W, H), (0, H)]
    gw.pf(c, ice, ICE_M, tex=0.2, ink=1.6)
    save(c, "trawler", "Fishing trawler frozen into the ice", W, H, base)


def container(col, name):
    W, H, base = 480, 260, 240
    c = Canvas(W, H, seed=41004 + len(name))
    c.soft_shadow((30, base - 18, 450, base + 8), alpha=120, blur=8)
    box = [(30, 70), (450, 70), (450, base - 6), (30, base - 6)]
    gw.pf(c, box, col, tex=0.35, ink=2.8, shade=(1, 0, 5, 70))
    for x in range(44, 440, 16):
        c.ink([(x, 74), (x, base - 10)], width=1.0, alpha=110, seg=8)
    gw.snow_band(c, [(30, 70), (240, 64), (450, 70)], 16)
    save(c, name, f"Shipping container ({name.split('_')[-1]})", W, H, base)


def small(name, label, W, H, base, draw):
    c = Canvas(W, H, seed=41100 + sum(map(ord, name)))
    draw(c, W, H, base)
    save(c, name, label, W, H, base)


def d_bollard(c, W, H, base):
    gw.pf(c, [(W / 2 - 16, 30), (W / 2 + 16, 30), (W / 2 + 18, base), (W / 2 - 18, base)], gw.STEEL_D, ink=2.2)
    c.ellipse_fill((W / 2 - 22, 20, W / 2 + 22, 40), gw.STEEL)
    gw.snow_band(c, [(W / 2 - 22, 26), (W / 2 + 22, 26)], 8)


def d_fishcrates(c, W, H, base):
    for i, (x, y) in enumerate(((20, base - 60), (100, base - 60), (60, base - 116))):
        gw.pf(c, [(x, y), (x + 76, y), (x + 76, y + 56), (x, y + 56)], gw.TIMBER_M if i % 2 else hexc("#5A6B78"), ink=2.0)
        gw.snow_band(c, [(x, y), (x + 76, y)], 6)


def d_headframe(c, W, H, base):
    for lx, rx in ((80, 160), (300, 220)):
        gw.pf(c, [(lx, base - 10), (lx + 22, base - 10), (rx + 22, 90), (rx, 90)], gw.STEEL_D, ink=2.4)
    for y in range(140, base - 30, 60):
        c.ink([(110 + (y - 90) * 0.0, y), (300 - (y - 90) * 0.25, y + 40)], width=1.8)
    c.ellipse_fill((150, 40, 250, 140), gw.STEEL)
    c.ellipse_fill((178, 68, 222, 112), gw.CHAR)
    c.ink([(200, 90), (200, base - 40)], width=1.4)
    gw.snow_band(c, [(150, 50), (200, 38), (250, 50)], 8)
    gw.drift(c, W / 2, base, 140, 30)


def d_adit(c, W, H, base):
    rock = [(0, base), (40, 120), (180, 40), (360, 30), (520, 120), (W, base)]
    gw.pf(c, rock, hexc("#4E4943"), tex=0.45, ink=3.0, shade=(1, 0.5, 5, 90))
    gw.snow_band(c, [(40, 118), (180, 38), (360, 28), (520, 118)], 22)
    mouth = [(210, base - 10), (210, 180), (240, 150), (340, 150), (370, 180), (370, base - 10)]
    c.fill(mouth, hexc("#0E0D0C"), tex=0.1)
    for x in (204, 366):
        gw.pf(c, [(x - 10, 160), (x + 10, 160), (x + 10, base - 6), (x - 10, base - 6)], gw.TIMBER, ink=2.0)
    gw.pf(c, [(186, 140), (394, 140), (394, 164), (186, 164)], gw.TIMBER_D, ink=2.2)
    paint_text(c, "No. 3", (250, 112, 330, 136), gw.SNOW_L, worn=0.4)
    c.ink([(220, base - 8), (360, base - 8)], width=3.0, color=gw.STEEL_D)


def d_hopper(c, W, H, base):
    for lx in (60, 240):
        gw.pf(c, [(lx, 150), (lx + 16, 150), (lx + 16, base), (lx, base)], gw.TIMBER_D, ink=2.0)
    gw.pf(c, [(30, 60), (290, 60), (210, 170), (110, 170)], CORR_R, ink=2.6)
    gw.snow_band(c, [(30, 58), (290, 58)], 14)


def d_slag(c, W, H, base):
    m = c.fill([(0, base), (80, 120), (200, 60), (330, 110), (W, base)], hexc("#3C3834"), tex=0.5, light=(-1, -1, 0.3))
    c.ink_poly([(0, base), (80, 120), (200, 60), (330, 110), (W, base)], width=2.6)
    gw.snow_band(c, [(60, 128), (200, 58), (330, 108)], 14)


def d_watertower(c, W, H, base):
    for lx, rx in ((60, 110), (260, 210)):
        gw.pf(c, [(lx, base - 10), (lx + 14, base - 10), (rx + 14, 250), (rx, 250)], gw.STEEL_D, ink=2.2)
    for y in range(290, base - 20, 70):
        c.ink([(80, y), (240, y + 40)], width=1.6)
    tank = [(70, 110), (250, 110), (260, 260), (60, 260)]
    gw.pf(c, tank, hexc("#7D8A88"), ink=3.0, shade=(1, 0, 5, 80))
    gw.pf(c, [(60, 110), (160, 50), (260, 110)], gw.CHAR_L, ink=2.6)
    paint_text(c, "CORRAN", (80, 160, 240, 200), gw.SNOW_L, worn=0.4)
    gw.snow_band(c, [(60, 110), (160, 48), (260, 110)], 12)


def d_tanks(c, W, H, base):
    for i, cx in enumerate((120, 330)):
        t = [(cx - 90, 90), (cx + 90, 90), (cx + 90, base - 10), (cx - 90, base - 10)]
        gw.pf(c, t, hexc("#8C8A80") if i == 0 else hexc("#77806F"), ink=2.8, shade=(1, 0, 5, 80))
        c.ellipse_fill((cx - 90, 70, cx + 90, 110), hexc("#9C9A90"))
        gw.snow_band(c, [(cx - 90, 88), (cx, 74), (cx + 90, 88)], 12)
        c.ink([(cx - 60, 140), (cx + 60, 140)], width=1.4, alpha=150)
    paint_text(c, "FUEL", (80, 170, 160, 210), RED, worn=0.4)


def d_substation(c, W, H, base):
    gw.pf(c, [(20, base - 20), (W - 20, base - 20), (W - 20, base - 6), (20, base - 6)], gw.ASH, ink=1.8)
    for x in range(40, W - 30, 40):
        c.ink([(x, base - 140), (x, base - 8)], width=1.2, alpha=180)
    c.ink([(30, base - 140), (W - 30, base - 140)], width=1.4)
    for cx in (110, 250):
        gw.pf(c, [(cx - 50, base - 120), (cx + 50, base - 120), (cx + 50, base - 24), (cx - 50, base - 24)], hexc("#5F6A5C"), ink=2.2)
        for k in range(3):
            c.ellipse_fill((cx - 36 + k * 30, base - 140, cx - 24 + k * 30, base - 116), hexc("#8A7A62"))
    gw.snow_band(c, [(60, base - 120), (310, base - 120)], 8)


def d_memorial(c, W, H, base):
    gw.pf(c, [(60, base - 20), (180, base - 20), (180, base - 4), (60, base - 4)], CONCRETE, ink=2.0)
    gw.pf(c, [(100, 60), (140, 60), (150, base - 20), (90, base - 20)], hexc("#8E8A80"), ink=2.6)
    gw.snow_band(c, [(96, 58), (144, 58)], 8)
    gw.drift(c, 120, base, 80, 18)


def d_iceberg(variant):
    def d(c, W, H, base):
        rng = c.rng
        pts = []
        n = 11
        for k in range(n):
            a = math.pi + math.pi * k / (n - 1)
            r = (W * 0.42) * (0.75 + rng.uniform(0, 0.35))
            pts.append((W / 2 + math.cos(a) * r, base - 30 + math.sin(a) * r * (0.9 + variant * 0.15)))
        under = [(W * 0.06, base - 30), (W * 0.94, base - 30), (W * 0.84, base - 6), (W * 0.16, base - 4)]
        c.fill(under, ICE_D, tex=0.2)
        m = c.fill(pts, ICE_L, tex=0.25, light=(-1, -1, 0.35))
        c.shade(m, 1, 0.5, 5, 80, reach=0.6)
        c.ink_poly(pts, width=2.8)
        for _ in range(4):
            x = rng.uniform(W * 0.2, W * 0.8)
            c.ink([(x, base - 40), (x + rng.uniform(-20, 20), base - 40 - rng.uniform(30, 90))], width=1.2, alpha=140, color=ICE_D)
        c.ink([(W * 0.04, base - 30), (W * 0.96, base - 30)], width=1.8, alpha=150, color=hexc("#9FB3BC"))
    return d


def d_floe(c, W, H, base):
    pts = [(10, base - 20), (60, base - 44), (180, base - 48), (250, base - 30), (230, base - 6), (40, base - 4)]
    m = c.fill(pts, ICE_M, tex=0.2, light=(-1, -1, 0.3))
    c.ink_poly(pts, width=2.0)


def tile(name, label, kind, size=256):
    n = size
    rng = np.random.default_rng(len(name) * 71)
    nz = value_noise(n, n, 32, int(rng.integers(1 << 20)), octaves=4, wrap=True)
    fine = value_noise(n, n, 6, int(rng.integers(1 << 20)), octaves=2, wrap=True)
    yy, xx = np.mgrid[0:n, 0:n]
    if kind == "water":
        base = np.array(SEA[:3], np.float32)
        shade = 0.85 + (nz - 0.5) * 0.4 + 0.08 * np.sin((yy / n) * math.tau * 6 + nz * 4)
    elif kind == "seaice":
        base = np.array(ICE_M[:3], np.float32)
        shade = 0.92 + (nz - 0.5) * 0.25 + (fine - 0.5) * 0.08
    elif kind == "pier":
        base = np.array(gw.TIMBER[:3], np.float32)
        shade = (0.86 + (fine - 0.5) * 0.2) * np.where((yy % 32) < 3, 0.55, 1.0)
    else:  # rail: frozen ballast with sleepers and two rails (horizontal)
        base = np.array(gw.ASH[:3], np.float32)
        shade = 0.85 + (nz - 0.5) * 0.3 + (fine - 0.5) * 0.25
    rgb = np.clip(base[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, np.full((n, n), 255, np.uint8)]), "RGBA")
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(len(name) * 13)
    if kind == "seaice":
        for _ in range(9):
            x, y = r.uniform(0, n), r.uniform(0, n)
            pts = [(x + ox, y + oy) for ox, oy in ((0, 0), (r.uniform(20, 60), r.uniform(-10, 10)), (r.uniform(40, 90), r.uniform(-20, 20)))]
            d.line(pts, fill=(120, 140, 150, 160), width=2)
    elif kind == "water":
        for _ in range(14):
            x, y = r.uniform(0, n), r.uniform(0, n)
            d.line((x, y, x + r.uniform(10, 30), y), fill=(70, 92, 104, 140), width=1)
    elif kind == "rail":
        for x in range(0, n, 32):
            d.rectangle((x + 4, 70, x + 18, 186), fill=(78, 62, 46, 255), outline=(30, 24, 18, 255))
        for y in (98, 158):
            d.rectangle((0, y, n, y + 7), fill=(70, 74, 76, 255), outline=(28, 30, 32, 255))
    rel = f"world/settlements/template_{name}.png"
    img.save(out(rel))
    entry("set." + name, label, rel, (size, size), (size, size), (0, 0), "Generated seamless tile (tools/art/gen_five_settlements.py).")


# ------------------------------------------------------------------ the catalogue of buildings
BUILDINGS = {
    # Port Halden (frozen harbor)
    "harbor_office": dict(label="Harbor master's office", w=560, storeys=2, mat="brick", col=mix(BRICK, NAVY, 0.25), sign="HARBOR MASTER", chimney=True),
    "warehouse_a": dict(label="Waterfront warehouse", w=900, storeys=2, mat="corr", col=CORR, roof="shed", sign="PIER 4", door="bay", windows=4, boarded=0.5),
    "cannery": dict(label="Cannery", w=820, storeys=2, mat="brick", col=BRICK_D, sign="NORTHSEA CANNERY", door="double", windows=5, boarded=0.4, chimney=True),
    "chandlery": dict(label="Ship chandlery (marine supplies)", w=520, storeys=1, mat="clap", col=mix(gw.PAINT_B, NAVY, 0.3), roof="gable", sign="CHANDLERY", awning=(NAVY, hexc("#C9C1AE"))),
    "net_shed": dict(label="Net shed", w=380, storeys=1, mat="clap", col=mix(gw.TIMBER_L, gw.ASH, 0.4), roof="shed", door="single", windows=2, boarded=0.6),
    "harbor_house": dict(label="Harbor cottage", w=420, storeys=2, mat="clap", col=mix(gw.PAINT_G, RED, 0.25), roof="gable", windows=2, chimney=True),
    # Greyhollow (mining)
    "mine_office": dict(label="Mine office", w=600, storeys=2, mat="brick", col=mix(BRICK, gw.ASH, 0.3), sign="GREYHOLLOW MINING CO.", windows=4, chimney=True),
    "general_store": dict(label="General store", w=560, storeys=1, mat="clap", col=mix(gw.TIMBER_L, gw.PAINT_G, 0.5), roof="gable", sign="GENERAL STORE", awning=(hexc("#6E3A2A"), hexc("#C9C1AE"))),
    "mine_supply": dict(label="Mining equipment supplier", w=620, storeys=1, mat="corr", col=CORR_R, roof="shed", sign="MINE SUPPLY", door="bay", windows=2),
    "rowhouse": dict(label="Miners' row house", w=720, storeys=2, mat="brick", col=mix(BRICK_D, gw.ASH, 0.35), roof="gable", windows=4, boarded=0.4, chimney=True),
    "store_shed": dict(label="Industrial storage shed", w=640, storeys=1, mat="corr", col=CORR, roof="shed", door="bay", windows=0),
    # Corran Junction (industrial / service)
    "factory": dict(label="Factory hall", w=1000, storeys=2, mat="brick", col=mix(BRICK, gw.CHAR_L, 0.3), roof="shed", sign="CORRAN WORKS", door="bay", windows=6, boarded=0.5, chimney=True),
    "machine_shop": dict(label="Machine shop", w=620, storeys=1, mat="concrete", col=CONCRETE, sign="MACHINE SHOP", door="bay", windows=3),
    "utility": dict(label="Power & water utility building", w=560, storeys=2, mat="concrete", col=mix(CONCRETE, gw.PAINT_G, 0.3), sign="POWER & WATER", windows=3),
    "corner_store": dict(label="Corner store", w=480, storeys=1, mat="brick", col=mix(BRICK, gw.PAINT_B, 0.3), sign="CORNER STORE", awning=(hexc("#3F5B4A"), hexc("#C9C1AE"))),
    "worker_house": dict(label="Worker's house", w=440, storeys=1, mat="clap", col=mix(gw.PAINT_B, gw.ASH, 0.4), roof="gable", windows=2, chimney=True),
    "warehouse_b": dict(label="Rail-side warehouse", w=860, storeys=2, mat="corr", col=CORR_R, roof="shed", sign="FREIGHT", door="bay", windows=3, boarded=0.4),
    # Stillwater (residential / commercial)
    "civic_hall": dict(label="Stillwater Civic Hall (three storeys)", w=760, storeys=3, mat="brick", col=mix(BRICK, hexc("#8A7A62"), 0.35), sign="CIVIC HALL", door="double", windows=5, boarded=0.2, extras=("clock",)),
    "clinic": dict(label="Clinic", w=600, storeys=1, mat="concrete", col=mix(CONCRETE, gw.SNOW, 0.35), sign="CLINIC", door="double", windows=3, extras=("cross",)),
    "police": dict(label="Police station", w=620, storeys=2, mat="brick", col=mix(BRICK, gw.ASH, 0.4), sign="POLICE", door="double", windows=3, extras=("police",)),
    "market": dict(label="Market (grocery)", w=640, storeys=1, mat="brick", col=mix(gw.PAINT_G, BRICK, 0.4), sign="MARKET", awning=(hexc("#7E3A2C"), hexc("#C9C1AE"))),
    "outfitters": dict(label="Outfitters (clothing)", w=560, storeys=1, mat="clap", col=mix(gw.TIMBER_L, gw.PAINT_B, 0.4), roof="gable", sign="OUTFITTERS", awning=(hexc("#5B3F5A"), hexc("#C9C1AE"))),
    "apartments": dict(label="Apartment block", w=680, storeys=3, mat="concrete", col=mix(CONCRETE, gw.PAINT_B, 0.3), windows=4, boarded=0.4),
    "church": dict(label="Church", w=500, storeys=1, mat="clap", col=gw.SNOW_SH, roof="gable", door="double", windows=2, extras=("steeple",)),
    "town_house_a": dict(label="Stillwater house", w=440, storeys=2, mat="clap", col=mix(gw.PAINT_G, gw.TIMBER_L, 0.3), roof="gable", windows=2, chimney=True),
    "quiet_house": dict(label="An ordinary house (quiet)", w=460, storeys=2, mat="clap", col=mix(gw.PAINT_B, gw.TIMBER_L, 0.45), roof="gable", windows=2, boarded=0.7),
}


def generate():
    for name, spec in BUILDINGS.items():
        spec = dict(spec)
        label = spec.pop("label")
        facade(name, label, **spec)
    lighthouse()
    crane()
    trawler()
    container(hexc("#7A3A2C"), "container_red")
    container(hexc("#3E5A66"), "container_blue")
    small("bollard", "Mooring bollard", 80, 120, 112, d_bollard)
    small("fish_crates", "Stacked fish crates", 200, 180, 170, d_fishcrates)
    small("headframe", "Mine headframe (winding tower)", 400, 640, 620, d_headframe)
    small("adit", "Mine entrance (adit No. 3) in the hillside", 580, 400, 380, d_adit)
    small("hopper", "Ore hopper", 320, 280, 268, d_hopper)
    small("slag", "Slag heap", 420, 260, 250, d_slag)
    small("water_tower", "Water tower", 320, 700, 680, d_watertower)
    small("fuel_tanks", "Fuel depot tanks", 440, 340, 324, d_tanks)
    small("substation", "Electrical substation", 360, 240, 230, d_substation)
    small("memorial", "War memorial", 240, 260, 250, d_memorial)
    for v in range(3):
        small(f"iceberg_{'abc'[v]}", f"Iceberg ({'abc'[v]}), drifts in the channel", 360 + v * 60, 240 + v * 40, 220 + v * 40, d_iceberg(v))
    small("floe", "Ice floe", 260, 80, 74, d_floe)
    tile("water", "Open harbor water, black and cold (tile)", "water")
    tile("sea_ice", "Sea ice (tile)", "seaice")
    tile("pier", "Pier planks (tile)", "pier")
    tile("rail", "Rail track in frozen ballast (tile)", "rail")


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_settlements.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "settlements", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("settlement art generated:", len(ENTRIES))


if __name__ == "__main__":
    generate()
    write_manifest()
