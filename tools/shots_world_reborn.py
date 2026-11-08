#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 015 (The World Reborn).
Needs a display (xvfb-run -a -s "-screen 0 1600x900x24"). Usage:
  shots_world_reborn.py [scavenge] [lock] ...
Writes JPEGs to docs/screenshots/iteration_015 (or $SHOTS_OUT) and prints CHECK lines."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_015")
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


def stand_at(s, region, region_file, eid, dx=-30):
    s.cmd(f"dev goto {region}"); s.cmd("wait 1.2")
    e = entity(region_file, eid)
    s.cmd(f"dev teleport {e['position'][0] + dx} {e['position'][1]}"); s.cmd("wait 0.6")


def scavenge(s):
    stand_at(s, "town.grocery", "town_grocery", "town.grocery.aisle_a")
    s.cmd("press_interact"); s.cmd("wait 2.2")
    st = s.state()["entities"]["town.grocery.aisle_a"]["state"]
    check("search runs slot by slot", st.get("by", "") != "" and 0 < int(st.get("revealed", 0)) < int(st.get("total", 0)), str(st))
    shot(s, "scavenge_grid_searching", 0.1)
    s.cmd("wait 6")
    st = s.state()["entities"]["town.grocery.aisle_a"]["state"]
    check("search completes", bool(st.get("searched")), str(st))
    shot(s, "scavenge_grid_done", 0.3)
    s.cmd("panel_close")


def lock(s):
    stand_at(s, "town.hardware", "town_hardware", "town.hardware.locked_case")
    s.cmd("dev grant lockpick:1"); s.cmd("wait 0.4")
    s.cmd("press_interact"); s.cmd("wait 0.8")
    s.cmd("tap_key Left"); s.cmd("tap_key Left"); s.cmd("tap_key Left"); s.cmd("tap_key Space"); s.cmd("wait 0.8")
    st = s.state()["entities"]["town.hardware.locked_case"]["state"]
    check("still locked after a miss", st.get("locked", True) is not False, str(st))
    shot(s, "lockpicking", 0.2)


def horde(s):
    s.cmd("dev peaceful 0")
    s.cmd("dev goto wild.corran_forest"); s.cmd("wait 1.5")
    s.cmd("dev horde"); s.cmd("wait 1")
    st = s.state()
    check("a horde forms", st.get("hordes") == 1, st.get("hordes"))
    for k in range(30):
        s.cmd("wait 2")
        me = next(p for p in s.state()["players"] if p["id"] == s.state()["local_player_id"])
        near = [z for z in s.state()["zombies"] if z["region"] == me["region"] and not z["persistent"] and ((z["x"] - me["x"]) ** 2 + (z["y"] - me["y"]) ** 2) ** 0.5 < 450]
        if len(near) >= 3:
            break
    check("the horde reaches the player", len(near) >= 3, len(near))
    if near:  # look toward them (unseen Burnt Ones are not drawn — PlayerSight)
        cx = sum(z["x"] for z in near) / len(near) - me["x"]; cy = sum(z["y"] for z in near) / len(near) - me["y"]
        s.cmd("face " + (("right" if cx > 0 else "left") if abs(cx) > abs(cy) else ("down" if cy > 0 else "up")))
    s.cmd("zoom 0.85")
    shot(s, "horde_closing_in", 0.6)
    s.cmd("dev peaceful 1"); s.cmd("wait 0.5")


def wolves(s):
    s.cmd("dev peaceful 0")
    s.cmd("dev goto homestead"); s.cmd("wait 1.2")
    s.cmd("dev time 23"); s.cmd("dev weather clear")
    s.cmd("dev teleport 1575 1390"); s.cmd("wait 5")
    st = s.state()
    hunting = [a for a in st["animals"] if a["species"] == "wolf" and a["activity"] in ("stalk", "attack")]
    check("the wolf pack stalks at night", len(hunting) >= 2, [a["activity"] for a in st["animals"] if a["region"] == "homestead"])
    shot(s, "wolves_stalking", 0.1)
    s.cmd("dev peaceful 1"); s.cmd("dev time 12")


def factions(s):
    s.cmd("dev peaceful 0"); s.cmd("dev time 12")
    s.cmd("dev faction_goto hearth"); s.cmd("wait 1.5"); s.cmd("zoom 0.8")
    st = s.state()
    check("Hearth Gate's people are drawn", st["view"].get("people", 0) >= 6, st["view"].get("people"))
    shot(s, "community_gate", 0.4)
    tr = next(p for p in st["people"] if p["id"] == "hearth.trader")
    s.cmd(f"dev teleport {tr['x'] + 40} {tr['y'] + 70}"); s.cmd("wait 0.6"); s.cmd("zoom 1.0")
    s.cmd("dev faction_credit 50"); s.cmd("wait 0.3")
    s.cmd("press_interact"); s.cmd("wait 0.6")
    s.cmd("ui_click_text Buy")
    shot(s, "community_trading", 0.4)
    s.cmd("panel_close")
    el = next(p for p in st["people"] if p["id"] == "hearth.elder")
    s.cmd(f"dev teleport {el['x'] + 40} {el['y'] + 70}"); s.cmd("wait 0.6")
    s.cmd("faction hearth.elder accept hearth_food"); s.cmd("wait 0.4")
    s.cmd("press_interact"); s.cmd("wait 0.6")
    s.cmd("ui_click_text Work")
    shot(s, "community_missions", 0.4)
    s.cmd("panel_close")
    s.cmd("panel factions on"); shot(s, "factions_screen", 0.5); s.cmd("panel factions off")
    s.cmd("dev faction_goto cinder"); s.cmd("wait 1.2")
    rd = next(p for p in s.state()["people"] if p["id"] == "cinder.raider_1")
    s.cmd(f"dev teleport {rd['x']} {rd['y'] + 420}"); s.cmd("face up"); s.cmd("zoom 0.85"); s.cmd("wait 1.5")
    shot(s, "raider_camp", 0.2)
    s.cmd("dev heal"); s.cmd("dev peaceful 1")


if __name__ == "__main__":
    s = session("shots015", 1515)
    try:
        if want("scavenge"):
            scavenge(s)
        if want("lock"):
            lock(s)
        if want("horde"):
            horde(s)
        if want("wolves"):
            wolves(s)
        if want("factions"):
            factions(s)
    finally:
        s.quit()
