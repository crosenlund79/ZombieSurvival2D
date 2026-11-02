#!/usr/bin/env python3
"""Generates a seamless countryside ambience loop (wind + sparse distant birds).
Output: assets/templates/audio/environment/template_countryside_loop.wav (22.05 kHz mono)."""
import math, os, wave
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR, DUR = 22050, 24.0
n = int(SR * DUR)
rng = np.random.default_rng(7)
t = np.arange(n) / SR
# wind: low-passed noise with slow gusting envelope (periodic in DUR -> loops cleanly)
white = rng.standard_normal(n)
spec = np.fft.rfft(white)
freqs = np.fft.rfftfreq(n, 1 / SR)
spec *= 1 / (1 + (freqs / 380.0) ** 2)
spec[freqs < 40] *= 0.3
wind = np.fft.irfft(spec, n)            # FFT filtering is circular -> seamless
wind /= np.abs(wind).max()
gust = 0.55 + 0.25 * np.sin(2 * math.pi * t / DUR * 2) + 0.15 * np.sin(2 * math.pi * t / DUR * 5 + 1.3)
sig = wind * gust * 0.5
# leaves rustle: band-passed noise bursts
spec2 = np.fft.rfft(rng.standard_normal(n)); spec2 *= np.exp(-((freqs - 2600) / 900) ** 2)
rustle = np.fft.irfft(spec2, n); rustle /= np.abs(rustle).max()
sig += rustle * (0.06 + 0.05 * np.sin(2 * math.pi * t / DUR * 3)) 
# distant birds: a few short chirps, quiet
for start in (2.1, 2.5, 9.3, 15.8, 16.1, 21.0):
    i0 = int(start * SR); L = int(0.12 * SR)
    tt = np.arange(L) / SR
    f = 3200 + 900 * np.sin(2 * math.pi * 18 * tt)
    chirp = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.sin(math.pi * tt / tt[-1]) ** 2
    sig[i0:i0 + L] += chirp * 0.07
sig = sig / np.abs(sig).max() * 0.7
pcm = (sig * 32767).astype("<i2")
p = os.path.join(ROOT, "assets/templates/audio/environment/template_countryside_loop.wav")
os.makedirs(os.path.dirname(p), exist_ok=True)
with wave.open(p, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("ambience written", p)
