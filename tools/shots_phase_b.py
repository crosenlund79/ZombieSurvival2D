#!/usr/bin/env python3
"""Rendered screenshots of the Phase B homestead (needs a display, e.g. xvfb-run -a)."""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT
OUT = os.path.join(ROOT, "docs", "screenshots", "iteration_001")
os.makedirs(OUT, exist_ok=True)
only = sys.argv[1:]


def go(s, x, y, zoom, settle=1.6):
    s.cmd(f"dev teleport {x} {y}")
    s.cmd(f"zoom {zoom}")
    s.cmd(f"wait {settle}")


def solo():
    s = Instance("shots_b", headless=False); s.wipe(); s.start()
    try:
        s.cmd("window 1600 900")
        s.cmd("single new 21 Survivor")
        go(s, 1200, 850, 0.56, 2.5)
        s.cmd(f"screenshot {OUT}/b1_overview.png")
        go(s, 1150, 720, 1.25)
        s.cmd(f"screenshot {OUT}/b2_farmhouse_player_scale.png")
        go(s, 1180, 470, 1.15, 2.4)
        s.cmd(f"screenshot {OUT}/b3_occlusion_behind_house.png")
        go(s, 860, 455, 1.15, 2.4)
        s.cmd(f"screenshot {OUT}/b3b_occlusion_behind_tree.png")
        go(s, 1080, 960, 1.1)
        s.cmd(f"screenshot {OUT}/b4_bunker_entrance.png")
        go(s, 1150, 960, 1.0)
        s.cmd("press_interact")
        s.cmd("wait 0.6")
        s.cmd(f"screenshot {OUT}/b5_gate_open_prompt.png")
        go(s, 560, 1300, 1.0)
        s.cmd(f"screenshot {OUT}/b6_road_car_zoom1.png")
        go(s, 1150, 1000, 0.75)
        s.cmd(f"screenshot {OUT}/b7_zoom_075.png")
        go(s, 1160, 690, 1.8)
        s.cmd(f"screenshot {OUT}/b8_zoom_180_door.png")
    finally:
        s.quit()


def duo():
    h = Instance("shots_host", headless=False); c = Instance("shots_client", headless=False)
    h.wipe(); c.wipe(); h.start(); c.start()
    try:
        h.cmd("window 1280 720"); c.cmd("window 1280 720")
        h.cmd("host 24811 new 33 Anna")
        c.cmd("join 127.0.0.1 24811 Bo")
        c.cmd("walk_to 1150 960")
        c.cmd("press_interact")
        c.cmd("walk_to 1150 760")
        h.cmd("walk_to 1070 1000")
        h.cmd("zoom 1.0"); c.cmd("zoom 1.0")
        h.cmd("wait 1.5"); c.cmd("wait 0.2")
        h.cmd(f"screenshot {OUT}/b9_two_players_host_view.png")
        c.cmd(f"screenshot {OUT}/b9_two_players_client_view.png")
    finally:
        c.quit(); h.quit()


if not only or "solo" in only:
    solo()
if not only or "duo" in only:
    duo()
