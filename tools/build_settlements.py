#!/usr/bin/env python3
"""The Five Settlements (iteration 014): the four new towns, their interiors and roads.

  * Corran Junction ("junction")  — industrial / service town: factory, machine
    shop, rail-side warehouse, fuel depot, utility building, corner store, houses.
  * Greyhollow ("greyhollow")     — mining town: mine office, general store, mine
    supply, row houses, storage shed, headframe, hopper, slag, and the mine adit.
  * Stillwater ("stillwater")     — residential / commercial town: market,
    outfitters, the three-storey civic hall, clinic, police, church, apartments,
    houses — and one ordinary-looking quiet house.
  * Port Halden ("harbor")        — frozen harbor city: quay and piers, warehouse,
    cannery, chandlery, harbor master, net shed, cottages, crane, lighthouse, a
    trawler frozen in the sea ice, and icebergs drifting in the open channel.

Roads: Ashgrove (east) → Corran Junction; Junction north → Greyhollow;
Junction east → Stillwater; Stillwater east → Port Halden. Every road end is a
vehicle exit and an on-foot portal (the established hybrid travel system).

Outdoor regions are top-down (generated scene + region file); every enterable
building is a side-view cross-section (tools/build_side_interiors.Section).
Containers carry a loot "pool" (weighted, rolled once by the host when first
searched — content/loot_pools.json). Ids are stable; re-running is idempotent.
Usage: python3 tools/build_settlements.py
"""
import json, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_side_interiors import Section, dump_json, ROOT  # noqa: E402

# facade display widths (world px) = (source w + 120) / 2 — see gen_five_settlements.BUILDINGS
FACADE_W = {"harbor_office": 340, "warehouse_a": 510, "cannery": 470, "chandlery": 320, "net_shed": 250, "harbor_house": 270,
            "mine_office": 360, "general_store": 340, "mine_supply": 370, "rowhouse": 420, "store_shed": 380,
            "factory": 560, "machine_shop": 370, "utility": 340, "corner_store": 300, "worker_house": 280, "warehouse_b": 490,
            "civic_hall": 440, "clinic": 360, "police": 370, "market": 380, "outfitters": 340, "apartments": 400,
            "church": 310, "town_house_a": 280, "quiet_house": 290}
INTERIOR = {"climate": {"exposure": 1.0, "fog": 0.0, "shelter": 0.35}, "interior": True, "ambience": "amb.wind_muffled"}


