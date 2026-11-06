#!/usr/bin/env python3
"""Red Thaw — generated placeholder audio (numpy only, no external samples).

Cold wind ambiences (outdoor, snowfall, muffled indoors), suppressed human laughter
and distant giggling for abandoned settlements, a frightened survivor's muttering,
and human Burnt One sounds (ragged breathing, a sharp breath/laugh when they notice
someone, effort grunts, pain, a choked fall). Voices are additive harmonic synthesis
shaped by vowel formants; wind is spectrally shaped noise with slow gusts.

Writes WAV templates under assets/templates/audio/red_thaw/ and the manifest
assets/manifest/audio_red_thaw.json. Never touches existing sounds or overrides.
Run from the repository root.
"""
import json, math, os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR = 22050
OUT_DIR = os.path.join(ROOT, "assets", "templates", "audio", "red_thaw")
ENTRIES = []
RNG = np.random.default_rng(5150)

VOWELS = {  # F1, F2, F3 (Hz) with bandwidths
    "a": ((750, 90), (1200, 110), (2550, 160)),
    "e": ((500, 80), (1750, 110), (2500, 160)),
    "i": ((320, 60), (2200, 120), (2950, 170)),
    "u": ((330, 70), (850, 90), (2350, 160)),
    "m": ((260, 60), (1000, 200), (2200, 300)),   # nasal hum, lips closed
    "h": ((600, 200), (1500, 300), (2600, 400)),
}


def save(rel, x, aid, name, bus, vol, loop=False):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.85
    os.makedirs(OUT_DIR, exist_ok=True)
    p = os.path.join(OUT_DIR, rel)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    ENTRIES.append({"id": aid, "name": name, "template": "res://assets/templates/audio/red_thaw/" + rel, "bus": bus,
                    "volume_db": vol, "loop": loop, "status": "READY",
                    "notes": "Generated placeholder (tools/art/gen_red_thaw_audio.py). WAV or OGG override accepted."})


def shaped_noise(n, env_fn):
    """White noise filtered in the frequency domain by env_fn(freqs) -> gain."""
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(spec * env_fn(f), n)


def smooth(n, points, rate):
    """Slow random control curve: `points` random knots, cosine interpolated."""
    k = RNG.random(points + 1) * rate
    t = np.linspace(0, points, n)
    i = np.floor(t).astype(int); i = np.minimum(i, points - 1)
    u = t - i
    u = (1 - np.cos(u * math.pi)) / 2
    return k[i] * (1 - u) + k[i + 1] * u


def loopify(x, fade):
    """Crossfade the tail into the head so the loop is seamless."""
    f = int(fade * SR)
    head, tail = x[:f], x[-f:]
    w = np.linspace(0, 1, f)
    x = x[:-f].copy()
    x[:f] = head * w + tail * (1 - w)
    return x


def reverb(x, seconds=1.2, wet=0.35, damp=3000):
    n = int(seconds * SR)
    ir = RNG.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    ir = shaped_noise(n, lambda f: 1 / (1 + (f / damp) ** 2)) * np.exp(-np.linspace(0, 6, n))
    y = np.fft.irfft(np.fft.rfft(np.concatenate([x, np.zeros(n)])) * np.fft.rfft(np.concatenate([ir, np.zeros(len(x))])), len(x) + n)
    y = y / (np.max(np.abs(y)) or 1)
    out = np.concatenate([x, np.zeros(n)]) * (1 - wet) + y * wet * np.max(np.abs(x))
    return out


def lowpass(x, cutoff):
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (f / cutoff) ** 4), n)


