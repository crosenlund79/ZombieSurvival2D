#!/usr/bin/env python3
"""Iteration 015 A: lay out the larger world.

  1. python3 tools/build_settlements.py  (settlements read their offsets from world_layout)
  2. python3 tools/build_wilderness.py   (the five wilderness regions + their cabins)
  3. this script: puts the hand-made outdoor regions (the Pine Woods, the
     service station, Ashgrove) at their world offsets and removes their
     road-end portals and vehicle exits — outdoor regions now connect along
     their shared edges (WorldGeo) — and checks the whole layout: no overlaps,
     every outdoor region present, every main road continuing across each edge.
Idempotent. Usage: python3 tools/build_world.py [--all]  (--all also runs 1 and 2)
"""
import json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_side_interiors import dump_json, ROOT  # noqa: E402
import world_layout as WL  # noqa: E402

HANDMADE = {"homestead": "scenes/regions/homestead/homestead.tscn",
            "service_station": "scenes/regions/service_station/service_station.tscn",
            "town": "scenes/regions/town/town.tscn"}


def region_file(rid):
    return os.path.join(ROOT, "content", "regions", rid.replace(".", "_") + ".json")


def patch_handmade():
    outdoor = set(WL.REGIONS)
    for rid, scene in HANDMADE.items():
        p = region_file(rid)
        d = json.load(open(p))
        d.setdefault("map", {})["offset"] = WL.offset(rid)
        d["vehicle_exits"] = []
        gone = [e["id"] for e in d["entities"] if e.get("type") == "portal" and str(e.get("target", {}).get("region", "")) in outdoor]
        d["entities"] = [e for e in d["entities"] if e["id"] not in gone]
        dump_json(p, d)
        sp = os.path.join(ROOT, scene)
        s = open(sp).read()
        for eid in gone:
            # drop the PortalView node bound to the removed portal
            s = re.sub(r'\n\[node name="[^"]+" type="Node2D" parent="YSort"\]\nscript = ExtResource\("[^"]+"\)\nentity_id = "%s"\n' % re.escape(eid), "\n", s)
        open(sp, "w").write(s)
        print(f"  {rid}: offset {WL.offset(rid)}, removed {gone}")


# Iteration 015 B: timber houses and signs of former life in the hand-made outdoor scenes.
TIMBER_SWAP = {"world.house_a": "world.cabin_porch", "world.house_b": "world.cabin_large", "world.house_collapsed": "world.cabin_ruin"}
DRESSING = {
    "scenes/regions/town/town.tscn": [
        ("env.woodpile", 330, 1440, (150, 30)), ("env.bicycle", 700, 1460, None), ("env.fence_broken", 820, 1530, None),
        ("env.bench", 1060, 1450, (130, 16)), ("env.barrels", 1420, 1450, (110, 30)), ("env.belongings", 1500, 1560, None),
        ("env.woodpile", 1780, 1440, (150, 30)), ("env.stove_rusted", 2170, 1455, (90, 24)), ("env.crates", 2280, 935, (130, 30)),
        ("env.barrels", 2760, 960, (110, 30)), ("env.sign_wood", 140, 920, (20, 10)), ("env.fence_broken", 2420, 1530, None),
        ("env.buried_car", 2050, 1180, (380, 50))],
    "scenes/regions/service_station/service_station.tscn": [
        ("env.barrels", 1720, 640, (110, 30)), ("env.crates", 2050, 650, (130, 30)), ("env.woodpile", 820, 1070, (150, 30)),
        ("env.fence_broken", 1250, 1100, None), ("env.bicycle", 1600, 1080, None)],
}


