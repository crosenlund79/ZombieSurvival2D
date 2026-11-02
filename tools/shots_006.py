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
        s.cmd("single new 61 Builder"); s.cmd("dev peaceful 1"); s.cmd("tips off")
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


def craft():
    s = Instance("shots_006b", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 62 Crafter"); s.cmd("dev peaceful 1"); s.cmd("tips off")
        for g in ("wood:14", "scrap_metal:6", "cloth:4", "canned_food:2", "electrical_parts:2", "padded_jacket:1"):
            s.cmd(f"dev grant {g}")
        to_yard(s)
        s.cmd("walk_to 1300 860"); s.cmd("build workbench 1260 820"); s.cmd("wait 4.5")
        bench = [k for k, v in s.state()["objects"]["homestead"].items() if v["def"] == "workbench"][0]
        s.cmd(f"obj {bench} craft hatchet"); s.cmd("wait 6.5"); s.cmd(f"obj {bench} collect")
        s.cmd(f"obj {bench} craft bandage")
        s.cmd("dev hunger 30")
        s.cmd("zoom 1.1")
        s.cmd("interact_bench") if False else None
        s.cmd("walk_to 1262 862")
        s.cmd("press_interact")
        shot(s, "i1_workbench_crafting", 0.6)
        s.cmd("panel_close")
        s.cmd("panel inventory on")
        shot(s, "i2_inventory_and_needs", 0.5)
        s.cmd("panel inventory off")
        s.cmd("panel guide on")
        shot(s, "i3_survival_guide", 0.5)
        s.cmd("panel guide off")
    finally:
        s.quit()


def world():
    s = Instance("shots_006c", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 63 Wanderer"); s.cmd("dev peaceful 1"); s.cmd("tips off")
        s.cmd("teleport_to 2300 1400") if False else None
        s.cmd("dev teleport 2300 1400"); s.cmd("walk_to 2350 1400 8"); s.cmd("press_interact")
        s.cmd("walk_to 900 700"); s.cmd("zoom 0.6")
        shot(s, "j1_service_station", 1.0)
        s.cmd("ui map on"); shot(s, "j2_world_map_two_regions", 0.6); s.cmd("ui map off")
        s.cmd("walk_to 1700 700"); s.cmd("walk_to 2000 580 8"); s.cmd("zoom 0.9")
        s.cmd("press_interact")
        shot(s, "j3_workshop_discovery", 0.6)
        s.cmd("dev weather rain"); s.cmd("dev time 21.5"); s.cmd("walk_to 1500 700")
        s.cmd("zoom 0.7")
        shot(s, "j4_night_rain_station", 2.5)
        s.cmd("dev weather clear"); s.cmd("dev time 10")
        s.cmd("walk_to 90 710 8"); s.cmd("press_interact")
        s.cmd("dev grant wood:12"); s.cmd("dev grant scrap_metal:4")
        to_yard(s)
        s.cmd("walk_to 1360 760"); s.cmd("build rain_collector 1400 700"); s.cmd("build crate 1300 840"); s.cmd("wait 3.5")
        s.cmd("walk_to 1150 760"); s.cmd("walk_to 1160 690"); s.cmd("press_interact") if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"] else None
        s.cmd("dev peaceful 0"); s.cmd("dev siege 3"); s.cmd("wait 1.0")
        shot(s, "j5_horde_warning", 0.3)
        s.cmd("wait 25")
        s.cmd("zoom 0.6")
        shot(s, "j6_horde_at_homestead", 0.3)
    finally:
        s.quit()


def survivor():
    s = Instance("shots_006d", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("devworld Tester"); s.cmd("dev peaceful 1"); s.cmd("tips off")
        s.cmd("walk_to 1160 760"); s.cmd("walk_to 1160 690"); s.cmd("interact homestead.farmhouse_door") if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"] else None
        s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry")
        s.cmd("walk_to 300 452 4"); s.cmd("interact homestead.farmhouse.hatch_ladder")
        s.cmd("walk_to 500 520"); s.cmd("zoom 0.8"); s.cmd("wait 6")
        shot(s, "k1_dev_world_bunker_survivor", 0.5)
        s.cmd("panel settlement on"); shot(s, "k2_settlement_overview", 0.5); s.cmd("panel settlement off")
        s.cmd("npc mara assign farm"); s.cmd("wait 8")
        s.cmd("zoom 1.0")
        shot(s, "k3_survivor_farming", 0.5)
    finally:
        s.quit()


def duo():
    h = Instance("shots_006h", headless=False); c = Instance("shots_006g", headless=False)
    for i in (h, c):
        i.wipe()
    try:
        h.start(); c.start()
        for i in (h, c):
            i.cmd("window 1100 650")
        h.cmd("host 47912 new 71 Hosty"); h.cmd("tips off"); h.cmd("dev peaceful 1")
        c.cmd("join 127.0.0.1 47912 Cleo"); c.cmd("tips off")
        h.cmd("dev grant wood:12")
        to_yard(h); to_yard(c)
        h.cmd("walk_to 960 760"); h.cmd("walk_to 960 600")
        h.cmd("build barricade 934 480"); h.cmd("build barricade 998 480")
        c.cmd("walk_to 1150 960"); c.cmd("walk_to 1150 1400"); c.cmd("walk_to 2340 1400 10"); c.cmd("interact homestead.road_east")
        c.cmd("walk_to 900 700")
        h.cmd("zoom 0.8"); c.cmd("zoom 0.7"); h.cmd("wait 3")
        shot(h, "l1_mp_host_fortifying_home", 0.5)
        shot(c, "l2_mp_client_at_service_station", 0.3)
    finally:
        for i in (h, c):
            i.quit()


if not only or "survivor" in only:
    survivor()
if not only or "duo" in only:
    duo()
if not only or "world" in only:
    world()
if not only or "craft" in only:
    craft()
if not only or "build" in only:
    build()