# ====================================================================== outdoor scene writer
class Outdoor:
    def __init__(self, rid, display, w, h, ambience="amb.cold_wind", seed=1):
        self.rid, self.display, self.w, self.h = rid, display, w, h
        self.ambience = ambience
        self.R = random.Random(seed)
        self.ground = []      # (name, pts, asset, color)
        self.props = []       # (name, pos, asset, foot, occlude, flip, sway, nav, foff)
        self.entities = []
        self.views = []       # extra view nodes (text blocks)
        self.blocks = []      # collision polygons (water edges etc.)
        self.exits = []
        self.map_areas, self.map_roads, self.map_landmarks = [], [], []
        self.avoid = []
        self.drifts = []
        self.n = 0

    def _name(self, base):
        self.n += 1
        return f"{base}{self.n}"

    def road(self, pts, width=140, asset="env.ground_road_snow", map_kind="road"):
        """A road along a polyline (axis-aligned segments)."""
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            hw = width / 2
            if y0 == y1:
                poly = [(min(x0, x1) - hw, y0 - hw), (max(x0, x1) + hw, y0 - hw), (max(x0, x1) + hw, y0 + hw), (min(x0, x1) - hw, y0 + hw)]
            else:
                poly = [(x0 - hw, min(y0, y1) - hw), (x0 + hw, min(y0, y1) - hw), (x0 + hw, max(y0, y1) + hw), (x0 - hw, max(y0, y1) + hw)]
            self.ground.append((self._name("Road"), poly, asset, None))
            self.avoid.append((poly[0][0], poly[0][1], poly[2][0] - poly[0][0], poly[2][1] - poly[0][1]))
        self.map_roads.append({"kind": map_kind, "width": width, "points": [list(p) for p in pts]})

    def patch(self, rect, asset, color=None):
        x, y, w, h = rect
        self.ground.append((self._name("Patch"), [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], asset, color))

    def prop(self, pos, asset, foot=None, occlude=True, flip=False, sway=False, nav=True, foff=None, name=None):
        self.props.append((name or self._name("P"), pos, asset, foot, occlude, flip, sway, nav, foff))

    def building(self, kind, x, base, label_key=None, flip=False, enter=None):
        """A facade with collision; enter = (interior region id, interior spawn) adds a door portal."""
        fw = FACADE_W[kind]
        self.prop((x, base), "set." + kind, (fw - 24, 46), flip=flip, name=f"B_{kind}_{x}")
        self.avoid.append((x - fw / 2 - 20, base - 300, fw + 40, 340))
        self.map_landmarks.append({"kind": "building", "position": [x, base - 40], "size": [fw, 80], **({"label_key": label_key} if label_key else {})})
        if enter:
            rid, spawn, prompt = enter
            self.entities.append({"id": f"{self.rid}.{rid.split('.')[-1]}_entrance", "type": "portal", "position": [x, base + 6],
                                  "interact_range": 52, "priority": 2, "target": {"region": rid, "position": spawn}, "prompt_key": prompt})
        return (x, base)

    def exit(self, key, pos, rect, target_region, target_pos, rotation, prompt):
        self.entities.append({"id": f"{self.rid}.{key}", "type": "portal", "position": list(pos), "interact_range": 80, "priority": 2,
                              "target": {"region": target_region, "position": list(target_pos)}, "prompt_key": prompt})
        self.exits.append({"rect": list(rect), "target": {"region": target_region, "position": list(target_pos), "rotation": rotation}})

    def vehicle_container(self, key, pos, asset, pool, flip=False):
        self.prop(pos, asset, (190, 30), flip=flip, name=f"V_{key}")
        self.entities.append({"id": f"{self.rid}.{key}", "type": "container", "kind": "vehicle", "position": [pos[0] + 40, pos[1] + 24],
                              "interact_range": 90, "prompt_key": "PROMPT_SEARCH_VEHICLE", "art": "", "art_searched": "", "loot": {},
                              "pool": pool, "initial": {"searched": False}})

    def cache(self, key, pos, asset, pool, prompt, foot=(120, 24), kind="crate"):
        """Iteration 014 F: an outdoor cache (a snowed-in sled, a hunting camp crate) searched like any container."""
        self.prop(pos, asset, foot, name=f"C_{key}")
        self.entities.append({"id": f"{self.rid}.{key}", "type": "container", "kind": kind, "position": [pos[0], pos[1] + 16],
                              "interact_range": 80, "prompt_key": prompt, "art": "", "art_searched": "", "loot": {},
                              "pool": pool, "initial": {"searched": False}})

    def pines(self, bands, seed=7):
        R = random.Random(seed)
        for (x0, x1, y0, y1) in bands:
            x = x0
            while x < x1:
                y = R.uniform(y0, y1)
                self.prop((int(x), int(y)), R.choice(["env.pine_a", "env.pine_b"]), (30, 12), flip=R.random() < 0.5, sway=True, nav=False)
                x += R.uniform(90, 170)
            self.map_areas.append({"kind": "woods", "polygon": [[x0, y0 - 60], [x1, y0 - 60], [x1, y1 + 60], [x0, y1 + 60]]})

    def block(self, pts):
        self.blocks.append(pts)

    def scene(self, extra_nodes=""):
        L = ['[gd_scene format=3]', '',
             '[ext_resource type="Script" path="res://src/presentation/world/region_view.gd" id="region"]',
             '[ext_resource type="Script" path="res://src/presentation/world/prop.gd" id="prop"]',
             '[ext_resource type="Script" path="res://src/presentation/world/ground_patch.gd" id="ground"]',
             '[ext_resource type="Script" path="res://src/presentation/world/scatter.gd" id="scatter"]',
             '[ext_resource type="Script" path="res://src/presentation/world/atmosphere.gd" id="atmo"]',
             '[ext_resource type="Script" path="res://src/presentation/world/portal_view.gd" id="portalv"]',
             '[ext_resource type="Script" path="res://src/presentation/world/container_view.gd" id="containerv"]',
             '[ext_resource type="Script" path="res://src/presentation/world/ice_drift.gd" id="drift"]', '',
             f'[node name="{self.rid.title().replace("_", "")}" type="Node2D"]', 'script = ExtResource("region")',
             f'region_id = "{self.rid}"', f'ambience_id = "{self.ambience}"'] + ([f'ambience2_id = "{self.ambience2}"'] if getattr(self, "ambience2", "") else []) + ['',
             '[node name="Ground" type="Node2D" parent="."]', 'z_index = -10', '']

        def poly(pts):
            return "PackedVector2Array(" + ", ".join("%d, %d" % (round(a), round(b)) for a, b in pts) + ")"

        L.extend(['[node name="Snow" type="Polygon2D" parent="Ground"]', 'script = ExtResource("ground")',
                  'polygon = ' + poly([(-400, -400), (self.w + 400, -400), (self.w + 400, self.h + 400), (-400, self.h + 400)]),
                  'asset_id = "env.ground_snow"', ''])
        for name, pts, asset, color in self.ground:
            L.extend([f'[node name="{name}" type="Polygon2D" parent="Ground"]', 'script = ExtResource("ground")', 'polygon = ' + poly(pts), f'asset_id = "{asset}"'])
            if color:
                L.append(f'color = Color({color})')
            L.append('')
        L.extend(['[node name="Bounds" type="StaticBody2D" parent="."]', ''])
        edges = [[(-40, -40), (self.w + 40, -40), (self.w + 40, 0), (-40, 0)],
                 [(-40, self.h), (self.w + 40, self.h), (self.w + 40, self.h + 40), (-40, self.h + 40)],
                 [(-40, -40), (0, -40), (0, self.h + 40), (-40, self.h + 40)],
                 [(self.w, -40), (self.w + 40, -40), (self.w + 40, self.h + 40), (self.w, self.h + 40)]] + self.blocks
        for i, e in enumerate(edges):
            L.extend([f'[node name="Edge{i}" type="CollisionPolygon2D" parent="Bounds"]', 'polygon = ' + poly(e), ''])
        L.extend(['[node name="YSort" type="Node2D" parent="."]', 'y_sort_enabled = true', ''])
        for (name, pos, asset, foot, occlude, flip, sway, nav, foff) in self.props:
            L.extend([f'[node name="{name}" type="Node2D" parent="YSort"]', 'script = ExtResource("prop")', 'position = Vector2(%d, %d)' % pos, f'asset_id = "{asset}"'])
            if foot:
                L.append('footprint = Vector2(%d, %d)' % foot)
            if foff:
                L.append('footprint_offset = Vector2(%d, %d)' % foff)
            if not nav:
                L.append('nav_block = false')
            if occlude:
                L.append('occlude = true')
            if sway:
                L.append('sway = true')
            if flip:
                L.append('flip_h = true')
            L.append('')
        for e in self.entities:
            short = e["id"].split(".")[-1]
            if e["type"] == "portal":
                L.extend([f'[node name="E_{short}" type="Node2D" parent="YSort"]', 'script = ExtResource("portalv")', f'entity_id = "{e["id"]}"', ''])
            elif e["type"] == "container":
                L.extend([f'[node name="E_{short}" type="Node2D" parent="YSort"]', 'script = ExtResource("containerv")', f'entity_id = "{e["id"]}"', ''])
        for i, d in enumerate(self.drifts):
            L.extend([f'[node name="IceDrift{i}" type="Node2D" parent="YSort"]', 'script = ExtResource("drift")',
                      f'lane_y = {d["y"]}', f'speed = {d["speed"]}', f'span = Vector2({d["x0"]}, {d["x1"]})',
                      f'asset_ids = Array[String]({json.dumps(d["assets"])})', f'count = {d["count"]}', f'lane_seed = {d["seed"]}', ''])
        avoid = ", ".join("Rect2(%d, %d, %d, %d)" % tuple(round(v) for v in a) for a in self.avoid)
        L.extend(['[node name="Grass" type="Node2D" parent="YSort"]', 'script = ExtResource("scatter")', f'area = Rect2(20, 20, {self.w - 40}, {self.h - 40})',
                  f'avoid = Array[Rect2]([{avoid}])',
                  'asset_ids = Array[String](["env.dead_grass_a", "env.dead_grass_b", "env.dead_grass_c"])', 'count = 90',
                  f'layout_seed = {len(self.rid) * 13}', 'min_spacing = 70.0', ''])
        L.append(extra_nodes)
        L.extend(['[node name="Atmosphere" type="Node2D" parent="."]', 'script = ExtResource("atmo")', f'area = Rect2(0, 0, {self.w}, {self.h})', ''])
        return "\n".join(L)

    def region(self, extra):
        d = {"region_id": self.rid, "display_key": self.display,
             "scene": f"res://scenes/regions/settlements/{self.rid}.tscn",
             "bounds": [0, 0, self.w, self.h], "entities": self.entities, "vehicle_exits": self.exits}
        d.update(extra)
        d.setdefault("map", {})
        d["map"].update({"areas": self.map_areas + d["map"].get("areas", []), "roads": self.map_roads, "landmarks": self.map_landmarks + d["map"].get("landmarks", [])})
        return d

    def write(self, extra_region, extra_nodes=""):
        self.ambience2 = str(extra_region.get("ambience2", ""))
        os.makedirs(os.path.join(ROOT, "scenes", "regions", "settlements"), exist_ok=True)
        with open(os.path.join(ROOT, "scenes", "regions", "settlements", f"{self.rid}.tscn"), "w") as f:
            f.write(self.scene(extra_nodes))
        dump_json(os.path.join(ROOT, "content", "regions", f"{self.rid}.json"), self.region(extra_region))


# ====================================================================== interior templates
def _door_target(town, x, base):
    return [x, base + 52]


