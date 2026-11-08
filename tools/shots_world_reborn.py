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


if __name__ == "__main__":
    s = session("shots015", 1515)
    try:
        if want("scavenge"):
            scavenge(s)
        if want("lock"):
            lock(s)
    finally:
        s.quit()
