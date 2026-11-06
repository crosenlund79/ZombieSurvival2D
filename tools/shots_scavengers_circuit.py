#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 013 (The Scavenger's Circuit).
Needs a display (xvfb-run -a -s "-screen 0 1600x900x24"). Usage:
  shots_scavengers_circuit.py [interiors] [search] [dev] [stove]
Writes JPEGs to docs/screenshots/iteration_013 (or $SHOTS_OUT) and prints CHECK lines."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_013")
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


def session(name, cmd="single new 313 Tester"):
    s = Instance(name, headless=False); s.wipe(); s.start()
    s.cmd("window 1600 900"); s.cmd(cmd); s.cmd("tips off"); s.cmd("dev peaceful 1"); s.cmd("dev time 12"); s.cmd("dev weather clear")
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


if want("interiors"):
    s = session("s13_int")
    try:
        s.cmd("dev goto town"); s.cmd("wait 0.8")
        s.cmd("dev teleport 1112 920"); s.cmd("walk_to 1112 902 4"); s.cmd("zoom 1.0")
        check("the pharmacy entrance is offered on the street", (s.state().get("focused") or {}).get("id") == "town.pharmacy_entrance", s.state().get("focused"))
        shot(s, "01_street_shop_entrance", 0.4)
        s.cmd("press_interact"); s.cmd("wait 1.2")
        check("walking into the pharmacy", s.state()["region"] == "town.pharmacy", s.state()["region"])
        for n, (name, rid) in enumerate([("grocery", "town.grocery"), ("pharmacy", "town.pharmacy"), ("hardware", "town.hardware"),
                                         ("clothing", "town.clothing"), ("garage", "town.garage"), ("house_west", "town.house_west"),
                                         ("house_east", "town.house_east"), ("town_house_with_cellar", "town.house")]):
            s.cmd(f"dev goto {rid}"); s.cmd("wait 1.2"); s.cmd("zoom 0.85")
            check(f"{name} interior loads", s.state()["region"] == rid, s.state()["region"])
            shot(s, f"{n + 2:02d}_{name}", 0.5)
        s.cmd("dev goto town.grocery"); s.cmd("wait 1.0"); s.cmd("dev grant flashlight"); s.cmd("dev time 22"); s.cmd("wait 2.5")
        s.cmd("press_key flashlight"); s.cmd("walk_to 820 330 6"); s.cmd("face right"); s.cmd("zoom 0.85")
        shot(s, "10_grocery_backroom_at_night_flashlight", 1.0)
    finally:
        s.quit()

if want("search"):
    s = session("s13_search")
    try:
        s.cmd("dev goto town.hardware"); s.cmd("wait 1.2"); s.cmd("zoom 1.2")
        s.cmd("dev teleport 240 490"); s.cmd("wait 0.3"); s.cmd("interact town.hardware.aisle_lumber"); s.cmd("wait 2.4")
        st = s.state()["entities"]["town.hardware.aisle_lumber"]["state"]
        check("a search is in progress (progress bar)", st.get("by", "") != "" and not st.get("searched"), st)
        shot(s, "11_searching_progress", 0.0)
        s.cmd("wait 2.65")
        shot(s, "12_search_done_xp", 0.05)
        p, st = me(s)
        check("the search finished at level 1 in about 5 s", st["entities"]["town.hardware.aisle_lumber"]["state"].get("searched"), "")
        check("Scavenging XP earned", p["scav_xp"] > 0, p["scav_xp"])
        s.cmd("press_interact"); s.cmd("wait 0.6")
        shot(s, "13_container_contents_panel", 0.2)
        s.cmd("panel_close")
        for key, xy in (("aisle_fasteners", (220, 350)), ("aisle_tools", (510, 490))):
            s.cmd(f"dev teleport {xy[0]} {xy[1]}"); s.cmd(f"interact town.hardware.{key}"); s.cmd("wait 6.6")
        s.cmd("dev teleport 240 650"); s.cmd("wait 0.3")
        s.cmd("press_key skills"); s.cmd("wait 0.5")
        p, st = me(s)
        check("Scavenging level 2 after three searches", p["scav_level"] == 2, p["scav_level"])
        shot(s, "14_skills_screen", 0.3)
        s.cmd("press_key skills")
        s.cmd("dev teleport 1040 650"); s.cmd("interact town.hardware.aisle_bare"); s.cmd("wait 0.4")
    finally:
        s.quit()

if want("dev"):
    s = session("s13_dev")
    try:
        s.cmd("dev goto town.pharmacy"); s.cmd("wait 1"); s.cmd("dev xp_multiplier 5")
        s.cmd("ui dev_tab 2"); s.cmd("wait 0.6")
        check("the multiplier is active", s.state()["xp_multiplier"] == 5.0, s.state()["xp_multiplier"])
        shot(s, "15_dev_menu_progression_xp_multiplier", 0.3)
        s.cmd("ui dev_tab 0"); shot(s, "16_dev_menu_world", 0.3)
        s.cmd("ui dev off")
    finally:
        s.quit()

if want("stove"):
    s = session("s13_stove", "devworld Tester")
    try:
        s.cmd("dev goto town"); s.cmd("wait 0.6"); s.cmd("dev teleport 900 1010"); s.cmd("dev vehicle_here"); s.cmd("wait 0.4")
        for it in ("scrap_metal:3", "stovepipe:1", "cement:1", "canned_food:2"):
            s.cmd(f"dev grant {it}")
        s.cmd("vehicle wagon store stovepipe"); s.cmd("vehicle wagon store canned_food")
        s.cmd("dev teleport 1030 1080"); s.cmd("wait 0.3"); s.cmd("zoom 1.3")
        s.cmd("press_key repair"); s.cmd("wait 0.6")
        check("the trunk panel opens", s.state()["view"].get("panel") == "vehicle:wagon", s.state()["view"].get("panel"))
        shot(s, "17_trunk_cargo_panel", 0.2)
        s.cmd("panel_close"); s.cmd("vehicle wagon take_all")
        s.cmd("dev goto homestead"); s.cmd("wait 1"); down_cabin(s)
        s.cmd("walk_to 650 0 6"); s.cmd("entity_action storage store_all"); s.cmd("wait 0.3")
        s.cmd("walk_to 600 0 6"); s.cmd("build_ghost stove 520 701"); shot(s, "18_stove_build_preview_side_view", 0.4); s.cmd("build_cancel")
        s.cmd("build stove 520 701"); s.cmd("wait 7"); s.cmd("walk_to 640 0 6")
        st = s.state()
        check("the stove heats the shelter", st.get("heated") is True and st.get("warmth_rate", 0) >= 19, (st.get("heated"), st.get("warmth_rate")))
        shot(s, "19_stove_side_view", 0.5)
        s.cmd("press_key bunker_view"); s.cmd("wait 1.2"); shot(s, "20_stove_top_down", 0.4); s.cmd("press_key bunker_view")
    finally:
        s.quit()
