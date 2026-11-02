#!/usr/bin/env python3
"""Iteration 006 placeholder sounds (construction, structure damage) + manifest entries."""
import json, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bunker_audio import save, lowpass, bandpass, hit, place, SR
from gen_homestead import ROOT
rng = np.random.default_rng(1306)
NEW = []


def add(aid, name, rel, vol=-4.0, loop=False, bus="SFX"):
    NEW.append({"id": aid, "name": name, "template": "res://assets/templates/audio/" + rel, "bus": bus,
                "volume_db": vol, "loop": loop, "status": "READY", "notes": "Generated placeholder (tools/art/gen_build_audio.py)."})


# Construction reuses the existing sfx.build_hammer (iteration 002); never regenerate it here.
m = int(0.35 * SR); tm = np.arange(m) / SR
thud = lowpass(rng.standard_normal(m), 500) * np.exp(-tm * 14) * 1.4 + np.sin(2 * math.pi * 90 * tm) * np.exp(-tm * 10) * 0.6
save("world/template_struct_hit.wav", thud)
add("sfx.struct_hit", "Structure hit by a zombie", "world/template_struct_hit.wav", -3.0)
k = int(1.0 * SR); tk = np.arange(k) / SR
crash = lowpass(rng.standard_normal(k), 1400) * np.exp(-tk * 4) + place(1.0, [(0.05, hit(0.2, 300, 0.8, 18)), (0.2, hit(0.2, 220, 0.7, 16)), (0.42, hit(0.25, 180, 0.6, 12))])[:k]
save("world/template_struct_break.wav", crash)
add("sfx.struct_break", "Structure broken", "world/template_struct_break.wav", -2.0)
j = int(0.8 * SR); tj = np.arange(j) / SR
clank = sum(np.sin(2 * math.pi * f * tj) * np.exp(-tj * d) for f, d in ((620, 6), (1240, 9), (1870, 12))) * 0.4
save("world/template_upgrade_clank.wav", clank + place(0.8, [(0.0, hit(0.12, 1200, 0.6, 40))])[:j])
add("sfx.upgrade", "Structure upgraded (metal clank)", "world/template_upgrade_clank.wav")
q = int(0.3 * SR); tq = np.arange(q) / SR
save("world/template_spikes.wav", bandpass(rng.standard_normal(q), 2400, 1600) * np.exp(-tq * 18) + np.sin(2 * math.pi * 140 * tq) * np.exp(-tq * 20) * 0.5)
add("sfx.spikes", "Spike trap hit", "world/template_spikes.wav", -4.0)

if __name__ == "__main__":
    path = os.path.join(ROOT, "assets", "manifest", "audio.json")
    d = json.load(open(path))
    ids = {a["id"] for a in d["assets"]}
    d["assets"] += [a for a in NEW if a["id"] not in ids]
    with open(path, "w") as f:
        json.dump(d, f, indent="\t"); f.write("\n")
    print("build sounds generated:", len(NEW))