def voice(f0_curve, vowel_curve, amp_curve, breath=0.25, jitter=0.012):
    """Additive harmonic voice. f0/amp per-sample arrays; vowel_curve a list of
    vowel keys per sample block (one vowel per syllable)."""
    n = len(f0_curve)
    f0 = f0_curve * (1 + jitter * smooth(n, max(2, n // 400), 2.0) - jitter)
    phase = np.cumsum(2 * math.pi * f0 / SR)
    out = np.zeros(n)
    nh = 40
    for h in range(1, nh + 1):
        fh = f0 * h
        gain = np.zeros(n)
        for (fc, bw), _ in zip(vowel_curve, range(3)):
            pass
        # formant envelope per sample (vowel_curve gives arrays F1..F3)
        F = vowel_curve
        for k in range(3):
            fc, bw = F[k]
            gain += np.exp(-0.5 * ((fh - fc) / (bw * 1.6)) ** 2) * (1.0, 0.6, 0.3)[k]
        gain *= 1 / (1 + (fh / 4000) ** 2)
        gain *= (fh < SR / 2 - 200)
        out += np.sin(phase * h) * gain / h ** 0.6
    noise = shaped_noise(n, lambda f: np.exp(-0.5 * ((f - 1600) / 1400) ** 2) + 0.2)
    sig = out / (np.max(np.abs(out)) or 1) * (1 - breath) + noise / (np.max(np.abs(noise)) or 1) * breath
    return sig * amp_curve


def syllables(pattern, f0_start, f0_end, dur_range, gap_range, breath=0.3, vowel="a", hum=False):
    """A run of short voiced syllables (a laugh): returns the signal."""
    parts = []
    k = len(pattern)
    for i, strength in enumerate(pattern):
        d = RNG.uniform(*dur_range)
        n = int(d * SR)
        t = np.linspace(0, 1, n)
        f0s = f0_start + (f0_end - f0_start) * (i / max(1, k - 1))
        f0 = f0s * (1 + 0.12 * (1 - t)) * RNG.uniform(0.96, 1.04)
        amp = np.sin(np.pi * np.clip(t * 1.15, 0, 1)) ** 0.7 * strength
        v = VOWELS["m" if hum else vowel]
        x = voice(f0, v, amp, breath=breath)
        # an "h" breath burst at the start of each syllable (laughs are breathy)
        hb = int(0.035 * SR)
        x[:hb] += shaped_noise(hb, lambda f: np.exp(-0.5 * ((f - 1500) / 900) ** 2)) * np.linspace(0, 0.6, hb) * strength * 0.02
        parts.append(x)
        parts.append(np.zeros(int(RNG.uniform(*gap_range) * SR)))
    return np.concatenate(parts)


# ---------------------------------------------------------------- ambience
def wind(seconds, gust_rate, base_cut, whistle, level_curve=1.0):
    n = int(seconds * SR)
    lo = shaped_noise(n, lambda f: 1 / (1 + (f / base_cut) ** 2) * (f > 30))
    hi = shaped_noise(n, lambda f: np.exp(-0.5 * ((f - 900) / 500) ** 2))
    gust = 0.35 + smooth(n, int(seconds * gust_rate), 1.0)
    x = lo / np.max(np.abs(lo)) * gust + hi / np.max(np.abs(hi)) * gust ** 2 * 0.35
    if whistle:
        f = 600 + 260 * smooth(n, int(seconds / 2), 1.0)
        w = np.sin(np.cumsum(2 * math.pi * f / SR)) * np.clip(smooth(n, int(seconds / 3), 1.0) - 0.55, 0, 1) * 0.12
        x = x + w
    return x * level_curve


def ambience():
    x = loopify(wind(26, 0.5, 260, True), 3)
    save("template_cold_wind.wav", x, "amb.cold_wind", "Cold wind through pines (outdoor ambience)", "Ambience", -10.0, True)
    n = int(26 * SR)
    hiss = shaped_noise(n, lambda f: np.exp(-0.5 * ((f - 5000) / 2500) ** 2))
    x = wind(26, 0.8, 420, True) + hiss / np.max(np.abs(hiss)) * 0.25
    save("template_snow_wind.wav", loopify(x, 3), "amb.snow_wind", "Snowfall and gusting wind (weather loop)", "Ambience", -12.0, True)
    x = lowpass(wind(24, 0.4, 200, False), 380)
    t = np.arange(len(x)) / SR
    creak = np.zeros_like(x)
    for c0 in (5.3, 14.8, 21.1):  # an old timber creak now and then
        i0 = int(c0 * SR); m = int(0.5 * SR)
        tt = np.arange(m) / SR
        creak[i0:i0 + m] += np.sin(2 * math.pi * (110 + 40 * tt) * tt) * np.exp(-tt * 6) * 0.25 * (np.sin(2 * math.pi * 23 * tt) > 0)
    save("template_wind_muffled.wav", loopify(x + creak, 3), "amb.wind_muffled", "Wind outside, heard indoors", "Ambience", -14.0, True)


# ---------------------------------------------------------------- laughter (settlements, daytime)
def laughter():
    # suppressed: a hum-laugh through closed lips, as if someone is trying not to be heard
    x = syllables([0.5, 0.8, 0.7, 0.55, 0.35], 210, 170, (0.09, 0.13), (0.05, 0.09), breath=0.45, hum=True)
    x = np.concatenate([x, syllables([0.25, 0.2], 180, 160, (0.12, 0.16), (0.08, 0.1), breath=0.6, vowel="h")])
    save("template_laugh_suppressed.wav", reverb(lowpass(x, 2600), 1.0, 0.3), "sfx.laugh_suppressed",
         "Suppressed laughter (settlement)", "SFX", -12.0)
    # a giggle: higher, quick, breathy, falling apart at the end
    x = syllables([0.6, 0.75, 0.7, 0.6, 0.5, 0.4, 0.25], 380, 300, (0.06, 0.09), (0.03, 0.06), breath=0.4, vowel="i")
    save("template_giggle.wav", reverb(lowpass(x, 3200), 1.3, 0.35), "sfx.giggle", "Giggling behind a wall", "SFX", -13.0)
    # distant: an adult laugh heard from far off, muffled by walls and snow
    x = syllables([0.7, 0.9, 0.8, 0.7, 0.55], 170, 130, (0.11, 0.15), (0.06, 0.1), breath=0.3, vowel="a")
    save("template_laugh_distant.wav", reverb(lowpass(x, 900), 1.8, 0.55, damp=1200), "sfx.laugh_distant",
         "Distant laughter (settlement)", "SFX", -14.0)
    # a single, close, choked-off giggle
    x = syllables([0.5, 0.7, 0.3], 300, 260, (0.07, 0.1), (0.03, 0.05), breath=0.55, hum=True)
    save("template_giggle_close.wav", reverb(lowpass(x, 2200), 0.6, 0.2), "sfx.giggle_close", "A stifled giggle, very close", "SFX", -16.0)


# ---------------------------------------------------------------- the frightened survivor
def mutter():
    for k, (f0, n_syl) in enumerate(((170, 9), (190, 7))):
        parts = []
        for i in range(n_syl):
            d = RNG.uniform(0.09, 0.18); n = int(d * SR)
            t = np.linspace(0, 1, n)
            v = VOWELS[RNG.choice(["a", "e", "u", "m", "i"])]
            parts.append(voice(f0 * (1 + 0.08 * np.sin(t * 3)) * RNG.uniform(0.93, 1.05), v,
                               np.sin(np.pi * t) ** 0.8 * RNG.uniform(0.4, 0.8), breath=0.55))
            parts.append(np.zeros(int(RNG.uniform(0.02, 0.07 if i % 3 else 0.25) * SR)))
        x = lowpass(np.concatenate(parts), 1800)
        save(f"template_mutter_{'ab'[k]}.wav", reverb(x, 0.5, 0.15), f"sfx.mutter_{'ab'[k]}",
             "Frightened muttering", "SFX", -14.0)


# ---------------------------------------------------------------- Burnt Ones
def burnt():
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    breath = np.zeros(n)
    for s0, d in ((0.0, 0.5), (0.7, 0.45), (1.3, 0.6)):  # ragged in-out breaths with a wet catch
        i0, m = int(s0 * SR), int(d * SR)
        env = np.sin(np.linspace(0, math.pi, m)) ** 1.5
        breath[i0:i0 + m] += shaped_noise(m, lambda f: np.exp(-0.5 * ((f - 900) / 700) ** 2)) * env
    breath /= np.max(np.abs(breath))
    catch = voice(np.full(n, 95.0), VOWELS["u"], np.exp(-((t - 1.45) / 0.08) ** 2) * 0.6, breath=0.6)
    save("template_burnt_breath.wav", reverb(breath * 0.8 + catch, 0.4, 0.15), "sfx.burnt_breath",
         "Burnt One — ragged breathing", "SFX", -10.0)
    x = np.concatenate([shaped_noise(int(0.18 * SR), lambda f: np.exp(-0.5 * ((f - 1300) / 900) ** 2)) * 0.04 * np.linspace(0.3, 1, int(0.18 * SR)),
                        syllables([0.9, 0.8, 0.6], 240, 200, (0.06, 0.08), (0.02, 0.04), breath=0.45, vowel="e")])
    save("template_burnt_notice.wav", reverb(lowpass(x, 3000), 0.5, 0.2), "sfx.burnt_notice",
         "Burnt One — sharp breath and a short laugh (noticed you)", "SFX", -6.0)
    n = int(0.35 * SR); tt = np.linspace(0, 1, n)
    x = voice(np.full(n, 120.0) * (1 + 0.3 * tt), VOWELS["a"], np.sin(np.pi * tt) ** 0.5, breath=0.5)
    save("template_burnt_attack.wav", x, "sfx.burnt_attack", "Burnt One — effort grunt (attack)", "SFX", -5.0)
    n = int(0.3 * SR); tt = np.linspace(0, 1, n)
    x = voice(np.full(n, 160.0) * (1 - 0.3 * tt), VOWELS["e"], np.exp(-tt * 4), breath=0.5)
    thud = shaped_noise(n, lambda f: 1 / (1 + (f / 180) ** 2)) * np.exp(-tt * 18)
    save("template_burnt_hit.wav", x + thud / np.max(np.abs(thud)) * 0.8, "sfx.burnt_hit", "Burnt One — hit (pain)", "SFX", -5.0)
    n = int(1.1 * SR); tt = np.linspace(0, 1, n)
    x = voice(np.full(n, 130.0) * (1 - 0.35 * tt), VOWELS["u"], np.exp(-tt * 2.5) * (1 - 0.5 * (np.sin(tt * 40) > 0.7)), breath=0.6)
    fall = shaped_noise(n, lambda f: 1 / (1 + (f / 150) ** 2)) * np.exp(-((tt - 0.55) / 0.04) ** 2)
    save("template_burnt_death.wav", x + fall / np.max(np.abs(fall)), "sfx.burnt_death", "Burnt One — choked fall", "SFX", -5.0)


# ---------------------------------------------------------------- iteration 011
def burnt_screech():
    """A strained human throat cry: a ragged inhale, then a rising, cracking
    scream with rough (subharmonic + noise) excitation and a dry tail. Three
    variations so it never repeats identically. Human, not monstrous."""
    for k, (f_lo, f_hi, dur, crack) in enumerate(((330, 900, 1.55, 0.62), (290, 780, 1.85, 0.55), (370, 1050, 1.3, 0.7))):
        n = int(dur * SR); t = np.linspace(0, 1, n)
        rise = np.clip(t / crack, 0, 1) ** 0.6
        f0 = f_lo + (f_hi - f_lo) * rise
        f0 = np.where(t > crack, f_hi * (1 - 0.35 * (t - crack) / (1 - crack)), f0)
        f0 = f0 * (1 + 0.035 * np.sin(2 * math.pi * 7.5 * t * dur) + 0.02 * RNG.standard_normal(n).cumsum() / np.sqrt(n) * 3)
        amp = np.clip(t * 12, 0, 1) * np.clip((1 - t) * 3.5, 0, 1) ** 0.7
        v = voice(f0, VOWELS["a"], amp, breath=0.35, jitter=0.05)
        sub = voice(f0 * 0.5, VOWELS["e"], amp * 0.45, breath=0.2, jitter=0.07)   # vocal-fry roughness
        x = v + sub
        x = np.tanh(x / (np.max(np.abs(x)) or 1) * 2.4)                            # strained, clipped
        inh = shaped_noise(int(0.28 * SR), lambda f: np.exp(-0.5 * ((f - 1800) / 900) ** 2))
        inh = inh / np.max(np.abs(inh)) * np.linspace(0, 0.35, len(inh))
        x = np.concatenate([inh, x])
        save(f"template_burnt_screech_{'abc'[k]}.wav", reverb(lowpass(x, 5200), 1.1, 0.28, damp=2500),
             "sfx.burnt_screech" if k == 0 else f"sfx.burnt_screech_{'abc'[k]}", "Burnt One — screech" + ("" if k == 0 else f" (variation {k + 1})"), "SFX", -3.0)


if __name__ == "__main__":
    ambience(); laughter(); mutter(); burnt(); burnt_screech()
    with open(os.path.join(ROOT, "assets", "manifest", "audio_red_thaw.json"), "w") as f:
        json.dump({"kind": "audio", "category": "red_thaw", "assets": ENTRIES}, f, indent="\t"); f.write("\n")
    print("red thaw audio generated:", len(ENTRIES))
