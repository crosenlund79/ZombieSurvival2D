#!/usr/bin/env python3
"""Merge translation strings into locale/strings.json (keeps existing keys unless --force).
Usage from Python: add({"KEY": ("English", "Dansk"), ...})"""
import collections, json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "locale", "strings.json")


def add(strings, force=False):
    d = json.load(open(PATH, encoding="utf-8"), object_pairs_hook=collections.OrderedDict)
    n = 0
    for k, (en, da) in strings.items():
        if k in d and not force:
            continue
        d[k] = {"da": da, "en": en}
        n += 1
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    return n
