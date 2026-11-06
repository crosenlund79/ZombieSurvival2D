#!/usr/bin/env python3
"""Red Thaw — The World Awakens (iteration 011) generated placeholder audio.

Station wagon sounds (numpy synthesis, no samples): a loopable idling engine
(the game raises its pitch with speed), the starter cranking and catching, the
engine dying, and a car door thunk. Writes WAV templates under
assets/templates/audio/awakens/ and assets/manifest/audio_awakens.json.
Never touches existing sounds or overrides. Run from the repository root.
"""
import json, math, os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR = 22050
OUT_DIR = os.path.join(ROOT, "assets", "templates", "audio", "awakens")
ENTRIES = []
RNG = np.random.default_rng(1101)


def save(rel, x, aid, name, bus, vol, loop=False):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * 0.85
    os.makedirs(OUT_DIR, exist_ok=True)
    with wave.open(os.path.join(OUT_DIR, rel), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/audio/awakens/" + rel, "bus": bus,
                    "volume_db": vol, "loop": loop, "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_awakens_audio.py). WAV or OGG override accepted."})


def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec / np.sqrt(1 + (f / cutoff) ** 4), len(x))


def engine_wave(seconds, rpm_curve, rough=0.25):
    """Four-cylinder-ish engine: firing pulses at rpm/30 Hz with harmonics,
    exhaust noise modulated by the firing, low-passed."""
    n = int(SR * seconds)
    rpm = rpm_curve(np.linspace(0, 1, n))
    fire = rpm / 30.0
    phase = 2 * math.pi * np.cumsum(fire) / SR
    x = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (6, 0.1)):
        x += a * np.sin(k * phase + RNG.random() * 6)
    pulse = np.clip(np.sin(phase), 0, 1) ** 3
    noise = RNG.standard_normal(n) * (0.25 + 0.6 * pulse) * rough
    x = x * (0.7 + 0.3 * pulse) + noise
    return lowpass(x, 900)


