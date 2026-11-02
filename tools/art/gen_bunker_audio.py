#!/usr/bin/env python3
"""Generates iteration-002 placeholder sounds (WAV, 22.05 kHz mono) into assets/templates/audio/."""
import math, os, wave
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR = 22050
rng = np.random.default_rng(42)


def save(rel, sig):
    sig = sig / max(1e-6, np.abs(sig).max()) * 0.8
    p = os.path.join(ROOT, "assets/templates/audio", rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((sig * 32767).astype("<i2").tobytes())


def env(n, attack=0.002, decay=8.0):
    t = np.arange(n) / SR
    return np.minimum(1, t / attack) * np.exp(-decay * t)


def lowpass(x, cutoff):
    spec = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / (1 + (f / cutoff) ** 2)
    return np.fft.irfft(spec, len(x))


def bandpass(x, center, width):
    spec = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= np.exp(-((f - center) / width) ** 2)
    return np.fft.irfft(spec, len(x))


def hit(dur, freq, noise, decay, cutoff=3000):
    n = int(dur * SR); t = np.arange(n) / SR
    tone = np.sin(2 * math.pi * freq * t) + 0.5 * np.sin(2 * math.pi * freq * 2.3 * t)
    nz = lowpass(rng.standard_normal(n), cutoff)
    return (tone * (1 - noise) + nz / np.abs(nz).max() * noise) * env(n, decay=decay)


def place(total, parts):
    out = np.zeros(int(total * SR))
    for start, sig in parts:
        i = int(start * SR); out[i:i + len(sig)] += sig[:len(out) - i]
    return out


chop = hit(0.35, 160, 0.65, 14, 2500) + 0.4 * hit(0.35, 900, 0.8, 30, 6000)
save("world/template_chop.wav", chop)
n = int(2.2 * SR); t = np.arange(n) / SR
creak = np.sin(2 * math.pi * (120 + 80 * t) * t) * (t < 1.0) * np.minimum(1, t * 3) * 0.5
crash = np.zeros(n); i = int(1.05 * SR)
burst = lowpass(rng.standard_normal(n - i), 900) * env(n - i, decay=3.5)
crash[i:] = burst / np.abs(burst).max()
save("world/template_tree_fall.wav", creak + crash * 1.2 + bandpass(rng.standard_normal(n), 3000, 1500) * (t > 1.05) * env(n, decay=2) * 0.2)
save("world/template_wood_drop.wav", place(0.6, [(0.0, hit(0.2, 220, 0.4, 25)), (0.12, hit(0.2, 260, 0.4, 25)), (0.27, hit(0.25, 190, 0.4, 20))]))
n = int(1.2 * SR); t = np.arange(n) / SR
scrape = bandpass(rng.standard_normal(n), 1400, 900) * (0.5 + 0.5 * np.sin(2 * math.pi * 2.5 * t)) ** 2 * np.minimum(1, (1.2 - t) * 4)
save("world/template_dig.wav", scrape + place(1.2, [(0.05, hit(0.2, 120, 0.7, 18)), (0.45, hit(0.2, 110, 0.7, 18)), (0.85, hit(0.2, 130, 0.7, 18))]))
hammer = hit(0.18, 520, 0.35, 28, 5000)
save("world/template_build_hammer.wav", place(1.1, [(0.0, hammer), (0.33, hammer * 0.9), (0.66, hammer)]))
save("world/template_build_done.wav", place(0.9, [(0.0, hammer), (0.15, hammer * 0.8), (0.4, hit(0.5, 330, 0.15, 6) * 0.7)]))
n = int(0.9 * SR); t = np.arange(n) / SR
save("world/template_hatch_open.wav", np.sin(2 * math.pi * (200 + 260 * t) * t) * np.sin(math.pi * t / 0.9) * 0.6 + hit(0.9, 90, 0.6, 6) * 0.3)
save("world/template_hatch_close.wav", hit(0.5, 80, 0.7, 10, 1200))
save("world/template_ladder.wav", place(1.0, [(0.0, hit(0.18, 300, 0.5, 30)), (0.28, hit(0.18, 280, 0.5, 30)), (0.56, hit(0.18, 310, 0.5, 30))]))
# underground ambience: deep rumble + occasional drips; FFT filtering keeps it seamless.
D = 20.0; n = int(D * SR); t = np.arange(n) / SR
rumble = lowpass(rng.standard_normal(n), 90); rumble /= np.abs(rumble).max()
air = lowpass(rng.standard_normal(n), 500); air /= np.abs(air).max()
amb = rumble * 0.6 + air * 0.15 * (0.7 + 0.3 * np.sin(2 * math.pi * t / D * 3))
for s in (1.3, 4.9, 7.2, 11.8, 15.1, 18.4):
    L = int(0.25 * SR); tt = np.arange(L) / SR
    drip = np.sin(2 * math.pi * (1400 - 2400 * tt) * tt) * np.exp(-28 * tt) * 0.35
    i = int(s * SR); amb[i:i + L] += drip
save("environment/template_underground_loop.wav", amb)
print("bunker sounds generated")
