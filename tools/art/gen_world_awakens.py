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


def write_manifest():
    path = os.path.join(ROOT, "assets", "manifest", "visual_awakens.json")
    with open(path, "w") as f:
        json.dump({"kind": "visual", "category": "awakens", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("world awakens art generated:", len(ENTRIES))


if __name__ == "__main__":
    for i in range(16):
        wagon(i)
    write_manifest()
