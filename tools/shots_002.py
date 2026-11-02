#!/usr/bin/env python3
"""Rendered screenshots for iteration 002 (needs a display, e.g. xvfb-run -a).
Writes PNGs; the committed copies were converted to JPEG to keep the download small."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT
from mp_test import go_inside
OUT = os.path.join(ROOT, "docs", "screenshots", "iteration_002")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


def shot(i, name, settle=1.2):
    i.cmd(f"wait {settle}")
    i.cmd(f"screenshot {OUT}/{name}.png")


def solo():
    s = Instance("shots_002", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 77 Builder")
        go_inside(s)
        s.cmd("walk_to 300 500")
        shot(s, "c1_farmhouse_interior_site")
        s.cmd("press_interact")
        s.cmd("walk_to 420 520")
        shot(s, "c2_hatch_construction_progress", 2.5)
        s.cmd("wait 6")
        s.cmd("walk_to 300 492"); s.cmd("press_interact")
        s.cmd("walk_to 380 500")
        shot(s, "c3_hatch_open")
        s.cmd("walk_to 300 452 4"); s.cmd("press_interact")
        s.cmd("walk_to 560 470")
        shot(s, "c4_level1_unreinforced", 1.8)
        s.cmd("walk_to 540 296 4"); s.cmd("press_interact")
        s.cmd("walk_to 480 600"); s.cmd("press_interact")
        s.cmd("walk_to 860 585")
        s.cmd("press_repeat 2 0.45")
        shot(s, "c5a_chopping", 0.1)
        s.cmd("press_repeat 3 0.45")
        shot(s, "c5b_tree_felled_wood_carried", 1.6)
        s.cmd("dev teleport 640 368"); s.cmd("press_repeat 5 0.45")
        go_inside(s)
        s.cmd("walk_to 470 400"); s.cmd("press_interact")
        shot(s, "c6_timber_deposited", 0.8)
        s.cmd("walk_to 300 452 4"); s.cmd("press_interact")
        s.cmd("walk_to 220 350"); s.cmd("press_interact")
        shot(s, "c7a_reinforcement_building", 1.0)
        s.cmd("walk_to 760 350"); s.cmd("press_interact")
        s.cmd("wait 3.5")
        s.cmd("walk_to 520 420")
        s.cmd("zoom 0.85")
        shot(s, "c7b_level1_reinforced", 1.5)
        s.cmd("ui map on")
        shot(s, "c8b_map_underground", 0.6)
        s.cmd("ui map off")
        s.cmd("dev create_level")
        s.cmd("zoom 1.0")
        s.cmd("walk_to 820 640"); s.cmd("press_interact")
        s.cmd("walk_to 600 420")
        shot(s, "c9_test_level_minus2", 1.8)
        s.cmd("walk_to 500 296 4"); s.cmd("press_interact")
        s.cmd("walk_to 540 296 4"); s.cmd("press_interact")
        s.cmd("walk_to 480 600"); s.cmd("press_interact")
        s.cmd("walk_to 1150 760")
        s.cmd("ui map on")
        shot(s, "c8a_map_surface", 0.6)
        s.cmd("ui map off")
    finally:
        s.quit()


def duo():
    h = Instance("shots_002h", headless=False); c = Instance("shots_002c", headless=False)
    h.wipe(); c.wipe(); h.start(); c.start()
    try:
        h.cmd("window 1280 720"); c.cmd("window 1280 720")
        h.cmd("host 24813 new 99 Anna")
        go_inside(h)
        h.cmd("walk_to 300 492"); h.cmd("press_interact"); h.cmd("wait 8.5"); h.cmd("press_interact")
        h.cmd("dev create_level")
        c.cmd("join 127.0.0.1 24813 Bo")
        go_inside(c)
        c.cmd("walk_to 300 452 4"); c.cmd("press_interact")
        c.cmd("walk_to 820 640"); c.cmd("press_interact")
        c.cmd("walk_to 620 420")
        h.cmd("walk_to 480 600"); h.cmd("press_interact")
        h.cmd("walk_to 1080 760")
        h.cmd("wait 1.5"); c.cmd("wait 0.2")
        h.cmd(f"screenshot {OUT}/c10_two_players_host_surface.png")
        c.cmd(f"screenshot {OUT}/c10_two_players_client_level2.png")
        h.cmd("ui map on")
        h.cmd(f"screenshot {OUT}/c10_two_players_host_map.png")
    finally:
        c.quit(); h.quit()


if not only or "solo" in only:
    solo()
if not only or "duo" in only:
    duo()
