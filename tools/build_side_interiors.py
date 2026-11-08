#!/usr/bin/env python3
"""Side-view building interiors (iteration 014, The Five Settlements).

Every enterable building is a cross-section region ("view": "side", "style":
"building"): its rooms are the open cells of a fixed excavation grid (the same
data model as the bunker, so the side-view walking, climbing, reach and host
rules apply unchanged), storeys are stacked with a slab row between them,
stairwells are open columns with landings ("platforms") on each upper floor,
and the walls, wallpaper, windows, dividers and furniture come from the
region definition. The outdoor world stays top-down.

This module holds the layout builder (Section) and the specs for the original
buildings: the hunter's cabin, the House on Main Street (with its cellar),
the two Ashgrove houses and the five Ashgrove shops. Other generators (new
settlements, the hideout, the four-storey block) import Section from here.

Container, portal and other entity ids are stable, so saved states (searched
containers, the cellar hatch, claimed starter bags) carry over. Re-running is
idempotent. Usage: python3 tools/build_side_interiors.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 64
ROWS = 4          # open rows per storey (a storey reads 160 px tall on screen)
MARGIN = 4        # cells of outside around the building
SKY = 3           # rows above the roof


def dump_json(path, d):
    with open(path, "w") as f:
        json.dump(d, f, indent="\t", ensure_ascii=False)
        f.write("\n")


# Iteration 015 B: the Ashgrove interiors and the cabin get lived-in dressing (tools/interior_dressing.py).
DRESS = {"homestead.farmhouse": ("cabin", 0.5), "town.house": ("home", 1.0), "town.house_west": ("home", 1.0),
         "town.house_east": ("home", 1.0), "town.grocery": ("store", 1.0), "town.pharmacy": ("shop", 1.0),
         "town.hardware": ("workshop", 1.0), "town.clothing": ("outfitters", 1.0), "town.garage": ("workshop", 1.0)}


class Section:
    """A building cross-section. width = interior cells; storeys = levels, e.g. [-1, 0, 1, 2]."""

    def __init__(self, rid, width, storeys=(0,), display="", exterior="side.ext_siding", basement_mat="side.ext_concrete"):
        self.rid = rid
        self.width = width
        self.storeys = sorted(storeys)
        self.top = max(self.storeys)
        self.display = display
        self.exterior = exterior
        self.basement_mat = basement_mat
        self.cols = width + 2 + MARGIN * 2
        # row layout: SKY, roof slab, then each storey (top first) = ROWS open + 1 slab
        n_above = len([s for s in self.storeys if s >= 0])
        n_below = len([s for s in self.storeys if s < 0])
        self.rows = SKY + 1 + (n_above + n_below) * (ROWS + 1) + 3
        self.rooms = []        # {"rect", "wall", "floor"}
        self.windows = []
        self.dividers = []
        self.labels = []
        self.props = []
        self.entities = []
        self.open = []         # cell rects
        self.platforms = []
        self.stairs_cols = []
        for s in self.storeys:
            self.open.append([self.c0(), self.storey_top_row(s), self.width, ROWS])

    # ---- geometry
    def c0(self):
        return MARGIN + 1

    def storey_top_row(self, s):
        idx = self.top - s  # 0 for the top storey
        return SKY + 1 + idx * (ROWS + 1)

    def floor_row(self, s):  # the slab row under storey s
        return self.storey_top_row(s) + ROWS

    def ground_row(self):
        return self.floor_row(0)

    def x(self, cell):
        """Plan x of a position `cell` cells from the left inner wall (float)."""
        return round((self.c0() + cell) * CELL, 1)

    def y(self, s):
        """Plan y just above the floor of storey s (where feet rest)."""
        return self.floor_row(s) * CELL - 3

    def y_mid(self, s, frac=0.4):
        return round((self.storey_top_row(s) + ROWS * frac) * CELL, 1)

    # ---- authoring
    def room(self, s, c_from, c_to, wall="side.wall_house", floor="side.floorboards"):
        self.rooms.append({"rect": [self.c0() + c_from, self.storey_top_row(s), c_to - c_from, ROWS], "wall": wall, "floor": floor})

    def divider(self, s, cell, door=True):
        x = self.x(cell)
        top = self.storey_top_row(s) * CELL
        door_top = top + (1.4 * CELL if door else ROWS * CELL)
        self.dividers.append([x, top, door_top, self.floor_row(s) * CELL])

    def window(self, s, cell, boarded=False):
        w = [self.x(cell), self.y_mid(s, 0.42)]
        if boarded:
            w.append("boarded")
        self.windows.append(w)

    def label(self, s, cell, key):
        self.labels.append([self.x(cell), self.storey_top_row(s) * CELL + 28, key])

    def prop(self, asset, cell, s, hang=False, back=False, flip=False, dy=0):
        p = {"asset": asset, "x": self.x(cell), "y": self.y(s) + dy}
        if hang:
            p["y"] = self.storey_top_row(s) * CELL + 4
            p["hang"] = True
        if back:
            p["back"] = True
        if flip:
            p["flip"] = True
        self.props.append(p)

    def stairs(self, cell, s_from, s_to, key=None, flip=False):
        """A stair flight in column `cell` from storey s_from up to s_to (adjacent or more)."""
        col = self.c0() + int(cell)
        lo, hi = min(s_from, s_to), max(s_from, s_to)
        for s in range(lo, hi):
            self.open.append([col, self.floor_row(s + 1), 1, 1])  # the slab hole above storey s
        for s in range(lo + 1, hi + 1):
            self.platforms.append([col, self.storey_top_row(s) + ROWS - 1, 1, 1])
        for s in range(lo, hi):
            self.entities.append({"id": f"{self.rid}.{key or 'stairs'}_{s}", "type": "stairs",
                                  "position": [round((col + 0.5) * CELL, 1), self.y(s)], "top": self.y(s + 1), "flip": flip})

    def entity(self, e, cell, s):
        e = dict(e)
        e["position"] = [self.x(cell), self.y(s)]
        if not e["id"].startswith(self.rid):
            e["id"] = f"{self.rid}.{e['id']}"
        self.entities.append(e)
        return e

    def container(self, key, kind, cell, s, art, art_searched, loot, searched=False, gear=None, discovery=None, pool=None):
        e = {"id": key, "type": "container", "kind": kind, "interact_range": 72, "prompt_key": "PROMPT_SEARCH_" + kind.upper(),
             "art": art, "art_searched": art_searched, "loot": loot}
        if gear:
            e["gear"] = list(gear)
        if discovery:
            e["discovery"] = discovery
        if pool:
            e["pool"] = pool
        e["initial"] = {"searched": bool(searched)}
        return self.entity(e, cell, s)

    def exit(self, cell, target_region, target_pos, prompt="PROMPT_EXIT_HOUSE", key="exit"):
        return self.entity({"id": key, "type": "portal", "interact_range": 70, "priority": 2, "side_art": "side.door_ext",
                            "target": {"region": target_region, "position": list(target_pos)}, "prompt_key": prompt}, cell, 0)

    # ---- output
    def spawn(self, cell=1.6):
        return [self.x(cell), self.y(0)]

    def definition(self, extra):
        if self.rid in DRESS and not getattr(self, "_dressed", False):
            import interior_dressing  # iteration 015 B (imported here: it imports this module)
            theme, density = DRESS[self.rid]
            interior_dressing.dress(self, theme, seed=sum(map(ord, self.rid)), density=density)
            self._dressed = True
        env = [MARGIN, SKY, self.width + 2, self.floor_row(min(self.storeys)) + 1 - SKY]
        d = {
            "region_id": self.rid,
            "display_key": self.display,
            "view": "side",
            "style": "building",
            "bounds": [0, 0, self.cols * CELL, self.rows * CELL],
            "excavation": {"cell": CELL, "origin": [0, 0], "cols": self.cols, "rows": self.rows, "fixed": True,
                           "initial_open": self.open, "platforms": self.platforms,
                           "_comment": "Authored building cross-section (tools/build_side_interiors.py); fixed, never dug."},
            "section": {"ground_row": self.ground_row(), "envelope": env, "exterior": self.exterior,
                        "basement": self.basement_mat if min(self.storeys) < 0 else "",
                        "rooms": self.rooms, "windows": self.windows, "dividers": self.dividers, "labels": self.labels},
            "side_props": self.props,
            "spawn_points": [self.spawn()],
            "entities": self.entities,
        }
        d.update(extra)
        return d


def set_portal_target(region_file, entity_id, position):
    p = os.path.join(ROOT, "content", "regions", region_file)
    d = json.load(open(p))
    for e in d["entities"]:
        if e["id"] == entity_id:
            e["target"]["position"] = list(position)
    dump_json(p, d)


INTERIOR = {"climate": {"exposure": 1.0, "fog": 0.0, "shelter": 0.35}, "interior": True, "ambience": "amb.wind_muffled"}


# ====================================================================== the hunter's cabin
def cabin():
    s = Section("homestead.farmhouse", 16, (0,), "REGION_FARMHOUSE", exterior="side.ext_logs")
    s.room(0, 0, 15, wall="side.wall_cabin")
    s.exit(0.7, "homestead", [1160, 700])
    s.window(0, 4.5)
    s.window(0, 11.5)
    s.prop("world.furniture_stove", 2.6, 0)
    s.prop("world.furniture_cupboard", 6.0, 0)
    s.entity({"id": "pantry", "type": "loot", "interact_range": 75, "prompt_key": "PROMPT_SEARCH_PANTRY",
              "loot": {"canned_food": 2}, "restock_minutes": 25, "initial": {"looted_at": -1}}, 6.0, 0)
    s.entity({"id": "club_rack", "type": "weapon_rack", "interact_range": 70, "weapon": "club", "prompt_key": "PROMPT_TAKE_CLUB"}, 4.2, 0)
    s.entity({"id": "shelter", "type": "shelter_site", "interact_range": 84, "build_seconds": 8, "level_template": "bunker_earth",
              "initial": {"stage": "none", "open": False, "tier": "wood"},
              "upgrades": {"wood": {"to": "steel", "cost": {"scrap_metal": 4, "cement": 1}}}}, 8.0, 0)
    s.entity({"id": "hatch_ladder", "type": "portal", "interact_range": 40, "priority": 2, "requires_open": "homestead.farmhouse.shelter",
              "target": {"bunker_of": "homestead.farmhouse.shelter", "depth": -1}, "prompt_key": "PROMPT_CLIMB_DOWN"}, 8.0, 0)
    s.entity({"id": "timber", "type": "stockpile", "interact_range": 80, "bunker_of": "homestead.farmhouse.shelter",
              "prompt_key": "PROMPT_DEPOSIT_WOOD"}, 9.8, 0)
    s.prop("world.furniture_table", 10.9, 0)
    s.entity({"id": "flashlight", "type": "starter_bag", "interact_range": 80, "prompt_key": "PROMPT_TAKE_FLASHLIGHT",
              "kit": {"flashlight": 1}, "art": "item.flashlight", "art_empty": "", "art_offset": [0, -70],
              "initial": {"taken_by": []}, "taken_key": "FLASHLIGHT_TAKEN", "empty_key": "FLASHLIGHT_ALREADY"}, 10.9, 0)
    s.prop("int.dresser", 14.3, 0)
    s.entity({"id": "linen", "type": "loot", "interact_range": 75, "prompt_key": "PROMPT_SEARCH_LINEN",
              "loot": {"cloth": 2}, "restock_minutes": 30, "initial": {"looted_at": -1}}, 14.3, 0)
    s.entity({"id": "bed", "type": "bed", "interact_range": 75, "prompt_key": "PROMPT_SLEEP"}, 12.6, 0)
    s.prop("world.furniture_bed", 12.6, 0, back=True)
    d = s.definition({"surface": {"region": "homestead", "position": [1160, 641]}, "warmth": 1.2, "shelter_group": "home",
                      "ambience": "amb.wind_muffled", "ambience2": "amb.stove_fire", "tint": [0.74, 0.66, 0.56], "warm": True})
    return s, d, [("homestead.json", "homestead.farmhouse_entry")]


# ====================================================================== the House on Main Street (cellar)
def town_house():
    s = Section("town.house", 13, (0,), "REGION_TOWN_HOUSE", exterior="side.ext_logs")
    s.room(0, 0, 13, wall="side.wall_house")
    s.exit(0.7, "town", [1240, 1510])
    s.window(0, 4.0)
    s.window(0, 10.0, boarded=True)
    s.container("pantry", "cupboard", 2.6, 0, "world.furniture_cupboard", "world.furniture_cupboard", {}, searched=True)
    s.entity({"id": "cellar", "type": "shelter_site", "interact_range": 84, "build_seconds": 8, "level_template": "town_cellar",
              "initial": {"stage": "built", "open": False, "tier": "wood"},
              "upgrades": {"wood": {"to": "steel", "cost": {"scrap_metal": 4, "cement": 1}}}}, 5.2, 0)
    s.entity({"id": "cellar_ladder", "type": "portal", "interact_range": 40, "priority": 2, "requires_open": "town.house.cellar",
              "target": {"bunker_of": "town.house.cellar", "depth": -1}, "prompt_key": "PROMPT_CLIMB_DOWN"}, 5.2, 0)
    s.entity({"id": "timber", "type": "stockpile", "interact_range": 80, "bunker_of": "town.house.cellar", "prompt_key": "PROMPT_DEPOSIT_WOOD"}, 7.2, 0)
    s.container("linen", "drawer", 9.0, 0, "int.dresser", "int.dresser_open", {"cloth": 2})
    s.prop("world.furniture_bed", 11.2, 0, back=True)
    s.entity({"id": "bed", "type": "bed", "interact_range": 75, "prompt_key": "PROMPT_SLEEP"}, 11.2, 0)
    d = s.definition({"surface": {"region": "town", "position": [1240, 1456]}, "warmth": 1.0, "shelter_group": "town_house",
                      "ambience": "amb.wind_muffled", "tint": [0.6, 0.58, 0.56]})
    return s, d, [("town.json", "town.house_entry")]


# ====================================================================== two Ashgrove houses (two storeys)
def house_west():
    s = Section("town.house_west", 16, (0, 1), "REGION_TOWN_HOUSE_WEST", exterior="side.ext_logs")
    s.room(0, 0, 9, wall="side.wall_house", floor="side.floor_linoleum")   # kitchen
    s.room(0, 9, 16, wall="side.wall_house_b")                            # living room
    s.room(1, 0, 16, wall="side.wall_house")                              # upstairs bedroom + landing
    s.divider(0, 9)
    s.exit(0.7, "town", [561, 1510])
    s.window(0, 5.0)
    s.window(0, 12.5, boarded=True)
    s.window(1, 8.0)
    s.window(1, 13.0)
    s.container("kitchen_cupboards", "cupboard", 3.0, 0, "int.kitchen_counter", "int.kitchen_counter", {"canned_food": 1, "crackers": 1})
    s.container("fridge", "fridge", 6.0, 0, "int.home_fridge", "int.home_fridge_open", {"water_dirty": 1})
    s.prop("int.meal_table", 7.8, 0)
    s.prop("int.armchair", 11.0, 0)
    s.prop("int.barricade", 12.5, 0)
    s.stairs(14.5, 0, 1)
    s.label(1, 0.4, "SIDE_UPSTAIRS")
    s.container("dresser", "drawer", 4.0, 1, "int.dresser", "int.dresser_open", {"cloth": 1})
    s.prop("world.furniture_bed", 7.0, 1, back=True)
    s.container("closet", "locker", 10.5, 1, "int.locker", "int.locker_open", {}, searched=True)
    s.prop("int.boxes", 12.0, 1)
    d = s.definition({"surface": {"region": "town", "position": [561, 1456]}, "tint": [0.6, 0.58, 0.58], **INTERIOR})
    return s, d, [("town.json", "town.house_west_entrance")]


def house_east():
    s = Section("town.house_east", 16, (0, 1), "REGION_TOWN_HOUSE_EAST", exterior="side.ext_logs")
    s.room(0, 0, 16, wall="side.wall_house_b")
    s.room(1, 0, 16, wall="side.wall_house")
    s.divider(0, 8)
    s.exit(15.2, "town", [1940, 1510])
    s.window(0, 4.0, boarded=True)
    s.window(0, 11.0)
    s.window(1, 3.0, boarded=True)
    s.window(1, 10.0)
    s.container("bookshelf", "shelf", 2.0, 0, "int.bookshelf", "int.bookshelf", {}, searched=True)
    s.prop("int.sofa", 4.8, 0)
    s.container("kitchen_fridge", "fridge", 9.5, 0, "int.home_fridge_open", "int.home_fridge_open", {}, searched=True)
    s.prop("int.kitchen_counter", 11.6, 0)
    s.stairs(1.5, 0, 1, flip=True)
    s.container("dresser", "drawer", 5.0, 1, "int.dresser", "int.dresser_open", {"crackers": 1, "cloth": 1})
    s.prop("world.furniture_bed", 8.5, 1, back=True)
    s.container("wardrobe", "locker", 12.0, 1, "int.locker", "int.locker_open", {"cloth": 2})
    s.container("packed_crate", "crate", 14.0, 1, "int.crate", "int.crate_open", {"canned_food": 1})
    s.prop("int.barricade", 3.0, 1)
    d = s.definition({"surface": {"region": "town", "position": [1940, 1456]}, "tint": [0.58, 0.58, 0.6], **INTERIOR})
    return s, d, [("town.json", "town.house_east_entrance")]


# ====================================================================== the five Ashgrove shops
def grocery():
    s = Section("town.grocery", 30, (0,), "REGION_TOWN_GROCERY", exterior="side.ext_brick")
    s.room(0, 0, 22, wall="side.wall_shop", floor="side.floor_linoleum")
    s.room(0, 22, 30, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.divider(0, 22)
    s.exit(0.7, "town", [632, 926])
    s.window(0, 3.0)
    s.window(0, 7.0)
    s.container("checkout", "drawer", 3.4, 0, "int.checkout", "int.checkout", {"crackers": 1})
    s.container("aisle_a", "shelf", 7.0, 0, "int.gondola_full", "int.gondola_empty", {"canned_food": 2, "crackers": 1})
    s.container("aisle_b", "shelf", 10.8, 0, "int.gondola_sparse", "int.gondola_empty", {"crackers": 1, "water_bottle": 1})
    s.container("aisle_c", "shelf", 14.6, 0, "int.gondola_empty", "int.gondola_empty", {}, searched=True)
    s.container("aisle_d", "shelf", 18.4, 0, "int.gondola_sparse", "int.gondola_empty", {"canned_food": 1, "water_bottle": 1})
    s.container("freezer_a", "fridge", 20.6, 0, "int.freezer", "int.freezer_open", {"canned_food": 1, "water_bottle": 1})
    s.label(0, 22.4, "SIDE_STOREROOM")
    s.container("freezer_b", "fridge", 24.0, 0, "int.freezer_open", "int.freezer_open", {}, searched=True)
    s.container("storeroom_shelf", "shelf", 26.4, 0, "int.metal_shelf_full", "int.metal_shelf_empty", {"canned_food": 2, "water_bottle": 2})
    s.container("storeroom_crate", "crate", 28.6, 0, "int.crate", "int.crate_open", {"crackers": 2})
    s.prop("int.boxes", 22.9, 0)
    d = s.definition({"surface": {"region": "town", "position": [632, 880]}, "tint": [0.5, 0.52, 0.55], **INTERIOR})
    return s, d, [("town.json", "town.grocery_entrance")]


def pharmacy():
    s = Section("town.pharmacy", 24, (0,), "REGION_TOWN_PHARMACY", exterior="side.ext_siding")
    s.room(0, 0, 17, wall="side.wall_shop", floor="side.floor_linoleum")
    s.room(0, 17, 24, wall="side.wall_office", floor="side.floor_linoleum")
    s.divider(0, 17)
    s.exit(0.7, "town", [1112, 926])
    s.window(0, 3.0)
    s.window(0, 7.5)
    s.container("shelf_a", "shelf", 4.0, 0, "int.gondola_sparse", "int.gondola_empty", {"bandage": 1, "water_bottle": 1})
    s.container("shelf_b", "shelf", 7.8, 0, "int.gondola_empty", "int.gondola_empty", {}, searched=True)
    s.container("wall_cabinet", "medical", 10.4, 0, "int.med_cabinet_open", "int.med_cabinet_open", {}, searched=True)
    s.container("counter", "drawer", 13.6, 0, "int.pharm_counter", "int.pharm_counter", {"bandage": 1})
    s.label(0, 17.4, "SIDE_DISPENSARY")
    s.container("dispensary_a", "medical", 18.6, 0, "int.med_cabinet", "int.med_cabinet_open", {"bandage": 2})
    s.container("dispensary_b", "medical", 20.4, 0, "int.med_cabinet", "int.med_cabinet_open", {"bandage": 1, "water_clean": 1})
    s.container("dispensary_crate", "crate", 22.6, 0, "int.crate", "int.crate_open", {"water_bottle": 1})
    d = s.definition({"surface": {"region": "town", "position": [1112, 880]}, "tint": [0.52, 0.54, 0.56], **INTERIOR})
    return s, d, [("town.json", "town.pharmacy_entrance")]


def hardware():
    s = Section("town.hardware", 26, (0,), "REGION_TOWN_HARDWARE", exterior="side.ext_brick")
    s.room(0, 0, 19, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.room(0, 19, 26, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.divider(0, 19)
    s.exit(0.7, "town", [1592, 926])
    s.window(0, 3.0)
    s.window(0, 8.0)
    s.prop("int.pegboard", 3.6, 0, back=True, dy=-60)
    s.container("aisle_fasteners", "shelf", 5.0, 0, "int.metal_shelf_full", "int.metal_shelf_empty", {"scrap_metal": 2, "electrical_parts": 1})
    s.container("aisle_lumber", "shelf", 8.6, 0, "int.gondola_full", "int.gondola_empty", {"wood": 3})
    s.container("aisle_tools", "shelf", 12.4, 0, "int.gondola_sparse", "int.gondola_empty", {"scrap_metal": 1, "electrical_parts": 1, "cement": 1})
    s.container("aisle_bare", "shelf", 15.8, 0, "int.metal_shelf_empty", "int.metal_shelf_empty", {}, searched=True)
    s.label(0, 19.4, "SIDE_STOCKROOM")
    s.container("stock_crate", "crate", 21.0, 0, "int.crate", "int.crate_open", {"wood": 2, "cement": 1, "stovepipe": 1})
    s.container("locked_case", "toolbox", 23.6, 0, "int.tool_chest", "int.tool_chest_open", {}, gear=["flashlight", "hatchet"], discovery="hardware_case")
    s.prop("int.boxes", 25.2, 0)
    d = s.definition({"surface": {"region": "town", "position": [1592, 880]}, "tint": [0.5, 0.5, 0.52], **INTERIOR})
    return s, d, [("town.json", "town.hardware_entrance")]


def clothing():
    s = Section("town.clothing", 24, (0,), "REGION_TOWN_CLOTHING", exterior="side.ext_siding")
    s.room(0, 0, 17, wall="side.wall_house_b", floor="side.floorboards")
    s.room(0, 17, 24, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.divider(0, 17)
    s.exit(0.7, "town", [2072, 926])
    s.window(0, 3.0)
    s.window(0, 7.0)
    s.container("rack_coats", "rack", 3.8, 0, "int.clothes_rack_full", "int.clothes_rack_empty", {"cloth": 2})
    s.container("rack_bare", "rack", 6.8, 0, "int.clothes_rack_empty", "int.clothes_rack_empty", {}, searched=True)
    s.container("rack_mixed", "rack", 9.8, 0, "int.clothes_rack_full", "int.clothes_rack_empty", {"cloth": 1})
    s.container("display_table", "shelf", 12.6, 0, "int.display_table", "int.display_table", {"cloth": 1})
    s.container("fitting_dresser", "drawer", 15.4, 0, "int.dresser", "int.dresser_open", {}, searched=True)
    s.label(0, 17.4, "SIDE_STOCKROOM")
    s.container("stockroom_crate", "crate", 19.0, 0, "int.crate", "int.crate_open", {}, gear=["winter_coat"], discovery="clothing_stockroom")
    s.container("stock_boxes", "crate", 21.6, 0, "int.crate", "int.crate_open", {"cloth": 2})
    d = s.definition({"surface": {"region": "town", "position": [2072, 880]}, "tint": [0.52, 0.5, 0.52], **INTERIOR})
    return s, d, [("town.json", "town.clothing_entrance")]


def garage():
    s = Section("town.garage", 26, (0,), "REGION_TOWN_GARAGE", exterior="side.ext_brick")
    s.room(0, 0, 19, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.room(0, 19, 26, wall="side.wall_office", floor="side.floor_linoleum")
    s.divider(0, 19)
    s.exit(0.7, "town", [2594, 946])
    s.window(0, 10.0)
    s.container("tool_chest", "toolbox", 3.4, 0, "int.tool_chest", "int.tool_chest_open", {"scrap_metal": 2, "electrical_parts": 1})
    s.container("parts_shelf", "garage", 6.2, 0, "int.metal_shelf_full", "int.metal_shelf_empty", {"scrap_metal": 2, "fuel": 1, "stovepipe": 1})
    s.prop("int.car_lift", 10.4, 0)
    s.container("scrap_crate", "garage", 14.2, 0, "int.crate", "int.crate_open", {"scrap_metal": 2, "electrical_parts": 1})
    s.container("locker_a", "locker", 16.4, 0, "int.locker", "int.locker_open", {"fuel": 1})
    s.container("locker_b", "locker", 17.6, 0, "int.locker_open", "int.locker_open", {}, searched=True)
    s.label(0, 19.4, "SIDE_OFFICE")
    s.container("office_desk", "drawer", 21.4, 0, "int.dresser", "int.dresser_open", {"crackers": 1})
    s.container("office_locker", "locker", 24.4, 0, "int.locker", "int.locker_open", {}, searched=True)
    d = s.definition({"surface": {"region": "town", "position": [2594, 900]}, "tint": [0.48, 0.48, 0.5], **INTERIOR})
    return s, d, [("town.json", "town.garage_entrance")]


BUILDINGS = {
    "homestead_farmhouse.json": cabin,
    "town_house.json": town_house,
    "town_house_west.json": house_west,
    "town_house_east.json": house_east,
    "town_grocery.json": grocery,
    "town_pharmacy.json": pharmacy,
    "town_hardware.json": hardware,
    "town_clothing.json": clothing,
    "town_garage.json": garage,
}


def build(specs):
    for fname, fn in specs.items():
        s, d, entries = fn()
        dump_json(os.path.join(ROOT, "content", "regions", fname), d)
        for region_file, eid in entries:
            set_portal_target(region_file, eid, s.spawn())
    return list(specs)


if __name__ == "__main__":
    print("side interiors built:", ", ".join(build(BUILDINGS)))
