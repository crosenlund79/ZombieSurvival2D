#!/usr/bin/env python3
"""Iteration 015 C: the interface's dirty-ink material and iconography.

Surfaces (9-slice, used by UITheme as StyleBoxTexture): a weathered charcoal
panel with an inked, slightly uneven border; a paper panel; button states
(normal / hover / pressed / disabled); an inventory slot frame (empty / selected);
a tooltip card; a pointer for object-anchored panels; a key cap for prompts.

Icons (48 x 48, drawn like the item icons): health, water, food, warmth, noise,
quiet, eye, bag, rounds, light, shelter, clock, snowflake, fog, moon, sun, xp,
discovery, warning, info, lock, key, lockpick, coin/barter, wrench, mission,
faction friend / neutral / hostile, map, skills, craft, build, search.

Writes assets/templates/ui/... and assets/manifest/visual_ui_015.json (asset ids
"ui.*"). Replace any of them with assets/overrides/ui/<same path, no template_>.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPL = os.path.join(ROOT, "assets", "templates")
ENTRIES = []
CHAR, SOOT, STRAW, PAPER, RUST, MOSS, ICE = map(hexc, ["#1C1B1A", "#2A2925", "#CFB88D", "#E4D8BC", "#954C33", "#7A733F", "#9AB8C6"])
BLOOD, WATER, FOOD, WARM = hexc("#A43A2E"), hexc("#4F8FB0"), hexc("#C2953E"), hexc("#D9824A")


def save(c, rel, aid, label, W, H, notes="", pivot=(0.5, 0.5)):
    p = os.path.join(TPL, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    c.save(p, winter=False, finish=False)
    ENTRIES.append({"id": aid, "name": label, "template": "res://assets/templates/" + rel, "display_size": [W, H], "source_size": [W, H],
                    "pivot": list(pivot), "transparency": "required", "directions": "none", "complexity": "simple", "status": "READY",
                    "notes": notes or "Generated placeholder (tools/art/gen_ui.py) - replace with tablet art."})


def rough_rect(c, x0, y0, x1, y1, fill, border, width=2.4, tex=0.35, jitter=1.2):
    R = c.rng
    pts = []
    n = 14
    for k in range(n):
        pts.append((x0 + (x1 - x0) * k / n, y0 + R.uniform(-jitter, jitter)))
    for k in range(n):
        pts.append((x1 + R.uniform(-jitter, jitter), y0 + (y1 - y0) * k / n))
    for k in range(n):
        pts.append((x1 - (x1 - x0) * k / n, y1 + R.uniform(-jitter, jitter)))
    for k in range(n):
        pts.append((x0 + R.uniform(-jitter, jitter), y1 - (y1 - y0) * k / n))
    c.fill(pts, fill, tex=tex, cell=10, light=(-0.6, -1, 0.25))
    if border:
        c.ink(pts + [pts[0]], width=width, color=border, alpha=230, wobble=0.6)
    return pts


# ---------------------------------------------------------------- surfaces
def panel(name, fill, border, label, W=96, H=96, inner=True):
    c = Canvas(W, H, seed=4100 + len(name))
    rough_rect(c, 3, 3, W - 3, H - 3, fill, border)
    if inner:
        c.ink([(10, 9), (W - 10, 9)], width=1.0, color=mix(border, fill, 0.5), alpha=120)
        c.ink([(10, H - 9), (W - 10, H - 9)], width=1.0, color=mix(border, fill, 0.5), alpha=90)
    for k in range(10):  # grime specks
        x, y = c.rng.uniform(8, W - 8), c.rng.uniform(8, H - 8)
        c.ellipse_fill((x - 1, y - 1, x + 1.2, y + 1), (0, 0, 0, 60))
    save(c, f"ui/frames/template_{name}.png", "ui." + name, label, W, H, "9-slice: keep 20 px margins.")


def slot(name, border, label, W=72, H=72):
    c = Canvas(W, H, seed=4200 + len(name))
    rough_rect(c, 4, 4, W - 4, H - 4, mix(CHAR, SOOT, 0.6), border, width=2.0, jitter=0.8)
    c.ink([(9, H - 9), (W - 9, H - 9)], width=1.0, color=(0, 0, 0, 255), alpha=110)
    save(c, f"ui/frames/template_{name}.png", "ui." + name, label, W, H)


def pointer():
    W, H = 32, 24
    c = Canvas(W, H, seed=4301)
    pts = [(2, 2), (W - 2, 2), (W / 2, H - 2)]
    c.fill(pts, mix(CHAR, SOOT, 0.4), tex=0.3)
    c.ink([pts[1], pts[2], pts[0]], width=2.2, color=STRAW, alpha=200)
    save(c, "ui/frames/template_pointer.png", "ui.pointer", "Pointer under an object-anchored panel", W, H)


def keycap():
    W, H = 48, 48
    c = Canvas(W, H, seed=4302)
    rough_rect(c, 4, 4, W - 4, H - 6, mix(PAPER, STRAW, 0.4), CHAR, width=2.2, jitter=0.6)
    c.ink([(8, H - 8), (W - 8, H - 8)], width=3.0, color=mix(STRAW, CHAR, 0.5), alpha=200)
    save(c, "ui/frames/template_keycap.png", "ui.keycap", "Key cap behind a prompt key", W, H, "9-slice: 12 px margins.")


# ---------------------------------------------------------------- icons
def icon(name, label, draw):
    c = Canvas(48, 48, seed=4400 + len(name) * 3)
    draw(c)
    save(c, f"ui/icons/template_{name}.png", "ui.icon_" + name, label, 48, 48)


def P(c, pts, col, ink=1.8):
    c.fill(pts, col, tex=0.2, light=(-1, -1, 0.3))
    c.ink_poly(pts, width=ink)


def E(c, box, col, ink=1.6):
    c.ellipse_fill(box, col, light=(-1, -1, 0.3))
    x0, y0, x1, y1 = box
    c.ink([((x0 + x1) / 2 + (x1 - x0) / 2 * math.cos(t / 18 * math.tau), (y0 + y1) / 2 + (y1 - y0) / 2 * math.sin(t / 18 * math.tau)) for t in range(19)], width=ink)


def heart(c):
    pts = [(24, 41)] + [(24 + 15 * math.sin(t) ** 3, 22 - (12 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))) for t in [k / 24 * math.tau for k in range(1, 24)]]
    P(c, pts, BLOOD)


def drop(c):
    pts = [(24, 6)] + [(24 + 12 * math.cos(a), 30 + 12 * math.sin(a)) for a in [math.pi * (-0.15 + 1.3 * k / 16) for k in range(17)]]
    P(c, pts, WATER)


def bread(c):
    P(c, [(8, 34), (10, 20), (24, 14), (38, 20), (40, 34)], FOOD)
    for x in (18, 24, 30):
        c.ink([(x, 20), (x - 2, 28)], width=1.4, alpha=170)


def thermo(c):
    P(c, [(20, 6), (28, 6), (28, 30), (20, 30)], PAPER)
    E(c, (14, 26, 34, 44), WARM)
    P(c, [(22, 16), (26, 16), (26, 32), (22, 32)], WARM, ink=0.8)


def ear(c):
    P(c, [(16, 40), (12, 20), (22, 8), (34, 12), (36, 24), (28, 30), (26, 40)], mix(PAPER, STRAW, 0.4))
    for r in (8, 13):
        c.ink([(38 + r * math.cos(a), 24 + r * math.sin(a)) for a in [-0.8 + 1.6 * k / 8 for k in range(9)]], width=1.6, alpha=200)


def quiet(c):
    ear(c)
    c.ink([(8, 8), (40, 40)], width=3.0, color=RUST)


def eye(c):
    P(c, [(4, 24), (16, 12), (32, 12), (44, 24), (32, 36), (16, 36)], PAPER)
    E(c, (17, 17, 31, 31), mix(ICE, CHAR, 0.3))
    E(c, (21, 21, 27, 27), CHAR, ink=0.6)


def bag(c):
    P(c, [(12, 18), (36, 18), (40, 42), (8, 42)], mix(STRAW, MOSS, 0.4))
    c.ink([(18, 18), (18, 10), (30, 10), (30, 18)], width=2.4)
    P(c, [(16, 26), (32, 26), (32, 34), (16, 34)], mix(STRAW, CHAR, 0.3), ink=1.0)


def rounds(c):
    for x in (12, 21, 30):
        P(c, [(x, 20), (x + 7, 20), (x + 7, 42), (x, 42)], hexc("#B59A5A"), ink=1.2)
        P(c, [(x, 20), (x + 7, 20), (x + 3.5, 8)], hexc("#8A6A3A"), ink=1.2)


def light(c):
    P(c, [(8, 22), (26, 18), (26, 30), (8, 26)], mix(CHAR, SOOT, 0.4))
    P(c, [(26, 14), (34, 12), (34, 36), (26, 34)], STRAW)
    for a in (-0.4, 0.0, 0.4):
        c.ink([(36, 24), (36 + 10 * math.cos(a), 24 + 10 * math.sin(a))], width=1.6, color=hexc("#E8C27A"))


def shelter(c):
    P(c, [(8, 26), (24, 10), (40, 26), (40, 42), (8, 42)], mix(STRAW, CHAR, 0.3))
    P(c, [(18, 30), (30, 30), (30, 42), (18, 42)], CHAR, ink=1.0)
    for k in range(3):
        c.ink([(20, 33 + k * 3), (28, 33 + k * 3)], width=1.0, color=STRAW, alpha=200)


def clock(c):
    E(c, (6, 6, 42, 42), PAPER)
    c.ink([(24, 24), (24, 12)], width=2.4)
    c.ink([(24, 24), (32, 28)], width=2.0)


def snow(c):
    for a in range(6):
        t = a / 6 * math.tau
        c.ink([(24, 24), (24 + 17 * math.cos(t), 24 + 17 * math.sin(t))], width=2.2, color=ICE)
        c.ink([(24 + 10 * math.cos(t), 24 + 10 * math.sin(t)), (24 + 14 * math.cos(t + 0.4), 24 + 14 * math.sin(t + 0.4))], width=1.4, color=ICE)


def fog(c):
    for y in (14, 24, 34):
        c.ink([(6, y), (16, y - 3), (28, y + 2), (42, y - 2)], width=3.0, color=mix(ICE, PAPER, 0.5))


def moon(c):
    E(c, (8, 8, 40, 40), mix(PAPER, ICE, 0.3))
    c.ellipse_fill((18, 4, 46, 34), (0, 0, 0, 0))
    E(c, (20, 6, 44, 30), mix(CHAR, SOOT, 0.5), ink=0)


def sun(c):
    E(c, (14, 14, 34, 34), hexc("#E8C27A"))
    for a in range(8):
        t = a / 8 * math.tau
        c.ink([(24 + 14 * math.cos(t), 24 + 14 * math.sin(t)), (24 + 20 * math.cos(t), 24 + 20 * math.sin(t))], width=2.0, color=hexc("#E8C27A"))


def xp(c):
    P(c, [(24, 4), (29, 18), (44, 18), (32, 27), (37, 42), (24, 33), (11, 42), (16, 27), (4, 18), (19, 18)], hexc("#D9C38A"))


def discovery(c):
    E(c, (6, 6, 42, 42), PAPER)
    P(c, [(24, 9), (29, 24), (24, 39), (19, 24)], RUST, ink=1.0)


def warning(c):
    P(c, [(24, 5), (44, 41), (4, 41)], hexc("#D9A441"))
    c.ink([(24, 16), (24, 30)], width=3.4)
    c.ellipse_fill((22, 33, 26, 37), CHAR)


def info(c):
    E(c, (6, 6, 42, 42), mix(ICE, CHAR, 0.2))
    c.ink([(24, 21), (24, 36)], width=3.4, color=PAPER)
    c.ellipse_fill((22, 12, 26, 16), PAPER)


def lock(c):
    c.ink([(16, 22), (16, 14), (24, 8), (32, 14), (32, 22)], width=3.4)
    P(c, [(10, 22), (38, 22), (38, 42), (10, 42)], mix(STRAW, RUST, 0.3))
    c.ellipse_fill((22, 28, 26, 32), CHAR)


def key(c):
    E(c, (6, 16, 22, 32), hexc("#C9A86A"))
    P(c, [(20, 22), (42, 22), (42, 26), (20, 26)], hexc("#C9A86A"), ink=1.2)
    P(c, [(34, 26), (38, 26), (38, 32), (34, 32)], hexc("#C9A86A"), ink=1.0)


def lockpick(c):
    c.ink([(8, 40), (34, 14), (38, 10), (40, 14)], width=2.6, color=hexc("#9AA2A6"))
    c.ink([(10, 30), (30, 10)], width=1.8, color=hexc("#7A8083"))
    P(c, [(4, 40), (12, 36), (14, 44), (6, 46)], CHAR, ink=1.0)


def barter(c):
    for x, y in ((18, 30), (30, 30), (24, 20)):
        E(c, (x - 9, y - 9, x + 9, y + 9), hexc("#C9A86A"))


def wrench(c):
    c.ink([(10, 38), (30, 18)], width=6.0, color=hexc("#7A8083"))
    E(c, (26, 6, 42, 22), hexc("#7A8083"))
    c.ellipse_fill((31, 9, 38, 16), (0, 0, 0, 0))


def mission(c):
    P(c, [(10, 6), (34, 6), (40, 12), (40, 42), (10, 42)], PAPER)
    for y in (16, 23, 30):
        c.ink([(16, y), (34, y)], width=1.4, alpha=160)
    c.ink([(16, 36), (22, 40), (34, 30)], width=2.4, color=RUST)


def faction(col):
    def f(c):
        P(c, [(10, 6), (38, 6), (38, 28), (24, 42), (10, 28)], col)
        c.ink([(16, 14), (32, 14)], width=1.6, color=PAPER, alpha=200)
    return f


def mapi(c):
    P(c, [(6, 10), (18, 6), (30, 10), (42, 6), (42, 38), (30, 42), (18, 38), (6, 42)], PAPER)
    c.ink([(12, 30), (22, 20), (34, 26)], width=1.6, color=RUST)


def skills(c):
    for k, h in enumerate((14, 22, 32)):
        P(c, [(8 + k * 12, 42 - h), (16 + k * 12, 42 - h), (16 + k * 12, 42), (8 + k * 12, 42)], mix(STRAW, MOSS, 0.3), ink=1.2)


def craft(c):
    P(c, [(6, 30), (42, 30), (42, 38), (6, 38)], mix(STRAW, CHAR, 0.4))
    c.ink([(14, 30), (30, 10)], width=4, color=hexc("#7A8083"))
    P(c, [(26, 6), (38, 6), (38, 14), (26, 14)], hexc("#5E6467"))


def build(c):
    P(c, [(6, 40), (42, 40), (42, 44), (6, 44)], CHAR)
    for k in range(3):
        P(c, [(10 + k * 10, 40 - 10 * (k + 1)), (18 + k * 10, 40 - 10 * (k + 1)), (18 + k * 10, 40), (10 + k * 10, 40)], mix(STRAW, RUST, 0.2), ink=1.0)


def search(c):
    E(c, (6, 6, 30, 30), mix(ICE, PAPER, 0.4))
    c.ink([(26, 26), (42, 42)], width=5.0)


ICONS = [("health", "Health", heart), ("water", "Water", drop), ("food", "Food", bread), ("warmth", "Warmth", thermo),
         ("noise", "Noise", ear), ("quiet", "Quiet", quiet), ("eye", "Seen", eye), ("bag", "Bag / carrying", bag),
         ("rounds", "Rounds", rounds), ("light", "Light", light), ("shelter", "Shelter", shelter), ("clock", "Clock", clock),
         ("snow", "Snow", snow), ("fog", "Fog", fog), ("moon", "Night", moon), ("sun", "Day", sun), ("xp", "Experience", xp),
         ("discovery", "Discovery", discovery), ("warning", "Warning", warning), ("info", "Information", info),
         ("lock", "Locked", lock), ("key", "Key", key), ("lockpick", "Lockpick", lockpick), ("barter", "Trade", barter),
         ("wrench", "Repair", wrench), ("mission", "Mission", mission), ("faction_friend", "Friendly faction", faction(MOSS)),
         ("faction_neutral", "Neutral faction", faction(hexc("#8A7A52"))), ("faction_hostile", "Hostile faction", faction(BLOOD)),
         ("map", "Map", mapi), ("skills", "Skills", skills), ("craft", "Craft", craft), ("build", "Build", build), ("search", "Search", search)]


if __name__ == "__main__":
    panel("panel", mix(CHAR, SOOT, 0.55), mix(STRAW, CHAR, 0.35), "Weathered charcoal panel (9-slice)")
    panel("panel_paper", mix(PAPER, STRAW, 0.15), CHAR, "Paper panel (9-slice)")
    panel("button", SOOT, mix(STRAW, CHAR, 0.55), "Button (9-slice)", 64, 40, inner=False)
    panel("button_hover", mix(SOOT, STRAW, 0.12), STRAW, "Button, hover (9-slice)", 64, 40, inner=False)
    panel("button_pressed", mix(RUST, CHAR, 0.25), STRAW, "Button, pressed (9-slice)", 64, 40, inner=False)
    panel("button_disabled", mix(CHAR, SOOT, 0.3), mix(STRAW, CHAR, 0.8), "Button, disabled (9-slice)", 64, 40, inner=False)
    panel("tooltip", mix(PAPER, STRAW, 0.2), CHAR, "Tooltip card (9-slice)", 64, 64, inner=False)
    slot("slot", mix(STRAW, CHAR, 0.6), "Inventory slot")
    slot("slot_selected", STRAW, "Inventory slot, selected")
    pointer()
    keycap()
    for n, l, f in ICONS:
        icon(n, l, f)
    with open(os.path.join(ROOT, "assets", "manifest", "visual_ui_015.json"), "w") as f:
        json.dump({"kind": "visual", "category": "ui_015", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("ui art:", len(ENTRIES))
