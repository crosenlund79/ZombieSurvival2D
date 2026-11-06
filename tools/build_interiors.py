#!/usr/bin/env python3
"""Ashgrove interiors (iteration 013, The Scavenger's Circuit).

Generates, from the layout specs below:
  * content/regions/town_<name>.json      — one region per enterable building
  * scenes/regions/town/<name>_interior.tscn — its top-down 3/4 interior scene
and patches the street (content/regions/town.json + scenes/regions/town/town.tscn):
the old street-front search spots are replaced by entrances.

All interiors share one frame: a 1000 x 460 floor (x 100..1100, y 240..700),
the back wall along y = 240, the front wall with the doorway along y = 700, and
optionally a partition wall (a backroom) with a doorway. Furniture is art from
assets/manifest/visual_circuit.json (replaceable templates). Searchable containers
are entities (type "container", see src/sim/scavenge_sim.gd); everything else is
dressing with collision only.

Re-running is idempotent. Usage: python3 tools/build_interiors.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FX0, FX1, FY0, FY1 = 100, 1100, 240, 700

# ---------------------------------------------------------------------------
# Layout specs. Container: (key, kind, x, y, art_full, art_searched, loot, opts)
#   loot = {} with opts {"searched": True} → already picked clean (shows the
#   searched art from the start); opts may carry "gear", "discovery".
# Prop: (asset, x, y, footprint_w, footprint_h, extra)
# ---------------------------------------------------------------------------
SHOPS = {
    "grocery": {
        "display": "REGION_TOWN_GROCERY", "prompt_in": "PROMPT_ENTER_GROCERY",
        "door": (632, 880), "wall": "int.wall_shop", "floor": "int.floor_linoleum",
        "exit_x": 760, "partition": (860, 290, 380), "back_floor": "int.floor_concrete",
        "windows": [300, 560], "tint": (0.48, 0.49, 0.52),
        "containers": [
            ("freezer_a", "fridge", 230, 300, "int.freezer", "int.freezer_open", {"canned_food": 1, "water_bottle": 1}, {}),
            ("freezer_b", "fridge", 430, 300, "int.freezer", "int.freezer_open", {}, {"searched": True}),
            ("aisle_a", "shelf", 240, 440, "int.gondola_full", "int.gondola_empty", {"canned_food": 2, "crackers": 1}, {}),
            ("aisle_b", "shelf", 510, 440, "int.gondola_sparse", "int.gondola_empty", {"crackers": 1, "water_bottle": 1}, {}),
            ("aisle_c", "shelf", 240, 580, "int.gondola_empty", "int.gondola_empty", {}, {"searched": True}),
            ("aisle_d", "shelf", 510, 580, "int.gondola_sparse", "int.gondola_empty", {"canned_food": 1, "water_bottle": 1}, {}),
            ("checkout", "drawer", 720, 520, "int.checkout", "int.checkout", {"crackers": 1}, {}),
            ("storeroom_shelf", "shelf", 985, 310, "int.metal_shelf_full", "int.metal_shelf_empty", {"canned_food": 2, "water_bottle": 2}, {}),
            ("storeroom_crate", "crate", 960, 600, "int.crate", "int.crate_open", {"crackers": 2}, {}),
        ],
        "props": [
            ("int.boxes", 1050, 470, 70, 30, {}),
            ("int.boxes", 660, 300, 70, 30, {}),
            ("int.barricade", 400, 690, 0, 0, {"floor": True}),
        ],
    },
    "pharmacy": {
        "display": "REGION_TOWN_PHARMACY", "prompt_in": "PROMPT_ENTER_PHARMACY",
        "door": (1112, 880), "wall": "int.wall_shop", "floor": "int.floor_linoleum",
        "exit_x": 760, "partition": (860, 420, 510), "back_floor": "int.floor_linoleum",
        "windows": [300, 560], "tint": (0.49, 0.50, 0.52),
        "containers": [
            ("shelf_a", "shelf", 240, 440, "int.gondola_sparse", "int.gondola_empty", {"bandage": 1, "water_bottle": 1}, {}),
            ("shelf_b", "shelf", 240, 580, "int.gondola_empty", "int.gondola_empty", {}, {"searched": True}),
            ("counter", "drawer", 560, 420, "int.pharm_counter", "int.pharm_counter", {"bandage": 1}, {}),
            ("wall_cabinet", "medical", 330, 262, "int.med_cabinet_open", "int.med_cabinet_open", {}, {"searched": True}),
            ("dispensary_a", "medical", 930, 262, "int.med_cabinet", "int.med_cabinet_open", {"bandage": 2}, {}),
            ("dispensary_b", "medical", 1040, 262, "int.med_cabinet", "int.med_cabinet_open", {"bandage": 1, "water_clean": 1}, {}),
            ("dispensary_crate", "crate", 990, 610, "int.crate", "int.crate_open", {"water_bottle": 1}, {}),
        ],
        "props": [
            ("int.display_table", 560, 590, 130, 30, {}),
            ("int.boxes", 700, 300, 70, 30, {}),
            ("int.checkout", 200, 300, 190, 34, {}),
        ],
    },
    "hardware": {
        "display": "REGION_TOWN_HARDWARE", "prompt_in": "PROMPT_ENTER_HARDWARE",
        "door": (1592, 880), "wall": "int.wall_shop", "floor": "int.floor_concrete",
        "exit_x": 740, "partition": (860, 450, 540), "back_floor": "int.floor_concrete",
        "windows": [300, 560], "tint": (0.48, 0.48, 0.49),
        "containers": [
            ("aisle_fasteners", "shelf", 220, 310, "int.metal_shelf_full", "int.metal_shelf_empty", {"scrap_metal": 2, "electrical_parts": 1}, {}),
            ("aisle_lumber", "shelf", 240, 450, "int.gondola_full", "int.gondola_empty", {"wood": 3}, {}),
            ("aisle_tools", "shelf", 510, 450, "int.gondola_sparse", "int.gondola_empty", {"scrap_metal": 1, "electrical_parts": 1, "cement": 1}, {}),
            ("aisle_bare", "shelf", 240, 590, "int.metal_shelf_empty", "int.metal_shelf_empty", {}, {"searched": True}),
            ("stock_crate", "crate", 960, 330, "int.crate", "int.crate_open", {"wood": 2, "cement": 1}, {}),
            ("locked_case", "toolbox", 1040, 610, "int.tool_chest", "int.tool_chest_open", {}, {"gear": ["flashlight", "hatchet"], "discovery": "hardware_case"}),
        ],
        "props": [
            ("int.pegboard", 600, 250, 0, 0, {}),
            ("int.display_table", 520, 590, 130, 30, {}),
            ("int.boxes", 1050, 420, 70, 30, {}),
            ("int.checkout", 700, 360, 190, 34, {}),
        ],
    },
    "clothing": {
        "display": "REGION_TOWN_CLOTHING", "prompt_in": "PROMPT_ENTER_CLOTHING",
        "door": (2072, 880), "wall": "int.wall_shop", "floor": "int.floor_carpet",
        "exit_x": 760, "partition": (860, 290, 380), "back_floor": "int.floor_concrete",
        "windows": [300, 560], "tint": (0.49, 0.48, 0.49),
        "containers": [
            ("rack_coats", "rack", 230, 420, "int.clothes_rack_full", "int.clothes_rack_empty", {"cloth": 2}, {}),
            ("rack_bare", "rack", 470, 420, "int.clothes_rack_empty", "int.clothes_rack_empty", {}, {"searched": True}),
            ("rack_mixed", "rack", 230, 570, "int.clothes_rack_full", "int.clothes_rack_empty", {"cloth": 1}, {}),
            ("display_table", "shelf", 480, 580, "int.display_table", "int.display_table", {"cloth": 1}, {}),
            ("fitting_dresser", "drawer", 300, 290, "int.dresser", "int.dresser_open", {}, {"searched": True}),
            ("stockroom_crate", "crate", 980, 330, "int.crate", "int.crate_open", {}, {"gear": ["winter_coat"], "discovery": "clothing_stockroom"}),
            ("stock_boxes", "crate", 1000, 600, "int.crate", "int.crate_open", {"cloth": 2}, {}),
        ],
        "props": [
            ("int.checkout", 700, 520, 190, 34, {}),
            ("int.boxes", 640, 300, 70, 30, {}),
            ("int.boxes", 1060, 460, 70, 30, {}),
        ],
    },
    "garage": {
        "display": "REGION_TOWN_GARAGE", "prompt_in": "PROMPT_ENTER_GARAGE",
        "door": (2594, 900), "wall": "int.wall_garage", "floor": "int.floor_concrete",
        "exit_x": 600, "exit_w": 200, "partition": (880, 300, 390), "back_floor": "int.floor_linoleum",
        "windows": [600], "tint": (0.46, 0.46, 0.48),
        "containers": [
            ("tool_chest", "toolbox", 210, 300, "int.tool_chest", "int.tool_chest_open", {"scrap_metal": 2, "electrical_parts": 1}, {}),
            ("parts_shelf", "garage", 470, 310, "int.metal_shelf_full", "int.metal_shelf_empty", {"scrap_metal": 2, "fuel": 1}, {}),
            ("locker_a", "locker", 720, 290, "int.locker", "int.locker_open", {"fuel": 1}, {}),
            ("locker_b", "locker", 800, 290, "int.locker_open", "int.locker_open", {}, {"searched": True}),
            ("scrap_crate", "garage", 220, 620, "int.crate", "int.crate_open", {"scrap_metal": 2, "electrical_parts": 1}, {}),
            ("office_desk", "drawer", 1000, 470, "int.dresser", "int.dresser_open", {"crackers": 1}, {}),
            ("office_locker", "locker", 1050, 290, "int.locker", "int.locker_open", {}, {"searched": True}),
        ],
        "props": [
            ("int.car_lift", 470, 520, 230, 40, {}),
            ("int.boxes", 800, 620, 70, 30, {}),
            ("int.boxes", 960, 300, 70, 30, {}),
        ],
    },
}

HOUSES = {
    "house_west": {
        "display": "REGION_TOWN_HOUSE_WEST", "prompt_in": "PROMPT_ENTER_HOME",
        "door": (561, 1456), "door_entity": True, "wall": "int.wall_house", "floor": "int.floor_linoleum",
        "exit_x": 380, "partition": (640, 420, 520), "back_floor": "int.floor_carpet",
        "windows": [240, 520, 900], "tint": (0.45, 0.43, 0.43),
        "containers": [
            ("kitchen_cupboards", "cupboard", 260, 290, "int.kitchen_counter", "int.kitchen_counter", {"canned_food": 1, "crackers": 1}, {}),
            ("fridge", "fridge", 470, 290, "int.home_fridge", "int.home_fridge_open", {"water_dirty": 1}, {}),
            ("dresser", "drawer", 770, 300, "int.dresser", "int.dresser_open", {"cloth": 1}, {}),
            ("closet", "locker", 1050, 300, "int.locker", "int.locker_open", {}, {"searched": True}),
        ],
        "props": [
            ("int.meal_table", 330, 520, 130, 34, {}),
            ("world.furniture_bed", 920, 360, 190, 60, {"occlude": True}),
            ("int.armchair", 760, 600, 80, 30, {}),
            ("int.boxes", 1040, 620, 70, 30, {}),
            ("int.barricade", 620, 690, 0, 0, {"floor": True}),
        ],
    },
    "house_east": {
        "display": "REGION_TOWN_HOUSE_EAST", "prompt_in": "PROMPT_ENTER_HOME",
        "door": (1940, 1456), "door_entity": True, "wall": "int.wall_planks", "floor": "int.floor_carpet",
        "exit_x": 760, "partition": (560, 300, 400), "back_floor": "int.floor_carpet",
        "windows": [300, 900], "tint": (0.43, 0.43, 0.45),
        "containers": [
            ("bookshelf", "shelf", 220, 275, "int.bookshelf", "int.bookshelf", {}, {"searched": True}),
            ("kitchen_fridge", "fridge", 440, 280, "int.home_fridge_open", "int.home_fridge_open", {}, {"searched": True}),
            ("dresser", "drawer", 700, 290, "int.dresser", "int.dresser_open", {"crackers": 1, "cloth": 1}, {}),
            ("wardrobe", "locker", 1040, 300, "int.locker", "int.locker_open", {"cloth": 2}, {}),
            ("packed_crate", "crate", 920, 600, "int.crate", "int.crate_open", {"canned_food": 1}, {}),
        ],
        "props": [
            ("int.sofa", 300, 560, 160, 34, {}),
            ("int.armchair", 470, 470, 80, 30, {}),
            ("world.furniture_bed", 880, 360, 190, 60, {"occlude": True}),
            ("int.boxes", 640, 620, 70, 30, {}),
            ("int.barricade", 1000, 690, 0, 0, {"floor": True}),
            ("int.barricade", 200, 690, 0, 0, {"floor": True}),
        ],
    },
}

REMOVED_STREET_LOOT = [
    "town.grocery_shelves", "town.grocery_storeroom", "town.pharmacy_counter", "town.pharmacy_dispensary",
    "town.hardware_aisle", "town.hardware_case", "town.clothing_racks", "town.clothing_stockroom",
    "town.garage_bench", "town.garage_bay", "town.house_a_kitchen", "town.house_c_bedroom",
]

# footprints for container art (collision base, px)
FOOT = {
    "int.freezer": (170, 34), "int.freezer_open": (170, 34), "int.gondola_full": (220, 36),
    "int.gondola_sparse": (220, 36), "int.gondola_empty": (220, 36), "int.checkout": (190, 34),
    "int.metal_shelf_full": (170, 30), "int.metal_shelf_empty": (170, 30), "int.crate": (90, 30),
    "int.crate_open": (90, 30), "int.pharm_counter": (200, 34), "int.med_cabinet": (80, 22),
    "int.med_cabinet_open": (80, 22), "int.tool_chest": (80, 28), "int.tool_chest_open": (80, 28),
    "int.clothes_rack_full": (150, 26), "int.clothes_rack_empty": (150, 26), "int.display_table": (130, 30),
    "int.dresser": (110, 28), "int.dresser_open": (110, 28), "int.locker": (64, 24), "int.locker_open": (64, 24),
    "int.kitchen_counter": (190, 30), "int.home_fridge": (72, 26), "int.home_fridge_open": (72, 26),
    "int.bookshelf": (100, 26),
}
TALL = {"int.gondola_full", "int.gondola_sparse", "int.gondola_empty", "int.metal_shelf_full", "int.metal_shelf_empty",
        "int.locker", "int.locker_open", "int.home_fridge", "int.home_fridge_open", "int.bookshelf",
        "int.med_cabinet", "int.med_cabinet_open", "int.clothes_rack_full", "int.clothes_rack_empty", "int.tool_chest",
        "int.tool_chest_open", "world.furniture_bed", "int.pegboard"}


def region_id(name):
    return "town." + name


def container_entity(rid, c, mode):
    key, kind, x, y, art, art_s, loot, opts = c
    e = {"id": f"{rid}.{key}", "type": "container", "kind": kind, "position": [x, y], "interact_range": 72,
         "prompt_key": "PROMPT_SEARCH_" + kind.upper(), "art": art, "art_searched": art_s, "loot": loot}
    if opts.get("gear"):
        e["gear"] = list(opts["gear"])
    if opts.get("discovery"):
        e["discovery"] = opts["discovery"]
    e["initial"] = {"searched": bool(opts.get("searched", False))}
    return e


def region_json(name, spec):
    rid = region_id(name)
    dx, dy = spec["door"]
    ex = spec["exit_x"]
    out_y = dy + (54 if spec.get("door_entity") else 46)
    ents = [{
        "id": f"{rid}.exit", "type": "portal", "position": [ex, 672], "interact_range": 60, "priority": 2,
        "target": {"region": "town", "position": [dx, out_y]}, "prompt_key": "PROMPT_EXIT_HOUSE",
    }]
    ents += [container_entity(rid, c, "container") for c in spec["containers"]]
    return {
        "region_id": rid,
        "display_key": spec["display"],
        "scene": f"res://scenes/regions/town/{name}_interior.tscn",
        "bounds": [0, 0, 1200, 760],
        "surface": {"region": "town", "position": [dx, dy]},
        "spawn_points": [[ex, 610]],
        "climate": {"exposure": 1.0, "fog": 0.0, "shelter": 0.35},
        "interior": True,
        "entities": ents,
    }


# ---------------------------------------------------------------------------
# Scene writing
# ---------------------------------------------------------------------------
class Scene:
    def __init__(self, root_name):
        self.nodes = []
        self.root = root_name

    def node(self, name, typ, parent, props):
        self.nodes.append((name, typ, parent, props))

    def text(self, ext):
        out = ["[gd_scene format=3]", ""]
        for i, (k, path) in enumerate(ext):
            out.append(f'[ext_resource type="Script" path="{path}" id="{k}"]')
        out.append("")
        for name, typ, parent, props in self.nodes:
            head = f'[node name="{name}" type="{typ}"' + (f' parent="{parent}"' if parent is not None else "") + "]"
            out.append(head)
            for k, v in props:
                out.append(f"{k} = {v}")
            out.append("")
        return "\n".join(out)


def poly(*pts):
    return "PackedVector2Array(" + ", ".join(f"{a}, {b}" for a, b in pts) + ")"


def rect_pts(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def col(r, g, b, a=1):
    return f"Color({r}, {g}, {b}, {a})"


def vec(x, y):
    return f"Vector2({x}, {y})"


WALL_COLORS = {
    "int.wall_shop": ((0.25, 0.25, 0.26), (0.19, 0.19, 0.2)),
    "int.wall_garage": ((0.24, 0.24, 0.24), (0.18, 0.18, 0.18)),
    "int.wall_house": ((0.26, 0.21, 0.17), (0.2, 0.16, 0.12)),
    "int.wall_planks": ((0.24, 0.17, 0.11), (0.2, 0.14, 0.09)),
}


def scene_for(name, spec):
    rid = region_id(name)
    s = Scene(name)
    ex = spec["exit_x"]
    gap = spec.get("exit_w", 110) // 2
    side_c, front_c = WALL_COLORS[spec["wall"]]
    s.node(name.title().replace("_", "") + "Interior", "Node2D", None, [
        ("script", 'ExtResource("region")'), ("region_id", f'"{rid}"'),
        ("ambience_id", '"amb.wind_muffled"'), ("camera_limits", "false")])
    s.node("Ground", "Node2D", ".", [("z_index", "-10")])
    s.node("Darkness", "Polygon2D", "Ground", [("color", col(0.06, 0.055, 0.05)),
                                              ("polygon", poly(*rect_pts(-2000, -2000, 4000, 4000)))])
    px = spec.get("partition")
    split = px[0] if px else FX1
    s.node("Floor", "Polygon2D", "Ground", [("script", 'ExtResource("ground")'),
                                           ("polygon", poly(*rect_pts(FX0, FY0 - 4, split, FY1))),
                                           ("asset_id", f'"{spec["floor"]}"')])
    if px:
        s.node("BackroomFloor", "Polygon2D", "Ground", [("script", 'ExtResource("ground")'),
                                                       ("polygon", poly(*rect_pts(split, FY0 - 4, FX1, FY1))),
                                                       ("asset_id", f'"{spec["back_floor"]}"')])
    s.node("SideWallLeft", "Polygon2D", "Ground", [("color", col(*side_c)), ("polygon", poly(*rect_pts(FX0 - 24, 20, FX0, FY1 + 18)))])
    s.node("SideWallRight", "Polygon2D", "Ground", [("color", col(*side_c)), ("polygon", poly(*rect_pts(FX1, 20, FX1 + 24, FY1 + 18)))])
    s.node("FrontWallLeft", "Polygon2D", "Ground", [("color", col(*front_c)), ("polygon", poly(*rect_pts(FX0 - 24, FY1, ex - gap, FY1 + 18)))])
    s.node("FrontWallRight", "Polygon2D", "Ground", [("color", col(*front_c)), ("polygon", poly(*rect_pts(ex + gap, FY1, FX1 + 24, FY1 + 18)))])
    # windows in the front wall (pale strips, the light comes from them)
    for i, wx in enumerate(spec["windows"]):
        if abs(wx - ex) < gap + 80:
            continue
        s.node(f"Window{i}", "Polygon2D", "Ground", [("color", col(0.62, 0.66, 0.72)), ("polygon", poly(*rect_pts(wx - 70, FY1 + 4, wx + 70, FY1 + 12)))])
    if px:
        x, g0, g1 = px
        s.node("PartitionTop", "Polygon2D", "Ground", [("color", col(*side_c)), ("polygon", poly(*rect_pts(x - 10, FY0 - 4, x + 10, g0)))])
        s.node("PartitionBottom", "Polygon2D", "Ground", [("color", col(*side_c)), ("polygon", poly(*rect_pts(x - 10, g1, x + 10, FY1)))])
        s.node("PartitionCapTop", "Polygon2D", "Ground", [("color", col(*front_c)), ("polygon", poly(*rect_pts(x - 10, g0 - 8, x + 10, g0)))])
        s.node("PartitionCapBottom", "Polygon2D", "Ground", [("color", col(*front_c)), ("polygon", poly(*rect_pts(x - 10, FY1 - 8, x + 10, FY1)))])
    s.node("Walls", "StaticBody2D", ".", [])
    s.node("Edge", "CollisionPolygon2D", "Walls", [("build_mode", "1"),
                                                  ("polygon", poly((FX0, FY0 + 4), (FX1, FY0 + 4), (FX1, FY1 - 8), (FX0, FY1 - 8), (FX0, FY0 + 4)))])
    if px:
        x, g0, g1 = px
        s.node("PartitionA", "CollisionPolygon2D", "Walls", [("polygon", poly(*rect_pts(x - 10, FY0, x + 10, g0)))])
        s.node("PartitionB", "CollisionPolygon2D", "Walls", [("polygon", poly(*rect_pts(x - 10, g1, x + 10, FY1)))])
    s.node("YSort", "Node2D", ".", [("y_sort_enabled", "true")])
    s.node("BackWall", "Node2D", "YSort", [("script", 'ExtResource("prop")'), ("position", vec(600, FY0)), ("asset_id", f'"{spec["wall"]}"')])
    for i, (asset, x, y, fw, fh, extra) in enumerate(spec["props"]):
        props = [("script", 'ExtResource("prop")'), ("position", vec(x, y)), ("asset_id", f'"{asset}"')]
        if fw:
            props.append(("footprint", vec(fw, fh)))
            props.append(("footprint_offset", vec(0, fh // 2)))
        if extra.get("occlude") or asset in TALL:
            props.append(("occlude", "true"))
        parent = "Ground" if extra.get("floor") else "YSort"
        s.node(f"Prop{i}_{asset.split('.')[-1]}", "Node2D", parent, props)
    for c in spec["containers"]:
        key, kind, x, y, art, art_s = c[:6]
        fw, fh = FOOT.get(art, (90, 28))
        s.node(f"Block_{key}", "Node2D", "YSort", [("script", 'ExtResource("prop")'), ("position", vec(x, y)),
                                                   ("footprint", vec(fw, fh)), ("footprint_offset", vec(0, fh // 2))])
        props = [("script", 'ExtResource("container")'), ("entity_id", f'"{rid}.{key}"')]
        if art in TALL or art_s in TALL:
            props.append(("occlude", "true"))
        s.node(f"Container_{key}", "Node2D", "YSort", props)
    s.node("Exit", "Node2D", "YSort", [("script", 'ExtResource("portal")'), ("entity_id", f'"{rid}.exit"'),
                                       ("art_asset", '"world.exit_mat"'), ("hide_when_unavailable", "false"), ("floor_art", "true")])
    # light: daylight through the front windows and the doorway; the backroom stays dark
    for i, wx in enumerate(spec["windows"]):
        s.node(f"WindowLight{i}", "PointLight2D", ".", [("script", 'ExtResource("light")'), ("position", vec(wx, FY1 - 30)),
                                                        ("color", col(0.92, 0.95, 1)), ("texture_scale", "3.6"), ("energy", "0.7"), ("daylight", "true")])
    s.node("DoorLight", "PointLight2D", ".", [("script", 'ExtResource("light")'), ("position", vec(ex, FY1 - 10)),
                                              ("color", col(0.9, 0.93, 1)), ("texture_scale", "2.4"), ("energy", "0.55"), ("daylight", "true")])
    t = spec["tint"]
    s.node("Atmosphere", "Node2D", ".", [("script", 'ExtResource("atmo")'), ("tint", col(*t)), ("saturation", "0.72"),
                                         ("drift_amount", "0"), ("vignette_strength", "0.5"), ("follow_daylight", "true"),
                                         ("area", f"Rect2({FX0}, {FY0}, {FX1 - FX0}, {FY1 - FY0})")])
    ext = [("region", "res://src/presentation/world/region_view.gd"), ("prop", "res://src/presentation/world/prop.gd"),
           ("ground", "res://src/presentation/world/ground_patch.gd"), ("atmo", "res://src/presentation/world/atmosphere.gd"),
           ("portal", "res://src/presentation/world/portal_view.gd"), ("container", "res://src/presentation/world/container_view.gd"),
           ("light", "res://src/presentation/world/light_spot.gd")]
    return s.text(ext)


def dump_json(path, d):
    with open(path, "w") as f:
        json.dump(d, f, indent="\t", ensure_ascii=False)
        f.write("\n")


def patch_town(all_specs):
    p = os.path.join(ROOT, "content/regions/town.json")
    town = json.load(open(p))
    keep = [e for e in town["entities"] if e["id"] not in REMOVED_STREET_LOOT and not e["id"].endswith("_entrance")
            and not (e["id"].startswith("town.") and e["id"].split(".")[1] in [f"{n}_door" for n in HOUSES])]
    added = []
    for name, spec in all_specs.items():
        dx, dy = spec["door"]
        rid = region_id(name)
        if spec.get("door_entity"):
            added.append({"id": f"town.{name}_door", "type": "door", "position": [dx, dy], "interact_range": 80,
                          "initial": {"open": False}})
            added.append({"id": f"town.{name}_entrance", "type": "portal", "position": [dx, dy + 5], "interact_range": 44,
                          "priority": 2, "requires_open": f"town.{name}_door",
                          "target": {"region": rid, "position": [spec["exit_x"], 610]}, "prompt_key": spec["prompt_in"]})
        else:
            added.append({"id": f"town.{name}_entrance", "type": "portal", "position": [dx, dy + 6], "interact_range": 48,
                          "priority": 2, "target": {"region": rid, "position": [spec["exit_x"], 610]},
                          "prompt_key": spec["prompt_in"]})
    # the old town house entry: a proper prompt (it said "Enter the cabin")
    for e in keep:
        if e["id"] == "town.house_entry":
            e["prompt_key"] = "PROMPT_ENTER_HOME"
    town["entities"] = keep + added
    dump_json(p, town)

    sp = os.path.join(ROOT, "scenes/regions/town/town.tscn")
    txt = open(sp).read()
    blocks = txt.split("\n\n")
    out = []
    for b in blocks:
        if any(f'entity_id = "{eid}"' in b for eid in REMOVED_STREET_LOOT):
            continue
        if "_entrance\"" in b or any(f'entity_id = "town.{n}_door"' in b for n in HOUSES):
            continue
        out.append(b)
    txt = "\n\n".join(out).rstrip("\n") + "\n"
    for name, spec in all_specs.items():
        dx, dy = spec["door"]
        node = name.title().replace("_", "")
        if spec.get("door_entity"):
            txt += (f'\n[node name="{node}Door" type="Node2D" parent="YSort"]\nscript = ExtResource("door")\n'
                    f'position = Vector2({dx}, {dy})\nentity_id = "town.{name}_door"\n'
                    'closed_asset = "world.house_door_closed"\nopen_asset = "world.house_door_open"\n'
                    'blocker_size = Vector2(0, 0)\nsprite_offset = Vector2(0, -18)\n'
                    'prompt_open_key = "PROMPT_OPEN_DOOR"\nprompt_close_key = "PROMPT_CLOSE_DOOR"\n')
        txt += (f'\n[node name="{node}Entry" type="Node2D" parent="YSort"]\nscript = ExtResource("portalv")\n'
                f'entity_id = "town.{name}_entrance"\n')
    open(sp, "w").write(txt)


def main():
    specs = dict(SHOPS)
    specs.update(HOUSES)
    for name, spec in specs.items():
        dump_json(os.path.join(ROOT, f"content/regions/town_{name}.json"), region_json(name, spec))
        with open(os.path.join(ROOT, f"scenes/regions/town/{name}_interior.tscn"), "w") as f:
            f.write(scene_for(name, spec))
    patch_town(specs)
    print("interiors built:", ", ".join(specs))


if __name__ == "__main__":
    main()
