#!/usr/bin/env python3
"""Iteration 003 placeholder sounds (WAV, 22.05 kHz mono)."""
import math, os, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_bunker_audio import save, env, lowpass, bandpass, hit, place, SR
rng = np.random.default_rng(303)


def groan(dur, f0, rough, seed):
    r = np.random.default_rng(seed)
    n = int(dur * SR); t = np.arange(n) / SR
    f = f0 * (1 + 0.15 * np.sin(2 * math.pi * 2.2 * t) + 0.05 * r.standard_normal(n).cumsum() / np.sqrt(n))
    ph = 2 * math.pi * np.cumsum(f) / SR
    voice = np.sign(np.sin(ph)) * 0.4 + np.sin(ph * 2) * 0.3 + np.sin(ph * 3.1) * 0.2
    voice = lowpass(voice, 900) + bandpass(r.standard_normal(n), 500, 300) * rough
    e = np.sin(math.pi * np.clip(t / dur, 0, 1)) ** 0.7
    return voice * e


save("zombie/template_groan.wav", groan(1.4, 95, 0.8, 1))
save("zombie/template_alert.wav", groan(0.8, 140, 1.2, 2))
save("zombie/template_attack.wav", groan(0.5, 180, 1.5, 3) + place(0.5, [(0.35, hit(0.15, 120, 0.8, 30))]) * 0.6)
save("zombie/template_hit.wav", place(0.45, [(0.0, hit(0.25, 110, 0.8, 22, 2200)), (0.0, groan(0.4, 120, 1.0, 4) * 0.4)]))
save("zombie/template_death.wav", groan(1.2, 80, 1.0, 5) * np.linspace(1, 0.2, int(1.2 * SR)) + place(1.2, [(0.7, hit(0.4, 70, 0.8, 10, 900))]))
n = int(0.25 * SR); t = np.arange(n) / SR
save("combat/template_swing.wav", bandpass(rng.standard_normal(n), 1600, 700) * np.sin(math.pi * t / 0.25))
save("combat/template_player_hurt.wav", place(0.35, [(0.0, hit(0.3, 160, 0.6, 14, 1800)), (0.0, groan(0.3, 210, 0.4, 6) * 0.5)]))
print("survival sounds (milestone A) generated")
