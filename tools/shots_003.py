#!/usr/bin/env python3
"""Rendered screenshots for iteration 003 (needs a display, e.g. xvfb-run -a).
Usage: shots_003.py [danger] [dig] [infra] [duo]. Writes PNGs to docs/screenshots/iteration_003."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT
from mp_test import go_inside, take_club, to_west_trees, zs, wait_for
OUT = os.path.join(ROOT, "docs", "screenshots", "iteration_003")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


def shot(i, name, settle=0.8):
    i.cmd(f"wait {settle}")
    i.cmd(f"screenshot {OUT}/{name}.png")


def danger():
    s = Instance("shots_003a", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 31 Scout")
        take_club(s)
        to_west_trees(s)
        s.cmd("walk_to 200 685")
        s.cmd("zoom 0.8")
        s.cmd("press_repeat 3 0.45")
        shot(s, "d1_chopping_zombies_investigate", 1.5)
        s.cmd("press_repeat 2 0.45")
        s.cmd("dev heal")
        s.cmd("walk_to 380 945")
        s.cmd("press_repeat 5 0.45")
        s.cmd("dev heal")
        s.cmd("zoom 0.6")
        shot(s, "d2_horde_developing", 2.5)
        s.cmd("dev heal")
        wait_for(s, lambda st: any(abs(z["x"] - st["me_x"]) + abs(z["y"] - st["me_y"]) < 120 for z in zs(st)), timeout=20)
        s.cmd("zoom 1.2")
        s.cmd("attack_nearest 2 0.6")
        shot(s, "d3_combat", 0.05)
        s.cmd("attack_nearest 4 0.6")
        shot(s, "d4_after_fight_hud", 0.3)
    finally:
        s.quit()


def build_shelter(s):
    go_inside(s)
    s.cmd("walk_to 300 492"); s.cmd("press_interact"); s.cmd("wait 8.5"); s.cmd("press_interact")
    s.cmd("walk_to 300 452 4"); s.cmd("press_interact")


def dig():
    s = Instance("shots_003b", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 52 Digger")
        s.cmd("dev peaceful 1")
        build_shelter(s)
        s.cmd("dev grant_stock 12")
        s.cmd("walk_to 160 416 6")
        s.cmd("face left")
        shot(s, "e1_dig_target_prompt", 0.5)
        for c in ("12,12", "12,13", "12,11"):
            x, y = c.split(",")
            s.cmd(f"terrain dig {x} {y}")
            s.cmd("wait 2.3")
        s.cmd("walk_to 96 416 6")
        s.cmd("face left")
        shot(s, "e2_unsupported_needs_support", 0.5)
        s.cmd("terrain support 12 12")
        s.cmd("wait 3.4")
        for c in ("11,12", "10,12", "11,11", "11,13", "10,11", "10,13"):
            x, y = c.split(",")
            if c == "10,12":
                s.cmd("walk_to 32 416 6")
            s.cmd(f"terrain dig {x} {y}")
            s.cmd("wait 2.3")
        s.cmd("walk_to 200 480 6")
        s.cmd("zoom 0.85")
        shot(s, "e3_expanded_chamber_with_support", 1.2)
    finally:
        s.quit()


def infra():
    s = Instance("shots_003c", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 64 Keeper")
        s.cmd("dev peaceful 1")
        build_shelter(s)
        s.cmd("dev grant fuel:3"); s.cmd("dev grant water_dirty:4"); s.cmd("dev grant wood:5")
        s.cmd("walk_to 700 560 6"); s.cmd("zoom 0.75")
        shot(s, "f1_bunker_unpowered", 1.0)
        s.cmd("zoom 1.0")
        s.cmd("walk_to 650 345 6"); s.cmd("press_interact")
        s.cmd("entity_action storage store wood"); s.cmd("entity_action storage store water_dirty")
        shot(s, "f2_storage_panel", 0.4)
        s.cmd("panel_close")
        s.cmd("walk_to 930 610 6"); s.cmd("press_interact")
        s.cmd("entity_action generator fuel"); s.cmd("entity_action generator fuel")
        s.cmd("entity_action generator toggle")
        shot(s, "f3_generator_running_panel", 0.4)
        s.cmd("panel_close")
        s.cmd("walk_to 700 560 6"); s.cmd("zoom 0.75")
        shot(s, "f4_bunker_powered_lights", 1.0)
        s.cmd("zoom 1.0")
        s.cmd("walk_to 250 620 6"); s.cmd("press_interact")
        s.cmd("entity_action purifier fill")
        s.cmd("dev advance_clock 50")
        shot(s, "f5_purifier_water_panel", 0.6)
        s.cmd("entity_action purifier collect")
        s.cmd("panel_close")
        s.cmd("dev thirst 18")
        shot(s, "f6_hud_thirsty_inventory", 0.6)
        s.cmd("press_key drink")
        shot(s, "f7_hud_after_drink", 0.6)
    finally:
        s.quit()


def duo():
    h = Instance("shots_003h", headless=False); c = Instance("shots_003g", headless=False)
    for i in (h, c):
        i.wipe()
    try:
        h.start(); c.start()
        for i in (h, c):
            i.cmd("window 1100 700")
        h.cmd("host 47911 new 65 Hosty")
        h.cmd("dev peaceful 1")
        build_shelter(h)
        h.cmd("dev grant fuel:2")
        h.cmd("walk_to 930 610 6")
        h.cmd("entity_action generator fuel"); h.cmd("entity_action generator fuel"); h.cmd("entity_action generator toggle")
        c.cmd("join 127.0.0.1 47911 Cleo")
        c.cmd("walk_to 1150 960"); c.cmd("walk_to 1150 760"); c.cmd("walk_to 1640 760"); c.cmd("walk_to 1680 680 6")
        c.cmd("press_interact")
        h.cmd("walk_to 700 560 6")
        h.cmd("zoom 0.8"); c.cmd("zoom 0.8")
        shot(h, "g1_mp_host_underground_powered", 0.6)
        shot(c, "g2_mp_client_surface_scavenging", 0.2)
    finally:
        for i in (h, c):
            i.quit()


if not only or "infra" in only:
    infra()
if not only or "duo" in only:
    duo()
if not only or "danger" in only:
    danger()
if not only or "dig" in only:
    dig()
