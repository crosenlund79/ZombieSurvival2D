#!/usr/bin/env python3
"""Iteration 003 milestone C placeholder sounds."""
import math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bunker_audio import save, env, lowpass, bandpass, hit, place, SR
rng = np.random.default_rng(909)
D = 4.0; n = int(D * SR); t = np.arange(n) / SR
f0 = 50.0  # integer cycles in D seconds -> seamless loop
hum = np.sin(2 * math.pi * f0 * t) * 0.5 + np.sign(np.sin(2 * math.pi * f0 * 2 * t)) * 0.12 + np.sin(2 * math.pi * 150 * t) * 0.15
chug = (0.75 + 0.25 * np.sin(2 * math.pi * 6 * t)) * (lowpass(rng.standard_normal(n), 400) * 0.3)
save("environment/template_generator_loop.wav", hum + chug)
m = int(1.2 * SR); tm = np.arange(m) / SR
pour = bandpass(rng.standard_normal(m), 900, 600) * (0.6 + 0.4 * np.sin(2 * math.pi * 9 * tm)) * np.sin(math.pi * tm / 1.2)
save("world/template_water_pour.wav", pour)
save("world/template_rummage.wav", place(1.0, [(0.0, hit(0.2, 400, 0.8, 18)), (0.25, hit(0.2, 300, 0.8, 18)), (0.5, hit(0.25, 520, 0.7, 16)), (0.72, hit(0.2, 260, 0.8, 18))]))
k = int(0.9 * SR); tk = np.arange(k) / SR
gulp = sum(np.sin(2 * math.pi * (180 + 120 * np.sin(math.pi * (tk - s) / 0.18).clip(0)) * tk) * ((tk > s) & (tk < s + 0.18)) for s in (0.05, 0.35, 0.62))
save("world/template_drink.wav", gulp * 0.7)
print("infrastructure sounds generated")