def shop(rid, display, town, x, base, ext, wall, floor, front, back, labels=("SIDE_STOREROOM",)):
    """One storey: a sales floor (front containers) and a back room (back containers)."""
    width = max(18, 4 + 3 * len(front) + 3 * len(back) + 4)
    split = width - 3 * len(back) - 3
    s = Section(rid, width, (0,), display, exterior=ext)
    s.room(0, 0, split, wall=wall, floor=floor)
    s.room(0, split, width, wall="side.wall_brick_in", floor="side.floor_concrete")
    s.divider(0, split)
    s.exit(0.7, town, _door_target(town, x, base))
    s.window(0, 3.0)
    s.window(0, min(split - 2.0, 8.0))
    cx = 3.0
    for c in front:
        s.container(*_c(c, cx))
        cx += 3.0
    s.label(0, split + 0.4, labels[0])
    cx = split + 1.6
    for c in back:
        s.container(*_c(c, cx))
        cx += 3.0
    return s


def _c(c, cx):
    """(key, kind, art, art_searched, pool[, searched]) → container() args at column cx."""
    key, kind, art, art_s, pool = c[:5]
    searched = len(c) > 5 and c[5]
    return (key, kind, cx, 0, art, art_s, {}, searched, None, None, pool)


def house(rid, display, town, x, base, wall_a="side.wall_house", wall_b="side.wall_house_b", pool_prefix="home", storeys=2, extra=None,
          layout="a", ext="side.ext_siding"):
    """A home in three layouts (same container ids in each, so saves and pools stay put):
    a = kitchen by the door, stairs on the right; b = mirrored, living room first, stairs
    on the left; c = a wider flat with a reading corner and the bedroom up front."""
    width = 18 if layout == "c" else 16
    s = Section(rid, width, tuple(range(storeys)), display, exterior=ext)
    if layout == "b":
        s.room(0, 0, 7, wall=wall_b)
        s.room(0, 7, 16, wall=wall_a, floor="side.floor_linoleum")
        s.divider(0, 7)
        s.exit(3.4, town, _door_target(town, x, base))
        s.window(0, 5.6, boarded=True)
        s.window(0, 12.0)
        s.prop("int.sofa", 5.6, 0)
        s.prop("int.meal_table", 8.6, 0)
        s.container("kitchen", "cupboard", 11.2, 0, "int.kitchen_counter", "int.kitchen_counter", {}, pool=f"{pool_prefix}_kitchen")
        s.container("fridge", "fridge", 13.8, 0, "int.home_fridge", "int.home_fridge_open", {}, pool=f"{pool_prefix}_fridge")
    elif layout == "c":
        s.room(0, 0, 8, wall=wall_a, floor="side.floor_linoleum")
        s.room(0, 8, 18, wall=wall_b)
        s.divider(0, 8)
        s.exit(0.7, town, _door_target(town, x, base))
        s.window(0, 4.0)
        s.window(0, 11.5)
        s.container("kitchen", "cupboard", 2.8, 0, "int.kitchen_counter", "int.kitchen_counter", {}, pool=f"{pool_prefix}_kitchen")
        s.container("fridge", "fridge", 5.6, 0, "int.home_fridge", "int.home_fridge_open", {}, pool=f"{pool_prefix}_fridge")
        s.prop("int.bookshelf", 9.4, 0)
        s.prop("int.armchair", 11.0, 0)
        s.prop("int.sofa", 13.4, 0)
    else:
        s.room(0, 0, 9, wall=wall_a, floor="side.floor_linoleum")
        s.room(0, 9, 16, wall=wall_b)
        s.divider(0, 9)
        s.exit(0.7, town, _door_target(town, x, base))
        s.window(0, 5.0)
        s.window(0, 12.5, boarded=True)
        s.container("kitchen", "cupboard", 3.0, 0, "int.kitchen_counter", "int.kitchen_counter", {}, pool=f"{pool_prefix}_kitchen")
        s.container("fridge", "fridge", 6.0, 0, "int.home_fridge", "int.home_fridge_open", {}, pool=f"{pool_prefix}_fridge")
        s.prop("int.meal_table", 7.8, 0)
        s.prop("int.sofa", 11.0, 0)
    if storeys > 1:
        s.room(1, 0, width, wall=wall_b if layout == "b" else wall_a)
        s.label(1, 0.4 if layout != "b" else 4.0, "SIDE_UPSTAIRS")
        if layout == "b":
            s.window(1, 7.0, boarded=True)
            s.window(1, 13.5)
            s.stairs(1.5, 0, 1, flip=True)
            s.prop("int.boxes", 5.0, 1)
            s.container("wardrobe", "locker", 7.2, 1, "int.locker", "int.locker_open", {}, pool=f"{pool_prefix}_closet")
            s.prop("world.furniture_bed", 10.0, 1, back=True)
            s.container("dresser", "drawer", 13.4, 1, "int.dresser", "int.dresser_open", {}, pool=f"{pool_prefix}_bedroom")
        elif layout == "c":
            s.window(1, 6.0)
            s.window(1, 12.0)
            s.stairs(16.5, 0, 1)
            s.prop("world.furniture_bed", 3.4, 1, back=True)
            s.container("dresser", "drawer", 6.6, 1, "int.dresser", "int.dresser_open", {}, pool=f"{pool_prefix}_bedroom")
            s.container("wardrobe", "locker", 9.0, 1, "int.locker", "int.locker_open", {}, pool=f"{pool_prefix}_closet")
            s.prop("int.bookshelf", 12.4, 1)
        else:
            s.window(1, 8.0)
            s.window(1, 13.0, boarded=True)
            s.stairs(14.5, 0, 1)
            s.container("dresser", "drawer", 4.0, 1, "int.dresser", "int.dresser_open", {}, pool=f"{pool_prefix}_bedroom")
            s.prop("world.furniture_bed", 7.0, 1, back=True)
            s.container("wardrobe", "locker", 10.5, 1, "int.locker", "int.locker_open", {}, pool=f"{pool_prefix}_closet")
            s.prop("int.boxes", 12.0, 1)
    else:
        s.container("dresser", "drawer", 1.8 if layout == "b" else 13.4, 0, "int.dresser", "int.dresser_open", {}, pool=f"{pool_prefix}_bedroom")
    if extra:
        extra(s)
    return s


def office(rid, display, town, x, base, ext="side.ext_brick", pool="office", storeys=2, ground_extra=None, upper_extra=None):
    s = Section(rid, 18, tuple(range(storeys)), display, exterior=ext)
    s.room(0, 0, 18, wall="side.wall_office", floor="side.floor_linoleum")
    s.exit(0.7, town, _door_target(town, x, base))
    s.window(0, 4.0)
    s.window(0, 11.0)
    s.container("reception", "drawer", 3.6, 0, "int.pharm_counter", "int.pharm_counter", {}, pool=f"{pool}_desk")
    s.container("files", "locker", 7.2, 0, "int.locker", "int.locker_open", {}, pool=f"{pool}_files")
    s.container("files_b", "locker", 8.4, 0, "int.locker_open", "int.locker_open", {}, searched=True, pool=f"{pool}_files")
    s.prop("int.boxes", 10.4, 0)
    if ground_extra:
        ground_extra(s)
    if storeys > 1:
        s.room(1, 0, 18, wall="side.wall_office", floor="side.floor_linoleum")
        s.window(1, 4.0, boarded=True)
        s.window(1, 10.0)
        s.stairs(16.5, 0, 1)
        s.label(1, 0.4, "SIDE_UPSTAIRS")
        s.container("desk", "drawer", 3.6, 1, "int.dresser", "int.dresser_open", {}, pool=f"{pool}_desk")
        s.container("cabinet", "locker", 7.0, 1, "int.locker", "int.locker_open", {}, pool=f"{pool}_files")
        s.container("storage", "crate", 11.0, 1, "int.crate", "int.crate_open", {}, pool=f"{pool}_storage")
        if upper_extra:
            upper_extra(s)
    return s


