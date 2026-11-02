#!/usr/bin/env python3
"""Helper: insert script-guide rows (EN + DA) before an anchor row. Used by iteration work;
usage from Python: add_rows([(path, deps, en, da, anchor_path), ...])."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def add_rows(rows):
    for lang, idx in (("EN", 2), ("DA", 3)):
        p = os.path.join(ROOT, f"docs/guides/SCRIPT_GUIDE_{lang}.md")
        s = open(p, encoding="utf-8").read()
        for r in rows:
            line = f"| `{r[0]}` | {r[1]} | {r[idx]} |\n"
            if f"`{r[0]}`" in s:
                continue
            key = f"| `{r[4]}`"
            assert key in s, key
            s = s.replace(key, line + key, 1)
        open(p, "w", encoding="utf-8").write(s)
