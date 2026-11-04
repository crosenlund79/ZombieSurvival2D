#!/usr/bin/env python3
"""Red Thaw — nuclear-winter environment art ("dirty ink" style, cold palette).

Hand-composed winter templates: snow / frozen-mud / snowy-road ground tiles, pines,
a bare birch, frozen shrubs, dead grass, a snowy stump, the hunter's cabin, the
burned shed (opening landmark), a woodshed, a truck wreck, settlement houses (two
houses + a collapsed one), forgotten belongings, the starter bag, a thawing-blood
decal, snowflake and fog effects and the field-map paper.

Writes templates under assets/templates/ and the manifest
assets/manifest/visual_winter.json. Run from the repository root (or through
tools/art/regenerate_all.py). Never touches assets/overrides/.
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, value_noise, INK, SS
from gen_homestead import out, wrap_draw, ROOT

# Red Thaw palette: icy blue-grey, dirty white, charcoal, muted pine, faded timber, dark rust.
SNOW, SNOW_L, SNOW_SH, SNOW_D = map(hexc, ["#D6D9D7", "#E6E8E4", "#A7B1B6", "#7D898F"])
ICE = hexc("#AEBEC5")
CHAR, CHAR_L, ASH, ASH_L = map(hexc, ["#1E1C1B", "#34302D", "#6B6865", "#8E8B86"])
PINE_D, PINE, PINE_M, PINE_L = map(hexc, ["#18231F", "#26352E", "#36483E", "#52635A"])
TIMBER_D, TIMBER, TIMBER_M, TIMBER_L = map(hexc, ["#3E3329", "#5C4C3E", "#76644F", "#94826B"])
RUST_D, RUST = hexc("#4E2A22"), hexc("#73392A")
BLOOD, BLOOD_D = hexc("#8A1C18"), hexc("#4E1412")
MUD_D, MUD, MUD_L = map(hexc, ["#5A4F44", "#776B5D", "#968A7A"])
STRAW_D, STRAW = hexc("#7A7060"), hexc("#A39A85")
STEEL_D, STEEL = hexc("#3A3E40"), hexc("#5E6467")
PAINT_G, PAINT_B = hexc("#7D8579"), hexc("#7E8A90")
GLASS_F = hexc("#9AA9B0")   # frosted glass
GLASS_D = hexc("#1D2224")

ENTRIES = []


def entry(aid, name, rel, display, source, pivot):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": list(display),
                    "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_winter.py) - replace with tablet art."})


def pf(c, pts, col, tex=0.25, cell=8, light=(-1, -1, 0.3), ink=2.0, shade=None, alpha=230):
    m = c.fill(pts, col, tex=tex, cell=cell, light=light)
    if shade:
        c.shade(m, *shade)
    if ink:
        c.ink_poly(pts, width=ink, alpha=alpha)
    return m


def snow_band(c, pts, thick, shadow=True, ink=True):
    """A lumpy band of settled snow lying on top of a polyline (left -> right)."""
    top, bot = [], []
    for i, (x, y) in enumerate(pts):
        t = thick * c.rng.uniform(0.7, 1.25)
        top.append((x, y - t * 0.45 - c.rng.uniform(0, 2)))
        bot.append((x, y + t * 0.55))
    poly = top + bot[::-1]
    m = c.fill(poly, SNOW, tex=0.12, cell=6, light=(-1, -1, 0.25))
    if shadow:
        sh = [(x, y + thick * 0.15) for x, y in pts] + bot[::-1]
        c.fill(sh, mix(SNOW, SNOW_SH, 0.6), tex=0.1, cell=6)
    if ink:
        c.ink(bot, width=1.4, alpha=170, seg=4)
        c.ink(top, width=0.9, alpha=90, seg=4)
    return m


def drift(c, cx, by, rx, ry, ink=True):
    """Snow drift mound with a blue-grey shadow side."""
    b = c.blob(cx, by - ry * 0.45, rx, ry, n=18, irregular=0.14)
    b = [(x, min(y, by + 2)) for x, y in b]
    m = c.fill(b, SNOW, tex=0.1, cell=8, light=(-1, -1, 0.3))
    c.fill(c.blob(cx + rx * 0.25, by - ry * 0.2, rx * 0.75, ry * 0.55, n=14, irregular=0.12), mix(SNOW, SNOW_SH, 0.45), tex=0.1)
    if ink:
        n = len(b)
        c.ink(b[n // 2 + 2:] + b[:2], width=1.2, alpha=110, seg=4)
    return m


def icicles(c, x0, x1, y, n, length=(6, 18)):
    for _ in range(n):
        x = c.rng.uniform(x0, x1); L = c.rng.uniform(*length)
        p = [(x - 2.2, y), (x + 2.2, y), (x + 0.3, y + L)]
        c.fill(p, ICE, tex=0.05)
        c.ink([(x - 2.2, y), (x + 0.3, y + L), (x + 2.2, y)], width=0.9, alpha=170)


def dead_stalks(c, cx, by, w, h, n=14, cols=None):
    cols = cols or [STRAW_D, STRAW, ASH_L, TIMBER_M]
    for _ in range(n):
        x = cx + c.rng.uniform(-w / 2, w / 2)
        hh = h * c.rng.uniform(0.35, 1.0)
        lean = c.rng.uniform(-8, 8)
        col = c.rng.choice(cols)
        pts = [(x, by), (x + lean * 0.4, by - hh * 0.5), (x + lean, by - hh)]
        c.ink(pts, width=c.rng.uniform(1.1, 2.0), color=col, alpha=230, wobble=0.5)
        if c.rng.random() < 0.3:  # brittle seed head / broken tip
            c.ink([(x + lean, by - hh), (x + lean + c.rng.uniform(-5, 5), by - hh + c.rng.uniform(3, 7))], width=1.0, color=col)


# ================================================================ ground tiles
def _tile(size, cols, seed, cell):
    n = value_noise(size, size, cell, seed, octaves=5, wrap=True)
    n2 = value_noise(size, size, max(8, cell // 3), seed + 1, octaves=3, wrap=True)
    g = np.random.default_rng(seed).random((size, size)).astype(np.float32)
    t = np.clip(n * 0.85 + (n2 - 0.5) * 0.35, 0, 1)
    c0, c1, c2 = [np.array(c[:3], dtype=np.float32) for c in cols]
    rgb = np.where(t[..., None] < 0.5, c0 + (c1 - c0) * (t[..., None] / 0.5), c1 + (c2 - c1) * ((t[..., None] - 0.5) / 0.5))
    rgb *= (0.96 + 0.06 * g)[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def noise_snow(img, seed, cell, thresh, color, soft=0.08, alpha=1.0):
    """Composite natural, soft-edged snow/slush patches (thresholded wrap noise)."""
    S = img.size[0]
    n = value_noise(S, S, cell, seed, octaves=5, wrap=True)
    a = np.clip((n - thresh) / soft, 0, 1) * alpha
    edge = np.clip(1 - np.abs(n - thresh - soft * 0.5) / (soft * 0.6), 0, 1) * (a > 0)
    arr = np.zeros((S, S, 4), dtype=np.float32)
    col = np.array(color[:3], dtype=np.float32)
    shade = np.array(SNOW_SH[:3], dtype=np.float32)
    arr[..., :3] = col * (1 - edge[..., None] * 0.35) + shade * edge[..., None] * 0.35
    arr[..., 3] = a * 255
    return Image.alpha_composite(img, Image.fromarray(arr.astype(np.uint8), "RGBA"))


def snow_tile():
    S = 512
    rng = random.Random(9101)
    img = _tile(S, [mix(SNOW_SH, SNOW_D, 0.25), mix(SNOW, SNOW_SH, 0.45), SNOW], 9102, 170)
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ridges = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(40, 120), rng.uniform(-0.25, 0.25)) for _ in range(12)]
    def fr(d, ox, oy):  # wind-carved drift ridges: light crest + blue shadow below
        for x, y, L, a in ridges:
            pts = [(x + ox + t * L * math.cos(a), y + oy + t * L * math.sin(a) + 3 * math.sin(t * 6)) for t in np.linspace(0, 1, 9)]
            d.line(pts, fill=SNOW_L[:3] + (60,), width=4)
            d.line([(px, py + 3) for px, py in pts], fill=SNOW_SH[:3] + (55,), width=3)
    wrap_draw(ov, fr)
    pocks = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(2, 4.5)) for _ in range(70)]
    def fp(d, ox, oy):  # pocks and old prints half filled in
        for x, y, r in pocks:
            d.ellipse((x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy), fill=SNOW_SH[:3] + (110,))
            d.arc((x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy), 180, 360, fill=SNOW_D[:3] + (120,), width=1)
    wrap_draw(ov, fp)
    stalks = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(5, 14), rng.randint(2, 5)) for _ in range(150)]
    def fs(d, ox, oy):  # dead grass poking through
        for x, y, h, n in stalks:
            for k in range(n):
                lean = rng.uniform(-5, 5)
                col = rng.choice([STRAW_D, STRAW, ASH, TIMBER_M])
                d.line([(x + ox + k * 1.5, y + oy), (x + ox + k * 1.5 + lean, y + oy - h * rng.uniform(0.5, 1))], fill=col[:3] + (210,), width=1)
            d.ellipse((x + ox - 3, y + oy - 1, x + ox + 6, y + oy + 2), fill=SNOW_SH[:3] + (100,))
    wrap_draw(ov, fs)
    twigs = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(8, 20), rng.uniform(0, 6.28)) for _ in range(22)]
    def ft(d, ox, oy):
        for x, y, L, a in twigs:
            x2, y2 = x + math.cos(a) * L, y + math.sin(a) * L * 0.5
            d.line([(x + ox, y + oy), (x2 + ox, y2 + oy)], fill=TIMBER_D[:3] + (210,), width=2)
            d.line([((x + x2) / 2 + ox, (y + y2) / 2 + oy), ((x + x2) / 2 + ox + 5, (y + y2) / 2 + oy - 4)], fill=TIMBER_D[:3] + (190,), width=1)
    wrap_draw(ov, ft)
    needles = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(40)]
    def fn(d, ox, oy):
        for x, y in needles:
            for _ in range(5):
                a = rng.uniform(0, 6.28)
                d.line([(x + ox, y + oy), (x + ox + math.cos(a) * 4, y + oy + math.sin(a) * 2)], fill=PINE_M[:3] + (160,), width=1)
    wrap_draw(ov, fn)
    rocks = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(4, 9)) for _ in range(9)]
    def fk(d, ox, oy):
        for x, y, r in rocks:
            d.ellipse((x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy), fill=CHAR_L[:3] + (235,), outline=INK[:3] + (200,))
            d.chord((x - r * 0.9 + ox, y - r * 0.7 + oy, x + r * 0.9 + ox, y + oy), 180, 360, fill=SNOW[:3] + (200,))
    wrap_draw(ov, fk)
    ash = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(260)]
    def fa(d, ox, oy):  # fine ash fallen on the snow
        for x, y in ash:
            d.point((x + ox, y + oy), fill=ASH[:3] + (150,))
    wrap_draw(ov, fa)
    ov = ov.filter(ImageFilter.GaussianBlur(0.5))
    Image.alpha_composite(img, ov).save(out("env/ground/template_snow_tile.png"), optimize=True)
    entry("env.ground_snow", "Ground — snow over forest floor (tile)", "env/ground/template_snow_tile.png", (512, 512), (512, 512), (0, 0))


def frozen_mud_tile():
    S = 512
    rng = random.Random(9201)
    img = _tile(S, [MUD_D, MUD, MUD_L], 9202, 140)
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    puddles = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(8, 22), rng.uniform(4, 9)) for _ in range(6)]
    def fp(d, ox, oy):  # frozen puddles: pale ice, white rim, cracks
        for x, y, rx, ry in puddles:
            d.ellipse((x - rx + ox, y - ry + oy, x + rx + ox, y + ry + oy), fill=mix(ICE, SNOW_SH, 0.4)[:3] + (230,), outline=SNOW_L[:3] + (220,), width=2)
            for _ in range(3):
                a = rng.uniform(0, 6.28)
                d.line([(x + ox, y + oy), (x + ox + math.cos(a) * rx * 0.8, y + oy + math.sin(a) * ry * 0.8)], fill=SNOW_D[:3] + (170,), width=1)
    wrap_draw(ov, fp)
    img = noise_snow(img, 9203, 70, 0.55, mix(SNOW, MUD_L, 0.2), soft=0.08, alpha=0.9)
    ruts = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(60, 140)) for _ in range(5)]
    def fr(d, ox, oy):  # frozen wheel ruts
        for x, y, L in ruts:
            for off in (0, 26):
                pts = [(x + ox + t * L, y + oy + off + 4 * math.sin(t * 5)) for t in np.linspace(0, 1, 8)]
                d.line(pts, fill=MUD_D[:3] + (190,), width=5)
                d.line([(px, py - 3) for px, py in pts], fill=MUD_L[:3] + (120,), width=1)
    wrap_draw(ov, fr)
    frost = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(900)]
    def ff(d, ox, oy):
        for x, y in frost:
            d.point((x + ox, y + oy), fill=SNOW_L[:3] + (170,))
    wrap_draw(ov, ff)
    stones = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(3, 7)) for _ in range(30)]
    def fk(d, ox, oy):
        for x, y, r in stones:
            d.ellipse((x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy), fill=ASH[:3] + (230,), outline=INK[:3] + (180,))
    wrap_draw(ov, fk)
    ov = ov.filter(ImageFilter.GaussianBlur(0.8))
    Image.alpha_composite(img, ov).save(out("env/ground/template_frozen_mud_tile.png"), optimize=True)
    entry("env.ground_frozen_mud", "Ground — frozen mud and slush (tile)", "env/ground/template_frozen_mud_tile.png", (384, 384), (512, 512), (0, 0))


def road_snow_tile():
    S = 512
    rng = random.Random(9301)
    img = _tile(S, [hexc("#2C2F31"), hexc("#3B3F41"), hexc("#4F5355")], 9302, 90)
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    img = noise_snow(img, 9303, 130, 0.62, mix(SNOW, SNOW_SH, 0.35), soft=0.1, alpha=0.8)
    cracks = []
    for _ in range(16):
        x, y = rng.uniform(0, S), rng.uniform(0, S); pts = [(x, y)]
        for _ in range(5):
            x += rng.uniform(-16, 16); y += rng.uniform(-10, 10); pts.append((x, y))
        cracks.append(pts)
    def fc(d, ox, oy):
        for pts in cracks:
            d.line([(x + ox, y + oy) for x, y in pts], fill=INK[:3] + (200,), width=2)
            d.line([(x + ox + 1, y + oy - 1) for x, y in pts], fill=SNOW[:3] + (140,), width=1)
    wrap_draw(ov, fc)
    grit = [(rng.uniform(0, S), rng.uniform(0, S)) for _ in range(1600)]
    def fg(d, ox, oy):
        for x, y in grit:
            d.point((x + ox, y + oy), fill=SNOW_L[:3] + (130,))
    wrap_draw(ov, fg)
    ov = ov.filter(ImageFilter.GaussianBlur(0.8))
    Image.alpha_composite(img, ov).save(out("env/ground/template_road_snow_tile.png"), optimize=True)
    entry("env.ground_road_snow", "Ground — snowy cracked road (tile)", "env/ground/template_road_snow_tile.png", (512, 512), (512, 512), (0, 0))


# ================================================================ vegetation
def pine(variant):
    W, H = 520, 840
    c = Canvas(W, H, seed=9401 + variant)
    base = 816
    cx = 260 + (8 if variant else -6)
    c.soft_shadow((90, base - 30, 450, base + 22), alpha=120, blur=14)
    tr = [(cx - 16, base), (cx - 10, 140), (cx + 10, 140), (cx + 18, base)]
    pf(c, tr, TIMBER_D, tex=0.4, cell=5, light=(-1, 0, 0.4), ink=2.4, shade=(1, 0, 4, 100))
    for _ in range(8):
        y = c.rng.uniform(300, base - 20)
        c.ink([(cx - 8, y), (cx - 6, y + c.rng.uniform(12, 30))], width=1.0, alpha=140)
    tiers = 9 if variant == 0 else 11
    top, bottom = 60, 700 if variant == 0 else 730
    maxw = 210 if variant == 0 else 236
    for i in reversed(range(tiers)):
        t = i / (tiers - 1)
        ty = top + (bottom - top) * t ** 0.92 + c.rng.uniform(-10, 10)
        w = (26 + (maxw - 26) * t ** 0.85) * c.rng.uniform(0.72, 1.08)
        off = c.rng.uniform(-18, 18) * t
        h = 60 + 70 * t
        droop = 14 + 36 * t
        lw, rw = w * c.rng.uniform(0.75, 1.1), w * c.rng.uniform(0.75, 1.1)   # lopsided boughs
        bx = cx + off
        apex = (bx + c.rng.uniform(-5, 5), ty - h * 0.35)
        lower = []
        nzig = int(6 + 9 * t)
        for k in range(nzig + 1):
            u = k / nzig
            x = bx - lw + (lw + rw) * u
            edge = abs(u - lw / (lw + rw)) / max(lw, rw) * (lw + rw) / 2 * 2 / ((lw + rw) / 2)
            edge = min(1.0, edge)
            y = ty + h * 0.55 + droop * edge ** 1.5 - (h * c.rng.uniform(0.08, 0.3) if k % 2 else 0) * (0.5 + 0.5 * edge)
            lower.append((x + c.rng.uniform(-4, 4), y + c.rng.uniform(-4, 4)))
        poly = [apex] + [(lower[-1][0] + 5, lower[-1][1] - 14)] + lower[::-1] + [(lower[0][0] - 5, lower[0][1] - 14)]
        m = c.fill(poly, mix(PINE_D, PINE, c.rng.uniform(0, 0.35)), tex=0.35, cell=6, light=(-1, -1, 0.35))
        for _ in range(int(30 + 80 * t)):
            u = c.rng.uniform(-1, 1)
            x = bx + u * (lw if u < 0 else rw) * 0.85
            y = ty + c.rng.uniform(-h * 0.2, h * 0.45) + abs(u) * droop * 0.6
            col = PINE_L if (u < -0.2 and c.rng.random() < 0.55) else (PINE_M if c.rng.random() < 0.6 else PINE)
            a = math.radians(90 + u * 55 + c.rng.uniform(-15, 15))
            L = c.rng.uniform(6, 14)
            c.ink([(x, y), (x + math.cos(a) * L * (1 if u > 0 else -1) * 0.6, y + math.sin(a) * L * 0.6)], width=1.6, color=col, alpha=220, wobble=0.3)
        c.shade(m, 1, 0.8, 4.0, 85, reach=0.5)
        c.ink(lower, width=1.8, alpha=210, seg=3)
        # clumps of snow resting on the bough, heavier toward the trunk
        for _ in range(int(3 + 6 * t)):
            u = c.rng.uniform(-0.85, 0.85)
            x = bx + u * (lw if u < 0 else rw)
            edge = abs(u)
            y = apex[1] + (ty + h * 0.3 - apex[1]) * edge ** 0.7 + droop * edge ** 1.5 * 0.55
            r = (8 + 10 * t) * (1.1 - edge * 0.5) * c.rng.uniform(0.7, 1.2)
            b = c.blob(x, y, r * 1.6, r * 0.55, n=12, irregular=0.25)
            c.fill(b, SNOW, tex=0.1, light=(-1, -1, 0.3))
            c.fill(c.blob(x + r * 0.3, y + r * 0.2, r * 1.1, r * 0.3, n=10, irregular=0.2), mix(SNOW, SNOW_SH, 0.55), tex=0.1)
            nb = len(b)
            c.ink(b[nb // 2 - 1:] + b[:1], width=1.1, alpha=150, seg=3)
    c.ink([(cx, 40), (cx + 1, 66)], width=3, color=PINE_D)
    drift(c, cx, base + 2, 120, 22)
    dead_stalks(c, cx - 110, base + 2, 60, 26, n=8)
    name = "a" if variant == 0 else "b"
    c.save(out(f"env/trees/template_pine_{name}.png"), winter=False)
    entry(f"env.pine_{name}", f"Snow-laden pine ({name})", f"env/trees/template_pine_{name}.png", (260, 420), (W, H), (0.5, base / H))


def _branch(c, x, y, ang, L, w, depth, col):
    x2, y2 = x + math.cos(ang) * L, y + math.sin(ang) * L
    mid = ((x + x2) / 2 + c.rng.uniform(-L * 0.08, L * 0.08), (y + y2) / 2 + c.rng.uniform(-L * 0.06, L * 0.06))
    c.ink([(x, y), mid, (x2, y2)], width=w, color=col, wobble=0.4, alpha=240)
    if w > 2.2:  # a thin line of snow along the upper side
        c.ink([(x, y - w * 0.45), (mid[0], mid[1] - w * 0.45), (x2, y2 - w * 0.4)], width=max(1.0, w * 0.35), color=SNOW_L, alpha=220, wobble=0.3)
    if depth <= 0:
        return
    for k in range(c.rng.randint(2, 3)):
        a2 = ang + c.rng.uniform(-0.65, 0.65)
        _branch(c, x2, y2, a2, L * c.rng.uniform(0.55, 0.75), max(0.9, w * 0.62), depth - 1, col)


def birch_bare():
    W, H = 340, 620
    c = Canvas(W, H, seed=9501)
    base = 596
    c.soft_shadow((90, base - 18, 260, base + 14), alpha=110, blur=10)
    tr = [(160, base), (163, 300), (168, 150), (176, 150), (180, 300), (186, base)]
    m = pf(c, tr, hexc("#C9C7BE"), tex=0.25, cell=6, light=(-1, 0, 0.35), ink=2.2, shade=(1, 0, 3.5, 80))
    for _ in range(26):  # black birch marks
        y = c.rng.uniform(160, base - 10); x = c.rng.uniform(162, 182)
        c.ink([(x - 5, y), (x + 5, y + c.rng.uniform(-1, 1))], width=c.rng.uniform(1.2, 2.6), color=CHAR, alpha=230)
    c.fill([(158, base - 50), (188, base - 50), (188, base), (158, base)], CHAR_L, tex=0.4)  # dark base bark
    for ang, y, L in ((-2.2, 320, 90), (-0.9, 290, 95), (-2.6, 400, 70), (-0.5, 380, 80), (-1.6, 170, 70), (-2.0, 230, 80), (-1.1, 220, 85)):
        _branch(c, 172, y, ang, L, 5.5, 3, hexc("#3A3633"))
    drift(c, 172, base + 2, 70, 16)
    dead_stalks(c, 120, base + 2, 40, 22, n=6)
    c.save(out("env/trees/template_birch_bare.png"), winter=False)
    entry("env.birch_bare", "Bare winter birch", "env/trees/template_birch_bare.png", (170, 310), (W, H), (0.5, base / H))


def shrub_frozen(variant):
    W, H = (220, 160) if variant == 0 else (180, 140)
    c = Canvas(W, H, seed=9601 + variant)
    base = H - 14
    cx = W / 2
    c.soft_shadow((cx - W * 0.4, base - 8, cx + W * 0.4, base + 8), alpha=100, blur=6)
    col = hexc("#3B332D")
    for _ in range(16 if variant == 0 else 12):
        _branch(c, cx + c.rng.uniform(-12, 12), base - 4, math.radians(-90 + c.rng.uniform(-62, 62)),
                c.rng.uniform(30, 60) * (H / 160), 3.0, 2, col)
    for _ in range(10):  # a few hanging dead leaves
        x = cx + c.rng.uniform(-W * 0.35, W * 0.35); y = base - c.rng.uniform(20, H * 0.6)
        c.leaf(x, y, c.rng.uniform(5, 8), c.rng.uniform(40, 140), c.rng.choice([STRAW_D, TIMBER_M, TIMBER_L]), ink_alpha=150)
    drift(c, cx, base + 2, W * 0.42, 18)
    name = "a" if variant == 0 else "b"
    c.save(out(f"env/plants/template_shrub_frozen_{name}.png"), winter=False)
    entry(f"env.shrub_frozen_{name}", f"Frozen bare shrub ({name})", f"env/plants/template_shrub_frozen_{name}.png",
          (W // 2, H // 2), (W, H), (0.5, base / H))


def dead_grass(variant):
    W, H = 160, 100
    c = Canvas(W, H, seed=9701 + variant)
    base = 94
    c.fill(c.blob(80, base - 2, 56, 7, n=14, irregular=0.2), mix(SNOW, SNOW_SH, 0.5), tex=0.1)
    dead_stalks(c, 80, base - 2, 110, 70 if variant != 1 else 52, n=26 if variant == 0 else 18)
    if variant == 2:  # dry seed heads / reed tops
        for _ in range(6):
            x = c.rng.uniform(30, 130); y = base - c.rng.uniform(40, 70)
            c.fill(c.blob(x, y, 2.4, 6, n=8, irregular=0.1), TIMBER_M, tex=0.2)
    name = "abc"[variant]
    c.save(out(f"env/plants/template_dead_grass_{name}.png"), finish=False, winter=False)
    entry(f"env.dead_grass_{name}", f"Dead brittle grass ({name})", f"env/plants/template_dead_grass_{name}.png", (80, 50), (W, H), (0.5, 0.94))


def stump_snow():
    W, H = 180, 120
    c = Canvas(W, H, seed=9801)
    base = 104
    c.soft_shadow((24, base - 10, 156, base + 8), alpha=110, blur=6)
    body = [(40, 50), (140, 50), (146, base - 4), (34, base - 4)]
    pf(c, body, TIMBER_D, tex=0.4, cell=5, light=(-1, 0, 0.4), ink=2.2, shade=(1, 0, 3.5, 90))
    for x in (60, 84, 108, 128):
        c.ink([(x, 58), (x + c.rng.uniform(-3, 3), base - 8)], width=1.0, alpha=150)
    top = c.blob(90, 50, 52, 14, n=18, irregular=0.05)
    pf(c, top, TIMBER_M, tex=0.2, ink=1.8)
    for r in (8, 18, 30, 42):
        c.ink_poly(c.blob(90, 50, r, r * 0.27, n=16, irregular=0.04), width=0.8, alpha=110)
    cap = c.blob(84, 46, 44, 11, n=16, irregular=0.18)
    c.fill(cap, SNOW, tex=0.1); c.ink(cap[8:16], width=1.0, alpha=120)
    drift(c, 90, base + 2, 70, 14)
    c.save(out("env/trees/template_stump_snow.png"), winter=False)
    entry("env.stump_snow", "Snowy tree stump", "env/trees/template_stump_snow.png", (90, 60), (W, H), (0.5, base / H))


# ================================================================ buildings
def logs_wall(c, x0, x1, y0, y1, h=26, ends=True):
    """Horizontal log wall with dark chinking and round log ends at the corners."""
    y = y1
    rows = []
    while y > y0:
        ty = max(y0, y - h)
        col = mix(TIMBER, TIMBER_M if c.rng.random() < 0.5 else TIMBER_D, c.rng.uniform(0.1, 0.45))
        poly = [(x0, ty + 1), (x1, ty + c.rng.uniform(-1, 1)), (x1, y), (x0, y)]
        m = c.fill(poly, col, tex=0.3, cell=6, light=(-1, -1, 0.3))
        c.ink([(x0, y), (x1, y)], width=2.0, alpha=220, seg=10)
        c.ink([(x0, ty + h * 0.32), (x1, ty + h * 0.32)], width=0.8, color=TIMBER_L, alpha=110, seg=10)
        for _ in range(int((x1 - x0) / 90)):  # checks / splits
            x = c.rng.uniform(x0 + 10, x1 - 30)
            c.ink([(x, ty + h * 0.5), (x + c.rng.uniform(14, 40), ty + h * 0.5 + c.rng.uniform(-2, 2))], width=0.8, alpha=130)
        rows.append((ty, y))
        y = ty
    if ends:
        for xe in (x0 - 8, x1 + 8):
            for (ty, by) in rows:
                r = (by - ty) * 0.56
                e = c.blob(xe, (ty + by) / 2, r, r * 0.96, n=12, irregular=0.06)
                pf(c, e, TIMBER_L, tex=0.25, ink=1.4)
                c.ink_poly(c.blob(xe, (ty + by) / 2, r * 0.45, r * 0.42, n=10, irregular=0.08), width=0.7, alpha=120)
    return c.mask([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def frosted_window(c, x, y, w, h, boarded=False, dark=False):
    frame = [(x - 6, y - 6), (x + w + 6, y - 6), (x + w + 6, y + h + 8), (x - 6, y + h + 8)]
    pf(c, frame, TIMBER_D, tex=0.3, ink=2.0)
    pane = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    if dark:
        c.fill(pane, GLASS_D, tex=0.15)
    else:
        m = c.fill(pane, GLASS_D, tex=0.15)
        # frost creeping in from the corners and the bottom
        yy, xx = np.mgrid[0:c.h * SS, 0:c.w * SS].astype(np.float32)
        fr = c.mask(pane)
        g = value_noise(c.w * SS, c.h * SS, 5 * SS, c.seed + int(x), octaves=3)
        dx = np.minimum(np.abs(xx / SS - x), np.abs(xx / SS - (x + w))) / max(1, w)
        dy = np.abs(yy / SS - (y + h)) / max(1, h)
        f = np.clip(1.25 - (np.minimum(dx * 2.4, dy * 1.4) + g * 0.6), 0, 1)
        arr = np.zeros((c.h * SS, c.w * SS, 4), dtype=np.uint8)
        arr[..., :3] = np.array(GLASS_F[:3], dtype=np.uint8)
        arr[..., 3] = (np.asarray(fr, dtype=np.float32) * f * 0.92).astype(np.uint8)
        c.img = Image.alpha_composite(c.img, Image.fromarray(arr, "RGBA"))
    c.ink([(x + w / 2, y), (x + w / 2, y + h)], width=2.2, color=TIMBER_D)
    c.ink([(x, y + h / 2), (x + w, y + h / 2)], width=2.2, color=TIMBER_D)
    c.ink_poly(pane, width=1.6)
    snow_band(c, [(x - 8, y + h + 6), (x + w / 2, y + h + 5), (x + w + 8, y + h + 6)], 7)
    if boarded:
        for k, (a, b) in enumerate(((y + 8, y + h - 14), (y + h * 0.55, y + 12))):
            p = [(x - 10, a), (x + w + 10, b), (x + w + 10, b + 12), (x - 10, a + 12)]
            pf(c, p, TIMBER_M, tex=0.35, ink=1.6)
            c.ellipse_fill((x - 4, a + 3, x + 2, a + 9), CHAR)


def hunter_cabin():
    """Remote hunter's cabin — same canvas, base line and door opening as the old
    farmhouse template so the door, entry portal and collision stay aligned."""
    W, H = 880, 820
    c = Canvas(W, H, seed=9901)
    base = 790
    c.soft_shadow((60, base - 40, 860, base + 26), alpha=140, blur=14)
    fx0, fx1, ftop = 120, 760, 470
    # stone footing
    found = [(fx0 - 14, base - 30), (fx1 + 14, base - 30), (fx1 + 14, base), (fx0 - 14, base)]
    pf(c, found, ASH, tex=0.35, cell=6, ink=2.2)
    logs_wall(c, fx0, fx1, ftop, base - 30, h=26)
    c.shade(c.mask([(fx1 - 140, ftop), (fx1, ftop), (fx1, base), (fx1 - 100, base)]), 1, 0, 5, 70, cross=True, reach=1.0)
    c.shade(c.mask([(fx0, ftop), (fx1, ftop), (fx1, ftop + 70), (fx0, ftop + 70)]), 0, -1, 5, 90, reach=1.0)
    # roof: heavy snow over dark shakes; only the eave edge shows the wood
    rx0, rx1, rtop = 70, 810, 110
    roof = [(rx0 + 90, rtop), (rx1 - 90, rtop), (rx1, ftop + 20), (rx0, ftop + 20)]
    pf(c, roof, mix(TIMBER_D, CHAR, 0.4), tex=0.3, cell=10, ink=3.4)
    eave = [(rx0, ftop - 6), (rx1, ftop - 6), (rx1, ftop + 20), (rx0, ftop + 20)]
    pf(c, eave, mix(TIMBER_D, CHAR, 0.2), tex=0.35, ink=2.2)
    for x in range(rx0 + 10, rx1, 22):
        c.ink([(x, ftop - 4), (x + 2, ftop + 18)], width=1.0, alpha=150)
    snowroof = [(rx0 + 96, rtop - 10)] + [(rx0 + 96 + (rx1 - rx0 - 192) * k / 10, rtop - 12 - c.rng.uniform(0, 6)) for k in range(1, 10)] + \
               [(rx1 - 96, rtop - 10), (rx1 - 4, ftop - 4)] + \
               [(rx1 - (rx1 - rx0) * k / 14, ftop + c.rng.uniform(-2, 10)) for k in range(1, 14)] + [(rx0 + 4, ftop - 4)]
    m = c.fill(snowroof, SNOW, tex=0.12, cell=14, light=(-0.6, -1, 0.35))
    c.shade(m, 0.6, 1, 6, 55, reach=0.45)
    for _ in range(5):  # wind-scoured patches where the shakes show through
        x = c.rng.uniform(rx0 + 180, rx1 - 180); y = c.rng.uniform(rtop + 60, ftop - 60)
        b = c.blob(x, y, c.rng.uniform(16, 36), c.rng.uniform(6, 12), n=12, irregular=0.4)
        c.fill(b, mix(TIMBER_D, SNOW_SH, 0.35), tex=0.3)
        for k in range(3):
            c.ink([(x - 20, y - 4 + k * 4), (x + 20, y - 4 + k * 4)], width=0.8, alpha=110)
    c.ink(snowroof[11:], width=2.2, alpha=200, seg=4)
    c.ink(snowroof[:11], width=2.8, alpha=230, seg=4)
    icicles(c, rx0 + 30, rx1 - 30, ftop + 20, 34, (6, 22))
    # stovepipe chimney
    pipe = [(616, 30), (646, 30), (646, 200), (616, 204)]
    pf(c, pipe, mix(STEEL_D, RUST_D, 0.4), tex=0.35, ink=2.4, shade=(1, 0, 3.5, 90))
    for y in (70, 120, 170):
        c.ink([(614, y), (648, y)], width=1.6, alpha=200)
    pf(c, [(606, 18), (656, 18), (652, 32), (610, 32)], STEEL_D, ink=2.0)
    c.fill(c.blob(631, 14, 26, 8, n=12, irregular=0.2), SNOW, tex=0.1)
    # windows
    frosted_window(c, 196, 572, 92, 80)
    frosted_window(c, 600, 572, 92, 80, boarded=True)
    # porch: plank overhang on two peeled posts, centred on the door
    pr = [(356, 532), (566, 532), (582, 578), (340, 578)]
    pf(c, pr, mix(TIMBER_D, CHAR, 0.25), tex=0.35, ink=2.6, shade=(0, 1, 4, 80))
    snow_band(c, [(344, 532), (400, 527), (460, 525), (520, 528), (578, 532)], 16)
    icicles(c, 344, 578, 578, 10, (5, 14))
    for px in (372, 548):
        post = [(px - 8, 578), (px + 8, 578), (px + 9, base - 30), (px - 9, base - 30)]
        pf(c, post, TIMBER_M, tex=0.35, ink=2.0, shade=(1, 0, 3.5, 70))
    # antlers above the porch roof (someone hunted here once)
    ax, ay = 460, 506
    c.fill(c.blob(ax, ay, 10, 7, n=10, irregular=0.1), hexc("#CFC6B4"))
    for s in (-1, 1):
        pts = [(ax + s * 6, ay - 2), (ax + s * 26, ay - 14), (ax + s * 44, ay - 12), (ax + s * 58, ay - 26)]
        c.ink(pts, width=4, color=hexc("#CFC6B4")); c.ink(pts, width=1.0, alpha=200)
        for (bx, by) in pts[1:3]:
            c.ink([(bx, by), (bx + s * 4, by - 14)], width=3, color=hexc("#CFC6B4"))
    # door opening (the door itself is a separate sprite; geometry unchanged)
    dfr = [(420, 590), (500, 590), (500, base - 34), (420, base - 34)]
    c.fill(dfr, hexc("#141210"), tex=0.2)
    c.ink_poly(dfr, width=2.4)
    for x in (414, 506):
        pf(c, [(x - 6, 584), (x + 6, 584), (x + 6, base - 32), (x - 6, base - 32)], TIMBER_L, tex=0.3, ink=1.6)
    pf(c, [(406, 578), (514, 578), (514, 590), (406, 590)], TIMBER_L, tex=0.3, ink=1.6)
    # step
    st = [(398, base - 34), (522, base - 34), (534, base + 4), (386, base + 4)]
    pf(c, st, mix(TIMBER_D, ASH, 0.4), tex=0.4, ink=2.2)
    # firewood stacked along the right wall, snowed over
    for row in range(4):
        for k in range(6):
            lx = 640 + k * 19 + (row % 2) * 9; ly = base - 44 - row * 18
            e = c.blob(lx, ly, 9.5, 8.5, n=10, irregular=0.08)
            pf(c, e, TIMBER_L if (k + row) % 3 else TIMBER_M, tex=0.3, ink=1.3)
            c.ink_poly(c.blob(lx, ly, 3.5, 3, n=8, irregular=0.1), width=0.6, alpha=110)
    snow_band(c, [(628, base - 104), (690, base - 110), (758, base - 104)], 12)
    # snowshoes leaning by the door
    for sx in (318, 340):
        b = c.blob(sx, base - 70, 10, 34, n=14, irregular=0.04)
        c.ink_poly(b, width=3.0, color=TIMBER_M)
        c.ink_poly(b, width=1.0)
        for k in range(4):
            c.ink([(sx - 8, base - 92 + k * 12), (sx + 8, base - 86 + k * 12)], width=0.7, alpha=150)
    # drifts against the footing
    for dx, dw, dh in ((150, 120, 26), (300, 90, 20), (690, 140, 28), (780, 70, 22), (90, 60, 18)):
        drift(c, dx, base + 4, dw, dh)
    for x0 in range(40, 860, 70):
        dead_stalks(c, x0 + c.rng.uniform(-10, 10), base + 6, 60, c.rng.uniform(16, 30), n=8)
    c.save(out("world/buildings/template_hunter_cabin.png"), winter=False)
    entry("world.hunter_cabin", "Hunter's cabin (exterior)", "world/buildings/template_hunter_cabin.png", (440, 410), (W, H), (0.5, base / H))


def burned_shed():
    W, H = 460, 380
    c = Canvas(W, H, seed=10001)
    base = 350
    c.soft_shadow((30, base - 24, 430, base + 18), alpha=130, blur=10)
    # scorched ground ring with ash
    c.fill(c.blob(230, base - 16, 210, 34, n=20, irregular=0.18), mix(CHAR_L, ASH, 0.3), tex=0.4, cell=6)
    c.speckle(c.mask(c.blob(230, base - 16, 200, 30, n=20, irregular=0.18)), 220, ASH_L, size=(1, 3), alpha=(120, 220))
    # back wall: charred planks with jagged burnt tops
    for k, x in enumerate(range(70, 380, 28)):
        top = base - 40 - c.rng.uniform(60, 200) * (0.45 + 0.55 * abs(math.sin(k / 12 * math.pi)) ** 0.6)
        plank = [(x, base - 30), (x + 26, base - 30), (x + 26, top + c.rng.uniform(-8, 8)), (x + 18, top - c.rng.uniform(4, 22)),
                 (x + 9, top + c.rng.uniform(-4, 10)), (x, top - c.rng.uniform(0, 12))]
        col = mix(CHAR, TIMBER_D, c.rng.uniform(0.0, 0.35))
        m = pf(c, plank, col, tex=0.45, cell=4, ink=1.6)
        # alligatored char: crazed cracks
        for _ in range(5):
            yy = c.rng.uniform(top + 10, base - 40)
            c.ink([(x + 3, yy), (x + 23, yy + c.rng.uniform(-3, 3))], width=0.9, color=hexc("#0E0D0C"), alpha=220)
        # unburnt timber showing low on a few planks
        if c.rng.random() < 0.4:
            c.fill([(x + 2, base - 70), (x + 24, base - 70), (x + 24, base - 32), (x + 2, base - 32)], mix(TIMBER, CHAR, 0.4), tex=0.4)
    # one corner post still standing tall, blackened
    pf(c, [(76, base - 20), (96, base - 20), (94, 40), (84, 30), (74, 46)], CHAR, tex=0.4, ink=2.2)
    pf(c, [(352, base - 20), (372, base - 20), (370, 150), (360, 140), (350, 158)], CHAR_L, tex=0.4, ink=2.0)
    # fallen roof beams, diagonal, snow along their tops
    for (x0, y0, x1, y1, w) in ((40, 220, 330, base - 30, 16), (120, base - 20, 420, 190, 14), (200, base - 26, 300, 120, 12)):
        ang = math.atan2(y1 - y0, x1 - x0); nx, ny = -math.sin(ang) * w / 2, math.cos(ang) * w / 2
        beam = [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]
        pf(c, beam, mix(CHAR, TIMBER_D, 0.25), tex=0.4, cell=4, ink=2.0)
        for t in np.linspace(0.1, 0.9, 5):
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            c.ink([(px + nx * 0.6, py + ny * 0.6), (px - nx * 0.6, py - ny * 0.6)], width=0.9, color=hexc("#0E0D0C"), alpha=200)
        snow_band(c, [(x0 - nx, y0 - ny - 2), ((x0 + x1) / 2 - nx, (y0 + y1) / 2 - ny - 2), (x1 - nx, y1 - ny - 2)], 7)
    # rubble pile of charred debris and ash
    for _ in range(26):
        x = c.rng.uniform(80, 380); y = base - c.rng.uniform(12, 50)
        L = c.rng.uniform(14, 42); a = c.rng.uniform(-0.8, 0.8)
        c.ink([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L * 0.4)], width=c.rng.uniform(4, 8), color=CHAR, alpha=240)
    c.fill(c.blob(240, base - 22, 140, 20, n=18, irregular=0.3), mix(ASH, CHAR_L, 0.4), tex=0.45, cell=4)
    # a toppled, blackened stovepipe
    pf(c, [(250, base - 46), (330, base - 62), (334, base - 48), (254, base - 32)], mix(STEEL_D, CHAR, 0.4), tex=0.3, ink=1.8)
    # frost on the char and snow collecting around the remains
    c.speckle(c.img.split()[3].point(lambda v: 255 if v > 200 else 0), 160, SNOW_L, size=(0.8, 2.0), alpha=(90, 190))
    for x in (196, 252):  # what is left of the door frame
        pf(c, [(x - 7, base - 26), (x + 7, base - 26), (x + 6, 150 + (x - 196)), (x - 6, 140 + (x - 196) * 0.6)], mix(CHAR, TIMBER_D, 0.3), tex=0.4, ink=1.8)
    pf(c, [(186, 152), (264, 160), (262, 170), (188, 164)], CHAR, tex=0.4, ink=1.6)
    for dx, dw, dh in ((60, 70, 20), (170, 60, 14), (330, 90, 22), (420, 50, 16)):
        drift(c, dx, base + 4, dw, dh)
    c.save(out("world/buildings/template_burned_shed.png"), winter=False)
    entry("world.burned_shed", "Burned shed (opening landmark)", "world/buildings/template_burned_shed.png", (300, 248), (W, H), (0.5, base / H))


def woodshed():
    W, H = 400, 380
    c = Canvas(W, H, seed=10101)
    base = 356
    c.soft_shadow((24, base - 20, 380, base + 14), alpha=130, blur=10)
    back = [(50, 150), (350, 130), (350, base - 10), (50, base - 10)]
    pf(c, back, mix(TIMBER_D, CHAR, 0.35), tex=0.3, ink=2.4)
    for x in range(56, 350, 24):
        c.ink([(x, 148 - (x - 50) * 0.066), (x, base - 12)], width=1.0, alpha=130)
    # stacked firewood inside (log ends)
    for row in range(8):
        for k in range(13):
            lx = 70 + k * 21 + (row % 2) * 10; ly = base - 24 - row * 19
            if lx > 338 or ly < 180:
                continue
            e = c.blob(lx, ly, 10.5, 9.5, n=10, irregular=0.08)
            pf(c, e, TIMBER_L if (k * 7 + row) % 4 else TIMBER_M, tex=0.3, ink=1.2)
            c.ink_poly(c.blob(lx, ly, 3.6, 3.2, n=8, irregular=0.1), width=0.6, alpha=110)
    for x in (54, 346):
        pf(c, [(x - 9, 140), (x + 9, 138), (x + 9, base), (x - 9, base)], TIMBER_M, tex=0.35, ink=2.0, shade=(1, 0, 3.5, 70))
    roof = [(20, 150), (380, 112), (390, 132), (26, 176)]
    pf(c, roof, mix(TIMBER_D, CHAR, 0.3), tex=0.35, ink=2.6)
    sr = [(16, 150), (100, 136), (200, 126), (300, 116), (386, 108)]
    snow_band(c, sr, 26)
    icicles(c, 30, 380, 162, 14, (5, 16))
    drift(c, 120, base + 4, 110, 24); drift(c, 300, base + 4, 90, 18)
    c.save(out("world/buildings/template_woodshed.png"), winter=False)
    entry("world.woodshed", "Woodshed with stacked firewood", "world/buildings/template_woodshed.png", (200, 190), (W, H), (0.5, base / H))


def truck_wreck():
    W, H = 400, 260
    c = Canvas(W, H, seed=10201)
    base = 247
    c.soft_shadow((20, base - 18, 380, base + 10), alpha=130, blur=8)
    paint = mix(PAINT_B, RUST, 0.25)
    body = [(30, 150), (110, 150), (130, 96), (230, 92), (250, 150), (370, 150), (376, 206), (24, 212)]
    m = pf(c, body, paint, tex=0.4, cell=6, ink=2.6, shade=(0.4, 1, 4, 90))
    c.grime(m, 0.6, drips=True, color=RUST_D)
    for _ in range(9):
        c.fill(c.blob(c.rng.uniform(40, 360), c.rng.uniform(120, 200), c.rng.uniform(8, 20), c.rng.uniform(5, 10), n=9, irregular=0.4),
               mix(RUST, RUST_D, c.rng.random())[:3] + (200,), tex=0.3)
    win = [(140, 104), (222, 101), (238, 146), (136, 146)]
    c.fill(win, GLASS_D); c.fill(win, GLASS_F[:3] + (150,))
    c.ink_poly(win, width=1.8)
    c.ink([(150, 110), (200, 140)], width=1.2, color=SNOW_L, alpha=170)
    c.ink([(250, 150), (250, 204)], width=1.4); c.ink([(130, 150), (130, 206)], width=1.4)
    bed = [(250, 150), (370, 150), (370, 160), (250, 160)]
    pf(c, bed, mix(paint, CHAR, 0.3), tex=0.3, ink=1.6)
    for wx in (90, 310):  # flat tyres sagging into the snow
        t = c.blob(wx, 214, 30, 24, n=16, irregular=0.05)
        pf(c, t, CHAR, tex=0.2, ink=2.0)
        c.fill(c.blob(wx, 214, 12, 10, n=10, irregular=0.05), STEEL_D)
    for pts, th in (([(130, 96), (180, 90), (230, 92)], 14), ([(30, 150), (70, 146), (110, 150)], 12), ([(252, 150), (310, 146), (370, 150)], 18)):
        snow_band(c, pts, th)
    drift(c, 90, base + 2, 90, 26); drift(c, 300, base + 2, 110, 30); drift(c, 200, base + 4, 70, 14)
    c.save(out("props/vehicles/template_truck_wreck.png"), winter=False)
    entry("prop.truck_wreck", "Abandoned pickup truck (snowed in)", "props/vehicles/template_truck_wreck.png", (200, 130), (W, H), (0.5, base / H))


def clapboard(c, x0, x1, y0, y1, col, board=18):
    m = c.fill([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, tex=0.35, cell=10, light=(-1, -1, 0.3))
    y = y0 + board
    while y < y1:
        c.ink([(x0, y), (x1, y + c.rng.uniform(-1, 1))], width=1.2, alpha=150, seg=10)
        c.ink([(x0, y + 2), (x1, y + 2)], width=0.8, color=mix(col, INK, 0.5), alpha=90, seg=10)
        y += board
    for _ in range(12):  # peeling paint showing grey timber
        b = c.blob(c.rng.uniform(x0 + 10, x1 - 10), c.rng.uniform(y0 + 10, y1 - 10), c.rng.uniform(6, 22), c.rng.uniform(3, 8), n=9, irregular=0.45)
        c.fill(b, mix(TIMBER_M, ASH, 0.5), tex=0.3)
    c.grime(m, 0.55, drips=True)
    return m


def blocked_door(c, x, y, w, h):
    door = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    pf(c, door, mix(TIMBER_D, CHAR, 0.3), tex=0.3, ink=2.2)
    for k in range(3):  # planks nailed across
        yy = y + 16 + k * (h - 30) / 2
        p = [(x - 10, yy), (x + w + 10, yy + c.rng.uniform(-8, 8)), (x + w + 10, yy + 14), (x - 10, yy + 12)]
        pf(c, p, TIMBER_M, tex=0.35, ink=1.6)
        for nx in (x - 4, x + w + 4):
            c.ellipse_fill((nx - 2.5, yy + 4, nx + 2.5, yy + 9), CHAR)


def house(variant):
    if variant == 0:
        W, H, base = 640, 560, 532
        fx0, fx1, ftop, rtop = 120, 520, 200, 40
    else:
        W, H, base = 600, 460, 436
        fx0, fx1, ftop, rtop = 70, 530, 230, 90
    c = Canvas(W, H, seed=10301 + variant)
    c.soft_shadow((fx0 - 40, base - 26, fx1 + 40, base + 18), alpha=130, blur=12)
    col = PAINT_G if variant == 0 else mix(PAINT_B, TIMBER_L, 0.35)
    clapboard(c, fx0, fx1, ftop, base - 20, col, board=18)
    c.shade(c.mask([(fx1 - 90, ftop), (fx1, ftop), (fx1, base), (fx1 - 60, base)]), 1, 0, 5, 70, reach=1.0)
    c.shade(c.mask([(fx0, ftop), (fx1, ftop), (fx1, ftop + 50), (fx0, ftop + 50)]), 0, -1, 5, 85, reach=1.0)
    c.ink_poly([(fx0, ftop), (fx1, ftop), (fx1, base - 20), (fx0, base - 20)], width=3.0)
    found = [(fx0 - 8, base - 22), (fx1 + 8, base - 22), (fx1 + 8, base), (fx0 - 8, base)]
    pf(c, found, ASH, tex=0.35, ink=2.0)
    mid = (fx0 + fx1) / 2
    if variant == 0:  # steep gable, two storeys
        roof = [(mid, rtop), (fx1 + 34, ftop + 16), (fx0 - 34, ftop + 16)]
        pf(c, roof, mix(CHAR_L, RUST_D, 0.35), tex=0.35, ink=3.0)
        snow = [(mid, rtop - 10), (fx1 + 30, ftop + 6), (fx1 - 30, ftop + 14), (mid, rtop + 40), (fx0 + 30, ftop + 14), (fx0 - 30, ftop + 6)]
        m = c.fill(snow, SNOW, tex=0.12, light=(-1, -1, 0.3)); c.shade(m, 1, 0.5, 5, 60, reach=0.5)
        c.ink([(fx0 - 30, ftop + 6), (mid, rtop - 10), (fx1 + 30, ftop + 6)], width=2.6, alpha=220)
        icicles(c, fx0 - 20, fx1 + 20, ftop + 16, 18)
        frosted_window(c, mid - 40, 110, 80, 70)
        for wx in (160, 410):
            frosted_window(c, wx, 250, 74, 84, dark=wx > 300)
        frosted_window(c, 160, 380, 74, 84, boarded=True)
        blocked_door(c, 360, 380, 74, base - 20 - 380)
        # collapsed porch roof hanging off one corner
        pr = [(330, 356), (470, 344), (500, 372), (340, 392)]
        pf(c, pr, mix(TIMBER_D, CHAR, 0.3), tex=0.4, ink=2.2)
        pf(c, [(334, 392), (346, 392), (360, base - 20), (346, base - 20)], TIMBER_M, ink=1.6)
        snow_band(c, [(330, 352), (400, 346), (470, 340)], 10)
    else:  # low single storey with a hip roof and a buried porch chair
        roof = [(fx0 + 60, rtop), (fx1 - 60, rtop), (fx1 + 30, ftop + 16), (fx0 - 30, ftop + 16)]
        pf(c, roof, mix(CHAR_L, TIMBER_D, 0.4), tex=0.35, ink=3.0)
        snow = [(fx0 + 56, rtop - 10), (fx1 - 56, rtop - 10), (fx1 + 26, ftop + 4)] + \
               [(fx1 - (fx1 - fx0) * k / 8, ftop + c.rng.uniform(0, 10)) for k in range(1, 8)] + [(fx0 - 26, ftop + 4)]
        m = c.fill(snow, SNOW, tex=0.12, light=(-1, -1, 0.3)); c.shade(m, 1, 0.5, 5, 55, reach=0.45)
        c.ink(snow[:3], width=2.6, alpha=220); c.ink([snow[-1], snow[0]], width=2.6, alpha=220)
        icicles(c, fx0 - 20, fx1 + 20, ftop + 16, 20)
        frosted_window(c, 110, 282, 90, 80)
        frosted_window(c, 400, 282, 90, 80, dark=True)
        c.ink([(410, 300), (440, 330), (452, 312)], width=1.4, color=SNOW_L, alpha=200)  # broken pane
        blocked_door(c, 262, 270, 76, base - 20 - 270)
        # a chair left out on the step, half buried
        ch = [(180, 400), (226, 400), (226, 408), (180, 408)]
        pf(c, ch, TIMBER_M, ink=1.6)
        for lx in (184, 222):
            c.ink([(lx, 408), (lx, 428)], width=3, color=TIMBER_D)
        pf(c, [(180, 360), (186, 360), (186, 400), (180, 400)], TIMBER_M, ink=1.4)
        snow_band(c, [(176, 398), (204, 395), (230, 398)], 8)
    for dx in range(fx0 - 30, fx1 + 50, 90):
        drift(c, dx + c.rng.uniform(-10, 10), base + 4, c.rng.uniform(40, 70), c.rng.uniform(12, 24))
    for x0 in range(fx0 - 20, fx1 + 20, 80):
        dead_stalks(c, x0, base + 6, 50, c.rng.uniform(14, 26), n=7)
    name = "a" if variant == 0 else "b"
    c.save(out(f"world/settlement/template_house_{name}.png"), winter=False)
    entry(f"world.house_{name}", f"Abandoned house ({name})", f"world/settlement/template_house_{name}.png", (W // 2, H // 2), (W, H), (0.5, base / H))


def house_collapsed():
    """Two standing walls meeting in a back-left corner, roof fallen in. The
    frightened survivor shelters in that corner (inner corner at about x 96, y base-8)."""
    W, H = 520, 420
    c = Canvas(W, H, seed=10401)
    base = 396
    c.soft_shadow((30, base - 26, 500, base + 16), alpha=130, blur=12)
    col = mix(PAINT_G, ASH, 0.3)
    # back wall (behind), broken top edge
    back = [(80, 170), (180, 150), (260, 190), (330, 160), (420, 210), (440, 250), (440, base - 40), (80, base - 40)]
    m = pf(c, back, mix(col, CHAR_L, 0.35), tex=0.35, cell=8, ink=2.4)
    y = 190
    while y < base - 40:
        c.ink([(82, y), (438, y)], width=1.0, alpha=110, seg=8)
        y += 18
    c.grime(m, 0.6)
    frosted_window(c, 250, 236, 70, 64, dark=True)
    # left side wall seen in perspective (receding toward the back corner)
    side = [(30, 120), (86, 168), (86, base - 40), (30, base - 2)]
    pf(c, side, mix(col, CHAR_L, 0.15), tex=0.35, ink=2.4, shade=(1, 0, 4, 70))
    # interior floor with snow piled in
    floor = [(86, base - 40), (440, base - 40), (480, base - 2), (30, base - 2)]
    pf(c, floor, mix(TIMBER_D, ASH, 0.4), tex=0.4, ink=1.8)
    for x in range(120, 470, 34):
        c.ink([(x, base - 38), (x + 10, base - 4)], width=0.9, alpha=120)
    # fallen roof: sagging rafters and boards from the back wall down to the floor on the right
    for k in range(5):
        x0 = 200 + k * 50; pts = [(x0, 170 + k * 6), (x0 + 60, 260), (x0 + 110, base - 30)]
        c.ink(pts, width=10, color=mix(TIMBER_D, CHAR, 0.4)); c.ink(pts, width=1.6, alpha=210)
    rf = [(220, 176), (460, 230), (500, base - 20), (360, base - 16), (280, 262)]
    pf(c, rf, mix(CHAR_L, TIMBER_D, 0.45), tex=0.4, ink=2.6)
    snow_band(c, [(220, 172), (340, 196), (460, 226)], 20)
    snow_band(c, [(30, 116), (60, 140), (86, 164)], 10)
    snow_band(c, [(80, 166), (180, 146), (260, 186)], 9)
    drift(c, 250, base + 4, 120, 24); drift(c, 420, base + 4, 70, 18)
    # snow blown into the room, but the corner itself stays sheltered
    drift(c, 200, base - 6, 70, 14)
    # a wool blanket and a tin cup left in the sheltered corner
    c.fill(c.blob(118, base - 26, 30, 10, n=12, irregular=0.2), mix(RUST_D, TIMBER_D, 0.3), tex=0.4)
    c.ink_poly(c.blob(118, base - 26, 30, 10, n=12, irregular=0.2), width=1.2, alpha=180)
    pf(c, [(160, base - 34), (170, base - 34), (169, base - 22), (161, base - 22)], STEEL, ink=1.2)
    c.save(out("world/settlement/template_house_collapsed.png"), winter=False)
    entry("world.house_collapsed", "Collapsed house (sheltered corner)", "world/settlement/template_house_collapsed.png", (260, 210), (W, H), (0.5, base / H))


# ================================================================ small props
def sled():
    W, H = 160, 90
    c = Canvas(W, H, seed=10501)
    base = 80
    c.soft_shadow((20, base - 8, 140, base + 6), alpha=100, blur=5)
    deck = [(26, 48), (126, 44), (128, 56), (28, 60)]
    pf(c, deck, mix(RUST, TIMBER_M, 0.4), tex=0.35, ink=1.8)
    for x in (50, 76, 102):
        c.ink([(x, 46), (x, 58)], width=1.0, alpha=150)
    c.ink([(18, 70), (130, 66), (146, 52)], width=3, color=STEEL_D)
    c.ink([(40, 60), (40, 70)], width=2.4, color=STEEL_D); c.ink([(112, 56), (112, 67)], width=2.4, color=STEEL_D)
    c.ink([(126, 44), (150, 30), (158, 34)], width=1.4, color=hexc("#5A4A3A"))  # pull rope
    drift(c, 80, base + 2, 60, 12)
    c.save(out("props/clutter/template_sled.png"), winter=False)
    entry("prop.sled", "Child's sled left in the snow", "props/clutter/template_sled.png", (80, 45), (W, H), (0.5, base / H))


def starter_bag(empty):
    W, H = 120, 90
    c = Canvas(W, H, seed=10601 + empty)
    base = 82
    c.soft_shadow((14, base - 10, 106, base + 4), alpha=110, blur=4)
    canvas_col = hexc("#6A6650")
    if not empty:
        body = [(24, 40), (96, 36), (104, 78), (18, 80)]
        m = pf(c, body, canvas_col, tex=0.35, ink=2.0, shade=(1, 0.5, 3.5, 80))
        c.grime(m, 0.4)
        flap = [(26, 36), (94, 32), (90, 52), (60, 58), (30, 52)]
        pf(c, flap, mix(canvas_col, INK, 0.2), tex=0.3, ink=1.8)
        c.ink([(60, 56), (60, 66)], width=2.2, color=hexc("#3A3022"))
        c.ink([(28, 40), (40, 18), (78, 16), (92, 36)], width=3.2, color=hexc("#4A3E2C"))
        c.ink([(28, 40), (40, 18), (78, 16), (92, 36)], width=1.0, alpha=180)
        snow_band(c, [(24, 34), (60, 30), (96, 32)], 6)
    else:
        body = [(16, 62), (100, 58), (108, 80), (12, 82)]
        pf(c, body, mix(canvas_col, INK, 0.1), tex=0.35, ink=2.0)
        c.ink([(20, 64), (40, 50), (70, 48), (100, 60)], width=1.6, alpha=200)
        c.ink([(100, 62), (114, 44), (116, 30)], width=3, color=hexc("#4A3E2C"))
    c.save(out(f"props/clutter/template_starter_bag{'_empty' if empty else ''}.png"))
    entry("prop.starter_bag" + ("_empty" if empty else ""), "Starter bag" + (" (emptied)" if empty else ""),
          f"props/clutter/template_starter_bag{'_empty' if empty else ''}.png", (60, 45), (W, H), (0.5, base / H))


def blood_snow():
    """Cosmetic only: a little blood that thawed by warmth and ran into the snow."""
    W, H = 200, 100
    c = Canvas(W, H, seed=10701)
    c.fill(c.blob(100, 50, 70, 26, n=18, irregular=0.2), mix(SNOW, SNOW_SH, 0.35)[:3] + (200,), tex=0.1)
    for _ in range(9):
        x = c.rng.uniform(50, 150); y = c.rng.uniform(32, 66); r = c.rng.uniform(2, 7)
        c.fill(c.blob(x, y, r, r * 0.6, n=10, irregular=0.4), mix(BLOOD, BLOOD_D, c.rng.random())[:3] + (215,), tex=0.2)
    pts = [(70, 44), (96, 50), (118, 47), (146, 58)]
    c.ink(pts, width=3.2, color=BLOOD_D, alpha=200); c.ink(pts, width=1.2, color=BLOOD, alpha=230)
    c.save(out("props/clutter/template_blood_snow.png"), finish=False, winter=False)
    entry("prop.blood_snow", "Thawed blood in snow (decal)", "props/clutter/template_blood_snow.png", (100, 50), (W, H), (0.5, 0.5))


def snowflake():
    S = 24
    img = Image.new("RGBA", (S * 4, S * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((30, 30, 66, 66), fill=(235, 238, 240, 230))
    img = img.filter(ImageFilter.GaussianBlur(6)).resize((S, S), Image.LANCZOS)
    img.save(out("fx/template_snowflake.png"))
    entry("fx.snowflake", "Snowflake (particle)", "fx/template_snowflake.png", (12, 12), (S, S), (0.5, 0.5))


def fog():
    S = 512
    n = value_noise(S, S, 180, 11101, octaves=4, wrap=True)
    n2 = value_noise(S, S, 60, 11102, octaves=3, wrap=True)
    a = np.clip((n * 0.8 + n2 * 0.4 - 0.45) * 2.2, 0, 1) * 200
    arr = np.zeros((S, S, 4), dtype=np.uint8)
    arr[..., :3] = (214, 220, 224)
    arr[..., 3] = a.astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(out("fx/template_fog.png"), optimize=True)
    entry("fx.fog", "Cold fog (tileable overlay)", "fx/template_fog.png", (512, 512), (S, S), (0, 0))


def map_paper():
    """Weathered field-map paper: cold grey stock, folds, water stains, faint grid."""
    S = 512
    n = value_noise(S, S, 120, 11201, octaves=5, wrap=True)
    g = np.random.default_rng(11202).random((S, S)).astype(np.float32)
    base = np.array([196, 196, 186], dtype=np.float32)
    dark = np.array([150, 152, 144], dtype=np.float32)
    rgb = base * (1 - n[..., None] * 0.35) + dark * (n[..., None] * 0.35)
    rgb *= (0.95 + 0.07 * g)[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rng = random.Random(11203)
    def fg(d, ox, oy):
        for k in range(0, S, 64):
            d.line([(k + ox, oy), (k + ox, S + oy)], fill=(90, 110, 120, 34), width=1)
            d.line([(ox, k + oy), (S + ox, k + oy)], fill=(90, 110, 120, 34), width=1)
    wrap_draw(ov, fg)
    stains = [(rng.uniform(0, S), rng.uniform(0, S), rng.uniform(30, 80)) for _ in range(4)]
    def fs(d, ox, oy):
        for x, y, r in stains:
            d.ellipse((x - r + ox, y - r * 0.8 + oy, x + r + ox, y + r * 0.8 + oy), outline=(120, 110, 90, 60), width=3)
    wrap_draw(ov, fs)
    Image.alpha_composite(img, ov).save(out("ui/template_map_paper.png"), optimize=True)


def cabin_back_wall():
    """Interior back wall of the hunter's cabin (same id/size as the old farmhouse
    wall): horizontal logs, two small frosted windows, antlers, empty rifle pegs,
    a shelf with a few tins, a snowshoe on a nail. Indoors: no snow, warm wood."""
    W, H = 1520, 440
    c = Canvas(W, H, seed=11301)
    logs_wall(c, 0, W, 0, H - 46, h=30, ends=False)
    sk = [(0, H - 46), (W, H - 46), (W, H), (0, H)]
    pf(c, sk, TIMBER_D, tex=0.3, ink=2.0)
    for wx in (300, 1120):
        fr = [(wx - 12, 110), (wx + 172, 110), (wx + 172, 290), (wx - 12, 290)]
        pf(c, fr, TIMBER_M, tex=0.3, ink=2.4)
        frosted_window(c, wx, 122, 160, 156)
    # antlers mounted on a board
    ax, ay = 760, 120
    pf(c, [(ax - 30, ay - 10), (ax + 30, ay - 10), (ax + 24, ay + 34), (ax - 24, ay + 34)], TIMBER_L, ink=2.0)
    for sgn in (-1, 1):
        pts = [(ax + sgn * 10, ay), (ax + sgn * 46, ay - 30), (ax + sgn * 80, ay - 26), (ax + sgn * 104, ay - 58)]
        c.ink(pts, width=7, color=hexc("#D3CABA")); c.ink(pts, width=1.4, alpha=210)
        for (bx, by) in pts[1:3]:
            c.ink([(bx, by), (bx + sgn * 8, by - 30)], width=5, color=hexc("#D3CABA"))
    # empty rifle pegs: whatever hung here was taken
    for py in (210, 250):
        for px in (640, 880):
            pf(c, [(px - 6, py), (px + 6, py), (px + 6, py + 16), (px - 6, py + 16)], TIMBER_D, ink=1.4)
    c.ink([(650, 222), (870, 220)], width=1.0, color=TIMBER_L, alpha=110)  # a pale mark where it lay
    # shelf with tins
    pf(c, [(960, 300), (1060, 300), (1060, 312), (960, 312)], TIMBER_D, ink=1.6)
    for i, col in enumerate([STEEL, RUST, ASH_L]):
        x = 970 + i * 30
        pf(c, [(x, 270), (x + 20, 270), (x + 20, 300), (x, 300)], col, tex=0.25, ink=1.2)
    # a snowshoe hanging on a nail
    b = c.blob(160, 210, 22, 60, n=16, irregular=0.04)
    c.ink_poly(b, width=4, color=TIMBER_M); c.ink_poly(b, width=1.2)
    for k in range(6):
        c.ink([(142, 170 + k * 14), (178, 178 + k * 14)], width=0.9, alpha=150)
    c.ink([(0, H - 1), (W, H - 1)], width=3)
    c.save(out("world/interior/template_back_wall.png"), winter=False)


if __name__ == "__main__":
    snow_tile(); frozen_mud_tile(); road_snow_tile()
    pine(0); pine(1); birch_bare(); shrub_frozen(0); shrub_frozen(1)
    for v in range(3):
        dead_grass(v)
    stump_snow()
    hunter_cabin(); burned_shed(); woodshed(); truck_wreck(); house(0); house(1); house_collapsed()
    cabin_back_wall()
    sled(); starter_bag(0); starter_bag(1); blood_snow(); snowflake(); fog(); map_paper()
    path = os.path.join(ROOT, "assets", "manifest", "visual_winter.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "winter", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("winter art generated:", len(ENTRIES))