def engine_loop():
    secs = 2.0
    n = int(SR * secs)
    # an exact whole number of firing cycles so the loop is seamless
    f = round(26.0 * secs) / secs
    t = np.arange(n) / SR
    phase = 2 * math.pi * f * t
    x = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.6), (3, 0.38), (4, 0.2), (6, 0.12), (8, 0.05)):
        x += a * np.sin(k * phase + k * 0.7)
    pulse = np.clip(np.sin(phase), 0, 1) ** 3
    noise = RNG.standard_normal(n)
    noise = lowpass(np.concatenate([noise, noise]), 700)[:n]  # periodic noise -> seamless
    x = x * (0.75 + 0.25 * pulse) + noise * (0.15 + 0.35 * pulse) * 0.5
    x = lowpass(np.concatenate([x, x]), 1000)[n // 2: n // 2 + n]
    save("template_engine_loop.wav", x, "sfx.engine_loop", "Station wagon engine running (loop; pitch follows speed)", "SFX", -9.0, loop=True)


def engine_start():
    crank = 0.9
    n1 = int(SR * crank)
    t = np.arange(n1) / SR
    # starter motor whine + slow compression chugs
    whine = 0.3 * np.sin(2 * math.pi * (180 + 40 * t) * t) + 0.15 * np.sin(2 * math.pi * 360 * t)
    chug = np.clip(np.sin(2 * math.pi * 5.5 * t), 0, 1) ** 4
    crank_s = (whine * 0.5 + RNG.standard_normal(n1) * 0.3) * (0.4 + 0.6 * chug)
    crank_s = lowpass(crank_s, 2500)
    run = engine_wave(1.2, lambda u: 700 + 1400 * np.exp(-((u - 0.25) ** 2) / 0.02) + 300 * (1 - u), rough=0.35)
    run *= np.minimum(1, np.arange(len(run)) / (SR * 0.05))
    run[-int(SR * 0.3):] *= np.linspace(1, 0.6, int(SR * 0.3))
    x = np.concatenate([crank_s, run])
    save("template_engine_start.wav", x, "sfx.engine_start", "Engine cranks and catches", "SFX", -6.0)


def engine_stop():
    run = engine_wave(1.1, lambda u: 780 * (1 - u) ** 1.6 + 60, rough=0.3)
    run *= np.linspace(1, 0, len(run)) ** 1.5
    save("template_engine_stop.wav", run, "sfx.engine_stop", "Engine shuts off and shudders still", "SFX", -8.0)


def car_door():
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    thunk = np.sin(2 * math.pi * 85 * t) * np.exp(-t * 22) + 0.6 * np.sin(2 * math.pi * 140 * t) * np.exp(-t * 30)
    latch = RNG.standard_normal(n) * np.exp(-((t - 0.012) ** 2) / 0.00002) * 0.8
    rattle = lowpass(RNG.standard_normal(n), 1800) * np.exp(-t * 14) * 0.3
    x = thunk + latch + rattle
    save("template_car_door.wav", x, "sfx.car_door", "Car door opens/closes (thunk and latch)", "SFX", -6.0)


def formant_voice(f0, seconds, formants, breath=0.2, vib=0.0):
    """Harmonic source through formant resonances (cheap additive synthesis)."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    f = f0(np.linspace(0, 1, n)) * (1 + vib * np.sin(2 * math.pi * 5.2 * t))
    ph = 2 * math.pi * np.cumsum(f) / SR
    x = np.zeros(n)
    for h in range(1, 18):
        fh = f * h
        g = np.zeros(n)
        for fc, bw in formants:
            g += np.exp(-((fh - fc) ** 2) / (2 * bw * bw))
        x += g * np.sin(h * ph) / h ** 0.4
    x += lowpass(RNG.standard_normal(n), 2500) * breath
    return x


def wolf_howl():
    secs = 3.4
    env = lambda u: np.clip(np.minimum(u / 0.12, 1) * np.minimum((1 - u) / 0.3, 1), 0, 1)
    f0 = lambda u: 340 + 230 * np.sin(np.minimum(u / 0.35, 1) * math.pi / 2) - 120 * np.clip((u - 0.65) / 0.35, 0, 1) ** 2
    x = formant_voice(f0, secs, [(700, 160), (1150, 200)], breath=0.05, vib=0.012)
    x *= env(np.linspace(0, 1, len(x)))
    tail = np.zeros(int(SR * 1.2))
    x = np.concatenate([x, tail])
    for d, g in ((0.23, 0.35), (0.51, 0.22), (0.83, 0.12)):  # distant forest echo
        k = int(SR * d)
        x[k:] += x[:-k] * g
    save("template_wolf_howl.wav", lowpass(x, 3000), "sfx.wolf_howl", "Wolf howl (distant, echoing through the pines)", "SFX", -10.0)


def wolf_huff():
    secs = 0.5
    n = int(SR * secs)
    t = np.arange(n) / SR
    x = lowpass(RNG.standard_normal(n), 1400) * np.exp(-t * 9) * 0.8
    x += formant_voice(lambda u: 220 - 60 * u, secs, [(600, 150), (1000, 200)], breath=0.3) * np.exp(-t * 12) * 0.5
    save("template_wolf_huff.wav", x, "sfx.wolf_huff", "Wolf huff / short warning bark", "SFX", -8.0)


def bear_grunt():
    secs = 1.3
    n = int(SR * secs)
    u = np.linspace(0, 1, n)
    x = formant_voice(lambda u: 95 - 25 * u, secs, [(380, 120), (800, 180)], breath=0.45, vib=0.04)
    x *= np.clip(np.minimum(u / 0.08, 1) * np.minimum((1 - u) / 0.4, 1), 0, 1)
    rough = 1 + 0.6 * np.sign(np.sin(2 * math.pi * 23 * np.arange(n) / SR))
    save("template_bear_grunt.wav", lowpass(x * rough, 1500), "sfx.bear_grunt", "Bear grunt / low growl", "SFX", -6.0)


def bear_huff():
    secs = 0.9
    n = int(SR * secs)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for st in (0.0, 0.32):
        k = int(SR * st)
        m = n - k
        tt = np.arange(m) / SR
        x[k:] += lowpass(RNG.standard_normal(m), 900) * np.exp(-tt * 11)
    save("template_bear_huff.wav", x, "sfx.bear_huff", "Bear huffing (alarmed, backing off)", "SFX", -6.0)


if __name__ == "__main__":
    engine_loop(); engine_start(); engine_stop(); car_door()
    wolf_howl(); wolf_huff(); bear_grunt(); bear_huff()
    with open(os.path.join(ROOT, "assets", "manifest", "audio_awakens.json"), "w") as f:
        json.dump({"kind": "audio", "category": "awakens", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("world awakens audio generated:", len(ENTRIES))
