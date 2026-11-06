#!/usr/bin/env python3
"""Imports selected clips from the creator's `assets/audio inbox/` into the
game's audio templates (iteration 011).

The inbox is never modified: each selected clip is COPIED (and, where noted,
trimmed, faded, level-matched, low-passed or downmixed with ffmpeg) to
`assets/templates/audio/inbox/template_<name>.<ext>` and registered in
`assets/manifest/audio_inbox.json`. The inbox folder carries a `.gdignore`, so
Godot never imports the 149 MB of originals; only these copies ship.

Every selection, its source file and its use is listed in SELECTION and in
docs/guides/ASSET_REPLACEMENT.md. Run from the repository root:
    python3 tools/art/import_audio_inbox.py
Requires ffmpeg.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INBOX = os.path.join(ROOT, "assets", "audio inbox")
OUT = os.path.join(ROOT, "assets", "templates", "audio", "inbox")
MANIFEST = os.path.join(ROOT, "assets", "manifest", "audio_inbox.json")

# id, source (relative to the inbox), output name, ffmpeg filter, bus, volume dB, loop, use
SELECTION = [
    ("amb.heavy_rain", "Ambiance/Ambiance_Storm_02.wav", "heavy_rain.wav",
     "afade=t=in:d=0.05", "Ambience", -8.0, True, "Heavy-rain weather loop (steady rain bed)"),
    ("amb.thunderstorm", "Ambiance/Ambiance_Storm_01.wav", "thunderstorm.wav",
     "volume=4dB", "Ambience", -7.0, True, "Thunderstorm weather loop (rain bed under the thunder claps)"),
    ("sfx.thunder_near", "Impact/Impact 1.wav", "thunder_near.wav",
     "lowpass=f=900,aecho=0.8:0.7:300|900:0.35|0.25,volume=3dB", "SFX", -4.0, False, "Close thunder after a lightning flash"),
    ("sfx.thunder_far", "Impact/Impact Classic 2.wav", "thunder_far.wav",
     "lowpass=f=420,aecho=0.8:0.8:500|1300:0.4|0.3,volume=2dB", "SFX", -8.0, False, "Distant rolling thunder"),
    ("amb.stove_fire", "General effects/Campfire Fire Loop 3.wav", "stove_fire.wav",
     "volume=2dB", "Ambience", -12.0, True, "Crackling stove inside the hunter's cabin (warmth)"),
    ("sfx.body_drop", "Body drop/Body Drop 2.wav", "body_drop.wav",
     "atrim=0:1.2,afade=t=out:st=0.9:d=0.3", "SFX", -4.0, False, "A Burnt One collapses (death fall)"),
    ("sfx.swing", "Movement/Swing 3.wav", "swing.wav",
     "atrim=0:0.7,afade=t=out:st=0.5:d=0.2", "SFX", -6.0, False, "Melee swing (replaces the generated swing)"),
    ("sfx.hit_wood", "Bullet impact/Wood Heavy 1.wav", "hit_wood.wav",
     "", "SFX", -4.0, False, "A blow lands on wood (structures, chopping accent)"),
    ("sfx.hit_metal", "Bullet impact/Metal Heavy 2.wav", "hit_metal.wav",
     "volume=-3dB", "SFX", -6.0, False, "A blow lands on metal (vehicle body, metal barricades)"),
    ("sfx.glass_break", "Bullet impact/Glass 3.wav", "glass_break.wav",
     "", "SFX", -6.0, False, "Glass cracks (searching a shop window)"),
    ("sfx.laugh_mocking_m", "Hero Voice - Male/mocking laugh.wav", "laugh_mocking_m.wav",
     "highpass=f=180,lowpass=f=1800,aecho=0.8:0.6:200|600:0.3|0.2,volume=-4dB", "SFX", -14.0, False,
     "Settlement laughter variant: a man's mocking laugh, muffled behind walls"),
    ("sfx.laugh_mocking_f", "Hero Voice - Female/MOCKING_LAUGH.wav", "laugh_mocking_f.wav",
     "highpass=f=200,lowpass=f=2200,aecho=0.8:0.6:180|500:0.3|0.2", "SFX", -14.0, False,
     "Settlement laughter variant: a woman's short mocking laugh, muffled"),
    ("sfx.voice_trust", "Hero Voice - Female/CAN_I_TRUST_YOU.wav", "voice_trust.wav",
     "lowpass=f=3000,volume=-2dB", "SFX", -10.0, False, "The frightened survivor, whispering when first spoken to"),
    ("ui.click", "UI sounds/Simple Click Sound 11.wav", "ui_click.wav",
     "atrim=0:0.25,afade=t=out:st=0.18:d=0.07", "UI", -10.0, False, "Menu click (replaces the generated click)"),
    ("ui.error", "UI sounds/Error 11.wav", "ui_error.wav",
     "atrim=0:0.6,afade=t=out:st=0.4:d=0.2", "UI", -14.0, False, "Refused action / declined vote"),
    ("music.theme", "Theme/Where the Ice Once Lay.mp3", "theme_where_the_ice_once_lay.ogg",
     "", "Music", -8.0, True, "Main-menu theme \"Where the Ice Once Lay\""),
    # iteration 014: firearms (single shots trimmed from the creator's gun library)
    ("sfx.gun_pistol", "Gun sounds/Assault Rifle Shot 10.wav", "gun_pistol.wav",
     "atrim=0:0.7,highpass=f=160,afade=t=out:st=0.45:d=0.25", "SFX", -3.0, False, "Handgun shot"),
    ("sfx.gun_revolver", "Gun sounds/Assault Rifle Shot 12.wav", "gun_revolver.wav",
     "atrim=0:0.9,lowpass=f=5000,afade=t=out:st=0.6:d=0.3", "SFX", -3.0, False, "Revolver shot (heavier)"),
    ("sfx.gun_shotgun", "Gun sounds/Machine Gun Shot 2.wav", "gun_shotgun.wav",
     "atrim=0:1.0,lowpass=f=2600,volume=3dB,afade=t=out:st=0.6:d=0.4", "SFX", -2.0, False, "Shotgun blast"),
    ("sfx.gun_rifle", "Gun sounds/Assault Rifle Shot 13.wav", "gun_rifle.wav",
     "atrim=0:1.1,aecho=0.8:0.5:350:0.3,afade=t=out:st=0.7:d=0.4", "SFX", -2.0, False, "Rifle shot (echoes off the hills)"),
    ("sfx.gun_mag_out", "Gun sounds/Mag Out.wav", "gun_mag_out.wav", "", "SFX", -8.0, False, "Reload: magazine out"),
    ("sfx.gun_mag_in", "Gun sounds/Mag In.wav", "gun_mag_in.wav", "", "SFX", -8.0, False, "Reload: magazine in"),
    ("sfx.gun_dry", "UI sounds/Simple Click Sound 11.wav", "gun_dry.wav",
     "atrim=0:0.12,lowpass=f=3000,volume=-2dB", "SFX", -6.0, False, "Dry fire: click on an empty chamber"),
]


def convert(src, dst, flt):
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src]
    if flt:
        cmd += ["-af", flt]
    if dst.endswith(".ogg"):
        cmd += ["-c:a", "libvorbis", "-q:a", "5"]
    else:
        cmd += ["-c:a", "pcm_s16le"]
    cmd.append(dst)
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    assets = []
    for aid, src, name, flt, bus, vol, loop, use in SELECTION:
        path = os.path.join(INBOX, src)
        if not os.path.exists(path):
            print("missing in inbox, skipped:", src)
            continue
        base, ext = os.path.splitext(name)
        out_name = "template_" + base + ext
        convert(path, os.path.join(OUT, out_name), flt)
        assets.append({"id": aid, "name": use, "template": "res://assets/templates/audio/inbox/" + out_name, "bus": bus,
                       "volume_db": vol, "loop": loop, "status": "READY",
                       "notes": "From the creator's audio inbox: '%s' (copied%s by tools/art/import_audio_inbox.py)." % (
                           src, ", processed: " + flt if flt else "")})
    # A selection whose id already exists in another manifest REPLACES that entry's
    # template (the generated original stays on disk); new ids go to audio_inbox.json.
    mdir = os.path.dirname(MANIFEST)
    new_assets = []
    for a in assets:
        replaced = False
        for fn in sorted(os.listdir(mdir)):
            if not fn.endswith(".json") or fn == os.path.basename(MANIFEST):
                continue
            mp = os.path.join(mdir, fn)
            m = json.load(open(mp))
            for e in m.get("assets", []):
                if e.get("id") == a["id"]:
                    if "replaced_template" not in e:
                        e["replaced_template"] = e["template"]
                    e["template"] = a["template"]; e["notes"] = a["notes"]; e["volume_db"] = a["volume_db"]
                    replaced = True
            if replaced:
                with open(mp, "w") as f:
                    json.dump(m, f, indent="\t"); f.write("\n")
                print("replaced", a["id"], "in", fn)
                break
        if not replaced:
            new_assets.append(a)
    with open(MANIFEST, "w") as f:
        json.dump({"kind": "audio", "category": "inbox", "assets": new_assets}, f, indent="\t"); f.write("\n")
    print("imported from the audio inbox:", len(assets))
