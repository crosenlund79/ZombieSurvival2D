#!/usr/bin/env python3
"""Rendered screenshots for iterations 006-009 (needs a display, e.g. xvfb-run -a).
Usage: shots_006.py [build] [craft] [world] [survivor] [duo]. Writes JPEGs to docs/screenshots/iteration_006."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT
from mp_test import go_inside, to_west_trees, zs, wait_for, cell_xy
OUT = os.path.join(ROOT, "docs", "screenshots", "iteration_006")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


def shot(i, name, settle=0.8):
    i.cmd(f"wait {settle}")
    png = f"{OUT}/{name}.png"
    i.cmd(f"screenshot {png}")
    try:
        from PIL import Image
        Image.open(png).convert("RGB").save(png[:-4] + ".jpg", quality=88)
        os.remove(png)
    except Exception as e:
        print("jpeg conversion failed", e)


def to_yard(s):
    s.cmd("walk_to 1150 960")
    if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
        s.cmd("press_interact")
    s.cmd("walk_to 1150 760")


def build_shelter(s):
    go_inside(s)
    s.cmd("walk_to 300 492"); s.cmd("press_interact"); s.cmd("wait 8.5"); s.cmd("press_interact")
    s.cmd("walk_to 300 452 4"); s.cmd("press_interact")


def build():
    s = Instance("shots_006a", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 61 Builder"); s.cmd("dev peaceful 1")
        for g in ("wood:16", "scrap_metal:8", "cement:3", "spike_kit:2"):
            s.cmd(f"dev grant {g}")
        to_yard(s)
        s.cmd("walk_to 950 760"); s.cmd("walk_to 950 560")
        for x in (934, 998):
            s.cmd(f"build barricade {x} 480")
        s.cmd("wait 3.2")
        objs = s.state()["objects"]["homestead"]
        ids = sorted(objs, key=lambda k: objs[k]["x"])
        s.cmd(f"obj {ids[1]} upgrade")
        s.cmd("walk_to 950 700"); s.cmd("walk_to 1360 700"); s.cmd("walk_to 1360 600")
        s.cmd("build barricade 1350 490"); s.cmd("wait 3.2")
        objs = s.state()["objects"]["homestead"]
        ids = sorted(objs, key=lambda k: objs[k]["x"])
        s.cmd(f"obj {ids[2]} upgrade"); s.cmd(f"obj {ids[2]} upgrade")
        s.cmd("walk_to 1360 760"); s.cmd("build spike_trap 1250 790")
        s.cmd("build rain_collector 1400 700"); s.cmd("build crate 1300 840")
        s.cmd("walk_to 950 700"); s.cmd("walk_to 950 400"); s.cmd("walk_to 1150 400")
        s.cmd("build spike_trap 1060 470")
        s.cmd("wait 4.5")
        s.cmd("dev damage_structures 70")
        s.cmd("zoom 0.7")
        s.cmd("build_ghost barricade 1420 470")
        shot(s, "h1_yard_fortifications_preview", 0.6)
        s.cmd("build_ghost barricade 1150 900")
        shot(s, "h2_preview_refused_at_gate", 0.4)
        s.cmd("build_cancel")
        s.cmd("build_menu"); shot(s, "h3_build_menu", 0.4); s.cmd("build_menu off")
        s.cmd("walk_to 1440 440"); s.cmd("walk_to 1440 760")
        build_shelter(s)
        s.cmd("walk_to 650 345 6")
        s.cmd("dev grant wood:12")
        for item in ("wood", "scrap_metal", "cement"):
            s.cmd(f"entity_action storage store {item}")
        x, y = cell_xy(16, 14); s.cmd(f"walk_to {x} {y + 80} 8"); s.cmd(f"build barricade {x} {y}")
        x2, y2 = cell_xy(18, 15); s.cmd(f"build crate {x2} {y2}")
        s.cmd("wait 3.5")
        s.cmd("zoom 0.8")
        shot(s, "h4_bunker_construction", 0.6)
    finally:
        s.quit()


if not only or "build" in only:
    build()
