"""Iteration 015 B: dressing for side-view interiors (shared by every interior generator).

dress(section, theme, seed) fills the gaps a room layout leaves with the things
that make it read as a place people lived in and left: pictures, a stopped
clock, coats on hooks, a calendar, curtains at the windows, a hanging lamp
(which still gives light), rugs, chairs (one knocked over), boots by the door,
bottles, books, debris, cracks, water stains and cobwebs. Themes pick from
different sets (home, cabin, shop, outfitters, office, workshop, store).
Never covers a container, a door, stairs or another prop; deterministic per seed.
"""
import random

from build_side_interiors import CELL

WALL = {
    "home": ["side.frame", "side.frame_tilt", "side.clock", "side.calendar", "side.coat_hooks", "side.stain", "side.crack"],
    "cabin": ["side.frame", "side.clock", "side.coat_hooks", "side.calendar", "side.stain", "side.jar_shelf"],
    "shop": ["side.poster", "side.calendar", "side.clock", "side.stain", "side.crack"],
    "outfitters": ["side.poster", "side.clock", "side.calendar", "side.coat_hooks"],
    "office": ["side.calendar", "side.clock", "side.frame", "side.poster", "side.crack", "side.stain"],
    "workshop": ["side.pegboard", "side.calendar", "side.poster", "side.stain", "side.jar_shelf"],
    "store": ["side.poster", "side.stain", "side.crack", "side.calendar"],
}
FLOOR = {
    "home": ["side.chair", "side.chair_fallen", "side.side_table_lamp", "side.boots", "side.bottles", "side.books", "side.plant_dead", "side.radiator", "side.rug"],
    "cabin": ["side.chair", "side.boots", "side.bottles", "side.books", "side.rug", "side.debris"],
    "shop": ["side.debris", "side.bottles", "side.stock_crates", "side.chair_fallen", "side.plant_dead"],
    "outfitters": ["side.mannequin", "side.boot_rack", "side.coat_rail", "side.coat_rail_empty", "side.debris", "side.stock_crates"],
    "office": ["side.chair", "side.chair_fallen", "side.books", "side.plant_dead", "side.radiator", "side.debris"],
    "workshop": ["side.stock_crates", "side.debris", "side.bottles", "side.chair"],
    "store": ["side.stock_crates", "side.debris", "side.bottles"],
}
WIDTH = {"side.chair": 1.0, "side.chair_fallen": 1.4, "side.side_table_lamp": 1.2, "side.boots": 1.0, "side.bottles": 1.1, "side.books": 1.3,
         "side.plant_dead": 1.1, "side.radiator": 1.6, "side.rug": 2.6, "side.debris": 2.2, "side.stock_crates": 1.9, "side.mannequin": 1.2,
         "side.boot_rack": 1.8, "side.coat_rail": 2.2, "side.coat_rail_empty": 2.2}
LIGHTS = {"side.side_table_lamp"}


def _occupied(s, storey):
    """Cells (from the left inner wall) already used on a storey: containers, doors, stairs, props."""
    y = s.y(storey)
    used = []
    for e in s.entities:
        pos = e.get("position", [0, 0])
        if abs(pos[1] - y) < CELL * 2:
            used.append((pos[0] / CELL - s.c0(), 1.6))
    for p in s.props:
        if abs(p["y"] - y) < CELL * 2 and not p.get("hang"):
            used.append((p["x"] / CELL - s.c0(), 1.8))
    for col in getattr(s, "stairs_cols", []):
        used.append((col - s.c0(), 2.4))
    return used


def _free(used, cell, w):
    return all(abs(cell - c) > (w + cw) * 0.5 + 0.15 for c, cw in used)


def dress(s, theme="home", seed=1, density=1.0, lamp=True):
    R = random.Random(seed)
    wall, floor = WALL.get(theme, WALL["home"]), FLOOR.get(theme, FLOOR["home"])
    for storey in [st for st in s.storeys if st >= 0]:
        used = _occupied(s, storey)
        # floor dressing in the gaps
        cell = 1.2
        while cell < s.width - 1.0:
            if R.random() < 0.55 * density:
                a = R.choice(floor)
                w = WIDTH.get(a, 1.2)
                if _free(used, cell + w / 2, w):
                    s.prop(a, cell + w / 2, storey, flip=R.random() < 0.5)
                    if a in LIGHTS and R.random() < 0.5:
                        s.props[-1]["light"] = True
                    used.append((cell + w / 2, w))
                    cell += w
            cell += R.uniform(0.6, 1.6)
        # wall dressing on the back wall (above furniture height)
        cell = R.uniform(1.0, 2.5)
        while cell < s.width - 1.0:
            if R.random() < 0.6 * density:
                # "wall": placed where authored (not settled onto the floor), on the back wall
                s.props.append({"asset": R.choice(wall), "x": s.x(cell), "y": s.y(storey) - int(CELL * R.uniform(1.3, 1.75)),
                                "wall": True, "back": True})
            cell += R.uniform(2.2, 4.0)
        # a hanging lamp (still lit) and cobwebs in a top corner
        if lamp:
            s.prop("side.lamp_hanging", R.uniform(s.width * 0.3, s.width * 0.7), storey, hang=True)
            if R.random() < 0.6:
                s.props[-1]["light"] = True
        if R.random() < 0.7:
            s.prop("side.cobweb", 0.6 if R.random() < 0.5 else s.width - 0.6, storey, hang=True, flip=R.random() < 0.5)
    for w in s.windows:  # curtains at some windows
        if len(w) < 3 and R.random() < (0.6 if theme in ("home", "cabin") else 0.2):
            s.props.append({"asset": "side.curtains", "x": w[0], "y": w[1] + 60, "back": True, "wall": True})
    return s
