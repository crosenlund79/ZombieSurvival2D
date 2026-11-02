#!/usr/bin/env python3
"""Generates Phase A technical placeholder art/audio and test fixtures.

Run from the repository root:  python3 tools/gen_placeholders.py
Never overwrites files in assets/overrides/ (creator territory).
"""
import math, os, random, struct, wave
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def out(rel):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    assert "assets/overrides" not in rel, "refusing to write creator overrides"
    return p


def player(color, mark, rel):
    im = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((22, 112, 74, 126), fill=(0, 0, 0, 70))            # shadow
    d.rounded_rectangle((26, 50, 70, 116), 14, fill=color, outline=(30, 28, 24), width=4)
    d.ellipse((30, 12, 66, 48), fill=(214, 180, 140), outline=(30, 28, 24), width=4)
    d.rectangle((34, 60, 62, 70), fill=(40, 36, 30))
    d.text((42, 80), mark, fill=(255, 255, 255))
    im.save(out(rel))


def gate(open_, rel):
    im = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in (6, 170):
        d.rectangle((x, 20, x + 16, 124), fill=(110, 82, 52), outline=(30, 28, 24), width=3)
    if open_:
        d.polygon([(22, 40), (60, 20), (60, 100), (22, 116)], fill=(150, 120, 80), outline=(30, 28, 24))
    else:
        for i in range(6):
            x = 24 + i * 24
            d.rectangle((x, 36, x + 20, 116), fill=(150, 120, 80), outline=(30, 28, 24), width=3)
        d.rectangle((22, 60, 170, 70), fill=(120, 92, 60), outline=(30, 28, 24), width=2)
    im.save(out(rel))


def tone(rel, freqs, dur, noise=0.0, decay=6.0, rate=22050):
    n = int(dur * rate)
    rnd = random.Random(7)
    frames = bytearray()
    for i in range(n):
        t = i / rate
        env = math.exp(-decay * t) * min(1.0, t * 200)
        v = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        v = (v * (1 - noise) + (rnd.random() * 2 - 1) * noise) * env * 0.6
        frames += struct.pack("<h", int(max(-1, min(1, v)) * 32767))
    with wave.open(out(rel), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(bytes(frames))


if __name__ == "__main__":
    player((96, 112, 66), "T", "assets/templates/characters/player/template_body_01.png")
    gate(False, "assets/templates/world/doors/template_gate_closed.png")
    gate(True, "assets/templates/world/doors/template_gate_open.png")
    tone("assets/templates/audio/world/template_door_open.wav", [180, 260], 0.45, noise=0.35, decay=5)
    tone("assets/templates/audio/world/template_door_close.wav", [90, 130], 0.35, noise=0.5, decay=9)
    tone("assets/templates/audio/ui/template_click.wav", [1200], 0.06, decay=60)
    # Test fixtures (copied into override folders by tests, then removed).
    player((170, 60, 50), "O", "tests/fixtures/overrides/characters/player/body_01.png")
    tone("tests/fixtures/overrides/audio/world/door_open.wav", [600, 900], 0.3, decay=8)
    with open(out("tests/fixtures/overrides/characters/player/corrupt_body_01.png"), "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\nthis is not a real png")
    print("placeholders generated")