def hall(rid, display, town, x, base, ext, wall, pool, contents, width=26, props=()):
    """One wide storey: a warehouse, factory floor, cannery or workshop."""
    s = Section(rid, width, (0,), display, exterior=ext)
    s.room(0, 0, width, wall=wall, floor="side.floor_concrete")
    s.exit(0.7, town, _door_target(town, x, base))
    s.window(0, 5.0, boarded=True)
    s.window(0, width - 5.0)
    cx = 3.0
    for c in contents:
        key, kind, art, art_s, p = c[:5]
        searched = len(c) > 5 and c[5]
        s.container(key, kind, cx, 0, art, art_s, {}, searched=searched, pool=p or pool)
        cx += (width - 4.0) / max(1, len(contents))
    for (asset, cell) in props:
        s.prop(asset, cell, 0)
    return s


SHELF = ("int.gondola_full", "int.gondola_empty")
SPARSE = ("int.gondola_sparse", "int.gondola_empty")
METAL = ("int.metal_shelf_full", "int.metal_shelf_empty")
CRATE = ("int.crate", "int.crate_open")
LOCKER = ("int.locker", "int.locker_open")
TOOLS = ("int.tool_chest", "int.tool_chest_open")
MED = ("int.med_cabinet", "int.med_cabinet_open")
RACK = ("int.clothes_rack_full", "int.clothes_rack_empty")
FREEZER = ("int.freezer", "int.freezer_open")


def C(key, kind, art, pool, searched=False):
    return (key, kind, art[0], art[1], pool, searched)


