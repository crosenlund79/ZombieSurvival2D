#!/usr/bin/env python3
"""Iteration 015 A: the wilderness between the settlements.

Five large travel regions fill the world between the five named settlements
(tools/world_layout.py): Birchwater Road, the Corran Forest, the Greyhollow
Pass, the Stillwater Road and the Halden Coast. Each is many screens across:
a winding road (and side tracks), dense pine forest broken by clearings, frozen
lakes, rock outcrops and fallen trees, power lines along the main roads,
occasional landmarks (a hunting stand, a radio mast, a snow-buried car) and
isolated cabins — some abandoned, some ruined, a few you can enter (side-view
interiors with their own loot pools).

Written as data, not scene nodes: content/regions/wild_<name>.json holds the
"wild" block (ground, patches, scatter) that WildTerrain streams by chunk, the
"obstacles" the host navigation uses, and the map data (roads, lakes, a forest
grid, hidden cabin markers that appear once explored). Each region also gets a
tiny scene (scenes/regions/wild/<name>.tscn). Ids are stable; re-running is
deterministic (seeded). Usage: python3 tools/build_wilderness.py
"""
import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_side_interiors import Section, dump_json, ROOT  # noqa: E402
import world_layout as WL  # noqa: E402

FOOT = {"env.pine_a": (30, 12), "env.pine_b": (30, 12), "env.birch_bare": (20, 10), "env.stump_snow": (40, 14),
        "env.rock_a": (150, 40), "env.rock_b": (120, 34), "env.rock_c": (260, 60), "env.fallen_tree": (360, 26),
        "env.power_pole": (14, 10), "env.road_sign": (130, 12), "env.sign_wood": (20, 10), "env.hunting_stand": (150, 30),
        "env.buried_car": (380, 50), "env.radio_mast": (130, 30), "env.woodpile": (150, 30), "env.barrels": (110, 30),
        "env.crates": (130, 30), "env.stove_rusted": (90, 24), "env.bench": (130, 16), "env.fence_broken": (0, 0),
        "world.cabin_small": (300, 60), "world.cabin_porch": (420, 70), "world.cabin_large": (500, 70),
        "world.cabin_weathered": (420, 60), "world.cabin_ruin": (380, 60), "world.cabin_workshop": (380, 60),
        "world.lean_to": (240, 30), "world.outhouse": (80, 30), "prop.truck_wreck": (180, 40), "prop.car_sedan": (200, 46),
        "set.sea_ice": (0, 0)}
NAV = {"env.rock_a", "env.rock_b", "env.rock_c", "env.fallen_tree", "env.hunting_stand", "env.buried_car", "env.radio_mast",
       "world.cabin_small", "world.cabin_porch", "world.cabin_large", "world.cabin_weathered", "world.cabin_ruin",
       "world.cabin_workshop", "world.lean_to", "world.outhouse", "prop.truck_wreck", "prop.car_sedan", "env.woodpile", "env.crates"}
UNDER = ["env.shrub_frozen_a", "env.shrub_frozen_b", "env.dead_grass_a", "env.dead_grass_b", "env.dead_grass_c"]


def catmull(points, step=70.0):
    """Smooth polyline through control points (Catmull-Rom), sampled about every `step` px."""
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg = math.dist(p1, p2)
        n = max(2, int(seg / step))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(points[-1])
    return out


def strip(line, width):
    """A ribbon polygon around a polyline (one polygon, left side out and right side back)."""
    left, right = [], []
    for i, p in enumerate(line):
        a = line[max(0, i - 1)]
        b = line[min(len(line) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * width / 2, dx / L * width / 2
        left.append((p[0] + nx, p[1] + ny))
        right.append((p[0] - nx, p[1] - ny))
    return left + right[::-1]


def dist_to_line(p, line):
    best = 1e9
    for a, b in zip(line, line[1:]):
        ax, ay = a; bx, by = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy or 1.0
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L2))
        best = min(best, math.hypot(p[0] - ax - t * dx, p[1] - ay - t * dy))
    return best


