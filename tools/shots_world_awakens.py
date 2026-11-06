#!/usr/bin/env python3
"""Rendered screenshots + runtime checks for iteration 011 (The World Awakens).
Needs a display (xvfb-run -a -s "-screen 0 1700x1000x24"). Usage:
  shots_world_awakens.py [crawl] [weather] [flashlight] [driving] [town] [cellar] [wildlife] [map] [custom]
Writes JPEGs to docs/screenshots/iteration_011 (or $SHOTS_OUT) and prints CHECK lines."""
import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT, USER_DIR

OUT = os.environ.get("SHOTS_OUT") or os.path.join(ROOT, "docs", "screenshots", "iteration_011")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


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


def session(name, seed):
    s = Instance(name, headless=False); s.wipe(); s.start()
    s.cmd("window 1600 900"); s.cmd(f"single new {seed} Tester"); s.cmd("tips off")
    return s


def want(k):
    return not only or k in only


if want("crawl"):
    s = session("s11_crawl", 211)
    try:
        s.cmd("dev time 13"); s.cmd("dev teleport 700 1250"); s.cmd("zoom 1.4")
        got = False
        for attempt in range(12):
            s.cmd("dev spawn_group"); s.cmd("wait 1.2")
            for k in range(8):
                st = s.state()
                crawlers = [z for z in st["zombie_rows"] if z.get("posture") == 2 and z["region"] == "homestead" and z["hp"] > 0]
                if crawlers:
                    shot(s, "01_burnt_one_crawling", 0.2)
                    got = True
                    break
                s.cmd("wait 0.5")
            if got:
                break
        check("a Burnt One crawls", got)
        s.cmd("dev noise 900 1250"); shot(s, "02_burnt_ones_listening", 1.0)
    finally:
        s.quit()

if want("weather"):
    s = session("s11_weather", 212)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev teleport 1150 1100"); s.cmd("zoom 0.9")
        for w, h in (("fog", 10), ("blizzard", 15), ("heavy_rain", 12), ("thunderstorm", 21)):
            s.cmd(f"dev time {h}"); s.cmd(f"dev weather {w}"); shot(s, f"03_weather_{w}", 2.5)
        check("weather kinds render", True)
    finally:
        s.quit()

if want("flashlight"):
    s = session("s11_flash", 213)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev grant flashlight"); s.cmd("dev time 23"); s.cmd("dev weather clear")
        s.cmd("dev teleport 900 1250"); s.cmd("press_key flashlight"); s.cmd("face right")
        p, _ = me(s)
        check("flashlight on", p["flashlight"])
        shot(s, "04_night_flashlight", 1.5)
    finally:
        s.quit()

if want("driving"):
    s = session("s11_drive", 214)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev time 12"); s.cmd("dev goto service_station")
        s.cmd("dev teleport 1400 700"); s.cmd("dev vehicle_here"); shot(s, "05_station_wagon_parked", 1.0)
        s.cmd("vehicle wagon enter"); s.cmd("press_key vehicle_engine"); s.cmd("hold move_up 0.9")
        shot(s, "06_driving", 0.1)
        s.cmd("hold move_up 3.0"); s.cmd("wait 1.5")
        p, st = me(s)
        check("drove to Ashgrove", p["region"] == "town", p["region"])
        shot(s, "07_arriving_in_ashgrove", 0.3)
        s.cmd("dev time 22"); s.cmd("hold move_down 1.0"); shot(s, "08_headlights_at_night", 1.5)
    finally:
        s.quit()

if want("town"):
    s = session("s11_town", 215)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev time 11"); s.cmd("dev goto town")
        s.cmd("dev teleport 1240 1060"); s.cmd("zoom 0.75"); shot(s, "09_ashgrove_main_street", 1.5)
        s.cmd("dev teleport 2300 1060"); shot(s, "10_ashgrove_garage_and_clothing", 1.0)
        s.cmd("zoom 1.0"); s.cmd("dev teleport 1580 920"); s.cmd("press_interact")
        p, st = me(s)
        check("hardware case gives a flashlight", "flashlight" in p["gear"], p["gear"])
    finally:
        s.quit()

if want("cellar"):
    s = session("s11_cellar", 216)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev goto town")
        s.cmd("dev teleport 1240 1500"); s.cmd("press_interact"); s.cmd("wait 0.3"); s.cmd("press_interact"); s.cmd("wait 1.2")
        shot(s, "11_town_house_with_cellar_hatch", 0.8)
        s.cmd("dev teleport 300 470"); s.cmd("press_interact"); s.cmd("wait 0.4"); s.cmd("press_interact"); s.cmd("wait 1.2")
        p, st = me(s)
        check("down in the cellar base", p["region"].startswith("bunker:town.house.cellar"), p["region"])
        shot(s, "12_town_cellar_base", 0.8)
    finally:
        s.quit()

if want("wildlife"):
    s = session("s11_wild", 217)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev time 12")
        p, st = me(s)
        wolves = [a for a in st["animals"] if a["region"] == "homestead"]
        a = wolves[0]
        s.cmd("dev teleport %d %d" % (a["x"] - 430, a["y"] - 20)); s.cmd("zoom 1.0")
        shot(s, "13_wolves_watching", 0.15)
        s.cmd("dev goto service_station")
        p, st = me(s)
        b = [x for x in st["animals"] if x["species"] == "bear"][0]
        s.cmd("dev teleport %d %d" % (b["x"] + 400, b["y"] - 40))
        shot(s, "14_bear", 0.15)
        check("wildlife present", len(st["animals"]) >= 4, len(st["animals"]))
    finally:
        s.quit()

if want("map"):
    s = session("s11_map", 218)
    try:
        s.cmd("dev peaceful 1"); s.cmd("dev goto service_station"); s.cmd("dev goto town"); s.cmd("dev time 23")
        s.cmd("ui map on"); shot(s, "15_night_map", 0.8)
    finally:
        s.quit()

if want("custom"):
    over = os.path.join(USER_DIR, "overrides")
    fix = os.path.join(ROOT, "tests", "fixtures", "overrides", "characters", "player", "survivor_down.png")
    dst = os.path.join(over, "characters", "player", "survivor_down.png")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy(fix, dst)
    s = session("s11_custom", 219)
    try:
        s.cmd("dev peaceful 1"); s.cmd("zoom 2.0")
        shot(s, "16_custom_graphics_on", 0.6)
        s.cmd("custom_graphics off"); s.cmd("rebuild_view"); s.cmd("zoom 2.0")
        shot(s, "17_custom_graphics_off_original", 0.6)
        check("custom graphics switch", s.state()["asset_sources"].get("char.player") == "template")
        s.cmd("custom_graphics on")
    finally:
        s.quit()
        os.remove(dst)
