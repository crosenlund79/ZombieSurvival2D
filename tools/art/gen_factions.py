#!/usr/bin/env python3
"""Iteration 015 F: faction people and places.

People (same canvas, base line and pivot as the survivor figure, 104x168, so
overrides and sprite maths match): a Cinder raider (soot-dark coat, red rag
mask), a Hearth guard (olive parka), a Hearth villager (brown wool), the trader
(green coat), the mechanic (rust overalls), the elder (grey coat) and the Lantern
keeper (blue-grey). Each in three views (down / up / side), drawn by
gen_figures' survivor with a different palette — clearly people, never Burnt Ones.

Places: corrugated fence panels (horizontal + vertical run), the corrugated gate
(closed / open), a watchtower, a camp tent, a campfire, a barricade, a trade
stall, an outdoor workbench and a radio shack.

Templates under assets/templates/characters/factions/ and assets/templates/env/factions/,
manifest assets/manifest/visual_factions.json. Every picture can be replaced with
assets/overrides/<same path without template_>.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from inkkit import Canvas, hexc, mix  # noqa: E402
import gen_figures as F  # noqa: E402
from gen_winter import pf, drift, snow_band, SNOW, TIMBER_D, TIMBER, TIMBER_M, TIMBER_L, RUST_D, RUST, STEEL_D, STEEL, ASH, CHAR  # noqa: E402
from gen_homestead import out, ROOT  # noqa: E402

ENTRIES = []


def entry(aid, name, rel, display, source, pivot):
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/" + rel, "display_size": list(display),
                    "source_size": list(source), "pivot": [round(pivot[0], 4), round(pivot[1], 4)],
                    "transparency": "required", "directions": "none", "complexity": "moderate", "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_factions.py) - replace with tablet art."})


PALETTES = {
    "raider":   dict(JACKET=("#2E2A28", "#1E1B1A", "#4A4542"), TROUSER=("#2A2826", "#1B1A19"), PACK=("#4A3B2A", "#2F261B"),
                     SCARF=("#7A2A22", "#561C16"), HAIR="#1E1812", BEARD="#2A2018", CAP="#2B2826"),
    "guard":    dict(JACKET=("#5E6440", "#40452B", "#7E845C"), TROUSER=("#3C3A30", "#29271F"), PACK=("#6A5E40", "#4A412C"),
                     SCARF=("#8A7A52", "#635738"), HAIR="#3A2A1D", BEARD="#4A3426", CAP="#4C5232"),
    "villager": dict(JACKET=("#6E5440", "#4C3A2C", "#8E7460"), TROUSER=("#3E3B37", "#2A2725"), PACK=("#76644A", "#504330"),
                     SCARF=("#8A3E30", "#5E2A20"), HAIR="#5A3A24", BEARD="#5A3E2A", CAP="#6A5A48"),
    "trader":   dict(JACKET=("#3E5A44", "#2A3E2E", "#5E7A64"), TROUSER=("#3A3632", "#262320"), PACK=("#8A6A3A", "#5E4826"),
                     SCARF=("#C09A4A", "#8A6E34"), HAIR="#2E2218", BEARD="#3A2A1E", CAP="#5A4A30"),
    "mechanic": dict(JACKET=("#7A4A2E", "#56331F", "#9A6A4E"), TROUSER=("#5A3A26", "#3E2818"), PACK=("#5A5248", "#3E3830"),
                     SCARF=("#4A4A48", "#333331"), HAIR="#2A2018", BEARD="#3A2A1E", CAP="#3A3A38"),
    "elder":    dict(JACKET=("#6A6862", "#4A4844", "#8A8882"), TROUSER=("#3E3B37", "#2A2725"), PACK=("#6A5E4A", "#4A4232"),
                     SCARF=("#5A4A6A", "#3E3348"), HAIR="#B8B2A8", BEARD="#C8C2B8", CAP="#4E4A44"),
    "contact":  dict(JACKET=("#4A5A6A", "#33404C", "#6A7A8A"), TROUSER=("#33373B", "#232629"), PACK=("#5E5A4A", "#423F33"),
                     SCARF=("#C8A040", "#8E7230"), HAIR="#3A2A1D", BEARD="#4A3426", CAP="#3A4652"),
}
LABELS = {"raider": "Cinder Crew raider", "guard": "Hearth Gate guard", "villager": "Hearth Gate villager", "trader": "Hearth Gate trader",
          "mechanic": "Hearth Gate mechanic", "elder": "Hearth Gate elder", "contact": "Lantern Circle keeper"}


def _apply(pal):
    for k, v in pal.items():
        if isinstance(v, tuple):
            cols = [hexc(x) for x in v]
            setattr(F, k, cols[0]); setattr(F, k + "_D", cols[1])
            if len(cols) > 2:
                setattr(F, k + "_L", cols[2])
        else:
            setattr(F, k, hexc(v))


def figure(role):
    saved = {k: getattr(F, k) for k in ("JACKET", "JACKET_D", "JACKET_L", "TROUSER", "TROUSER_D", "PACK", "PACK_D", "SCARF", "SCARF_D", "HAIR", "BEARD", "CAP")}
    _apply(PALETTES[role])
    W, H, base = 104, 168, 160
    for view in ("down", "up", "side"):
        c = Canvas(W, H, seed=5100 + list(PALETTES).index(role) * 7 + ["down", "up", "side"].index(view))
        c.soft_shadow((22, base - 9, 82, base + 6), alpha=130, blur=4)
        if view == "side":
            F._survivor_side(c, base)
        else:
            F._survivor_front(c, base, view == "down")
        if role in ("raider", "guard"):  # a long gun on the shoulder strap
            if view == "side":
                c.ink([(36, 40), (70, 108)], width=4.2, color=hexc("#1E1C1A"))
                c.ink([(64, 96), (72, 112)], width=6.5, color=hexc("#4A3424"))
            else:
                c.ink([(30, 44), (74, 104)], width=4.0, color=hexc("#1E1C1A"), alpha=235)
        if role == "raider" and view == "down":  # rag mask over the lower face
            c.fill([(41, 27), (63, 27), (61, 39), (52, 42), (43, 39)], hexc("#7A2A22"), tex=0.3)
            c.ink_poly([(41, 27), (63, 27), (61, 39), (52, 42), (43, 39)], width=1.2, alpha=200)
        rel = f"characters/factions/template_{role}_{view}.png"
        c.save(out(rel), size=(W, H))
        aid = f"char.{role}" if view == "down" else f"char.{role}_{view}"
        entry(aid, f"{LABELS[role]} — {view}", rel, (52, 84), (W, H), (0.5, base / H))
    for k, v in saved.items():
        setattr(F, k, v)


def save(c, rel, aid, label, W, H, base, full=False):
    c.save(out(rel), winter=False)
    entry(aid, label, rel, (W, H) if full else (W // 2, H // 2), (W, H), (0.5, base / H))


def corrugated(c, x0, y0, x1, y1, col, ribs=14, vertical_ribs=True):
    m = pf(c, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, tex=0.45, ink=2.0, shade=(1, 0, 3.5, 70))
    n = ribs
    for k in range(1, n):
        if vertical_ribs:
            x = x0 + (x1 - x0) * k / n
            c.ink([(x, y0 + 2), (x, y1 - 2)], width=1.4, color=mix(col, hexc("#000000"), 0.35), alpha=170)
        else:
            y = y0 + (y1 - y0) * k / n
            c.ink([(x0 + 2, y), (x1 - 2, y)], width=1.4, color=mix(col, hexc("#000000"), 0.35), alpha=170)
    c.grime(m, 0.5, drips=True, color=RUST_D)


def fence_h():
    W, H = 320, 170
    c = Canvas(W, H, seed=5301)
    base = H - 12
    corrugated(c, 6, base - 120, W - 6, base - 6, mix(STEEL, RUST, 0.35), ribs=20)
    for x in (14, W - 14):
        pf(c, [(x - 7, base - 134), (x + 7, base - 134), (x + 7, base), (x - 7, base)], TIMBER_D, tex=0.35, ink=1.6)
    snow_band(c, [(6, base - 122), (W - 6, base - 122)], 7)
    drift(c, W / 2, base + 2, W * 0.5, 9)
    save(c, "env/factions/template_fence_corrugated.png", "env.fence_corrugated", "Corrugated fence panel", W, H, base, full=True)


def fence_v():
    W, H = 70, 380
    c = Canvas(W, H, seed=5302)
    base = H - 10
    corrugated(c, 22, 40, 48, base - 4, mix(STEEL, RUST, 0.4), ribs=12, vertical_ribs=False)
    pf(c, [(18, 30), (52, 30), (52, base - 110), (18, base - 110)], mix(STEEL_D, RUST, 0.3), tex=0.4, ink=1.6, alpha=110)
    for y in (46, base - 12):
        pf(c, [(14, y - 6), (56, y - 6), (56, y + 6), (14, y + 6)], TIMBER_D, tex=0.35, ink=1.4)
    drift(c, W / 2, base + 2, 30, 7)
    save(c, "env/factions/template_fence_corrugated_v.png", "env.fence_corrugated_v", "Corrugated fence (running north-south)", W, H, base, full=True)


def gate(open_):
    W, H = 340, 200
    c = Canvas(W, H, seed=5303 + open_)
    base = H - 12
    for x in (12, W - 12):
        pf(c, [(x - 9, base - 170), (x + 9, base - 170), (x + 9, base), (x - 9, base)], TIMBER_D, tex=0.35, ink=1.8)
    if open_:
        for sx, x0 in ((-1, 22), (1, W - 22)):
            dx = 46 if sx < 0 else -46   # the two leaves swung back against the posts
            pts = [(x0, base - 140), (x0 + dx, base - 150), (x0 + dx, base - 10), (x0, base - 4)]
            pf(c, pts, mix(STEEL, RUST, 0.3), tex=0.4, ink=1.8)
    else:
        corrugated(c, 22, base - 140, W / 2 - 2, base - 6, mix(STEEL, RUST, 0.25), ribs=10)
        corrugated(c, W / 2 + 2, base - 140, W - 22, base - 6, mix(STEEL, RUST, 0.32), ribs=10)
        c.ink([(30, base - 110), (W - 30, base - 30)], width=5, color=TIMBER)   # a brace
        c.ink([(W / 2 - 10, base - 76), (W / 2 + 10, base - 76)], width=5, color=STEEL_D)  # bar
    snow_band(c, [(4, base - 172), (24, base - 172)], 5)
    snow_band(c, [(W - 24, base - 172), (W - 4, base - 172)], 5)
    drift(c, W / 2, base + 2, W * 0.5, 8)
    st = "open" if open_ else "closed"
    save(c, f"env/factions/template_gate_corrugated_{st}.png", f"env.gate_corrugated_{st}", f"Corrugated gate ({st})", W, H, base, full=True)


def watchtower():
    W, H = 220, 420
    c = Canvas(W, H, seed=5305)
    base = H - 12
    for x0, x1 in ((40, 70), (180, 150)):
        c.ink([(x0, base), (x1, 150)], width=9, color=TIMBER_D)
    c.ink([(60, base - 60), (160, 180)], width=5, color=TIMBER)
    c.ink([(160, base - 60), (60, 180)], width=5, color=TIMBER)
    pf(c, [(50, 120), (170, 120), (170, 160), (50, 160)], TIMBER_M, tex=0.4, ink=2.0)   # platform walls
    corrugated(c, 40, 70, 180, 98, mix(STEEL, RUST, 0.35), ribs=9)                       # roof
    for x in (54, 166):
        c.ink([(x, 98), (x, 122)], width=4, color=TIMBER_D)
    snow_band(c, [(38, 70), (182, 70)], 8)
    drift(c, W / 2, base + 2, 90, 9)
    save(c, "env/factions/template_watchtower.png", "env.watchtower", "Watchtower", W, H, base)


def tent():
    W, H = 280, 190
    c = Canvas(W, H, seed=5306)
    base = H - 12
    m = pf(c, [(20, base), (140, base - 140), (260, base)], hexc("#5A5446"), tex=0.5, ink=2.2, shade=(1, 0, 3.4, 90))
    pf(c, [(112, base), (140, base - 70), (168, base)], hexc("#1E1C18"), tex=0.2, ink=1.6)
    c.grime(m, 0.5, drips=True, color=hexc("#2A2620"))
    snow_band(c, [(80, base - 80), (140, base - 140), (200, base - 80)], 6)
    drift(c, W / 2, base + 2, 120, 8)
    save(c, "env/factions/template_camp_tent.png", "env.camp_tent", "Camp tent", W, H, base)


def campfire():
    W, H = 140, 120
    c = Canvas(W, H, seed=5307)
    base = H - 14
    for k in range(7):
        a = k / 7 * 6.283
        c.fill(c.blob(70 + 34 * math.cos(a), base - 14 + 10 * math.sin(a), 11, 8, n=10, irregular=0.2), ASH, tex=0.3)
    c.ink([(44, base - 8), (96, base - 22)], width=7, color=CHAR)
    c.ink([(48, base - 22), (94, base - 8)], width=7, color=TIMBER_D)
    c.fill(c.blob(70, base - 34, 18, 28, n=14, irregular=0.25), hexc("#E09A3A"), tex=0.2)
    c.fill(c.blob(70, base - 28, 9, 16, n=10, irregular=0.2), hexc("#F6D27A"), tex=0.1)
    save(c, "env/factions/template_campfire.png", "env.campfire", "Campfire", W, H, base)


def barricade():
    W, H = 300, 150
    c = Canvas(W, H, seed=5308)
    base = H - 12
    for k, x in enumerate((30, 110, 190)):
        pf(c, [(x, base - 70), (x + 90, base - 70), (x + 84, base), (x + 6, base)], mix(TIMBER, TIMBER_D, 0.3 * k), tex=0.45, ink=1.8)
    corrugated(c, 60, base - 110, 230, base - 64, mix(STEEL, RUST, 0.45), ribs=8)
    c.ink([(20, base - 40), (280, base - 96)], width=6, color=TIMBER_D)
    for x in range(40, 270, 34):
        c.ink([(x, base - 112), (x + 6, base - 124)], width=1.4, color=STEEL_D)  # wire
    drift(c, W / 2, base + 2, 130, 8)
    save(c, "env/factions/template_barricade.png", "env.barricade", "Barricade", W, H, base)


def trade_stall():
    W, H = 280, 230
    c = Canvas(W, H, seed=5309)
    base = H - 12
    pf(c, [(30, base - 70), (250, base - 70), (250, base), (30, base)], TIMBER_M, tex=0.45, ink=2.0)
    for x in (36, 244):
        c.ink([(x, base - 70), (x, base - 180)], width=6, color=TIMBER_D)
    pf(c, [(20, base - 200), (260, base - 200), (250, base - 168), (30, base - 168)], hexc("#7A3A2A"), tex=0.4, ink=2.0)
    for k, x in enumerate(range(50, 230, 36)):
        c.fill(c.blob(x, base - 84, 14, 11, n=10, irregular=0.2), [hexc("#8A7A5A"), hexc("#5A6A4A"), hexc("#9A5A3A")][k % 3], tex=0.3)
    snow_band(c, [(20, base - 200), (260, base - 200)], 7)
    drift(c, W / 2, base + 2, 120, 8)
    save(c, "env/factions/template_trade_stall.png", "env.trade_stall", "Trade stall", W, H, base)


def workbench():
    W, H = 220, 150
    c = Canvas(W, H, seed=5310)
    base = H - 12
    pf(c, [(20, base - 64), (200, base - 64), (200, base - 50), (20, base - 50)], TIMBER_D, tex=0.4, ink=1.8)
    for x in (30, 190):
        c.ink([(x, base - 50), (x, base)], width=6, color=TIMBER_D)
    c.ink([(60, base - 72), (100, base - 76)], width=4, color=STEEL_D)
    c.fill(c.blob(150, base - 76, 22, 10, n=10, irregular=0.2), RUST, tex=0.4)
    pf(c, [(80, base - 30), (140, base - 30), (140, base), (80, base)], mix(STEEL, RUST, 0.3), tex=0.4, ink=1.4)
    drift(c, W / 2, base + 2, 90, 7)
    save(c, "env/factions/template_workbench_out.png", "env.workbench_out", "Outdoor workbench", W, H, base)


def radio_shack():
    W, H = 420, 330
    c = Canvas(W, H, seed=5311)
    base = H - 12
    pf(c, [(50, base - 160), (370, base - 160), (370, base), (50, base)], mix(TIMBER_M, STEEL_D, 0.3), tex=0.45, ink=2.2)
    corrugated(c, 34, base - 220, 386, base - 160, mix(STEEL, RUST, 0.3), ribs=16)
    pf(c, [(250, base - 120), (300, base - 120), (300, base), (250, base)], TIMBER_D, tex=0.3, ink=1.8)
    pf(c, [(90, base - 120), (170, base - 120), (170, base - 70), (90, base - 70)], hexc("#E2C27A"), tex=0.15, ink=1.8)  # lit window
    c.ink([(340, base - 220), (340, base - 300)], width=3, color=STEEL_D)
    for y in (base - 290, base - 270):
        c.ink([(320, y), (360, y)], width=2, color=STEEL_D)
    snow_band(c, [(34, base - 220), (386, base - 220)], 9)
    drift(c, W / 2, base + 2, 190, 9)
    save(c, "env/factions/template_radio_shack.png", "env.radio_shack", "Radio shack", W, H, base)


if __name__ == "__main__":
    for role in PALETTES:
        figure(role)
    fence_h(); fence_v(); gate(False); gate(True); watchtower(); tent(); campfire(); barricade(); trade_stall(); workbench(); radio_shack()
    with open(os.path.join(ROOT, "assets", "manifest", "visual_factions.json"), "w") as f:
        json.dump({"kind": "visual", "category": "factions", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("faction art:", len(ENTRIES))