def noise_field(w, h, cell, seed):
    """A smooth 0..1 value-noise field sampled on a coarse grid (bilinear)."""
    R = random.Random(seed)
    gw, gh = int(w / cell) + 3, int(h / cell) + 3
    g = [[R.random() for _ in range(gw)] for _ in range(gh)]

    def f(x, y):
        gx, gy = x / cell, y / cell
        x0, y0 = int(gx), int(gy)
        tx, ty = gx - x0, gy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] * (1 - tx) + g[y0][x0 + 1] * tx
        b = g[y0 + 1][x0] * (1 - tx) + g[y0 + 1][x0 + 1] * tx
        return a * (1 - ty) + b * ty
    return f


def in_poly(p, poly):
    x, y = p
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def blob(cx, cy, rx, ry, R, n=14, irr=0.25):
    return [(cx + rx * math.cos(2 * math.pi * k / n) * (1 + R.uniform(-irr, irr)),
             cy + ry * math.sin(2 * math.pi * k / n) * (1 + R.uniform(-irr, irr))) for k in range(n)]


class Wild:
    def __init__(self, rid, display, discovery, seed, ambience="amb.cold_wind", forest=0.42):
        self.rid = rid
        ox, oy, self.w, self.h = WL.REGIONS[rid]
        self.offset = [ox, oy]
        self.display, self.discovery, self.ambience = display, discovery, ambience
        self.R = random.Random(seed)
        self.seed = seed
        self.forest_thresh = forest
        self.patches, self.scatter, self.obstacles, self.entities = [], [], [], []
        self.roads = []        # (line, width, kind)
        self.clear = []        # (cx, cy, r) kept free of trees
        self.lakes = []
        self.map_landmarks, self.map_areas = [], []
        self.interiors = []
        self.spawns = []

    # ---- authoring
    def road(self, ctrl, width=150, kind="road", asset="env.ground_road_snow"):
        ctrl = [tuple(p) for p in ctrl]
        if kind == "road" and len(ctrl) > 2:
            # roads meet region edges straight on, so a car crossing over keeps a straight line for a while
            (x0, y0), (x1, y1) = ctrl[0], ctrl[-1]
            def lead(px, py):
                if px <= 1: return (900.0, py)
                if px >= self.w - 1: return (self.w - 900.0, py)
                if py <= 1: return (px, 900.0)
                return (px, self.h - 900.0)
            ctrl = [ctrl[0], lead(x0, y0)] + [c for c in ctrl[1:-1] if math.dist(c, ctrl[0]) > 1300 and math.dist(c, ctrl[-1]) > 1300] + [lead(x1, y1), ctrl[-1]]
        line = catmull(ctrl)
        self.patches.append([asset, [round(v, 1) for p in strip(line, width) for v in p]])
        self.roads.append((line, width, kind))
        return line

    def lake(self, cx, cy, rx, ry):
        poly = blob(cx, cy, rx, ry, self.R, n=18, irr=0.18)
        self.patches.append(["set.sea_ice", [round(v, 1) for p in poly for v in p]])
        self.lakes.append(poly)
        self.map_areas.append({"kind": "ice", "polygon": [[round(x), round(y)] for x, y in poly]})

    def clear_of_roads(self, x, y, fw):
        """Pushes a point away from every road until an object `fw` wide stands clear of it."""
        for _ in range(12):
            moved = False
            for line, width, _k in self.roads:
                best, bp = 1e9, None
                for a, b in zip(line, line[1:]):
                    dx, dy = b[0] - a[0], b[1] - a[1]
                    L2 = dx * dx + dy * dy or 1.0
                    t = max(0.0, min(1.0, ((x - a[0]) * dx + (y - a[1]) * dy) / L2))
                    px, py = a[0] + t * dx, a[1] + t * dy
                    d = math.hypot(x - px, y - py)
                    if d < best:
                        best, bp = d, (px, py)
                need = width / 2 + fw / 2 + 40
                if best < need:
                    nx, ny = (x - bp[0], y - bp[1]) if best > 1 else (0.0, 1.0)
                    L = math.hypot(nx, ny) or 1.0
                    x, y = bp[0] + nx / L * need, bp[1] + ny / L * need
                    moved = True
            if not moved:
                break
        return x, y

    def put(self, asset, x, y, flip=False, sway=False, foot=None):
        fw, fh = foot if foot is not None else FOOT.get(asset, (0, 0))
        if fw > 0 and asset not in ("env.power_pole", "env.pine_a", "env.pine_b", "env.birch_bare", "env.stump_snow"):
            x, y = self.clear_of_roads(x, y, fw)
        self.scatter.append([asset, round(x, 1), round(y, 1), 1 if flip else 0, fw, fh, 1 if sway else 0])
        if asset in NAV and fw > 0:
            self.obstacles.append([round(x - fw / 2), round(y - fh), fw, fh])

    def cabin(self, key, x, y, variant, enter=None, label="MAP_CABIN", dressing=("woodpile", "outhouse")):
        """An isolated cabin in its own clearing; enter = interior builder (side view)."""
        self.clear.append((x, y - 60, 520))
        self.put("world." + variant, x, y)
        R = self.R
        for i, d in enumerate(dressing):
            ang = R.uniform(0, math.pi * 2)
            dx, dy = (-300 + 600 * (i % 2), 90 + 40 * i) if d != "fence_broken" else (R.uniform(-200, 200), -40)
            self.put({"woodpile": "env.woodpile", "outhouse": "world.outhouse", "barrels": "env.barrels", "crates": "env.crates",
                      "bicycle": "env.bicycle", "stove": "env.stove_rusted", "bench": "env.bench", "belongings": "env.belongings",
                      "fence_broken": "env.fence_broken", "sign": "env.sign_wood"}[d], x + dx, y + dy, flip=R.random() < 0.5)
        if enter:
            rid, spawn = enter(self, key, x, y)
            self.entities.append({"id": f"{self.rid}.{key}_door", "type": "portal", "position": [x, y + 8], "interact_range": 60,
                                  "priority": 2, "target": {"region": rid, "position": spawn}, "prompt_key": "PROMPT_ENTER_CABIN"})
        self.map_landmarks.append({"kind": "cabin", "position": [x, y - 40], "size": [140, 70], "hidden": True, "label_key": label})

    def landmark(self, asset, x, y, kind, label=None, clear=260):
        self.clear.append((x, y, clear))
        self.put(asset, x, y)
        self.map_landmarks.append({"kind": kind, "position": [x, y], "hidden": True, **({"label_key": label} if label else {})})

    def cache(self, key, x, y, asset, pool, prompt):
        self.put(asset, x, y)
        self.entities.append({"id": f"{self.rid}.{key}", "type": "container", "kind": "crate", "position": [x, y + 16],
                              "interact_range": 80, "prompt_key": prompt, "art": "", "art_searched": "", "loot": {}, "pool": pool,
                              "initial": {"searched": False}})

    def power_line(self, line, side=1, every=520, offset=170):
        acc = 0.0
        for a, b in zip(line, line[1:]):
            seg = math.dist(a, b)
            acc += seg
            if acc >= every:
                acc = 0.0
                dx, dy = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
                self.put("env.power_pole", b[0] - dy * offset * side, b[1] + dx * offset * side)

    # ---- generation
    def fill(self):
        R = self.R
        field = noise_field(self.w, self.h, 900, self.seed)
        detail = noise_field(self.w, self.h, 260, self.seed + 1)
        step = 150
        def near_road(p, extra):
            for line, width, _k in self.roads:
                if dist_to_line(p, line) < width / 2 + extra:
                    return True
            return False
        def clear_spot(p):
            for (cx, cy, r) in self.clear:
                if math.hypot(p[0] - cx, p[1] - cy) < r:
                    return True
            for poly in self.lakes:
                if in_poly(p, poly):
                    return True
            return False
        forest_cells = {}
        y = 40.0
        while y < self.h - 10:
            x = 40.0 + (R.random() * step)
            while x < self.w - 10:
                p = (x + R.uniform(-50, 50), y + R.uniform(-40, 40))
                v = field(p[0], p[1]) * 0.75 + detail(p[0], p[1]) * 0.25
                if v > self.forest_thresh and not clear_spot(p) and not near_road(p, 90):
                    forest_cells[(int(p[0] // 400), int(p[1] // 400))] = 1
                    r = R.random()
                    if r < 0.12:
                        self.put("env.birch_bare", p[0], p[1], flip=R.random() < 0.5, sway=True)
                    elif r < 0.16:
                        self.put("env.stump_snow", p[0], p[1])
                    else:
                        self.put(R.choice(["env.pine_a", "env.pine_b"]), p[0], p[1], flip=R.random() < 0.5, sway=True)
                elif v > self.forest_thresh - 0.12 and not clear_spot(p) and not near_road(p, 40) and R.random() < 0.35:
                    self.put(R.choice(UNDER), p[0], p[1], flip=R.random() < 0.5, foot=(0, 0))
                elif not clear_spot(p) and not near_road(p, 160) and R.random() < 0.012:
                    self.put(R.choice(["env.rock_a", "env.rock_b", "env.rock_c", "env.fallen_tree"]), p[0], p[1], flip=R.random() < 0.5)
                x += step * R.uniform(0.75, 1.25) * (1.0 if v > self.forest_thresh else 1.6)
            y += step * 0.85
        gw, gh = int(self.w // 400) + 1, int(self.h // 400) + 1
        self.forest = {"cell": 400, "w": gw, "h": gh,
                       "data": "".join("1" if forest_cells.get((cx, cy)) else "0" for cy in range(gh) for cx in range(gw))}

    def region(self, extra):
        d = {"region_id": self.rid, "display_key": self.display, "discovery": self.discovery,
             "scene": f"res://scenes/regions/wild/{self.rid.split('.')[-1]}.tscn",
             "bounds": [0, 0, self.w, self.h], "wilderness": True,
             "spawn_points": [list(self.roads[0][0][len(self.roads[0][0]) // 2])] if self.roads else [[self.w / 2, self.h / 2]],
             "climate": {"exposure": 1.2, "fog": 1.15}, "entities": self.entities,
             "wild": {"ground": "env.ground_snow", "patches": self.patches, "scatter": self.scatter},
             "obstacles": self.obstacles,
             "zombies": {"base_population": 2, "spawns": self.spawns or [[self.w * 0.3, self.h * 0.3], [self.w * 0.7, self.h * 0.7]],
                         "entries": [[20, self.h / 2], [self.w - 20, self.h / 2]]},
             "map": {"offset": self.offset, "areas": self.map_areas, "forest": self.forest,
                     "roads": [{"kind": k, "width": wd, "points": [[round(x), round(y)] for x, y in line[::3]] + [[round(line[-1][0]), round(line[-1][1])]]}
                               for line, wd, k in self.roads],
                     "landmarks": self.map_landmarks}}
        d.update(extra)
        return d

    def write(self, extra=None):
        self.fill()
        name = self.rid.split(".")[-1]
        os.makedirs(os.path.join(ROOT, "scenes", "regions", "wild"), exist_ok=True)
        with open(os.path.join(ROOT, "scenes", "regions", "wild", f"{name}.tscn"), "w") as f:
            f.write("\n".join([
                '[gd_scene format=3]', '',
                '[ext_resource type="Script" path="res://src/presentation/world/region_view.gd" id="region"]',
                '[ext_resource type="Script" path="res://src/presentation/world/wild_terrain.gd" id="wild"]',
                '[ext_resource type="Script" path="res://src/presentation/world/atmosphere.gd" id="atmo"]', '',
                f'[node name="{name.title().replace("_", "")}" type="Node2D"]', 'script = ExtResource("region")',
                f'region_id = "{self.rid}"', f'ambience_id = "{self.ambience}"', '',
                '[node name="Terrain" type="Node2D" parent="."]', 'script = ExtResource("wild")', '',
                '[node name="Bounds" type="StaticBody2D" parent="."]', '',
                '[node name="YSort" type="Node2D" parent="."]', 'y_sort_enabled = true', '',
                '[node name="Atmosphere" type="Node2D" parent="."]', 'script = ExtResource("atmo")', f'area = Rect2(0, 0, {self.w}, {self.h})', '']))
        dump_json(os.path.join(ROOT, "content", "regions", f"wild_{name}.json"), self.region(extra or {}))
        for rid, d in self.interiors:
            dump_json(os.path.join(ROOT, "content", "regions", rid.replace(".", "_") + ".json"), d)
        return self.rid


# ====================================================================== cabin interiors
def cabin_interior(kind, pools):
    """Builder for an enterable wilderness cabin (side view, timber walls)."""
    def build(w, key, x, y):
        rid = f"{w.rid}.{key}"
        width = {"small": 11, "porch": 14, "large": 15, "workshop": 13}[kind]
        storeys = (0, 1) if kind == "large" else (0,)
        s = Section(rid, width, storeys, "REGION_" + rid.replace(".", "_").upper(), exterior="side.ext_logs")
        s.room(0, 0, width, wall="side.wall_cabin", floor="side.floorboards")
        s.exit(0.7, w.rid, [x, y + 60], prompt="PROMPT_EXIT_CABIN")
        s.window(0, 4.0)
        s.window(0, width - 3.0, boarded=True)
        R = w.R
        if kind == "workshop":
            s.container("bench", "toolbox", 3.2, 0, "int.tool_chest", "int.tool_chest_open", {}, pool=pools[0])
            s.container("shelf", "shelf", 6.8, 0, "int.metal_shelf_full", "int.metal_shelf_empty", {}, pool=pools[1])
            s.prop("int.boxes", 9.4, 0)
            s.container("crate", "crate", 11.2, 0, "int.crate", "int.crate_open", {}, pool=pools[0])
        else:
            s.prop("world.furniture_stove", 2.6, 0)
            s.container("cupboard", "cupboard", 4.6, 0, "world.furniture_cupboard", "world.furniture_cupboard", {}, pool=pools[0])
            s.prop("world.furniture_table", 6.8, 0)
            s.container("chest", "crate", 8.8, 0, "int.crate", "int.crate_open", {}, searched=R.random() < 0.3, pool=pools[1])
            if kind != "large":
                s.prop("world.furniture_bed", width - 2.0, 0, back=True)
            if kind == "porch":
                s.prop("int.armchair", 11.0, 0)
            if kind == "large":
                s.room(1, 0, width, wall="side.wall_cabin", floor="side.floorboards")
                s.stairs(13.5, 0, 1)
                s.window(1, 6.0)
                s.prop("world.furniture_bed", 4.0, 1, back=True)
                s.container("dresser", "drawer", 8.0, 1, "int.dresser", "int.dresser_open", {}, pool=pools[2] if len(pools) > 2 else pools[0])
        import interior_dressing
        interior_dressing.dress(s, "workshop" if kind == "workshop" else "cabin", seed=sum(map(ord, rid)))
        d = s.definition({"surface": {"region": w.rid, "position": [x, y]}, "tint": [0.55, 0.5, 0.46],
                          "climate": {"exposure": 1.0, "fog": 0.0, "shelter": 0.45}, "interior": True, "ambience": "amb.wind_muffled"})
        w.interiors.append((rid, d))
        return rid, s.spawn()
    return build


def sign(w, x, y, flip=False):
    w.put("env.road_sign", x, y, flip=flip)


# ====================================================================== the five regions
def birchwater():
    w = Wild("wild.birchwater", "REGION_WILD_BIRCHWATER", "wild_birchwater", 1501, forest=0.40)
    ry = WL.ROAD_Y - w.offset[1]
    line = w.road([(0, ry), (1400, ry - 120), (2800, ry + 260), (4200, ry + 80), (5600, ry - 300), (7000, ry - 60), (8000, ry)])
    w.power_line(line, 1)
    w.lake(3600, 1200, 900, 420)
    w.road([(5600, ry - 300), (5900, ry - 900), (6400, ry - 1400)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("hunters_rest", 6400, ry - 1450, "cabin_porch", enter=cabin_interior("porch", ["hunter_cabin", "home_closet"]),
            dressing=("woodpile", "outhouse", "bench"))
    w.cabin("lakeside", 3400, 600, "cabin_small", enter=cabin_interior("small", ["home_kitchen", "hunter_cabin"]),
            dressing=("woodpile", "barrels"))
    w.cabin("burnt_cabin", 1800, ry + 1500, "cabin_ruin", dressing=("belongings", "fence_broken"), label="MAP_RUIN")
    w.landmark("env.hunting_stand", 4700, ry + 900, "tower", "MAP_HUNTING_STAND")
    w.cache("sled", 4760, ry + 1000, "prop.sled", "wilderness_frozen", "PROMPT_SEARCH_SLED")
    w.put("env.buried_car", 2600, ry + 140, flip=True)
    sign(w, 400, ry - 140)
    sign(w, 7600, ry + 150, flip=True)
    return w.write({"ambience2": ""})


def corran_forest():
    w = Wild("wild.corran_forest", "REGION_WILD_CORRAN", "wild_corran", 1502, forest=0.36)
    ry = WL.ROAD_Y - w.offset[1]
    ctrl = [(0, ry), (1500, ry + 300), (3200, ry - 500), (4800, ry - 900), (6500, ry - 300), (8000, ry + 700), (9600, ry + 1100),
            (11200, ry + 400), (12600, ry - 200), (14000, ry)]
    line = w.road(ctrl)
    w.power_line(line, -1, every=560)
    w.lake(5400, ry + 1600, 1300, 600)
    w.lake(11000, 900, 700, 320)
    w.road([(8000, ry + 700), (8300, ry + 1700), (8700, ry + 2600)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("trapper", 8750, ry + 2650, "cabin_weathered", enter=cabin_interior("small", ["hunter_cabin", "wilderness_frozen"]),
            dressing=("woodpile", "stove", "crates"))
    w.cabin("logging_camp", 3000, ry - 1700, "cabin_workshop", enter=cabin_interior("workshop", ["workshop_tools", "industrial_materials"]),
            dressing=("woodpile", "barrels", "crates"), label="MAP_LOGGING_CAMP")
    w.road([(3200, ry - 500), (3100, ry - 1100), (3000, ry - 1600)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("hollow_house", 12000, ry + 1900, "cabin_large", enter=cabin_interior("large", ["home_kitchen", "home_closet", "home_bedroom"]),
            dressing=("woodpile", "bicycle", "fence_broken"), label="MAP_TIMBER_HOUSE")
    w.road([(11200, ry + 400), (11600, ry + 1200), (12000, ry + 1800)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("lean_to", 6400, 700, "lean_to", dressing=("belongings",), label="MAP_LEAN_TO")
    w.cabin("collapsed", 1200, ry + 2400, "cabin_ruin", dressing=("fence_broken",), label="MAP_RUIN")
    w.landmark("env.radio_mast", 9800, 600, "mast", "MAP_RADIO_MAST", clear=320)
    w.landmark("env.hunting_stand", 13000, ry + 2600, "tower", "MAP_HUNTING_STAND")
    w.put("prop.truck_wreck", 4400, ry - 760, flip=True)
    w.put("env.buried_car", 10500, ry + 900)
    w.cache("cache_truck", 4470, ry - 700, "env.crates", "vehicle_truck", "PROMPT_SEARCH_CRATE")
    sign(w, 500, ry - 150)
    sign(w, 13500, ry + 150, flip=True)
    w.spawns = [[6500, ry - 900], [9600, ry + 1800], [12000, 800]]
    return w.write()


def greyhollow_pass():
    w = Wild("wild.greyhollow_pass", "REGION_WILD_GREYHOLLOW_PASS", "wild_greyhollow_pass", 1503, forest=0.34)
    rx = 31400 - w.offset[0]          # the road leaves the junction at world x 31400 and arrives in Greyhollow at the same x
    H = w.h
    ctrl = [(rx, H), (rx - 600, H - 1800), (rx + 700, H - 3600), (rx + 900, H - 5200), (rx - 400, H - 7000),
            (rx - 1100, H - 8600), (rx + 200, H - 10400), (rx, 0)]
    line = w.road(ctrl, width=140)
    w.power_line(line, 1, every=600)
    w.lake(2900, H - 6200, 600, 900)
    w.cabin("pass_hut", 900, H - 4400, "cabin_small", enter=cabin_interior("small", ["mine_lamps", "hunter_cabin"]),
            dressing=("woodpile", "sign"), label="MAP_PASS_HUT")
    w.road([(rx + 700, H - 3600), (1600, H - 4000), (950, H - 4350)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("miners_rest", 3000, H - 9300, "cabin_weathered", enter=cabin_interior("small", ["miner_home_kitchen", "miner_home_closet"]),
            dressing=("barrels", "crates", "outhouse"))
    w.landmark("env.radio_mast", 600, H - 8000, "mast", "MAP_RADIO_MAST", clear=320)
    for k, (dx, dy) in enumerate(((-300, -2400), (500, -6000), (-600, -9900))):
        w.put("env.rock_c", rx + dx, H + dy, flip=k % 2 == 1)
    w.put("env.buried_car", rx + 420, H - 5600, flip=True)
    sign(w, rx + 160, H - 300)
    sign(w, rx - 160, 400, flip=True)
    w.spawns = [[1800, H - 5000], [2600, H - 8800]]
    return w.write({"climate": {"exposure": 1.4, "fog": 1.3}})


def stillwater_road():
    w = Wild("wild.stillwater_road", "REGION_WILD_STILLWATER_ROAD", "wild_stillwater_road", 1504, forest=0.40)
    ry = WL.ROAD_Y - w.offset[1]
    ctrl = [(0, ry), (1800, ry + 400), (3600, ry + 1300), (5400, ry + 1700), (7200, ry + 1200), (9000, ry + 500), (10600, ry + 200), (12000, ry)]
    line = w.road(ctrl)
    w.power_line(line, 1, every=520)
    w.lake(4200, 4600, 1400, 700)
    w.cabin("roadhouse", 6200, ry + 2600, "cabin_porch", enter=cabin_interior("porch", ["general_goods", "home_kitchen"]),
            dressing=("barrels", "bench", "sign"), label="MAP_ROADHOUSE")
    w.cabin("fisher", 4300, 3700, "cabin_small", enter=cabin_interior("small", ["harbor_home_kitchen", "marine"]),
            dressing=("woodpile", "belongings"))
    w.road([(5400, ry + 1700), (4900, 3200), (4400, 3650)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("abandoned_farm", 9600, 4600, "cabin_large", enter=cabin_interior("large", ["home_kitchen", "home_closet", "attic"]),
            dressing=("fence_broken", "barrels", "bicycle"), label="MAP_FARMHOUSE")
    w.road([(9000, ry + 500), (9300, 3200), (9600, 4500)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.landmark("env.hunting_stand", 2200, 600, "tower", "MAP_HUNTING_STAND")
    w.put("prop.car_sedan", 7600, ry + 1080, flip=True)
    w.put("env.buried_car", 1200, ry + 260)
    sign(w, 400, ry - 140)
    sign(w, 11600, ry + 150, flip=True)
    w.spawns = [[3000, 1000], [8000, 4200], [11000, 3000]]
    return w.write()


def halden_coast():
    w = Wild("wild.halden_coast", "REGION_WILD_HALDEN_COAST", "wild_halden_coast", 1505, forest=0.44, ambience="amb.harbor_ice")
    ry = WL.ROAD_Y - w.offset[1]
    ctrl = [(0, ry), (2000, ry - 200), (4000, ry + 500), (6000, ry + 300), (8000, ry - 400), (10000, ry + 200), (12000, ry)]
    line = w.road(ctrl)
    w.power_line(line, -1, every=620)
    # the frozen sea along the south: open-ice shore no tree grows on
    shore = [(0, 4300), (2000, 4100), (4000, 4500), (6000, 4200), (8000, 4400), (10000, 4000), (12000, 4300), (12000, 6000), (0, 6000)]
    w.patches.append(["set.sea_ice", [v for p in shore for v in p]])
    w.lakes.append(shore)
    w.map_areas.append({"kind": "ice", "polygon": [list(p) for p in shore]})
    w.cabin("boathouse", 5200, 4000, "cabin_weathered", enter=cabin_interior("workshop", ["marine", "marine_safety"]),
            dressing=("crates", "barrels"), label="MAP_BOATHOUSE")
    w.road([(4000, ry + 500), (4600, 3300), (5150, 3950)], width=80, kind="track", asset="env.ground_frozen_mud")
    w.cabin("watch_cabin", 9800, 900, "cabin_small", dressing=("woodpile",), label="MAP_CABIN")
    w.cabin("ruined_croft", 2400, 3500, "cabin_ruin", dressing=("fence_broken", "belongings"), label="MAP_RUIN")
    w.landmark("env.radio_mast", 11000, 700, "mast", "MAP_RADIO_MAST", clear=320)
    w.put("set.trawler", 7400, 4800) if False else None
    w.put("env.buried_car", 6800, ry + 380, flip=True)
    sign(w, 400, ry - 140)
    sign(w, 11600, ry + 150, flip=True)
    w.spawns = [[3000, 900], [7000, 3500]]
    return w.write({"climate": {"exposure": 1.35, "fog": 1.35}})


def build():
    WL.check()
    return [birchwater(), corran_forest(), greyhollow_pass(), stillwater_road(), halden_coast()]


if __name__ == "__main__":
    print("wilderness regions:", ", ".join(build()))
