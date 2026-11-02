#!/usr/bin/env python3
"""Freshness check: every .gd script must be listed in both script guides,
and every listed script must exist. Prints PASS/WARN/FAIL; exit 1 on FAIL."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDES = ["docs/guides/SCRIPT_GUIDE_EN.md", "docs/guides/SCRIPT_GUIDE_DA.md"]
scripts = set()
for base in ("src", "tests", "scenes"):
    for d, _, files in os.walk(os.path.join(ROOT, base)):
        if ".gdignore" in files:
            continue
        for f in files:
            if f.endswith(".gd"):
                scripts.add(os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, "/"))
fail = False
for g in GUIDES:
    text = open(os.path.join(ROOT, g), encoding="utf-8").read()
    listed = set(re.findall(r"`((?:src|tests|scenes)/[^`]+\.gd)`", text))
    for s in sorted(scripts - listed):
        print(f"FAIL {g}: {s} is not documented"); fail = True
    for s in sorted(listed - scripts):
        print(f"FAIL {g}: {s} is documented but does not exist"); fail = True
    if dupes := [s for s in listed if text.count(f"`{s}`") > 1]:
        print(f"WARN {g}: listed more than once: {', '.join(sorted(dupes))}")
    print(f"PASS {g}: {len(listed & scripts)}/{len(scripts)} scripts documented")
sys.exit(1 if fail else 0)
