#!/usr/bin/env python3
"""Iteration 014 landmarks: the Stillwater Civic Hall (basement + three floors)
and the Greyhollow mine. Both are side-view cross-sections on the shared grid
model (tools/build_side_interiors.Section / the excavation grid), fixed — never
dug. Called by tools/build_settlements.py; ids are stable.

Civic hall: storeys -1 (boiler room and emergency stores), 0 (lobby, records),
1 (council offices), 2 (archive and attic storage), joined by three stair
flights that alternate sides, so you really walk the building floor by floor.

Mine (adit No. 3): an entrance gallery from the hillside, a ladder shaft down to
the second level, a long haulage drift with side chambers, a winze down to the
third level, two collapsed passages (rubble you cannot pass), timber sets,
rails, ore veins, carts and lamps. The grid can grow in every direction: no
depth limit is built into the rules.
"""
from build_side_interiors import Section, CELL


def civic_hall(rid, display, town, door_target):
    s = Section(rid, 24, (-1, 0, 1, 2), display, exterior="side.ext_brick", basement_mat="side.ext_concrete")
    # basement
    s.room(-1, 0, 24, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.label(-1, 3.0, "SIDE_BASEMENT")
    s.container("boiler_tools", "toolbox", 6.0, -1, "int.tool_chest", "int.tool_chest_open", {}, pool="workshop_tools")
    s.container("emergency_a", "crate", 10.0, -1, "int.crate", "int.crate_open", {}, pool="civic_emergency")
    s.container("emergency_b", "shelf", 13.6, -1, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool="civic_emergency")
    s.container("fuel_cage", "garage", 17.4, -1, "int.crate", "int.crate_open", {}, searched=True, pool="fuel_depot")
    s.prop("int.boxes", 20.0, -1)
    # ground floor: lobby and records
    s.room(0, 0, 13, wall="side.wall_office", floor="side.floor_linoleum")
    s.room(0, 13, 24, wall="side.wall_house", floor="side.floor_linoleum")
    s.divider(0, 13)
    s.exit(3.4, town, door_target)
    s.window(0, 7.0)
    s.window(0, 18.0)
    s.label(0, 13.4, "SIDE_RECORDS")
    s.container("lobby_desk", "drawer", 6.6, 0, "int.pharm_counter", "int.pharm_counter", {}, pool="office_desk")
    s.prop("int.armchair", 10.0, 0)
    s.container("records", "locker", 15.4, 0, "int.locker", "int.locker_open", {}, pool="office_files")
    s.container("records_b", "locker", 16.6, 0, "int.locker_open", "int.locker_open", {}, searched=True, pool="office_files")
    s.container("clerk_desk", "drawer", 19.6, 0, "int.dresser", "int.dresser_open", {}, pool="office_desk")
    # first floor: council offices
    s.room(1, 0, 24, wall="side.wall_house_b", floor="side.floorboards")
    s.window(1, 5.0)
    s.window(1, 12.0, boarded=True)
    s.window(1, 19.0)
    s.label(1, 2.2, "SIDE_FLOOR_1")
    s.prop("int.meal_table", 8.0, 1)  # the council table
    s.container("council_cabinet", "locker", 11.4, 1, "int.locker", "int.locker_open", {}, pool="office_files")
    s.container("mayor_desk", "drawer", 15.0, 1, "int.dresser", "int.dresser_open", {}, pool="civic_mayor")
    s.container("bookcase", "shelf", 18.4, 1, "int.bookshelf", "int.bookshelf", {}, pool="household")
    # second floor: archive and attic
    s.room(2, 0, 24, wall="side.wall_office", floor="side.floorboards")
    s.window(2, 9.0, boarded=True)
    s.window(2, 16.0)
    s.label(2, 3.0, "SIDE_FLOOR_2")
    s.container("archive_a", "shelf", 6.0, 2, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool="office_files")
    s.container("archive_b", "shelf", 9.6, 2, "int.metal_shelf_empty", "int.metal_shelf_empty", {}, searched=True, pool="office_files")
    s.container("attic_trunk", "crate", 14.0, 2, "int.crate", "int.crate_open", {}, pool="attic")
    s.prop("int.boxes", 17.0, 2)
    s.container("attic_wardrobe", "locker", 20.0, 2, "int.locker", "int.locker_open", {}, pool="home_closet")
    # stairs: basement→ground (left), ground→first (right), first→second (left)
    s.stairs(1.5, -1, 0, key="stairs_basement", flip=True)
    s.stairs(22.5, 0, 1, key="stairs_main")
    s.stairs(1.5, 1, 2, key="stairs_upper", flip=True)
    return s


# ---------------------------------------------------------------------- the mine
def mine(rid, display, exit_region, exit_pos):
    cols, rows = 64, 30
    open_rects = []
    platforms = []
    ents = []
    props = []

    def x(c):
        return round((c + 0.5) * CELL, 1)

    def floor(r_bottom):
        return (r_bottom + 1) * CELL - 3

    def gallery(c0, c1, top, h=3):
        open_rects.append([c0, top, c1 - c0, h])
        return top + h - 1  # bottom row

    # level 1: the entrance gallery (adit) at rows 4..6, cols 2..34
    b1 = gallery(2, 36, 4)
    # level 2: the haulage drift, rows 12..14, cols 8..60
    b2 = gallery(8, 61, 12)
    # level 3: the deep workings, rows 21..23, cols 20..52
    b3 = gallery(20, 53, 21)
    # a side chamber off level 2 (taller, the old pump room)
    open_rects.append([44, 10, 6, 2])
    # ladder shaft level 1 -> 2 at col 30, winze level 2 -> 3 at col 48
    open_rects.append([30, 7, 1, 5])
    platforms.append([30, b1, 1, 1])
    open_rects.append([48, 15, 1, 6])
    platforms.append([48, b2, 1, 1])
    ents.append({"id": f"{rid}.shaft_1", "type": "stairs", "style": "ladder", "position": [x(30), floor(b2)], "top": floor(b1)})
    ents.append({"id": f"{rid}.winze_2", "type": "stairs", "style": "ladder", "position": [x(48), floor(b3)], "top": floor(b2)})
    # exit to the hillside
    ents.append({"id": f"{rid}.exit", "type": "portal", "position": [x(2.4), floor(b1)], "interact_range": 70, "priority": 2,
                 "side_art": "side.door_ext", "target": {"region": exit_region, "position": list(exit_pos)}, "prompt_key": "PROMPT_LEAVE_MINE"})

    def c(key, kind, col, bottom, art, art_s, pool, searched=False):
        ents.append({"id": f"{rid}.{key}", "type": "container", "kind": kind, "position": [x(col), floor(bottom)], "interact_range": 72,
                     "prompt_key": "PROMPT_SEARCH_" + kind.upper(), "art": art, "art_searched": art_s, "loot": {}, "pool": pool,
                     "initial": {"searched": searched}})

    c("lamp_locker", "locker", 8, b1, "int.locker", "int.locker_open", "mine_lamps")
    c("tool_crate", "crate", 14, b1, "int.crate", "int.crate_open", "mine_tools")
    c("powder_box", "crate", 22, b1, "int.crate_open", "int.crate_open", "mine_store", searched=True)
    c("pump_room_chest", "toolbox", 46, 11, "int.tool_chest", "int.tool_chest_open", "industrial_parts")
    c("supply_cache", "crate", 12, b2, "int.crate", "int.crate_open", "mine_store")
    c("shift_locker", "locker", 38, b2, "int.locker", "int.locker_open", "worker_locker")
    c("deep_cache", "crate", 26, b3, "int.crate", "int.crate_open", "mine_deep")
    c("last_shift", "drawer", 40, b3, "int.dresser", "int.dresser_open", "mine_deep")
    # dressing: timber sets, carts, ore, lamps, rubble where the passage collapsed
    for col in range(6, 36, 6):
        props.append({"asset": "side.mine_beam", "x": x(col), "y": floor(b1), "back": True})
    for col in range(12, 60, 7):
        props.append({"asset": "side.mine_beam", "x": x(col), "y": floor(b2), "back": True})
    for col in range(24, 52, 6):
        props.append({"asset": "side.mine_beam", "x": x(col), "y": floor(b3), "back": True})
    props += [{"asset": "side.mine_cart", "x": x(18), "y": floor(b1)}, {"asset": "side.mine_cart", "x": x(54), "y": floor(b2)},
              {"asset": "side.ore", "x": x(26), "y": floor(b2), "back": True}, {"asset": "side.ore", "x": x(33), "y": floor(b3), "back": True},
              {"asset": "side.ore", "x": x(58), "y": floor(b2), "back": True},
              {"asset": "side.rubble", "x": x(35.3), "y": floor(b1)}, {"asset": "side.rubble", "x": x(52.3), "y": floor(b3)},
              {"asset": "side.rubble", "x": x(8.6), "y": floor(b2)}]
    for col, b in ((10, b1), (26, b1), (20, b2), (40, b2), (30, b3), (45, b3)):
        props.append({"asset": "side.mine_lamp", "x": x(col), "y": floor(b), "back": True})
    return {
        "region_id": rid, "display_key": display, "view": "side", "style": "mine",
        "bounds": [0, 0, cols * CELL, rows * CELL],
        "excavation": {"cell": CELL, "origin": [0, 0], "cols": cols, "rows": rows, "fixed": True,
                       "initial_open": open_rects, "platforms": platforms,
                       "_comment": "Adit No. 3 (tools/build_landmarks.py): three levels, a ladder shaft and a winze, collapsed ends. Fixed."},
        "side_props": props,
        "spawn_points": [[x(3.4), floor(b1)]],
        "surface": {"region": exit_region, "position": list(exit_pos)},
        "climate": {"exposure": 1.0, "fog": 0.0, "shelter": 0.5},
        "interior": True, "ambience": "amb.underground", "ambience2": "amb.mine_drip",
        "tint": [0.3, 0.29, 0.28], "warm": False,
        "entities": ents,
    }
