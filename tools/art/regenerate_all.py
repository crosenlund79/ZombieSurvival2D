#!/usr/bin/env python3
"""Regenerate every visual template (graphics only — never audio).

Order matters: later scripts overwrite some templates of earlier ones
(gen_overhaul redraws stump/shed/farmhouse/trees/tiles, gen_figures redraws the
standing characters, gen_station recolours the finished survivor into the NPC).
Writes only assets/templates/** and the visual manifests those scripts own;
never touches assets/overrides/**. Run from the repository root:
    python3 tools/art/regenerate_all.py
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STEPS = [
    ["gen_homestead.py"], ["gen_bunker.py"], ["gen_survival.py", "milestone_b"], ["gen_infra.py"],
    ["gen_build.py"], ["gen_tools.py"], ["gen_overhaul.py"], ["gen_winter.py"], ["gen_figures.py"], ["gen_station.py"],
]

if __name__ == "__main__":
    for step in STEPS:
        print("==", " ".join(step), flush=True)
        subprocess.run([sys.executable, os.path.join(HERE, step[0])] + step[1:], check=True)
    print("all visual templates regenerated")
