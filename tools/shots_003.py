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


if not only or "danger" in only:
    danger()
if not only or "dig" in only:
    dig()
