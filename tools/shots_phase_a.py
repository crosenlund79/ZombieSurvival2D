#!/usr/bin/env python3
"""Rendered screenshots of the Phase A baseline (needs an X display, e.g. xvfb-run)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aftergrowth_driver import Instance, ROOT
OUT = os.path.join(ROOT, "docs", "screenshots", "iteration_001")
os.makedirs(OUT, exist_ok=True)
s = Instance("shots_a", headless=False); s.wipe(); s.start()
try:
    s.cmd("window 1600 900")
    s.cmd(f"screenshot {OUT}/a1_main_menu.png")
    s.cmd("single new 7 Survivor")
    s.cmd("walk_to 1150 960")
    s.cmd(f"screenshot {OUT}/a2_placeholder_world_prompt.png")
    s.cmd("press_interact")
    s.cmd("ui dev on")
    s.cmd(f"screenshot {OUT}/a3_gate_open_dev_overlay.png")
    s.cmd("ui dev off")
    s.cmd("ui pause on")
    s.cmd(f"screenshot {OUT}/a4_pause_menu.png")
    s.cmd("ui pause off")
    s.cmd("ui settings on")
    s.cmd(f"screenshot {OUT}/a5_settings.png")
    s.cmd("ui settings off")
    s.cmd("save")
finally:
    s.quit()
# Ultrawide: launch at 2560x1080 and continue the saved world.
u = Instance("shots_a", headless=False, extra_args=["--resolution", "2560x1080"]); u.start()
try:
    u.cmd("single continue Survivor")
    u.cmd(f"screenshot {OUT}/a6_ultrawide_21x9.png")
finally:
    u.quit()
