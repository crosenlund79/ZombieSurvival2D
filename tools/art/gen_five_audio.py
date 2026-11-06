#!/usr/bin/env python3
"""Iteration 014 generated ambiences (no fitting clip in the creator's audio inbox):

* amb.harbor_ice — under the wind: the sea ice groaning and creaking, a far
  slap of water in the open channel (layered under the cold wind in Port Halden).
* amb.mine_drip  — a low mountain rumble, water dripping somewhere in the dark,
  the odd tick of settling timber (layered under the underground loop in the mine).

Writes WAV templates to assets/templates/audio/five/ and the manifest
assets/manifest/audio_five.json. Replaceable like every sound
(overrides/audio/five/<name>.wav|ogg). Deterministic.
"""
import json, math, os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "templates", "audio", "five")
SR = 22050


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def write(name, data):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(data / max(1e-6, np.max(np.abs(data))) * 0.8, -1, 1)
    # seamless loop: cross-fade the last half second into the start
    n = int(SR * 0.5)
    data[:n] = data[:n] * np.linspace(0, 1, n) + data[-n:] * np.linspace(1, 0, n)
    data = data[:-n]
    path = os.path.join(OUT, f"template_{name}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())
    return "res://assets/templates/audio/five/" + f"template_{name}.wav"


def harbor_ice(seconds=24.0):
    rng = np.random.default_rng(1401)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    wind = lowpass(rng.normal(0, 1, n), 0.02) * (0.6 + 0.4 * np.sin(t * 0.35 + 1.0))
    out = wind * 0.5
    for k in range(9):  # groans: slow, low, frequency-wobbling
        start = rng.uniform(0, seconds - 3)
        dur = rng.uniform(0.8, 2.4)
        i0, i1 = int(start * SR), int((start + dur) * SR)
        tt = np.arange(i1 - i0) / SR
        f = rng.uniform(55, 110) * (1 + 0.15 * np.sin(tt * rng.uniform(2, 6)))
        env = np.sin(np.pi * tt / dur) ** 2
        out[i0:i1] += 0.35 * env * np.sin(2 * np.pi * np.cumsum(f) / SR) * (1 + 0.3 * rng.normal(0, 1, len(tt)))
    for k in range(18):  # sharp creaks
        i0 = int(rng.uniform(0, seconds - 0.3) * SR)
        m = int(SR * rng.uniform(0.04, 0.12))
        out[i0:i0 + m] += 0.25 * rng.normal(0, 1, m) * np.exp(-np.arange(m) / (m / 4))
    for k in range(6):  # far water slaps
        i0 = int(rng.uniform(0, seconds - 1) * SR)
        m = int(SR * 0.6)
        out[i0:i0 + m] += 0.18 * lowpass(rng.normal(0, 1, m), 0.08) * np.exp(-np.arange(m) / (m / 3))
    return out


def mine_drip(seconds=20.0):
    rng = np.random.default_rng(1402)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    rumble = lowpass(rng.normal(0, 1, n), 0.004) * 3.0 * (0.7 + 0.3 * np.sin(t * 0.2))
    out = rumble
    for k in range(26):  # drips: a short pitched blip with a tail of echo
        i0 = int(rng.uniform(0, seconds - 1.0) * SR)
        m = int(SR * 0.25)
        tt = np.arange(m) / SR
        f = rng.uniform(900, 1700) * (1 - tt * 2.5)
        blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 40)
        for e, g in ((0, 0.35), (int(SR * 0.11), 0.12), (int(SR * 0.23), 0.05)):
            j = i0 + e
            out[j:j + m] += g * blip[: max(0, min(m, n - j))]
    for k in range(5):  # settling timber
        i0 = int(rng.uniform(0, seconds - 0.3) * SR)
        m = int(SR * 0.05)
        out[i0:i0 + m] += 0.3 * rng.normal(0, 1, m) * np.exp(-np.arange(m) / 80)
    return out


if __name__ == "__main__":
    assets = [
        {"id": "amb.harbor_ice", "name": "Harbor: sea ice creaking and groaning under the wind",
         "template": write("harbor_ice", harbor_ice()), "bus": "Ambience", "volume_db": -12.0, "loop": True, "status": "READY",
         "notes": "Generated (tools/art/gen_five_audio.py) - replace with a field recording."},
        {"id": "amb.mine_drip", "name": "Mine: low rumble, dripping water, settling timber",
         "template": write("mine_drip", mine_drip()), "bus": "Ambience", "volume_db": -12.0, "loop": True, "status": "READY",
         "notes": "Generated (tools/art/gen_five_audio.py) - replace with a field recording."},
    ]
    with open(os.path.join(ROOT, "assets", "manifest", "audio_five.json"), "w") as f:
        json.dump({"kind": "audio", "category": "five", "assets": assets}, f, indent="\t"); f.write("\n")
    print("iteration 014 ambiences generated:", len(assets))