def timber_and_dressing():
    for scene, items in DRESSING.items():
        sp = os.path.join(ROOT, scene)
        s = open(sp).read()
        for a, b in TIMBER_SWAP.items():
            s = s.replace(f'asset_id = "{a}"', f'asset_id = "{b}"')
        if "D15_" not in s:
            nodes = []
            for k, (asset, x, y, foot) in enumerate(items):
                nodes += [f'[node name="D15_{k}" type="Node2D" parent="YSort"]', 'script = ExtResource("prop")', f'position = Vector2({x}, {y})',
                          f'asset_id = "{asset}"'] + ([f'footprint = Vector2({foot[0]}, {foot[1]})', 'occlude = true'] if foot else []) + ['']
            s = s.rstrip("\n") + "\n\n" + "\n".join(nodes)
        open(sp, "w").write(s)
    print("  timber houses and dressing in the hand-made scenes")


# Iteration 015 D: locked doors and containers (LockSim). id -> (level 1..3, key item or "").
# A key opens every lock that names it ("keys" = a ring of building keys, "keycard" = a
# security card). EXTRA puts a guaranteed find first in a container's search.
LOCKS = {
    "stillwater.police.armory": (3, "keycard"), "stillwater.police.evidence": (2, "keycard"),
    "stillwater.clinic.drug_store": (2, ""), "stillwater.civic_hall.council_cabinet": (2, ""),
    "stillwater.house.wardrobe": (1, "keys"), "junction.utility.desk": (1, ""),
    "junction.machine_shop.tool_chest": (1, ""), "greyhollow.mine_supply.explosives_locker": (2, "keys"),
    "greyhollow.mine_office.cabinet": (1, "keys"), "harbor.chandlery.flares": (1, ""),
    "harbor.warehouse.tool_chest": (2, ""), "town.hardware.locked_case": (1, ""),
    "town.garage.office_locker": (1, "keys"), "town.pharmacy.wall_cabinet": (1, ""),
    "wild.corran_forest.logging_camp.bench": (1, ""),
    # doors: a storage building, a net shed and two isolated cabins
    "greyhollow.store_shed_entrance": (2, "keys"), "harbor.net_shed_entrance": (1, ""),
    "wild.corran_forest.trapper_door": (2, ""), "wild.corran_forest.hollow_house_door": (1, "keys"),
}
EXTRA = {"greyhollow.mine_office.reception": {"keys": 1}, "town.garage.office_desk": {"keys": 1},
         "stillwater.police.desk": {"keycard": 1}, "wild.corran_forest.cache_truck": {"keys": 1},
         "stillwater.apartments.dresser": {"keys": 1}, "town.garage.tool_chest": {"lockpick": 1}}


def locks():
    import glob
    found = set()
    for f in sorted(glob.glob(os.path.join(ROOT, "content", "regions", "*.json"))):
        d = json.load(open(f))
        hit = False
        for e in d.get("entities", []):
            if e["id"] in LOCKS:
                lvl, key = LOCKS[e["id"]]
                e["lock"] = {"level": lvl, **({"key": key} if key else {})}
                hit = True
                found.add(e["id"])
            if e["id"] in EXTRA:
                e["extra"] = EXTRA[e["id"]]
                hit = True
                found.add(e["id"])
        if hit:
            dump_json(f, d)
    missing = (set(LOCKS) | set(EXTRA)) - found
    assert not missing, missing
    print("  locks:", len(LOCKS), "extra finds:", len(EXTRA))


def check():
    WL.check()
    for rid, (x, y, w, h) in WL.REGIONS.items():
        d = json.load(open(region_file(rid)))
        assert d["map"]["offset"] == [x, y], (rid, d["map"]["offset"], [x, y])
        assert d["bounds"] == [0, 0, w, h], (rid, d["bounds"], [w, h])
        assert not d.get("vehicle_exits"), rid
        for e in d["entities"]:
            if e.get("type") == "portal":
                assert str(e.get("target", {}).get("region", "")) not in WL.REGIONS, (rid, e["id"])
    print("  layout checked:", len(WL.REGIONS), "outdoor regions")


if __name__ == "__main__":
    if "--all" in sys.argv:
        import build_settlements, build_wilderness
        build_settlements.build()
        build_wilderness.build()
    patch_handmade()
    timber_and_dressing()
    locks()
    check()
