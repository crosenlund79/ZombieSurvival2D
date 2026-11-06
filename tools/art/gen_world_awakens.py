#!/usr/bin/env python3
"""Red Thaw — The World Awakens (iteration 011) generated template art.

* The drivable station wagon in 16 screen headings. The car is a small 3D model
  (extruded side profiles + wheels) projected into the game's oblique 3/4 view
  (ground y foreshortened by OBLIQUE, heights drawn upward), lit from the upper
  left and inked with the shared inkkit pipeline, so every heading matches.
* The town settlement: storefront buildings with painted signs (grocery,
  clothing, hardware, pharmacy, garage), houses, a snowed-in parked car, street
  details, and the town house basement hatch.

Writes templates under assets/templates/ and assets/manifest/visual_awakens.json.
Never touches creator overrides. Run from the repository root.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix, INK, value_noise  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []
OBLIQUE = 0.6   # must match VehicleView.OBLIQUE


def out(rel):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def entry(aid, name, rel, display, source, pivot, notes=""):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel,
                    "display_size": list(display), "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_world_awakens.py) - replace with tablet art."})


# ------------------------------------------------------------------ station wagon
PAINT = hexc("#56676A")       # faded slate-blue paint
PAINT_D = hexc("#3B4749")
WOOD = hexc("#7A5A3C")        # wood-grain side panel
GLASS = hexc("#2E3A3E")
GLASS_L = hexc("#8C9CA0")
TYRE = hexc("#25221F")
CHROME = hexc("#A3A49B")
RUST = hexc("#7B4A2E")
LIGHT_DIR = np.array([-0.45, -0.35, 0.82]); LIGHT_DIR = LIGHT_DIR / np.linalg.norm(LIGHT_DIR)
VIEW = np.array([0.0, 1.0, OBLIQUE]); VIEW = VIEW / np.linalg.norm(VIEW)


def prism(profile, y0, y1):
    """Faces of a side profile [(x, z)] extruded from y0 to y1: list of (pts3d, tag)."""
    faces = [([(x, y1, z) for x, z in profile], "side+"), ([(x, y0, z) for x, z in reversed(profile)], "side-")]
    n = len(profile)
    for i in range(n):
        (xa, za), (xb, zb) = profile[i], profile[(i + 1) % n]
        faces.append(([(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)], "edge%d" % i))
    return faces


def wagon(index):
    S = 2.0                     # source px per display px
    DW, DH = 240, 200
    W, H = int(DW * S), int(DH * S)
    cx, cy = W / 2, 130 * S
    a = math.radians(index * 22.5)
    g = math.atan2(math.sin(a) / OBLIQUE, math.cos(a))
    cg, sg = math.cos(g), math.sin(g)
    c = Canvas(W, H, seed=700 + index)

    def rot(p):
        x, y, z = p
        return np.array([x * cg - y * sg, x * sg + y * cg, z])

    def proj(p3):
        return (cx + p3[0] * S, cy + (p3[1] * OBLIQUE - p3[2]) * S)

    def normal(pts):
        p = [rot(q) for q in pts]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        ln = np.linalg.norm(n)
        return n / ln if ln > 0 else n

    def depth(pts):
        return float(np.mean([rot(q) @ VIEW for q in pts]))

    L2, W2 = 88, 38
    # contact shadow (projected footprint, softened)
    foot = [proj(rot((x, y, 0))) for x, y in [(L2 + 4, W2 + 4), (L2 + 4, -W2 - 4), (-L2 - 4, -W2 - 4), (-L2 - 4, W2 + 4)]]
    xs = [p[0] for p in foot]; ys = [p[1] for p in foot]
    c.soft_shadow((min(xs) / 1, min(ys) - 4, max(xs), max(ys) + 6), alpha=130, blur=12)
    shadow = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(shadow).polygon([(x * 2, y * 2) for x, y in foot], fill=150)

    lower = [(-L2, 12), (L2 - 2, 12), (L2, 22), (L2 - 3, 33), (34, 37), (-L2 + 2, 38), (-L2, 30)]
    cabin = [(-L2 + 6, 37), (32, 37), (12, 63), (-L2 + 10, 65)]
    wheels = [(56, -W2 + 2), (56, W2 - 2), (-58, -W2 + 2), (-58, W2 - 2)]
    R = 15.0

    def wheel_poly(wx, wy, yoff):
        return [rot((wx + R * math.cos(t), wy + yoff, R + R * math.sin(t))) for t in np.linspace(0, 2 * math.pi, 18, endpoint=False)]

    def draw_wheel(wx, wy):
        side = 1 if wy > 0 else -1
        outer = wheel_poly(wx, wy, side * 5)
        inner = wheel_poly(wx, wy, -side * 5)
        hull_pts = [proj(p) for p in outer + inner]
        from PIL import ImageDraw as D
        m = Image.new("L", c.img.size, 0)
        # convex hull of both discs = the tyre silhouette
        pts = np.array(hull_pts)
        hull = _hull(pts)
        D.Draw(m).polygon([(x * 2, y * 2) for x, y in hull], fill=255)
        c.fill(None, TYRE, tex=0.2, mask=m)
        disc_n = normal([(wx, wy + side * 5, R + 1), (wx + 1, wy + side * 5, R), (wx, wy + side * 5, R - 1)])
        if (disc_n * side) @ VIEW > 0.02 or (-disc_n * side) @ VIEW > 0.02:
            vis = disc_n @ VIEW
            if side * vis < 0:
                pass
            hub = [proj(rot((wx + R * 0.48 * math.cos(t), wy + side * 6, R + R * 0.48 * math.sin(t)))) for t in np.linspace(0, 2 * math.pi, 12, endpoint=False)]
            facing = normal([(wx, wy + side * 6, 0), (wx + 1, wy + side * 6, 0), (wx, wy + side * 6, 1)])
            if (facing * side) @ VIEW > 0.05:
                c.fill(hub, CHROME, tex=0.25)
                c.ink_poly(hub, width=1.4, alpha=200)
        c.ink_poly(hull, width=2.0, alpha=230)

    body_faces = prism(lower, -W2, W2)
    cab_faces = prism(cabin, -W2 + 5, W2 - 5)
    # far-side wheels first (hidden mostly by the body)
    near = []
    for wx, wy in wheels:
        side_vec = np.array([-sg, cg, 0.0]) * (1 if wy > 0 else -1)
        if side_vec @ VIEW < 0:
            draw_wheel(wx, wy)
        else:
            near.append((wx, wy))

    def draw_faces(faces, base_color, kind):
        vis = []
        allp = [rot(q) for pts, _ in faces for q in pts]
        centre = np.mean(allp, axis=0)
        for pts, tag in faces:
            n = normal(pts)
            if n @ (np.mean([rot(q) for q in pts], axis=0) - centre) < 0:
                n = -n
            if n @ VIEW <= 0.01:
                continue
            vis.append((depth(pts), pts, tag, n))
        vis.sort(key=lambda t: t[0])
        for _, pts, tag, n in vis:
            poly = [proj(rot(p)) for p in pts]
            lit = float(np.clip(n @ LIGHT_DIR, -1, 1))
            k = 0.72 + 0.42 * max(0.0, lit)
            col = base_color
            if kind == "cabin" and tag in ("edge1", "edge3"):
                col = GLASS          # windscreen and rear window
            col = tuple(int(min(255, v * k)) for v in col[:3]) + (255,)
            m = c.fill(poly, col, tex=0.28, cell=10, light=(-0.6, -0.8, 0.25))
            if lit < 0.25 and not (kind == "cabin" and tag in ("edge1", "edge3")):
                c.shade(m, spacing=4.5, alpha=70, reach=0.8)
            _details(c, kind, tag, pts, rot, proj, n)
            c.ink_poly(poly, width=2.0, alpha=225)

    draw_faces(body_faces, PAINT, "body")
    draw_faces(cab_faces, PAINT, "cabin")
    for wx, wy in near:
        draw_wheel(wx, wy)
    # silhouette accent
    c.save(out("props/vehicles/template_wagon_%02d.png" % index), winter=False)
    entry("vehicle.wagon_%02d" % index, "Station wagon, heading %d deg (screen, clockwise from east)" % (index * 22.5),
          "props/vehicles/template_wagon_%02d.png" % index, (DW, DH), (W, H), (0.5, 130 / DH),
          "Generated placeholder (tools/art/gen_world_awakens.py): 16 headings of one 3D model. Replace each heading with "
          "matching art; origin = centre of the car on the ground.")


def _details(c, kind, tag, pts, rot, proj, n):
    """Windows, wood panel, lights and trim on the visible faces."""
    def lerp3(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    if kind == "body" and tag in ("side+", "side-"):
        y = pts[0][1]
        # wood-grain panel along the flank, door lines, rust at the sill
        panel = [(-80, y, 18), (78, y, 18), (78, y, 30), (-80, y, 31)]
        pp = [proj(rot(p)) for p in panel]
        c.fill(pp, WOOD, tex=0.4, cell=6)
        c.ink_poly(pp, width=1.2, alpha=170)
        for x in (-30, 26):
            c.ink([proj(rot((x, y, 13))), proj(rot((x, y, 36)))], width=1.3, alpha=170)
        for _ in range(3):
            x = c.rng.uniform(-80, 70)
            blob = [proj(rot((x + dx, y, 13 + dz))) for dx, dz in ((0, 0), (9, 0), (7, 4), (1, 5))]
            c.fill(blob, RUST, tex=0.5, cell=3)
    elif kind == "body" and tag == "edge2":       # front lamps and grille
        y0, y1 = pts[0][1], pts[2][1]
        for yy in (y0 + 8, y1 - 8):
            lamp = [proj(rot((89, yy + dy, 26 + dz))) for dy, dz in ((-5, -3), (5, -3), (5, 3), (-5, 3))]
            c.fill(lamp, hexc("#E6DDB8"), tex=0.15)
            c.ink_poly(lamp, width=1.2)
        grille = [proj(rot((89, y, 15 + dz))) for y, dz in ((y0 + 14, 0), (y1 - 14, 0), (y1 - 14, 7), (y0 + 14, 7))]
        c.fill(grille, CHROME, tex=0.3)
        c.ink_poly(grille, width=1.2)
    elif kind == "body" and tag == "edge6":       # tailgate face
        y0, y1 = pts[0][1], pts[2][1]
        for yy in (y0 + 7, y1 - 7):
            lamp = [proj(rot((-88.5, yy + dy, 30 + dz))) for dy, dz in ((-4, -4), (4, -4), (4, 4), (-4, 4))]
            c.fill(lamp, hexc("#8E2A22"), tex=0.2)
            c.ink_poly(lamp, width=1.1)
    elif kind == "cabin" and tag in ("side+", "side-"):
        y = pts[0][1]
        for x0, x1 in ((-74, -32), (-28, 2), (6, 24)):
            top = 61 if x1 < 10 else 61 - (x1 - 6) * 1.2
            win = [(x0, y, 41), (x1, y, 41), (min(x1, 26) - (2 if x1 > 10 else 0), y, top), (x0, y, 61)]
            if x0 == 6:
                win = [(6, y, 41), (26, y, 41), (13, y, 59), (6, y, 59)]
            wp = [proj(rot(p)) for p in win]
            c.fill(wp, GLASS, tex=0.25, light=(1, 1, 0.5))
            c.ink([wp[3], wp[1]], width=0.9, color=GLASS_L, alpha=120)
            c.ink_poly(wp, width=1.4, alpha=210)
    elif kind == "cabin" and tag == "edge2":      # roof with a rack
        x0, x1 = -70, 6
        y0, y1 = pts[0][1] + 6, pts[2][1] - 6
        for yy in (y0, y1):
            c.ink([proj(rot((x0, yy, 66))), proj(rot((x1, yy, 66)))], width=1.6, color=hexc("#2B2B27"))
        for xx in np.linspace(x0, x1, 5):
            c.ink([proj(rot((xx, y0, 66))), proj(rot((xx, y1, 66)))], width=1.2, color=hexc("#2B2B27"), alpha=200)


def _hull(pts):
    pts = sorted(map(tuple, pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


# ------------------------------------------------------------------ the town (Ashgrove)
import gen_winter as gw  # noqa: E402  (shared winter helpers and palette)

FONT_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]


def _font(size):
    for fp in FONT_PATHS:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default(size=size)


def paint_text(c, text, box, color, alpha=230, worn=0.35):
    """Hand-painted sign lettering: text fitted into box (source px), worn by noise."""
    from inkkit import SS
    x0, y0, x1, y1 = box
    w, h = (x1 - x0) * SS, (y1 - y0) * SS
    size = int(h * 0.8)
    f = _font(size)
    while size > 8 and f.getbbox(text)[2] > w * 0.92:
        size -= 2
        f = _font(size)
    m = Image.new("L", (int(w), int(h)), 0)
    d = ImageDraw.Draw(m)
    bb = d.textbbox((0, 0), text, font=f)
    d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], (h - (bb[3] - bb[1])) / 2 - bb[1]), text, font=f, fill=alpha)
    n = value_noise(int(w), int(h), 6, c.rng.randint(0, 1 << 20), octaves=2)
    keep = (n > worn * 0.6).astype(np.float32)
    arr = (np.asarray(m, dtype=np.float32) * (0.55 + 0.45 * keep)).astype(np.uint8)
    full = Image.new("L", c.img.size, 0)
    full.paste(Image.fromarray(arr, "L"), (int(x0 * SS), int(y0 * SS)))
    layer = Image.new("RGBA", c.img.size, color[:3] + (255,))
    c.paste_layer(layer, full)


STORES = {
    # kind: (sign text, facade colour, awning colours, display goods colours)
    "grocery": ("GROCERY", gw.mix(gw.PAINT_G, gw.TIMBER_L, 0.25), (hexc("#7E3A2C"), hexc("#C9C1AE")), [hexc("#A0703A"), hexc("#8A9A55"), hexc("#B5582F")]),
    "pharmacy": ("PHARMACY", gw.mix(gw.PAINT_B, gw.SNOW_SH, 0.3), (hexc("#3F6457"), hexc("#C9C1AE")), [hexc("#C9C6BC"), hexc("#7F9C8E"), hexc("#B9A26A")]),
    "hardware": ("HARDWARE", gw.mix(gw.RUST, gw.ASH, 0.45), (hexc("#3C4B57"), hexc("#B9AD90")), [gw.STEEL, gw.TIMBER_M, hexc("#9C7A2E")]),
    "clothing": ("CLOTHING", gw.mix(gw.TIMBER_L, gw.PAINT_B, 0.35), (hexc("#5B3F5A"), hexc("#C9C1AE")), [hexc("#6E4B63"), hexc("#4F6670"), hexc("#A88A5C")]),
    "garage": ("GARAGE  ·  SERVICE", gw.mix(gw.ASH, gw.SNOW_SH, 0.35), (hexc("#6A2F25"), hexc("#B9AD90")), [gw.STEEL_D, gw.STEEL, gw.RUST]),
}


def storefront(kind):
    sign, col, (aw1, aw2), goods = STORES[kind]
    W, H, base = 880, 640, 612
    c = Canvas(W, H, seed=11000 + sum(map(ord, kind)))
    fx0, fx1, ftop = 70, 810, 150
    c.soft_shadow((fx0 - 40, base - 28, fx1 + 40, base + 18), alpha=135, blur=12)
    # facade: brick for the town core, clapboard for the garage
    if kind == "garage":
        gw.clapboard(c, fx0, fx1, ftop, base - 16, col, board=20)
    else:
        m = c.fill([(fx0, ftop), (fx1, ftop), (fx1, base - 16), (fx0, base - 16)], col, tex=0.35, cell=8, light=(-1, -1, 0.3))
        y = ftop + 14
        row = 0
        while y < base - 16:
            c.ink([(fx0, y), (fx1, y)], width=0.9, alpha=90, seg=10)
            off = 0 if row % 2 == 0 else 22
            for x in range(fx0 + off, fx1, 44):
                c.ink([(x, y - 14), (x, y)], width=0.8, alpha=70, seg=6)
            y += 14
            row += 1
        c.grime(m, 0.45)
    c.shade(c.mask([(fx1 - 110, ftop), (fx1, ftop), (fx1, base), (fx1 - 80, base)]), 1, 0, 5, 70, reach=1.0)
    # parapet + cornice
    par = [(fx0 - 14, ftop - 34), (fx1 + 14, ftop - 34), (fx1 + 14, ftop + 6), (fx0 - 14, ftop + 6)]
    gw.pf(c, par, gw.mix(col, gw.CHAR_L, 0.35), tex=0.3, ink=2.6)
    gw.snow_band(c, [(fx0 - 14, ftop - 34), ((fx0 + fx1) / 2, ftop - 38), (fx1 + 14, ftop - 34)], 16)
    gw.icicles(c, fx0, fx1, ftop + 6, 26)
    # sign board with painted lettering
    sb = [(fx0 + 60, ftop + 16), (fx1 - 60, ftop + 16), (fx1 - 60, ftop + 78), (fx0 + 60, ftop + 78)]
    gw.pf(c, sb, gw.mix(gw.CHAR_L, gw.TIMBER_D, 0.5), tex=0.3, ink=2.4)
    paint_text(c, sign, (fx0 + 76, ftop + 22, fx1 - 76, ftop + 72), gw.mix(gw.SNOW_L, hexc("#D9C38A"), 0.35))
    gw.snow_band(c, [(fx0 + 60, ftop + 14), (fx1 - 60, ftop + 14)], 6)
    if kind == "garage":
        # two roll-up bays, one jammed half open
        for bx, open_ in ((fx0 + 50, False), (fx0 + 380, True)):
            bay = [(bx, ftop + 110), (bx + 300, ftop + 110), (bx + 300, base - 16), (bx, base - 16)]
            gw.pf(c, bay, gw.STEEL_D if not open_ else gw.CHAR, tex=0.3, ink=2.4)
            top = ftop + 110 + (0 if not open_ else 0)
            yy = top
            stop = base - 16 if not open_ else ftop + 260
            gw.pf(c, [(bx + 4, top), (bx + 296, top), (bx + 296, stop), (bx + 4, stop)], gw.STEEL, tex=0.3, ink=1.8)
            while yy < stop:
                c.ink([(bx + 6, yy), (bx + 294, yy)], width=1.0, alpha=120, seg=8)
                yy += 18
            if open_:
                gw.drift(c, bx + 150, base - 14, 120, 30)
        c.shade(c.mask([(fx0 + 380, ftop + 260), (fx0 + 680, ftop + 260), (fx0 + 680, base - 16), (fx0 + 380, base - 16)]), 0, -1, 4, 110, reach=1.0)
    else:
        # awning (torn), shop window with goods silhouettes, door
        aw = [(fx0 + 20, ftop + 96), (fx1 - 20, ftop + 96), (fx1 - 4, ftop + 150), (fx0 + 4, ftop + 150)]
        m = c.fill(aw, aw2, tex=0.3)
        stripes = 12
        for k in range(stripes):
            if k % 2 == 0:
                x0 = fx0 + 20 + (fx1 - fx0 - 40) * k / stripes
                x1 = fx0 + 20 + (fx1 - fx0 - 40) * (k + 1) / stripes
                c.fill([(x0, ftop + 96), (x1, ftop + 96), (x1 + 6 * (k - 6) / 6 + 4, ftop + 150), (x0 + 6 * (k - 6) / 6, ftop + 150)], aw1, tex=0.3)
        c.ink_poly(aw, width=2.2)
        for k in range(10):  # scalloped torn edge
            x = fx0 + 4 + (fx1 - fx0 - 8) * k / 10
            c.ink([(x, ftop + 150), (x + 18, ftop + 160 + c.rng.uniform(-4, 8)), (x + (fx1 - fx0 - 8) / 10, ftop + 150)], width=1.6, alpha=200)
        gw.snow_band(c, [(fx0 + 20, ftop + 94), (fx1 - 20, ftop + 94)], 10)
        wx0, wx1, wy0, wy1 = fx0 + 40, fx0 + 470, ftop + 180, base - 70
        gw.pf(c, [(wx0 - 8, wy0 - 8), (wx1 + 8, wy0 - 8), (wx1 + 8, wy1 + 10), (wx0 - 8, wy1 + 10)], gw.TIMBER_D, ink=2.2)
        gw.pf(c, [(wx0, wy0), (wx1, wy0), (wx1, wy1), (wx0, wy1)], gw.GLASS_D, tex=0.2, ink=1.6)
        # shelves and goods behind the glass (dim, mostly emptied)
        for sy in (wy0 + 60, wy0 + 130, wy1 - 20):
            c.ink([(wx0 + 6, sy), (wx1 - 6, sy)], width=2.0, color=gw.TIMBER_M, alpha=200)
            x = wx0 + 14
            while x < wx1 - 30:
                if c.rng.random() < 0.45:
                    gh = c.rng.uniform(14, 34)
                    g = [(x, sy - gh), (x + c.rng.uniform(12, 26), sy - gh), (x + c.rng.uniform(12, 26), sy), (x, sy)]
                    c.fill(g, gw.mix(c.rng.choice(goods), gw.GLASS_D, 0.55), tex=0.3)
                x += c.rng.uniform(18, 40)
        # frost creeping over the glass + a crack
        frost = c.mask([(wx0, wy1 - 70), (wx0 + 120, wy1 - 40), (wx1, wy1 - 60), (wx1, wy1), (wx0, wy1)])
        c.speckle(frost, 160, gw.SNOW_L, size=(1, 3), alpha=(60, 160))
        cx_ = c.rng.uniform(wx0 + 80, wx1 - 80)
        c.ink([(cx_, wy0 + 10), (cx_ + 30, wy0 + 70), (cx_ + 12, wy0 + 120), (cx_ + 50, wy0 + 170)], width=1.2, color=gw.SNOW_L, alpha=190)
        gw.snow_band(c, [(wx0 - 8, wy1 + 10), (wx1 + 8, wy1 + 10)], 8)
        # door
        dx0 = fx0 + 500
        gw.pf(c, [(dx0 - 8, ftop + 172), (dx0 + 140, ftop + 172), (dx0 + 140, base - 16), (dx0 - 8, base - 16)], gw.TIMBER_D, ink=2.2)
        gw.pf(c, [(dx0, ftop + 180), (dx0 + 132, ftop + 180), (dx0 + 132, base - 16), (dx0, base - 16)], gw.mix(gw.GLASS_D, gw.TIMBER_D, 0.4), tex=0.3, ink=1.8)
        c.ink([(dx0 + 66, ftop + 180), (dx0 + 66, base - 16)], width=1.6, alpha=200)
        if kind == "pharmacy":
            cross = [(dx0 + 52, ftop + 214), (dx0 + 80, ftop + 214), (dx0 + 80, ftop + 232), (dx0 + 52, ftop + 232)]
            c.fill(cross, hexc("#4E8A6C")); c.fill([(dx0 + 58, ftop + 202), (dx0 + 74, ftop + 202), (dx0 + 74, ftop + 244), (dx0 + 58, ftop + 244)], hexc("#4E8A6C"))
        if kind in ("grocery", "clothing"):
            gw.blocked_door(c, dx0 + 6, ftop + 186, 120, base - 16 - (ftop + 186))
        # window on the right
        gw.frosted_window(c, fx0 + 656, ftop + 190, 62, 90, dark=True)
    found = [(fx0 - 8, base - 18), (fx1 + 8, base - 18), (fx1 + 8, base), (fx0 - 8, base)]
    gw.pf(c, found, gw.ASH, tex=0.35, ink=2.0)
    for dx in range(fx0 - 30, fx1 + 50, 110):
        gw.drift(c, dx + c.rng.uniform(-10, 10), base + 4, c.rng.uniform(40, 80), c.rng.uniform(12, 26))
    rel = f"world/town/template_{kind}.png"
    c.save(out(rel), winter=False)
    entry(f"world.town_{kind}", f"Town {kind} storefront", rel, (W // 2, H // 2), (W, H), (0.5, base / H))


def streetlamp():
    W, H, base = 120, 400, 388
    c = Canvas(W, H, seed=11501)
    c.soft_shadow((30, base - 10, 90, base + 8), alpha=120, blur=6)
    pole = [(56, 70), (64, 70), (66, base), (54, base)]
    gw.pf(c, pole, gw.STEEL_D, tex=0.3, ink=2.0, shade=(1, 0, 4, 70))
    arm = [(60, 70), (100, 52), (104, 58), (62, 80)]
    gw.pf(c, arm, gw.STEEL_D, ink=1.8)
    head = [(86, 54), (114, 50), (116, 66), (88, 70)]
    gw.pf(c, head, gw.STEEL, ink=2.0)
    c.fill([(92, 66), (112, 63), (110, 70), (94, 72)], hexc("#3A3A34"))  # dead bulb
    gw.snow_band(c, [(84, 50), (100, 47), (116, 48)], 6)
    gw.drift(c, 60, base + 2, 34, 12)
    rel = "world/town/template_streetlamp.png"
    c.save(out(rel), winter=False)
    entry("world.town_streetlamp", "Dead street lamp", rel, (W // 2, H // 2), (W, H), (0.5, base / H))


def town_sign():
    W, H, base = 300, 240, 226
    c = Canvas(W, H, seed=11601)
    c.soft_shadow((40, base - 12, 260, base + 8), alpha=120, blur=8)
    for px in (70, 228):
        gw.pf(c, [(px - 5, 110), (px + 5, 110), (px + 6, base), (px - 6, base)], gw.TIMBER_D, ink=1.8)
    board = [(30, 40), (270, 40), (272, 128), (28, 132)]
    gw.pf(c, board, gw.mix(hexc("#3F5B4A"), gw.ASH, 0.25), tex=0.3, ink=2.6)
    c.ink_poly([(38, 48), (262, 48), (264, 122), (36, 124)], width=1.4, color=gw.SNOW_L, alpha=170)
    paint_text(c, "ASHGROVE", (46, 54, 254, 98), gw.SNOW_L, worn=0.25)
    paint_text(c, "POP. 2,140", (90, 100, 210, 118), gw.SNOW_L, worn=0.5)
    c.ink([(120, 98), (196, 120)], width=2.4, color=hexc("#7E2A22"), alpha=210)  # population crossed out
    gw.snow_band(c, [(28, 38), (150, 34), (272, 38)], 8)
    gw.drift(c, 150, base + 4, 120, 20)
    rel = "world/town/template_town_sign.png"
    c.save(out(rel), winter=False)
    entry("world.town_sign", "Town sign: Ashgrove (population crossed out)", rel, (W // 2, H // 2), (W, H), (0.5, base / H))


def roadblock():
    """A wall of ploughed-up snow and a jackknifed trailer closing the road east."""
    W, H, base = 560, 360, 340
    c = Canvas(W, H, seed=11701)
    c.soft_shadow((20, base - 30, 540, base + 14), alpha=130, blur=12)
    trailer = [(90, 120), (470, 90), (480, 250), (100, 280)]
    gw.pf(c, trailer, gw.mix(gw.STEEL, gw.RUST, 0.35), tex=0.4, ink=3.0, shade=(1, 0.4, 5, 80))
    for k in range(8):
        x = 120 + k * 44
        c.ink([(x, 118 - k * 3.4), (x + 6, 270 - k * 3.6)], width=1.2, alpha=130)
    gw.snow_band(c, [(90, 118), (280, 104), (470, 88)], 22)
    for x in range(40, 540, 70):
        gw.drift(c, x + c.rng.uniform(-14, 14), base + 2, c.rng.uniform(60, 90), c.rng.uniform(40, 80))
    rel = "world/town/template_roadblock.png"
    c.save(out(rel), winter=False)
    entry("world.town_roadblock", "Road east blocked: jackknifed trailer in ploughed snow", rel, (W // 2, H // 2), (W, H), (0.5, base / H))


# ------------------------------------------------------------------ wildlife (iteration 011 D)
SPECIES = {
    # W, H, base, body (cx, cy, rx, ry), fur, dark, light
    "wolf": dict(W=220, H=140, base=128, fur=hexc("#77726A"), dark=hexc("#45413B"), light=hexc("#B2AC9F"), bulk=1.0),
    "bear": dict(W=300, H=200, base=186, fur=hexc("#46372C"), dark=hexc("#2A211B"), light=hexc("#7A644F"), bulk=1.45),
}


def _leg(c, top, foot, w_top, w_foot, col, ink_a=220):
    (x0, y0), (x1, y1) = top, foot
    d = math.atan2(y1 - y0, x1 - x0) + math.pi / 2
    ox0, oy0 = math.cos(d) * w_top / 2, math.sin(d) * w_top / 2
    ox1, oy1 = math.cos(d) * w_foot / 2, math.sin(d) * w_foot / 2
    poly = [(x0 - ox0, y0 - oy0), (x0 + ox0, y0 + oy0), (x1 + ox1, y1 + oy1), (x1 - ox1, y1 - oy1)]
    c.fill(poly, col, tex=0.3, cell=5)
    c.ink([poly[0], poly[3]], width=1.6, alpha=ink_a)
    c.ink([poly[1], poly[2]], width=1.6, alpha=ink_a)
    c.ellipse_fill((x1 - w_foot * 0.7, y1 - 3, x1 + w_foot * 0.7, y1 + 3), mix(col, INK, 0.5))


def quadruped(kind, view, frame=0):
    sp = SPECIES[kind]
    W, H, base, k = sp["W"], sp["H"], sp["base"], sp["bulk"]
    fur, dark, light = sp["fur"], sp["dark"], sp["light"]
    c = Canvas(W, H, seed=12000 + len(kind) * 31 + frame * 7 + {"side": 0, "down": 1, "up": 2}[view])
    cx = W / 2
    if view == "side":
        c.soft_shadow((cx - 70 * k, base - 10, cx + 70 * k, base + 8), alpha=120, blur=8)
        bx, by = cx - 6 * k, base - 46 * k
        swing = 9 * k if frame == 0 else -9 * k
        hip, shoulder = bx - 30 * k, bx + 30 * k
        legw = 11 * k
        # far legs (darker), then body, then near legs
        _leg(c, (hip + 6, by + 6), (hip + 6 - swing, base - 2), legw, legw * 0.7, mix(fur, INK, 0.35))
        _leg(c, (shoulder + 6, by + 6), (shoulder + 6 + swing, base - 2), legw, legw * 0.7, mix(fur, INK, 0.35))
        if kind == "wolf":  # bushy tail
            tail = [(bx - 44 * k, by - 6), (bx - 66 * k, by + 2), (bx - 78 * k, by + 22), (bx - 70 * k, by + 26), (bx - 54 * k, by + 12), (bx - 40 * k, by + 4)]
            c.fill(tail, fur, tex=0.4, cell=4); c.ink_poly(tail, width=1.8)
        body = c.blob(bx, by, 50 * k, 19 * k, n=16, irregular=0.06)
        m = c.fill(body, fur, tex=0.4, cell=6, light=(-0.6, -1, 0.35))
        c.shade(m, spacing=4.5, alpha=80, reach=0.5)
        belly = c.blob(bx + 2, by + 10 * k, 38 * k, 7 * k, n=12, irregular=0.1)
        c.fill(belly, light, tex=0.3, cell=4)
        back = c.blob(bx - 4, by - 12 * k, 42 * k, 6 * k, n=12, irregular=0.12)
        c.fill(back, dark, tex=0.3, cell=4)
        if kind == "bear":  # shoulder hump
            hump = c.blob(shoulder - 6, by - 14 * k, 18 * k, 12 * k, n=12, irregular=0.08)
            c.fill(hump, fur, tex=0.4, cell=5)
            c.fill([(bx - 50 * k, by - 6), (bx - 58 * k, by), (bx - 50 * k, by + 4)], dark)  # stub tail
        c.ink_poly(body, width=2.6)
        for _ in range(14):  # fur strokes
            fx = c.rng.uniform(bx - 40 * k, bx + 40 * k); fy = c.rng.uniform(by - 12 * k, by + 8 * k)
            c.ink([(fx, fy), (fx - 4, fy + 5)], width=1.0, alpha=130)
        _leg(c, (hip, by + 8), (hip + swing, base), legw * 1.1, legw * 0.75, fur)
        _leg(c, (shoulder, by + 8), (shoulder - swing, base), legw * 1.1, legw * 0.75, fur)
        # neck + head
        hx, hy = bx + 54 * k, by - 16 * k
        neck = [(shoulder - 4, by - 14 * k), (hx - 6, hy - 10), (hx + 2, hy + 12), (shoulder + 8, by + 6)]
        c.fill(neck, fur, tex=0.35, cell=5)
        head = c.blob(hx, hy, 17 * k, 13 * k, n=14, irregular=0.06)
        c.fill(head, fur, tex=0.35, cell=4, light=(-0.6, -1, 0.3))
        sn = 24 if kind == "wolf" else 16
        snout = [(hx + 8 * k, hy - 5 * k), (hx + sn * k, hy + 1 * k), (hx + (sn - 2) * k, hy + 7 * k), (hx + 6 * k, hy + 9 * k)]
        c.fill(snout, light if kind == "wolf" else sp["light"], tex=0.3)
        c.ink_poly(snout, width=1.8)
        c.ellipse_fill((hx + (sn - 3) * k, hy - 1 * k, hx + (sn + 2) * k, hy + 4 * k), INK)  # nose
        c.ink_poly(head, width=2.2)
        if kind == "wolf":
            for ex in (-6, 2):
                ear = [(hx + ex * k, hy - 10 * k), (hx + (ex + 4) * k, hy - 24 * k), (hx + (ex + 9) * k, hy - 9 * k)]
                c.fill(ear, dark); c.ink_poly(ear, width=1.6)
        else:
            for ex in (-8, 2):
                c.ellipse_fill((hx + ex * k, hy - 15 * k, hx + (ex + 8) * k, hy - 8 * k), dark)
        c.ellipse_fill((hx + 3 * k, hy - 4 * k, hx + 6 * k, hy - 1 * k), hexc("#D9C88A") if kind == "wolf" else INK)
    else:
        front = view == "down"
        c.soft_shadow((cx - 44 * k, base - 10, cx + 44 * k, base + 8), alpha=120, blur=8)
        by = base - 44 * k
        legw = 12 * k
        for lx in (-18, 18):  # far pair
            _leg(c, (cx + lx * k, by + 4), (cx + lx * k, base - 6), legw, legw * 0.7, mix(fur, INK, 0.35))
        if not front and kind == "wolf":
            tail = [(cx - 6, by - 4), (cx + 6, by - 4), (cx + 8, by + 30 * k), (cx, by + 38 * k), (cx - 8, by + 30 * k)]
        body = c.blob(cx, by, 30 * k, 24 * k, n=16, irregular=0.06)
        m = c.fill(body, fur, tex=0.4, cell=6, light=(-0.6, -1, 0.35))
        c.shade(m, spacing=4.5, alpha=80, reach=0.5)
        c.fill(c.blob(cx, by - 12 * k, 22 * k, 9 * k, n=12, irregular=0.1), dark, tex=0.3, cell=4)
        c.ink_poly(body, width=2.6)
        for lx in (-14, 14):  # near pair
            _leg(c, (cx + lx * k, by + 12 * k), (cx + lx * k, base), legw * 1.1, legw * 0.8, fur)
        if front:
            hy = by + 6 * k
            head = c.blob(cx, hy, 17 * k, 15 * k, n=14, irregular=0.05)
            c.fill(head, fur, tex=0.35, cell=4, light=(-0.6, -1, 0.3))
            muzzle = c.blob(cx, hy + 9 * k, 9 * k, 8 * k, n=12, irregular=0.05)
            c.fill(muzzle, light, tex=0.3)
            c.ink_poly(muzzle, width=1.6)
            c.ellipse_fill((cx - 3 * k, hy + 7 * k, cx + 3 * k, hy + 11 * k), INK)
            for ex in (-8, 8):
                c.ellipse_fill((cx + ex * k - 2, hy - 3 * k, cx + ex * k + 2, hy + 1 * k), hexc("#D9C88A") if kind == "wolf" else INK)
            c.ink_poly(head, width=2.2)
            if kind == "wolf":
                for ex in (-1, 1):
                    ear = [(cx + ex * 6 * k, hy - 11 * k), (cx + ex * 15 * k, hy - 26 * k), (cx + ex * 17 * k, hy - 8 * k)]
                    c.fill(ear, dark); c.ink_poly(ear, width=1.6)
            else:
                for ex in (-1, 1):
                    c.ellipse_fill((cx + ex * 14 * k - 5 * k, hy - 16 * k, cx + ex * 14 * k + 5 * k, hy - 7 * k), dark)
        else:
            hy = by - 18 * k
            head = c.blob(cx, hy, 14 * k, 11 * k, n=14, irregular=0.05)
            c.fill(head, dark, tex=0.35, cell=4)
            c.ink_poly(head, width=2.0)
            if kind == "wolf":
                for ex in (-1, 1):
                    ear = [(cx + ex * 5 * k, hy - 8 * k), (cx + ex * 12 * k, hy - 22 * k), (cx + ex * 14 * k, hy - 6 * k)]
                    c.fill(ear, dark); c.ink_poly(ear, width=1.6)
                c.fill(tail, fur, tex=0.4, cell=4); c.ink_poly(tail, width=1.8)
    rel = f"characters/animals/template_{kind}_{view}" + (f"_{frame}" if view == "side" else "") + ".png"
    c.save(out(rel), winter=False)
    aid = f"char.{kind}_{view}" + (f"_{frame}" if view == "side" else "")
    entry(aid, f"{kind.capitalize()} ({view}{', walk frame %d' % frame if view == 'side' else ''})", rel,
          (W // 2, H // 2), (W, H), (0.5, base / H),
          "Generated placeholder (tools/art/gen_world_awakens.py). Side art faces right (flipped for left).")


def flashlight_art():
    """Hand-held flashlight (shown in the hand while it is switched on) and the
    light cone texture (white = lit; replace to reshape the beam)."""
    W, H = 80, 40
    c = Canvas(W, H, seed=12501)
    body = [(8, 14), (52, 12), (54, 26), (8, 26)]
    c.fill(body, hexc("#3E4A4C"), tex=0.3); c.ink_poly(body, width=1.8)
    head = [(50, 8), (70, 6), (72, 32), (50, 30)]
    c.fill(head, hexc("#5A6467"), tex=0.3); c.ink_poly(head, width=1.8)
    c.fill([(68, 9), (72, 9), (72, 29), (68, 29)], hexc("#E6DDB8"))
    for x in (16, 24, 32):
        c.ink([(x, 14), (x, 26)], width=1.0, alpha=150)
    c.save(out("items/template_flashlight.png"), winter=False)
    entry("item.flashlight", "Flashlight (in the hand while switched on)", "items/template_flashlight.png", (40, 20), (W, H), (0.5, 0.5))
    n = 256
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    half = math.radians(24.0)
    for y in range(n):
        for x in range(n):
            dx, dy = x - n / 2, y - n / 2
            r = math.hypot(dx, dy) / (n / 2)
            a = 0.0
            if dx > 0 and r < 1.0:
                ang = abs(math.atan2(dy, dx))
                edge = 1.0 if ang < half * 0.55 else max(0.0, 1.0 - (ang - half * 0.55) / (half * 0.45))
                a = edge * (1.0 - r) ** 0.8 * min(1.0, r / 0.08)
            px[x, y] = (255, 255, 255, int(a * 255))
    p = out("fx/template_flashlight_cone.png")
    img.save(p, optimize=True)
    ENTRIES.append({"id": "fx.flashlight_cone", "name": "Flashlight / headlight beam (light texture; points right from the centre)",
                    "template": "res://assets/templates/fx/template_flashlight_cone.png", "display_size": [256, 256], "source_size": [256, 256],
                    "pivot": [0.5, 0.5], "transparency": "required", "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": "Generated (tools/art/gen_world_awakens.py). White where lit; the beam points to the right from the image centre."})


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_awakens.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "awakens", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("world awakens art generated:", len(ENTRIES))


if __name__ == "__main__":
    for i in range(16):
        wagon(i)
    for k in STORES:
        storefront(k)
    streetlamp(); town_sign(); roadblock()
    for kind in SPECIES:
        quadruped(kind, "side", 0); quadruped(kind, "side", 1); quadruped(kind, "down"); quadruped(kind, "up")
    flashlight_art()
    write_manifest()
