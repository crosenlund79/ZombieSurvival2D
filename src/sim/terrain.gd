class_name Terrain
extends RefCounted
## Excavation rules for a region whose definition has an "excavation" block
## (a logical grid of earth cells; prototype choice, not a final perspective
## decision). State lives in RegionState.terrain:
##   dug:      {"c,r": true}                       cells opened by players
##   digging:  {"c,r": {started, ticks}}           timed dig in progress
##   supports: {"c,r": {stage, started, ticks}}    timber supports (building/reinforced)
## A cell can be dug when it is solid, next to open space, not permanent, and
## *supported*: inside the original chamber's safe margin or within range of a
## reinforced support. Supports are placed on open cells and cost stockpile wood.

static func cfg(region: RegionState) -> Dictionary:
	return region.definition().get("excavation", {})


static func has_terrain(region: RegionState) -> bool:
	return region != null and not cfg(region).is_empty()


static func key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func parse_key(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func cell_size(region: RegionState) -> float:
	return float(cfg(region).get("cell", 64))


static func origin(region: RegionState) -> Vector2:
	var o: Array = cfg(region).get("origin", [0, 0])
	return Vector2(float(o[0]), float(o[1]))


static func grid_size(region: RegionState) -> Vector2i:
	return Vector2i(int(cfg(region).get("cols", 1)), int(cfg(region).get("rows", 1)))


static func cell_of(region: RegionState, pos: Vector2) -> Vector2i:
	var s := cell_size(region)
	var o := origin(region)
	return Vector2i(floori((pos.x - o.x) / s), floori((pos.y - o.y) / s))


static func cell_center(region: RegionState, c: Vector2i) -> Vector2:
	var s := cell_size(region)
	return origin(region) + (Vector2(c) + Vector2(0.5, 0.5)) * s


static func cell_rect(region: RegionState, c: Vector2i) -> Rect2:
	var s := cell_size(region)
	return Rect2(origin(region) + Vector2(c) * s, Vector2(s, s))


static func in_grid(region: RegionState, c: Vector2i) -> bool:
	var g := grid_size(region)
	return c.x >= 0 and c.y >= 0 and c.x < g.x and c.y < g.y


static func _in_rects(rects: Array, c: Vector2i, grow: int = 0) -> bool:
	for r in rects:
		if c.x >= int(r[0]) - grow and c.y >= int(r[1]) - grow and c.x < int(r[0]) + int(r[2]) + grow and c.y < int(r[1]) + int(r[3]) + grow:
			return true
	return false


static func is_initial_open(region: RegionState, c: Vector2i) -> bool:
	return _in_rects(cfg(region).get("initial_open", []), c)


static func is_open(region: RegionState, c: Vector2i) -> bool:
	if not in_grid(region, c):
		return false
	return is_initial_open(region, c) or region.terrain.get("dug", {}).has(key(c))


static func is_permanent(region: RegionState, c: Vector2i) -> bool:
	if bool(cfg(region).get("fixed", false)):
		return true  # iteration 014: building interiors and the mine are authored, not dug
	var g := grid_size(region)
	if c.x <= 0 or c.y <= 0 or c.x >= g.x - 1 or c.y >= g.y - 1:
		return true  # region boundary
	return _in_rects(cfg(region).get("permanent", []), c)


## Reinforced support positions (world) — dynamic supports and support_site entities.
static func anchors(region: RegionState) -> Array:
	var out := []
	var sup: Dictionary = region.terrain.get("supports", {})
	for k in sup:
		if str(sup[k].get("stage", "")) == "reinforced":
			out.append(cell_center(region, parse_key(k)))
	for eid in Content.entity_ids(region.def_id):
		var d := region.entity_def(eid)
		if str(d.get("type", "")) == "support_site" and str(region.entity_state(eid).get("stage", "")) == "reinforced":
			out.append(Content.entity_position(d))
	return out


static func is_supported(region: RegionState, c: Vector2i) -> bool:
	var margin := int(cfg(region).get("safe_margin", 1))
	if _in_rects(cfg(region).get("initial_open", []), c, margin):
		return true
	var reach := float(cfg(region).get("support_radius_cells", 3.2)) * cell_size(region)
	var center := cell_center(region, c)
	for a in anchors(region):
		if (a as Vector2).distance_to(center) <= reach:
			return true
	return false


static func touches_open(region: RegionState, c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_open(region, c + d):
			return true
	return false


## Why a cell cannot be dug ("" = it can).
static func dig_problem(region: RegionState, c: Vector2i) -> String:
	if not in_grid(region, c) or is_permanent(region, c):
		return "ACTION_DIG_PERMANENT"
	if is_open(region, c):
		return "ACTION_DIG_OPEN"
	if region.terrain.get("digging", {}).has(key(c)):
		return "ACTION_BUSY"
	if not touches_open(region, c):
		return "ACTION_DIG_NOT_REACHABLE"
	if not is_supported(region, c):
		return "ACTION_DIG_UNSUPPORTED"
	return ""


## Why a support cannot go on this (open) cell ("" = it can, wood permitting).
static func support_problem(region: RegionState, c: Vector2i) -> String:
	if bool(cfg(region).get("fixed", false)) or not is_open(region, c):
		return "ACTION_SUPPORT_NOT_HERE"
	var sup: Dictionary = region.terrain.get("supports", {})
	var min_gap := int(cfg(region).get("support_min_gap_cells", 2))
	for k in sup:
		var o := parse_key(k)
		if maxi(absi(o.x - c.x), absi(o.y - c.y)) < min_gap:
			return "ACTION_SUPPORT_TOO_CLOSE"
	return ""


## Iteration 014: a stair landing — open (you can climb through it), but it carries
## a floor at its bottom edge for anyone walking.
static func is_platform(region: RegionState, c: Vector2i) -> bool:
	return _in_rects(cfg(region).get("platforms", []), c)


static func open_cells(region: RegionState) -> Array:
	var out := []
	var g := grid_size(region)
	for r in cfg(region).get("initial_open", []):
		for y in range(int(r[1]), int(r[1]) + int(r[3])):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				out.append(Vector2i(x, y))
	for k in region.terrain.get("dug", {}):
		out.append(parse_key(k))
	return out