# ====================================================================== Corran Junction
def junction(interiors):
    o = Outdoor("junction", "REGION_JUNCTION", 3200, 2200, seed=71)
    RY, NB, SB = 1100, 960, 1440
    o.road([(0, RY), (3200, RY)])
    o.road([(1600, 0), (1600, RY)])
    o.patch((0, 470, 3200, 64), "set.rail")
    o.map_roads.append({"kind": "track", "width": 30, "points": [[0, 500], [3200, 500]]})
    o.exit("road_west", (60, RY), (0, RY - 90, 40, 180), "town", (3040, 1010), 180, "PROMPT_ROAD_ASHGROVE")
    o.exit("road_east", (3140, RY), (3160, RY - 90, 40, 180), "stillwater", (220, 1200), 0, "PROMPT_ROAD_STILLWATER")
    o.exit("road_north", (1600, 60), (1510, 0, 180, 40), "greyhollow", (1400, 2040), -90, "PROMPT_ROAD_GREYHOLLOW")
    # north side of the road
    o.building("factory", 420, NB, "MAP_FACTORY")
    sp = interiors("junction.machine_shop", "REGION_JUNCTION_MACHINE_SHOP", 950, NB, "junction")
    o.building("machine_shop", 950, NB, "MAP_MACHINE_SHOP", enter=("junction.machine_shop", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("junction.warehouse", "REGION_JUNCTION_WAREHOUSE", 2050, NB, "junction")
    o.building("warehouse_b", 2050, NB, "MAP_WAREHOUSE", enter=("junction.warehouse", sp, "PROMPT_ENTER_BUILDING"))
    o.prop((2620, NB), "set.fuel_tanks", (200, 40), name="FuelTanks")
    o.map_landmarks.append({"kind": "building", "position": [2620, NB - 40], "size": [220, 80], "label_key": "MAP_FUEL_DEPOT"})
    o.entities.append({"id": "junction.fuel_valve", "type": "container", "kind": "garage", "position": [2620, NB + 20], "interact_range": 90,
                       "prompt_key": "PROMPT_SEARCH_GARAGE", "art": "", "art_searched": "", "loot": {}, "pool": "fuel_depot", "initial": {"searched": False}})
    # south side
    sp = interiors("junction.corner_store", "REGION_JUNCTION_CORNER_STORE", 500, SB, "junction")
    o.building("corner_store", 500, SB, "MAP_CORNER_STORE", enter=("junction.corner_store", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("junction.worker_house", "REGION_JUNCTION_HOUSE", 900, SB, "junction")
    o.building("worker_house", 900, SB, None, enter=("junction.worker_house", sp, "PROMPT_ENTER_HOME"))
    o.building("worker_house", 1250, SB, None, flip=True)
    sp = interiors("junction.utility", "REGION_JUNCTION_UTILITY", 2000, SB, "junction")
    o.building("utility", 2000, SB, "MAP_UTILITY", enter=("junction.utility", sp, "PROMPT_ENTER_BUILDING"))
    o.prop((2450, SB), "set.substation", (170, 30), name="Substation")
    o.prop((2860, SB - 20), "set.water_tower", (130, 30), name="WaterTower")
    o.map_landmarks.append({"kind": "building", "position": [2860, SB - 60], "size": [140, 90], "label_key": "MAP_WATER_TOWER"})
    o.vehicle_container("truck", (1300, RY + 120), "prop.truck_wreck", "vehicle_truck", flip=True)
    o.vehicle_container("sedan", (2400, RY - 120), "prop.car_sedan", "vehicle_car")
    o.cache("sled", (1460, 430), "prop.sled", "wilderness_frozen", "PROMPT_SEARCH_SLED")
    o.cache("hunting_camp", (3010, 1610), "build.crate", "hunter_cabin", "PROMPT_SEARCH_HUNTING_CAMP", foot=(80, 20))
    for xl in (300, 1000, 1900, 2700):
        o.prop((xl, NB + 58), "world.town_streetlamp", (10, 8))
    o.pines([(40, 3160, 60, 380), (40, 3160, 1780, 2160)], seed=72)
    o.write({"spawn_points": [[220, RY]], "climate": {"exposure": 1.1, "fog": 1.0}, "discovery": "junction",
             "zombies": {"base_population": 4, "spawns": [[700, 700], [1800, 650], [2600, 1600], [400, 1700], [1300, 1600]],
                         "entries": [[20, 400], [20, 1800], [3180, 400], [3180, 1800], [1600, 20], [800, 2180]]},
             "omens": {"laugh_spots": [[420, 900], [2050, 900], [2860, 1400]], "laugh_radius": 700,
                       "shadow_paths": [[[1700, 1500], [1820, 1520]], [[2700, 900], [2840, 880]]]},
             "map": {"offset": [7840, 285], "areas": [{"kind": "yard", "polygon": [[120, 620], [2900, 620], [2900, 990], [120, 990]]}]}})


def junction_interiors(rid, display, x, base, town):
    if rid == "junction.machine_shop":
        s = hall(rid, display, town, x, base, "side.ext_concrete", "side.wall_brick_in", "workshop",
                 [C("tool_chest", "toolbox", TOOLS, "workshop_tools"), C("parts_shelf", "garage", METAL, "workshop_parts"),
                  C("lathe_bench", "drawer", ("int.display_table", "int.display_table"), "workshop_tools"),
                  C("scrap_bin", "garage", CRATE, "industrial_scrap"), C("locker", "locker", LOCKER, "worker_locker")],
                 width=22, props=(("int.pegboard", 9.0),))
    elif rid == "junction.warehouse":
        s = hall(rid, display, town, x, base, "side.ext_brick", "side.wall_brick_in", "warehouse",
                 [C("pallet_a", "crate", CRATE, "warehouse_freight"), C("rack_a", "shelf", METAL, "warehouse_freight"),
                  C("pallet_b", "crate", CRATE, "warehouse_freight", True), C("rack_b", "shelf", METAL, "industrial_materials"),
                  C("pallet_c", "crate", CRATE, "industrial_materials"), C("office_locker", "locker", LOCKER, "worker_locker")],
                 width=28, props=(("int.boxes", 13.0), ("int.boxes", 20.0)))
    elif rid == "junction.corner_store":
        s = shop(rid, display, town, x, base, "side.ext_brick", "side.wall_shop", "side.floor_linoleum",
                 [C("counter", "drawer", ("int.checkout", "int.checkout"), "store_counter"), C("aisle_a", "shelf", SPARSE, "grocery_shelf"),
                  C("aisle_b", "shelf", ("int.gondola_empty", "int.gondola_empty"), "grocery_shelf", True), C("cooler", "fridge", FREEZER, "grocery_cooler")],
                 [C("stock", "crate", CRATE, "grocery_stock")])
    elif rid == "junction.worker_house":
        s = house(rid, display, town, x, base, storeys=1, layout="b", ext="side.ext_logs")
    else:  # utility
        s = office(rid, display, town, x, base, ext="side.ext_concrete", pool="utility",
                   ground_extra=lambda s: s.container("switch_room", "garage", 13.5, 0, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool="electronics"))
    return s


# ====================================================================== Greyhollow (mining)
def greyhollow(interiors):
    o = Outdoor("greyhollow", "REGION_GREYHOLLOW", 3000, 2200, seed=81)
    RY, NB, SB = 1300, 1170, 1680
    o.road([(1400, 2200), (1400, RY)])
    o.road([(200, RY), (2800, RY)])
    o.road([(1700, RY), (1700, 760)], width=110, asset="env.ground_frozen_mud", map_kind="track")
    o.exit("road_south", (1400, 2140), (1310, 2160, 180, 40), "junction", (1600, 220), 90, "PROMPT_ROAD_JUNCTION")
    # the mine: hillside, adit, headframe, hopper, slag
    o.map_areas.append({"kind": "yard", "polygon": [[1300, 400], [2900, 400], [2900, 1000], [1300, 1000]]})
    o.prop((1700, 700), "set.adit", (420, 60), foff=(0, -20), name="Adit")
    o.entities.append({"id": "greyhollow.mine_entrance", "type": "portal", "position": [1700, 712], "interact_range": 70, "priority": 2,
                       "target": {"region": "greyhollow.mine", "position": [0, 0]}, "prompt_key": "PROMPT_ENTER_MINE"})
    o.map_landmarks.append({"kind": "ruin", "position": [1700, 660], "size": [260, 90], "label_key": "MAP_MINE"})
    o.prop((2250, 820), "set.headframe", (160, 40), name="Headframe")
    o.map_landmarks.append({"kind": "building", "position": [2250, 760], "size": [180, 90], "label_key": "MAP_HEADFRAME"})
    o.prop((2620, 900), "set.hopper", (240, 30), name="Hopper")
    o.prop((2850, 700), "set.slag", (300, 40), name="Slag")
    o.prop((1150, 760), "set.slag", (300, 40), flip=True, name="Slag2")
    # main street
    sp = interiors("greyhollow.mine_office", "REGION_GREYHOLLOW_MINE_OFFICE", 600, NB, "greyhollow")
    o.building("mine_office", 600, NB, "MAP_MINE_OFFICE", enter=("greyhollow.mine_office", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("greyhollow.general_store", "REGION_GREYHOLLOW_GENERAL_STORE", 1050, NB, "greyhollow")
    o.building("general_store", 1050, NB, "MAP_GENERAL_STORE", enter=("greyhollow.general_store", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("greyhollow.mine_supply", "REGION_GREYHOLLOW_MINE_SUPPLY", 700, SB, "greyhollow")
    o.building("mine_supply", 700, SB, "MAP_MINE_SUPPLY", enter=("greyhollow.mine_supply", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("greyhollow.rowhouse", "REGION_GREYHOLLOW_ROWHOUSE", 2000, SB, "greyhollow")
    o.building("rowhouse", 2000, SB, "MAP_ROWHOUSES", enter=("greyhollow.rowhouse", sp, "PROMPT_ENTER_HOME"))
    o.building("rowhouse", 2480, SB, None, flip=True)
    sp = interiors("greyhollow.store_shed", "REGION_GREYHOLLOW_STORE_SHED", 2350, NB, "greyhollow")
    o.building("store_shed", 2350, NB + 20, "MAP_STORAGE", enter=("greyhollow.store_shed", sp, "PROMPT_ENTER_BUILDING"))
    o.vehicle_container("ore_truck", (1100, RY + 150), "prop.truck_wreck", "vehicle_truck")
    o.cache("hunting_camp", (560, 420), "build.crate", "hunter_cabin", "PROMPT_SEARCH_HUNTING_CAMP", foot=(80, 20))
    o.cache("sled", (2820, 1640), "prop.sled", "wilderness_frozen", "PROMPT_SEARCH_SLED")
    for xl in (400, 900, 1900, 2600):
        o.prop((xl, NB + 58), "world.town_streetlamp", (10, 8))
    o.pines([(40, 1250, 60, 380), (40, 2960, 1900, 2160), (2950, 2990, 60, 2100)], seed=82)
    o.write({"spawn_points": [[1400, 2040]], "climate": {"exposure": 1.25, "fog": 1.2}, "discovery": "greyhollow",
             "zombies": {"base_population": 4, "spawns": [[600, 900], [2300, 1500], [2600, 700], [900, 1900]],
                         "entries": [[20, 600], [20, 1800], [2980, 900], [2980, 1700], [800, 20], [2400, 20]]},
             "omens": {"laugh_spots": [[1700, 760], [2250, 860], [2480, 1640]], "laugh_radius": 700,
                       "shadow_paths": [[[1500, 900], [1620, 880]]]},
             "map": {"offset": [8240, -2215]}})


def greyhollow_interiors(rid, display, x, base, town):
    if rid == "greyhollow.mine_office":
        s = office(rid, display, town, x, base, pool="mine_office",
                   upper_extra=lambda s: s.container("lamp_room", "shelf", 14.0, 1, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool="mine_lamps"))
    elif rid == "greyhollow.general_store":
        s = shop(rid, display, town, x, base, "side.ext_siding", "side.wall_house_b", "side.floorboards",
                 [C("counter", "drawer", ("int.checkout", "int.checkout"), "store_counter"), C("aisle_food", "shelf", SPARSE, "grocery_shelf"),
                  C("aisle_goods", "shelf", SHELF, "general_goods"), C("rack", "rack", RACK, "clothing_rack")],
                 [C("stock", "crate", CRATE, "grocery_stock"), C("stock_b", "crate", CRATE, "general_goods", True)])
    elif rid == "greyhollow.mine_supply":
        s = shop(rid, display, town, x, base, "side.ext_brick", "side.wall_brick_in", "side.floor_concrete",
                 [C("counter", "drawer", ("int.pharm_counter", "int.pharm_counter"), "store_counter"), C("tool_wall", "shelf", METAL, "mine_tools"),
                  C("lamps", "shelf", METAL, "mine_lamps"), C("ropes", "garage", CRATE, "mine_tools")],
                 [C("explosives_locker", "locker", LOCKER, "mine_store", True), C("parts", "garage", METAL, "industrial_parts")], labels=("SIDE_STOCKROOM",))
    elif rid == "greyhollow.rowhouse":
        s = house(rid, display, town, x, base, wall_a="side.wall_house_b", wall_b="side.wall_house", pool_prefix="miner_home", layout="b", ext="side.ext_brick")
    else:
        s = hall(rid, display, town, x, base, "side.ext_concrete", "side.wall_brick_in", "industrial",
                 [C("crate_a", "crate", CRATE, "industrial_materials"), C("shelf_a", "shelf", METAL, "industrial_parts"),
                  C("crate_b", "crate", CRATE, "mine_store"), C("drums", "garage", CRATE, "fuel_depot", True)], width=20)
    return s


# ====================================================================== Stillwater (residential / commercial)
def stillwater(interiors):
    o = Outdoor("stillwater", "REGION_STILLWATER", 3600, 2400, seed=91)
    RY, NB, SB = 1200, 1060, 1720
    o.road([(0, RY), (3600, RY)])
    o.road([(1800, RY), (1800, 1520)], width=120)
    o.patch((1640, 1290, 320, 200), "env.ground_frozen_mud", "1, 1, 1, 0.85")
    o.prop((1800, 1430), "set.memorial", (60, 20), name="Memorial")
    o.map_landmarks.append({"kind": "ruin", "position": [1800, 1400], "size": [160, 120], "label_key": "MAP_SQUARE"})
    o.exit("road_west", (60, RY), (0, RY - 90, 40, 180), "junction", (3000, 1100), 180, "PROMPT_ROAD_JUNCTION")
    o.exit("road_east", (3540, RY), (3560, RY - 90, 40, 180), "harbor", (220, 900), 0, "PROMPT_ROAD_HARBOR")
    sp = interiors("stillwater.market", "REGION_STILLWATER_MARKET", 500, NB, "stillwater")
    o.building("market", 500, NB, "MAP_MARKET", enter=("stillwater.market", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("stillwater.outfitters", "REGION_STILLWATER_OUTFITTERS", 950, NB, "stillwater")
    o.building("outfitters", 950, NB, "MAP_OUTFITTERS", enter=("stillwater.outfitters", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("stillwater.civic_hall", "REGION_STILLWATER_CIVIC_HALL", 1800, NB, "stillwater")
    o.building("civic_hall", 1800, NB, "MAP_CIVIC_HALL", enter=("stillwater.civic_hall", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("stillwater.clinic", "REGION_STILLWATER_CLINIC", 2550, NB, "stillwater")
    o.building("clinic", 2550, NB, "MAP_CLINIC", enter=("stillwater.clinic", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("stillwater.police", "REGION_STILLWATER_POLICE", 3080, NB, "stillwater")
    o.building("police", 3080, NB, "MAP_POLICE", enter=("stillwater.police", sp, "PROMPT_ENTER_BUILDING"))
    o.building("church", 500, SB, "MAP_CHURCH")
    sp = interiors("stillwater.apartments", "REGION_STILLWATER_APARTMENTS", 1050, SB, "stillwater")
    o.building("apartments", 1050, SB, "MAP_APARTMENTS", enter=("stillwater.apartments", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("stillwater.house", "REGION_STILLWATER_HOUSE", 2300, SB, "stillwater")
    o.building("town_house_a", 2300, SB, None, enter=("stillwater.house", sp, "PROMPT_ENTER_HOME"))
    sp = interiors("stillwater.quiet_house", "REGION_STILLWATER_QUIET_HOUSE", 2800, SB, "stillwater")
    o.building("quiet_house", 2800, SB, None, enter=("stillwater.quiet_house", sp, "PROMPT_ENTER_HOME"))
    o.building("town_house_a", 3250, SB, None, flip=True)
    o.vehicle_container("sedan", (1300, RY + 130), "prop.car_sedan", "vehicle_car")
    o.vehicle_container("police_car", (2850, RY - 140), "prop.car_sedan", "vehicle_police", flip=True)
    for xl in (300, 750, 1350, 2250, 2800, 3300):
        o.prop((xl, NB + 58), "world.town_streetlamp", (10, 8))
    o.pines([(40, 3560, 60, 420), (40, 3560, 2000, 2360)], seed=92)
    o.write({"spawn_points": [[220, RY]], "climate": {"exposure": 1.0, "fog": 1.0}, "discovery": "stillwater",
             "zombies": {"base_population": 5, "spawns": [[700, 800], [2000, 760], [3100, 1500], [1500, 1900], [600, 1950]],
                         "entries": [[20, 500], [20, 1900], [3580, 500], [3580, 1900], [1800, 20], [1800, 2380]]},
             "omens": {"laugh_spots": [[1800, 1000], [2800, 1680], [500, 1680]], "laugh_radius": 700,
                       "shadow_paths": [[[2700, 1800], [2860, 1790]], [[1000, 900], [1150, 920]]]},
             "map": {"offset": [10840, 185], "areas": [{"kind": "yard", "polygon": [[200, 760], [3400, 760], [3400, 1110], [200, 1110]]}]}})


def stillwater_interiors(rid, display, x, base, town):
    if rid == "stillwater.market":
        return shop(rid, display, town, x, base, "side.ext_brick", "side.wall_shop", "side.floor_linoleum",
                    [C("checkout", "drawer", ("int.checkout", "int.checkout"), "store_counter"), C("aisle_a", "shelf", SHELF, "grocery_shelf"),
                     C("aisle_b", "shelf", SPARSE, "grocery_shelf"), C("aisle_c", "shelf", ("int.gondola_empty", "int.gondola_empty"), "grocery_shelf", True),
                     C("drinks", "fridge", FREEZER, "grocery_cooler"), C("household", "shelf", SPARSE, "household")],
                    [C("stock_a", "shelf", METAL, "grocery_stock"), C("stock_b", "crate", CRATE, "grocery_stock")])
    if rid == "stillwater.outfitters":
        return shop(rid, display, town, x, base, "side.ext_siding", "side.wall_house_b", "side.floorboards",
                    [C("rack_coats", "rack", RACK, "clothing_rack"), C("rack_b", "rack", ("int.clothes_rack_empty", "int.clothes_rack_empty"), "clothing_rack", True),
                     C("boots", "shelf", ("int.display_table", "int.display_table"), "clothing_shoes"), C("packs", "shelf", SPARSE, "clothing_gear")],
                    [C("stock", "crate", CRATE, "clothing_stock")], labels=("SIDE_STOCKROOM",))
    if rid == "stillwater.clinic":
        return shop(rid, display, town, x, base, "side.ext_concrete", "side.wall_office", "side.floor_linoleum",
                    [C("reception", "drawer", ("int.pharm_counter", "int.pharm_counter"), "clinic_desk"), C("exam_a", "medical", MED, "clinic_medical"),
                     C("exam_b", "medical", ("int.med_cabinet_open", "int.med_cabinet_open"), "clinic_medical", True), C("supply", "shelf", METAL, "clinic_supply")],
                    [C("drug_store", "medical", MED, "clinic_drugs"), C("crate", "crate", CRATE, "clinic_supply")], labels=("SIDE_DISPENSARY",))
    if rid == "stillwater.police":
        def ground(s):
            s.container("evidence", "crate", 12.0, 0, "int.crate", "int.crate_open", {}, pool="police_evidence")

        def upper(s):
            s.container("armory", "locker", 14.0, 1, "int.locker", "int.locker_open", {}, pool="police_armory")
        return office(rid, display, town, x, base, pool="police", ground_extra=ground, upper_extra=upper)
    if rid == "stillwater.apartments":
        return house(rid, display, town, x, base, wall_a="side.wall_office", wall_b="side.wall_house", pool_prefix="home", layout="c", ext="side.ext_brick")
    if rid == "stillwater.house":
        return house(rid, display, town, x, base, wall_a="side.wall_house_b", wall_b="side.wall_cabin", pool_prefix="home", layout="c")
    if rid == "stillwater.quiet_house":
        def hideout(s):
            # An ordinary house. Two disturbed survivors hide here (an approved situational
            # hunt trigger): upstairs behind the boxes, downstairs behind the sofa.
            s.entity({"id": "hideout", "type": "hideout", "threshold": 0.9,
                      "lairs": [[s.x(13.4), s.y(1)], [s.x(12.2), s.y(0)]],
                      "initial": {"disturbance": 0.0, "triggered": False, "cleared": False, "zombies": []}}, 8.0, 0)
        return house(rid, display, town, x, base, wall_a="side.wall_house_b", pool_prefix="home", extra=hideout)
    return civic_hall(rid, display, x, base, town)


def civic_hall(rid, display, x, base, town):
    """Milestone C: basement + three above-ground floors (filled in by build_civic_hall)."""
    import build_landmarks
    return build_landmarks.civic_hall(rid, display, town, _door_target(town, x, base))


# ====================================================================== Port Halden (frozen harbor)
def harbor(interiors):
    o = Outdoor("harbor", "REGION_HARBOR", 3600, 2600, ambience="amb.cold_wind", seed=101)
    RY, NB, QB = 900, 780, 1300
    SHORE = 1460
    CHANNEL = 1720
    o.road([(0, RY), (3500, RY)])
    o.exit("road_west", (60, RY), (0, RY - 90, 40, 180), "stillwater", (3400, 1200), 180, "PROMPT_ROAD_STILLWATER")
    # quay, sea ice, piers and the open channel
    o.patch((120, QB + 20, 3360, SHORE - QB - 20), "set.pier")
    o.patch((-400, SHORE, 4400, CHANNEL - SHORE), "set.sea_ice")
    o.avoid.append((-400, QB, 4400, 2000))  # no dead grass on the quay, the ice or the water
    o.patch((-400, CHANNEL, 4400, 1300), "set.water")
    piers = [(1000, 120), (2300, 140), (3000, 120)]
    for (px, pw) in piers:
        o.patch((px - pw / 2, SHORE - 10, pw, CHANNEL - SHORE + 50), "set.pier")
    o.block([(-40, CHANNEL), (3640, CHANNEL), (3640, 2640), (-40, 2640)])  # the open water cannot be walked
    o.map_areas.append({"kind": "water", "polygon": [[0, CHANNEL], [3600, CHANNEL], [3600, 2600], [0, 2600]]})
    o.map_areas.append({"kind": "ice", "polygon": [[0, SHORE], [3600, SHORE], [3600, CHANNEL], [0, CHANNEL]]})
    o.drifts.append({"y": 1960, "speed": 9.0, "x0": -500, "x1": 4100, "assets": ["set.iceberg_a", "set.iceberg_b", "set.floe"], "count": 4, "seed": 11})
    o.drifts.append({"y": 2240, "speed": -6.0, "x0": -600, "x1": 4200, "assets": ["set.iceberg_c", "set.floe", "set.iceberg_a"], "count": 3, "seed": 23})
    o.drifts.append({"y": 2520, "speed": 4.0, "x0": -600, "x1": 4200, "assets": ["set.iceberg_b", "set.iceberg_c"], "count": 3, "seed": 37})
    o.prop((1700, 1650), "set.trawler", (330, 50), name="Trawler")
    o.map_landmarks.append({"kind": "ruin", "position": [1700, 1600], "size": [320, 70], "label_key": "MAP_TRAWLER"})
    o.entities.append({"id": "harbor.trawler_hold", "type": "container", "kind": "crate", "position": [1760, 1680], "interact_range": 90,
                       "prompt_key": "PROMPT_SEARCH_CRATE", "art": "", "art_searched": "", "loot": {}, "pool": "marine", "initial": {"searched": False}})
    o.prop((2900, QB + 60), "set.crane", (200, 40), name="Crane")
    o.map_landmarks.append({"kind": "building", "position": [2900, QB], "size": [200, 80], "label_key": "MAP_CRANE"})
    for i, (cx, col) in enumerate(((2400, "red"), (2620, "blue"))):
        o.prop((cx, QB + 30 + i * 40), f"set.container_{col}", (220, 40), name=f"Container{i}")
    o.entities.append({"id": "harbor.container_cargo", "type": "container", "kind": "crate", "position": [2420, QB + 60], "interact_range": 90,
                       "prompt_key": "PROMPT_SEARCH_CRATE", "art": "", "art_searched": "", "loot": {}, "pool": "harbor_cargo", "initial": {"searched": False}})
    for bx in (900, 1200, 2150, 2850, 3300):
        o.prop((bx, SHORE - 20), "set.bollard", (20, 12))
    o.prop((1150, QB + 70), "set.fish_crates", (90, 30))
    o.prop((3350, 640), "set.lighthouse", (110, 40), name="Lighthouse")
    o.map_landmarks.append({"kind": "building", "position": [3350, 600], "size": [110, 90], "label_key": "MAP_LIGHTHOUSE"})
    # buildings: north of the road and on the quay
    sp = interiors("harbor.cottage", "REGION_HARBOR_COTTAGE", 500, NB, "harbor")
    o.building("harbor_house", 500, NB, None, enter=("harbor.cottage", sp, "PROMPT_ENTER_HOME"))
    o.building("harbor_house", 850, NB, None, flip=True)
    sp = interiors("harbor.chandlery", "REGION_HARBOR_CHANDLERY", 1450, NB, "harbor")
    o.building("chandlery", 1450, NB, "MAP_CHANDLERY", enter=("harbor.chandlery", sp, "PROMPT_ENTER_STORE"))
    sp = interiors("harbor.office", "REGION_HARBOR_OFFICE", 2150, NB, "harbor")
    o.building("harbor_office", 2150, NB, "MAP_HARBOR_MASTER", enter=("harbor.office", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("harbor.cannery", "REGION_HARBOR_CANNERY", 600, QB, "harbor")
    o.building("cannery", 600, QB, "MAP_CANNERY", enter=("harbor.cannery", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("harbor.warehouse", "REGION_HARBOR_WAREHOUSE", 1400, QB, "harbor")
    o.building("warehouse_a", 1400, QB, "MAP_WAREHOUSE", enter=("harbor.warehouse", sp, "PROMPT_ENTER_BUILDING"))
    sp = interiors("harbor.net_shed", "REGION_HARBOR_NET_SHED", 2000, QB, "harbor")
    o.building("net_shed", 2000, QB, None, enter=("harbor.net_shed", sp, "PROMPT_ENTER_BUILDING"))
    o.vehicle_container("pickup", (2700, RY + 120), "prop.truck_wreck", "vehicle_truck")
    for xl in (300, 1100, 1800, 2500, 3100):
        o.prop((xl, NB + 58), "world.town_streetlamp", (10, 8))
    o.pines([(40, 3200, 60, 380)], seed=102)
    o.write({"spawn_points": [[220, RY]], "climate": {"exposure": 1.35, "fog": 1.4}, "discovery": "harbor",
             "ambience2": "amb.harbor_ice",
             "zombies": {"base_population": 4, "spawns": [[700, 600], [2200, 1200], [3000, 1400], [1500, 600]],
                         "entries": [[20, 500], [20, 1300], [3580, 500], [3580, 1300], [1700, 20]]},
             "omens": {"laugh_spots": [[1400, 1250], [3350, 700], [1700, 1600]], "laugh_radius": 700,
                       "shadow_paths": [[[2300, 1500], [2300, 1640]], [[600, 1350], [760, 1360]]]},
             "map": {"offset": [14440, 85]}},
            extra_nodes="")


def harbor_interiors(rid, display, x, base, town):
    if rid == "harbor.cottage":
        return house(rid, display, town, x, base, wall_a="side.wall_cabin", wall_b="side.wall_house", pool_prefix="harbor_home", layout="b", ext="side.ext_logs")
    if rid == "harbor.chandlery":
        return shop(rid, display, town, x, base, "side.ext_siding", "side.wall_house_b", "side.floorboards",
                    [C("counter", "drawer", ("int.checkout", "int.checkout"), "store_counter"), C("ropes", "shelf", METAL, "marine"),
                     C("lamps", "shelf", SPARSE, "marine"), C("oilskins", "rack", RACK, "clothing_rack")],
                    [C("stock", "crate", CRATE, "marine"), C("flares", "locker", LOCKER, "marine_safety")], labels=("SIDE_STOCKROOM",))
    if rid == "harbor.office":
        return office(rid, display, town, x, base, pool="harbor_office",
                      upper_extra=lambda s: s.container("radio_room", "shelf", 14.0, 1, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool="harbor_radio"))
    if rid == "harbor.cannery":
        return hall(rid, display, town, x, base, "side.ext_brick", "side.wall_shop", "cannery",
                    [C("cold_store", "fridge", FREEZER, "cannery_cold"), C("tins", "shelf", METAL, "cannery_tins"),
                     C("line_bench", "drawer", ("int.display_table", "int.display_table"), "cannery_tins", True),
                     C("crate", "crate", CRATE, "cannery_tins"), C("locker", "locker", LOCKER, "worker_locker")], width=26)
    if rid == "harbor.warehouse":
        return hall(rid, display, town, x, base, "side.ext_brick", "side.wall_brick_in", "warehouse",
                    [C("pallet_a", "crate", CRATE, "harbor_cargo"), C("rack_a", "shelf", METAL, "marine"),
                     C("pallet_b", "crate", CRATE, "harbor_cargo", True), C("rack_b", "shelf", METAL, "warehouse_freight"),
                     C("fuel_cage", "garage", CRATE, "fuel_depot"), C("tool_chest", "toolbox", TOOLS, "workshop_tools")], width=30,
                    props=(("int.boxes", 14.0),))
    return hall(rid, display, town, x, base, "side.ext_siding", "side.wall_cabin", "marine",
                [C("nets", "shelf", METAL, "marine"), C("chest", "toolbox", TOOLS, "marine"), C("crate", "crate", CRATE, "marine_safety")], width=16)


# ====================================================================== Ashgrove: the road east opens
def open_ashgrove_east():
    p = os.path.join(ROOT, "content", "regions", "town.json")
    d = json.load(open(p))
    d["vehicle_exits"] = [e for e in d.get("vehicle_exits", []) if e["target"]["region"] != "junction"]
    d["vehicle_exits"].append({"rect": [3160, 920, 40, 180], "target": {"region": "junction", "position": [220, 1100], "rotation": 0}})
    d["entities"] = [e for e in d["entities"] if e["id"] != "town.road_east"]
    d["entities"].append({"id": "town.road_east", "type": "portal", "position": [3140, 1010], "interact_range": 80, "priority": 2,
                          "target": {"region": "junction", "position": [220, 1100]}, "prompt_key": "PROMPT_ROAD_JUNCTION"})
    lm = d.get("map", {}).get("landmarks", [])
    d["map"]["landmarks"] = [l for l in lm if l.get("label_key") != "MAP_ROAD_BLOCKED"]
    roads = d["map"].get("roads", [])
    for r in roads:
        if r.get("points") == [[0, 1010], [3000, 1010]]:
            r["points"] = [[0, 1010], [3200, 1010]]
    dump_json(p, d)
    sp = os.path.join(ROOT, "scenes", "regions", "town", "town.tscn")
    s = open(sp).read()
    # the jackknifed trailer was dragged to the verge: the road east is passable now
    s = s.replace('[node name="Roadblock" type="Node2D" parent="YSort"]\nscript = ExtResource("prop")\nposition = Vector2(3080, 1100)',
                  '[node name="Roadblock" type="Node2D" parent="YSort"]\nscript = ExtResource("prop")\nposition = Vector2(3080, 1330)')
    if 'entity_id = "town.road_east"' not in s:
        s = s.rstrip("\n") + '\n\n[node name="RoadEast" type="Node2D" parent="YSort"]\nscript = ExtResource("portalv")\nentity_id = "town.road_east"\n'
    open(sp, "w").write(s)


# ====================================================================== build
def build():
    made = []

    def maker(fn):
        def interiors(rid, display, x, base, town):
            s = fn(rid, display, x, base, town)
            d = s.definition({"surface": {"region": town, "position": [x, base]}, "tint": [0.5, 0.5, 0.53], **INTERIOR})
            dump_json(os.path.join(ROOT, "content", "regions", rid.replace(".", "_") + ".json"), d)
            made.append(rid)
            return s.spawn()
        return interiors

    junction(maker(junction_interiors))
    greyhollow(maker(greyhollow_interiors))
    import build_landmarks
    m = build_landmarks.mine("greyhollow.mine", "REGION_GREYHOLLOW_MINE", "greyhollow", [1700, 780])
    dump_json(os.path.join(ROOT, "content", "regions", "greyhollow_mine.json"), m)
    made.append("greyhollow.mine")
    g = json.load(open(os.path.join(ROOT, "content", "regions", "greyhollow.json")))
    for e in g["entities"]:
        if e["id"] == "greyhollow.mine_entrance":
            e["target"]["position"] = m["spawn_points"][0]
    dump_json(os.path.join(ROOT, "content", "regions", "greyhollow.json"), g)
    stillwater(maker(stillwater_interiors))
    harbor(maker(harbor_interiors))
    open_ashgrove_east()
    return made


if __name__ == "__main__":
    print("settlements built; interiors:", ", ".join(build()))
