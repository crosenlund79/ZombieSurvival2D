#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 012 (Shadows & Depth).
Needs a display (xvfb-run -a -s "-screen 0 1700x1000x24"). Usage:
  shots_shadows_depth.py [silhouettes] [blood] [side] [cellar] [custom]
Writes JPEGs to docs/screenshots/iteration_012 (or $SHOTS_OUT) and prints CHECK lines."""
import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT, USER_DIR

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_012")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]
SITE = "homestead.farmhouse.shelter"


def check(name, ok, detail=""):
    print(("CHECK PASS " if ok else "CHECK FAIL ") + name + (f" — {detail}" if detail else ""), flush=True)


def shot(i, name, settle=0.8):
    i.cmd(f"wait {settle}")
    png = f"{OUT}/{name}.png"
    i.cmd(f"screenshot {png}")
    from PIL import Image
    Image.open(png).convert("RGB").save(png[:-4] + ".jpg", quality=88)
    os.remove(png)


def me(s):
    st = s.state()
    return next(p for p in st["players"] if p["id"] == st["local_player_id"]), st


def want(k):
    return not only or k in only


def session(name, cmd="single new 212 Tester"):
    s = Instance(name, headless=False); s.wipe(); s.start()
    s.cmd("window 1600 900"); s.cmd(cmd); s.cmd("tips off")
    return s


def down_cabin(s):
    s.cmd("walk_to 1150 960")
    if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
        s.cmd("interact homestead.yard_gate")
    s.cmd("walk_to 1150 760"); s.cmd("walk_to 1160 700")
    if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
        s.cmd("interact homestead.farmhouse_door")
    s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry"); s.cmd("wait 1")
    s.cmd("walk_to 300 470 6")
    if not s.state()["entities"][SITE]["state"].get("open", False):
        s.cmd("interact " + SITE)
    s.cmd("walk_to 300 452 4"); s.cmd("interact homestead.farmhouse.hatch_ladder"); s.cmd("wait 1.2")


if want("silhouettes"):
    s = session("s12_sil")
    try:
        s.cmd("dev time 13"); s.cmd("dev weather clear"); s.cmd("dev grant flashlight"); s.cmd("dev teleport 700 1250"); s.cmd("zoom 1.5")
        s.cmd("dev spawn_group"); shot(s, "01_silhouettes_daylight", 0.5)
        got = False
        for k in range(16):
            st = s.state()
            if any(z.get("posture") == 2 and z["hp"] > 0 for z in st["zombie_rows"]):
                got = True
                shot(s, "02_silhouette_crawling", 0.1)
                break
            s.cmd("wait 0.5")
        check("a crawling silhouette", got)
        s.cmd("dev peaceful 1"); s.cmd("dev peaceful 0"); s.cmd("dev heal")
        s.cmd("dev time 23"); s.cmd("wait 1.2"); s.cmd("press_key flashlight"); s.cmd("face right")
        s.cmd("dev spawn_group"); shot(s, "03_silhouettes_flashlight", 0.5)
        s.cmd("flash"); shot(s, "04_silhouettes_lightning", 0.0)
        s.cmd("dev peaceful 1"); s.cmd("dev peaceful 0"); s.cmd("dev heal")
        s.cmd("dev teleport 1900 1400"); s.cmd("dev vehicle_here"); s.cmd("vehicle wagon enter"); s.cmd("press_key vehicle_engine")
        s.cmd("dev spawn_zombie"); shot(s, "05_silhouette_headlights", 0.8)
        check("silhouette shots taken", True)
    finally:
        s.quit()

if want("blood"):
    s = session("s12_blood")
    try:
        s.cmd("dev time 12"); s.cmd("dev weather clear")
        s.cmd("dev teleport 1700 1400"); s.cmd("dev vehicle_here"); s.cmd("vehicle wagon enter"); s.cmd("press_key vehicle_engine")
        s.cmd("dev spawn_group"); s.cmd("zoom 1.4")
        for k in range(9):
            s.cmd("wait 5")
        p, st = me(s)
        check("Burnt Ones by a warm engine leave a few marks", st["blood_count"] > 0, st["blood_count"])
        shot(s, "06_blood_burnt_ones_at_a_warm_engine", 0.1)
        s.cmd("press_key vehicle_engine"); s.cmd("dev peaceful 1"); s.cmd("vehicle wagon exit"); s.cmd("wait 0.4")
        # the weather comparison: three fresh drops on open snow beside the player
        for x, y in ((1500, 1580), (1530, 1600), (1490, 1612)):
            s.cmd(f"dev teleport {x} {y}"); s.cmd("dev blood")
        s.cmd("dev teleport 1480 1600"); s.cmd("zoom 2.2")
        shot(s, "07_blood_clear_day", 0.6)
        s.cmd("dev weather fog"); shot(s, "08_blood_fog", 3.0)
        s.cmd("dev weather blizzard"); shot(s, "09_blood_blizzard", 3.0)
        s.cmd("dev weather snow"); s.cmd("dev advance_clock 150"); shot(s, "10_blood_buried_by_snow", 2.0)
        n0 = me(s)[1]["blood_count"]
        s.cmd("dev weather heavy_rain"); s.cmd("dev advance_clock 120"); s.cmd("wait 1")
        n1 = me(s)[1]["blood_count"]
        check("rain washes marks away", n1 < n0 or n0 == 0, (n0, n1))
        s.cmd("dev weather clear"); s.cmd("dev teleport 300 1300")
        p, st = me(s)
        s.cmd("dev time 12")
        before = st["blood_count"]
        for k in range(6):
            s.cmd("wait 5")
        check("no marks without warmth (quiet woods)", me(s)[1]["blood_count"] <= before, (before, me(s)[1]["blood_count"]))
    finally:
        s.quit()

if want("side"):
    s = session("s12_side", "devworld Tester")
    try:
        s.cmd("dev peaceful 1")
        down_cabin(s)
        p, st = me(s)
        check("entered the cabin bunker in the side view", st["region"].endswith(":-1") and st["view"].get("side") is True, st["view"].get("side"))
        shot(s, "11_side_cabin_bunker_level_1", 1.0)
        s.cmd("press_key bunker_view"); s.cmd("wait 1.2"); shot(s, "12_compare_top_down_same_bunker", 0.5)
        s.cmd("press_key bunker_view"); s.cmd("wait 1.2")
        s.cmd("walk_to 720 0 6"); s.cmd("build_ghost crate 600 701"); shot(s, "13_side_build_preview", 0.4)
        s.cmd("build_cancel"); s.cmd("build crate 600 701"); s.cmd("wait 2.5")
        s.cmd("walk_to 160 0 4"); s.cmd("terrain support 13 16"); s.cmd("wait 3.6")
        s.cmd("hold move_up 2.5"); shot(s, "14_side_climbing_new_scaffold", 0.2)
        s.cmd("hold move_left 1.0"); s.cmd("wait 0.6"); s.cmd("walk_to 30 0 6")
        p, st = me(s)
        check("climbed onto the raised chamber", p["y"] < 600, p["y"])
        shot(s, "15_side_raised_chamber_workbench", 0.4)
        s.cmd("press_interact"); shot(s, "16_side_workbench_panel", 0.6); s.cmd("panel_close")
        s.cmd("walk_to -110 0 6"); s.cmd("face left"); s.cmd("terrain dig 8 14"); shot(s, "17_side_digging", 0.9)
        s.cmd("wait 2.5")
        s.cmd("hold move_right 0.6"); s.cmd("wait 0.8"); s.cmd("walk_to 650 0 6"); s.cmd("press_interact"); shot(s, "18_side_storage_panel", 0.6); s.cmd("panel_close")
        s.cmd("dev create_level"); s.cmd("dev create_level")
        s.cmd("walk_to 820 0 6"); s.cmd("interact ladder_down"); s.cmd("wait 1.5"); shot(s, "19_side_level_2", 0.6)
        s.cmd("walk_to 760 0 6"); s.cmd("interact ladder_down"); s.cmd("wait 1.5")
        p, st = me(s)
        check("three underground levels reached", st["region"].endswith(":-3"), st["region"])
        shot(s, "20_side_level_3", 0.6)
        s.cmd("hold move_up 1.5"); shot(s, "21_side_ladder_transition", 0.1)
        for k in range(3):
            s.cmd("walk_to 520 0 6"); s.cmd("interact ladder_up"); s.cmd("wait 1.4")
        p, st = me(s)
        check("back up to the cabin (top-down)", st["region"] == "homestead.farmhouse", st["region"])
        shot(s, "22_back_in_the_cabin_top_down", 0.6)
    finally:
        s.quit()

if want("cellar"):
    s = session("s12_cellar")
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev goto town"); s.cmd("dev grant wood:8")
        s.cmd("dev teleport 1240 1500"); s.cmd("press_interact"); s.cmd("wait 0.3"); s.cmd("press_interact"); s.cmd("wait 1.2")
        s.cmd("dev teleport 300 470"); s.cmd("press_interact"); s.cmd("wait 0.5"); s.cmd("press_interact"); s.cmd("wait 1.5")
        p, st = me(s)
        check("the Ashgrove cellar in the side view", st["region"].startswith("bunker:town.house.cellar") and st["view"].get("side") is True, st["region"])
        s.cmd("walk_to 300 0 6"); s.cmd("build crate 360 613"); s.cmd("wait 2.5")
        shot(s, "23_side_ashgrove_cellar", 0.6)
        s.cmd("press_key bunker_view"); s.cmd("wait 1.2"); shot(s, "24_compare_top_down_ashgrove_cellar", 0.5)
        s.cmd("press_key bunker_view")
    finally:
        s.quit()

if want("custom"):
    dst = os.path.join(USER_DIR, "overrides", "characters", "player", "survivor_down.png")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy(os.path.join(ROOT, "tests", "fixtures", "overrides", "characters", "player", "survivor_down.png"), dst)
    s = session("s12_custom")
    try:
        s.cmd("dev peaceful 1"); s.cmd("zoom 2.0"); shot(s, "25_custom_graphics_on", 0.6)
        s.cmd("custom_graphics off"); s.cmd("rebuild_view"); s.cmd("zoom 2.0"); shot(s, "26_custom_graphics_off", 0.6)
        check("custom graphics switch still works", s.state()["asset_sources"].get("char.player") == "template")
        s.cmd("custom_graphics on")
    finally:
        s.quit()
        os.remove(dst)
