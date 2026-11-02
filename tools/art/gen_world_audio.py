#!/usr/bin/env python3
"""Iteration 008 placeholder sounds: rain loop, horde warning horn-groan, weather. Appends manifest entries."""
import json, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bunker_audio import save, lowpass, bandpass, SR
from gen_homestead import ROOT
rng = np.random.default_rng(1508)
NEW = []
D = 6.0; n = int(D * SR); t = np.arange(n) / SR
rain = bandpass(rng.standard_normal(n), 3000, 2500) * 0.35 + lowpass(rng.standard_normal(n), 300) * 0.25
drops = np.zeros(n)
for k in range(260):
    i = int(rng.uniform(0, n - 400)); drops[i:i + 300] += np.sin(np.arange(300) * 0.9) * np.exp(-np.arange(300) / 60) * rng.uniform(0.1, 0.35)
sig = rain + drops
fade = int(0.25 * SR)  # cross-fade the loop seam
sig[:fade] = sig[:fade] * np.linspace(0, 1, fade) + sig[-fade:] * np.linspace(1, 0, fade)
save("environment/template_rain_loop.wav", sig[:-fade])
NEW.append({"id": "amb.rain", "name": "Rain (loop)", "template": "res://assets/templates/audio/environment/template_rain_loop.wav", "bus": "Ambience", "volume_db": -6.0, "loop": True, "status": "READY", "notes": "Generated placeholder (tools/art/gen_world_audio.py)."})
m = int(3.0 * SR); tm = np.arange(m) / SR
groans = sum(np.sin(2 * math.pi * (70 + 15 * k + 10 * np.sin(2 * math.pi * 0.7 * tm)) * tm) * np.clip(np.sin(math.pi * (tm - 0.3 * k) / 2.2), 0, 1) for k in range(4))
save("world/template_horde_warning.wav", lowpass(groans * 0.35 + rng.standard_normal(m) * 0.05, 900))
NEW.append({"id": "sfx.horde_warning", "name": "Distant horde gathering", "template": "res://assets/templates/audio/world/template_horde_warning.wav", "bus": "SFX", "volume_db": -2.0, "loop": False, "status": "READY", "notes": "Generated placeholder (tools/art/gen_world_audio.py)."})
if __name__ == "__main__":
    path = os.path.join(ROOT, "assets", "manifest", "audio.json")
    d = json.load(open(path)); ids = {a["id"] for a in d["assets"]}
    d["assets"] += [a for a in NEW if a["id"] not in ids]
    with open(path, "w") as f:
        json.dump(d, f, indent="\t"); f.write("\n")
    print("world sounds generated:", len(NEW))
