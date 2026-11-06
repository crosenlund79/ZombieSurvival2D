#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 014 (The Five Settlements).
Needs a display (xvfb-run -a -s "-screen 0 1600x900x24"). Usage:
  shots_five_settlements.py [interiors] [build] [towns] [landmarks] [hideout] [items]
Writes JPEGs to docs/screenshots/iteration_014 (or $SHOTS_OUT) and prints CHECK lines."""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_014")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


def check(name, ok, detail=""):
    print(("CHECK PASS " if ok else "CHECK FAIL ") + name + (f" — {detail}" if detail else ""), flush=True)


def shot(i, name, settle=0.8):
    i.cmd(f"wait {settle}")
    png = f"{OUT}/{name}.png"
    i.cmd(f"screenshot {png}")
    from PIL import Image
    Image.open(png).convert("RGB").save(png[:-4] + ".jpg", quality=86)
    os.remove(png)


def me(s):
    st = s.state()
    return next(p for p in st["players"] if p["id"] == st["local_player_id"]), st


def want(k):
    return not only or k in only


def session(name, seed, peaceful=True, hour=12):
    s = Instance(name, headless=False); s.wipe(); s.start()
    s.cmd("window 1600 900"); s.cmd(f"single new {seed} Tester"); s.cmd("tips off")
    if peaceful:
        s.cmd("dev peaceful 1")
    s.cmd(f"dev time {hour}"); s.cmd("dev weather clear")
    return s


def entity(region_file, eid):
    d = json.load(open(os.path.join(ROOT, "content", "regions", region_file + ".json")))
    return next(e for e in d["entities"] if e["id"] == eid)


def hop(s, region_file, portal):
    e = entity(region_file, portal)
    s.cmd(f"dev teleport {e['position'][0]} {e['position'][1]}"); s.cmd("wait 0.3"); s.cmd(f"interact {portal}"); s.cmd("wait 1.5")
    return s.state()["region"]


def into_cabin(s):
    s.cmd("walk_to 1150 960")
    if not s.state()["entities"]["homestead.yard_gate"]["state"]["open"]:
        s.cmd("interact homestead.yard_gate")
    s.cmd("walk_to 1150 760"); s.cmd("walk_to 1160 700")
    if not s.state()["entities"]["homestead.farmhouse_door"]["state"]["open"]:
        s.cmd("interact homestead.farmhouse_door")
    s.cmd("walk_to 1160 664 4"); s.cmd("interact homestead.farmhouse_entry"); s.cmd("wait 1.5")


if want("interiors"):
    s = session("s14_int", 314)
    try:
        into_cabin(s)
        p, st = me(s)
        check("the cabin is a side-view interior", st["region"] == "homestead.farmhouse" and st["view"].get("side") is True, st["region"])
        shot(s, "01_cabin_side_view")
        for n, rid in enumerate(("town.house_west", "town.grocery", "town.garage", "stillwater.apartments", "harbor.cottage")):
            s.cmd(f"dev goto {rid}"); s.cmd("wait 1.4"); s.cmd("zoom 0.8")
            check(f"{rid} loads in the side view", s.state()["region"] == rid and s.state()["view"].get("side") is True, s.state()["region"])
            shot(s, f"{n + 2:02d}_interior_{rid.replace('.', '_')}", 0.5)
        s.cmd("dev goto town.house_west"); s.cmd("wait 1.2"); s.cmd("zoom 0.9")
        stairs = next(e for e in json.load(open(os.path.join(ROOT, "content", "regions", "town_house_west.json")))["entities"] if e["type"] == "stairs")
        s.cmd(f"walk_to {stairs['position'][0]} 0 6"); s.cmd("hold move_up 2.5"); s.cmd("hold move_left 1.0")
        p, st = me(s)
        check("the stairs lead to the upper floor", abs(p["y"] - stairs["top"]) < 6, (p["y"], stairs["top"]))
        shot(s, "07_upstairs", 0.5)
    finally:
        s.quit()

if want("build"):
    s = Instance("s14_build", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900"); s.cmd("devworld Tester"); s.cmd("tips off"); s.cmd("dev peaceful 1"); s.cmd("dev time 12")
        s.cmd("dev grant wood:12"); s.cmd("dev grant scrap_metal:4")
        s.cmd("dev goto homestead"); s.cmd("wait 1")
        into_cabin(s)
        s.cmd("walk_to 832 0 6")
        if not s.state()["entities"]["homestead.farmhouse.shelter"]["state"].get("open", False):
            s.cmd("interact homestead.farmhouse.shelter")
        s.cmd("interact homestead.farmhouse.hatch_ladder"); s.cmd("wait 1.5")
        s.cmd("walk_to 520 0 6"); s.cmd("build workbench 600 701"); s.cmd("wait 1.4")
        shot(s, "08_progress_bar_side_view", 0.1)
        s.cmd("wait 4")
        s.cmd("dev goto homestead"); s.cmd("wait 1"); s.cmd("dev teleport 1300 870"); s.cmd("wait 0.3")
        s.cmd("build workbench 1260 820"); s.cmd("wait 1.4")
        shot(s, "09_progress_bar_top_down", 0.1)
    finally:
        s.quit()

if want("towns"):
    s = session("s14_towns", 315)
    try:
        s.cmd("dev goto town"); s.cmd("wait 1")
        check("Ashgrove opens east to the junction", hop(s, "town", "town.road_east") == "junction", s.state()["region"])
        s.cmd("zoom 0.6"); s.cmd("dev teleport 1000 1150"); shot(s, "10_corran_junction", 1.0)
        check("the junction leads north to Greyhollow", hop(s, "junction", "junction.road_north") == "greyhollow", s.state()["region"])
        s.cmd("zoom 0.6"); s.cmd("dev teleport 1700 1000"); shot(s, "11_greyhollow_mining_town", 1.0)
        s.cmd("dev goto junction"); s.cmd("wait 1")
        check("and east to Stillwater", hop(s, "junction", "junction.road_east") == "stillwater", s.state()["region"])
        s.cmd("zoom 0.6"); s.cmd("dev teleport 1800 1300"); shot(s, "12_stillwater_town_centre", 1.0)
        check("Stillwater leads east to the harbour", hop(s, "stillwater", "stillwater.road_east") == "harbor", s.state()["region"])
        s.cmd("zoom 0.6"); s.cmd("dev teleport 1500 1300"); shot(s, "13_frozen_harbor", 1.0)
        s.cmd("dev teleport 2600 1600"); shot(s, "14_harbor_icebergs", 1.5)
        s.cmd("ui map on"); shot(s, "15_world_map_five_settlements", 0.6); s.cmd("ui map off")
    finally:
        s.quit()

if want("landmarks"):
    s = session("s14_land", 316, hour=21)
    try:
        s.cmd("dev goto stillwater.civic_hall"); s.cmd("wait 1.4"); s.cmd("zoom 0.55"); s.cmd("dev time 12")
        shot(s, "16_civic_hall_four_storeys", 1.0)
        s.cmd("dev time 21")
        s.cmd("dev goto greyhollow.mine"); s.cmd("wait 1"); s.cmd("dev grant flashlight"); s.cmd("press_key flashlight"); s.cmd("zoom 0.9")
        shot(s, "17_mine_entrance_gallery_dark", 0.8)
        s.cmd("walk_to 1952 0 4"); s.cmd("hold move_down 3.5"); s.cmd("wait 0.5"); s.cmd("hold move_right 1.0")
        p, st = me(s)
        check("the ladder shaft leads to the second level", p["y"] > 900, p["y"])
        shot(s, "18_mine_level_two_flashlight", 0.6)
    finally:
        s.quit()

if want("hideout"):
    s = session("s14_hide", 317, peaceful=False, hour=21)
    try:
        s.cmd("dev grant handgun"); s.cmd("dev grant ammo_pistol:16"); s.cmd("dev grant flashlight")
        s.cmd("equip_item handgun"); s.cmd("press_key reload"); s.cmd("wait 2")
        p, st = me(s)
        check("the handgun is loaded", p["loaded"] == 8, p["loaded"])
        s.cmd("dev goto stillwater.quiet_house"); s.cmd("wait 1.5"); s.cmd("press_key flashlight")
        s.cmd("dev noise"); s.cmd("wait 0.3"); s.cmd("dev noise"); s.cmd("wait 1.0")
        hide = s.state()["entities"]["stillwater.quiet_house.hideout"]["state"]
        check("noise wakes the hideout", hide.get("triggered") is True, hide)
        shot(s, "19_hideout_burnt_ones_emerge", 1.5)
        s.cmd("attack_nearest 2"); s.cmd("wait 0.05")
        shot(s, "20_handgun_fired", 0.0)
        p, st = me(s)
        check("two rounds fired", p["loaded"] == 6, p["loaded"])
        s.cmd("dev goto homestead"); s.cmd("wait 1"); s.cmd("dev time 12")
        t0 = s.state()["tick"]; time.sleep(2); t1 = s.state()["tick"]
        s.cmd("dev time_scale 5"); time.sleep(2); t2 = s.state()["tick"]
        s.cmd("ui dev_tab 0"); shot(s, "21_time_controls_5x", 0.4); s.cmd("ui dev off")
        s.cmd("dev time_scale 0"); time.sleep(1.0); t3 = s.state()["tick"]; time.sleep(1.5); t4 = s.state()["tick"]
        s.cmd("dev time_scale 1")
        check("single-player time runs faster at 5x", (t2 - t1) > 3 * (t1 - t0), (t1 - t0, t2 - t1))
        check("and stops when paused", t4 - t3 <= 1, t4 - t3)
    finally:
        s.quit()

if want("items"):
    s = session("s14_items", 318)
    try:
        for it in ("handgun", "ammo_pistol:20", "canned_soup:2", "coffee", "hand_warmer:3", "backpack", "winter_coat", "hat",
                   "gun_oil", "glow_sticks:4", "nails:40", "rope", "batteries:6", "jewellery:2", "first_aid_kit"):
            s.cmd("dev grant " + it)
        s.cmd("ui inventory on"); shot(s, "22_inventory_icons_and_slots", 0.6); s.cmd("ui inventory off")
        s.cmd("dev goto harbor.cannery"); s.cmd("wait 1.2"); s.cmd("zoom 0.85")
        # search the cannery's containers in turn until one holds something (some are empty by design)
        for n, (eid, x) in enumerate((("harbor.cannery.crate", 1357), ("harbor.cannery.tins", 794), ("harbor.cannery.cold_store", 512),
                                      ("harbor.cannery.locker", 1638))):
            s.cmd(f"walk_to {x} 0 8"); s.cmd(f"interact {eid}"); s.cmd("wait 1.5")
            if n == 0:
                shot(s, "23_searching_a_pooled_container", 0.1)
            s.cmd("wait 8")
            st = s.state()["entities"][eid]["state"]
            check(f"{eid} was searched (seeded pool roll)", st.get("searched") is True, st)
            if st.get("items") or st.get("gear"):
                break
        shot(s, "24_search_result", 0.3)
    finally:
        s.quit()
