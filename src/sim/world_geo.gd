class_name WorldGeo
extends RefCounted
## World geography (iteration 015). Every outdoor region (one with a "map"
## block and no side view) sits at its "map.offset" in one world coordinate
## system, so the world map and the playable world are the same geography.
##
## Edge travel: where two outdoor regions touch, walking or driving off one
## region's edge carries you into the other at the matching world point — on or
## off the road. Edges with no neighbour are the edge of the world (dense forest,
## the frozen sea). There are no road-only exits between outdoor regions.
##   * crossing(): the host checks a position past the edge (by MARGIN) and maps
##     it into the neighbour, a little inside its edge (INSET) and onto a free
##     navigation cell, keeping the direction of travel.
##   * walls(): RegionView rebuilds its boundary walls from this: a wall right at
##     the edge where nothing lies beyond, and one well past it where a neighbour
##     does (so you can step over the edge and be carried across).
## Exploration (the map's fog of war) is recorded here too, in world cells.

const MARGIN := 12.0       # past the edge before a crossing happens
const INSET := 64.0        # arrival distance inside the neighbour's edge
const VEHICLE_INSET := 150.0
const OPEN_WALL := 260.0   # where the wall stands beyond a traversable edge
const EXPLORE_CELL := 600.0
const EXPLORE_RADIUS := 1  # cells around the player marked explored

static var _rects := {}    # def_id -> Rect2 in world coordinates (cache)


static func clear_cache() -> void:
	_rects.clear()


static func is_outdoor(def: Dictionary) -> bool:
	return def.has("map") and str(def.get("view", "")) != "side" and not def.has("surface")


static func outdoor_ids() -> Array:
	var out := []
	for rid in Content.region_ids():
		if is_outdoor(Content.region_def(rid)):
			out.append(rid)
	return out


static func offset(region_id: String) -> Vector2:
	var o: Array = Content.region_def(region_id).get("map", {}).get("offset", [0, 0])
	return Vector2(float(o[0]), float(o[1]))


static func local_bounds(region_id: String) -> Rect2:
	var b: Array = Content.region_def(region_id).get("bounds", [0, 0, 1600, 1100])
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))


## The region's rectangle in world coordinates (empty for interiors).
static func world_rect(region_id: String) -> Rect2:
	if not _rects.has(region_id):
		var def := Content.region_def(region_id)
		_rects[region_id] = Rect2(local_bounds(region_id).position + offset(region_id), local_bounds(region_id).size) if is_outdoor(def) else Rect2()
	return _rects[region_id]


static func to_world(region_id: String, pos: Vector2) -> Vector2:
	return pos + offset(region_id)


## The outdoor region (other than `exclude`) containing a world point, or "".
static func region_at(world_pos: Vector2, exclude: String = "") -> String:
	for rid in outdoor_ids():
		if rid != exclude and world_rect(rid).grow(MARGIN * 2.0).has_point(world_pos):
			return rid
	return ""


## Where crossing out of `region_id` at local `pos` leads: {} (still inside, or
## nothing beyond), else {"region": id, "position": Vector2, "normal": Vector2}.
## `inset` keeps the arrival clear of the edge (more for a car). Host and tests.
static func crossing(region_id: String, pos: Vector2, inset: float = INSET) -> Dictionary:
	if not is_outdoor(Content.region_def(region_id)):
		return {}
	var b := local_bounds(region_id)
	var normal := Vector2.ZERO
	if pos.x < b.position.x - MARGIN:
		normal = Vector2.LEFT
	elif pos.x > b.end.x + MARGIN:
		normal = Vector2.RIGHT
	elif pos.y < b.position.y - MARGIN:
		normal = Vector2.UP
	elif pos.y > b.end.y + MARGIN:
		normal = Vector2.DOWN
	if normal == Vector2.ZERO:
		return {}
	var wp := to_world(region_id, pos)
	var to := region_at(wp, region_id)
	if to == "":
		return {}
	var tb := local_bounds(to)
	var lp := wp - offset(to)
	# Keep the arrival inside the neighbour, `inset` past its edge in the direction of travel.
	lp.x = clampf(lp.x, tb.position.x + inset, tb.end.x - inset)
	lp.y = clampf(lp.y, tb.position.y + inset, tb.end.y - inset)
	return {"region": to, "position": free_spot(to, lp), "normal": normal}


## Nearest unblocked navigation cell to `pos` in a region (never inside an obstacle).
static func free_spot(region_id: String, pos: Vector2) -> Vector2:
	var grid := NavGrid.for_def(region_id)
	var c := grid.to_cell(pos)
	if not grid.is_blocked(c, {}):
		return pos
	for r in range(1, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cc := c + Vector2i(dx, dy)
				if cc.x >= 0 and cc.y >= 0 and cc.x < grid.w and cc.y < grid.h and not grid.is_blocked(cc, {}):
					return grid.origin + (Vector2(cc) + Vector2(0.5, 0.5)) * NavGrid.CELL
	return pos


## Local intervals along each side ("west"/"east"/"north"/"south") where a
## neighbour lies beyond: {side: [[from, to], ...]} (y for west/east, x for north/south).
static func open_edges(region_id: String) -> Dictionary:
	var out := {"west": [], "east": [], "north": [], "south": []}
	if not is_outdoor(Content.region_def(region_id)):
		return out
	var me := world_rect(region_id)
	var off := offset(region_id)
	for rid in outdoor_ids():
		if rid == region_id:
			continue
		var o := world_rect(rid)
		var y0 := maxf(me.position.y, o.position.y) - off.y
		var y1 := minf(me.end.y, o.end.y) - off.y
		var x0 := maxf(me.position.x, o.position.x) - off.x
		var x1 := minf(me.end.x, o.end.x) - off.x
		if absf(o.end.x - me.position.x) < 2.0 and y1 > y0:
			out["west"].append([y0, y1])
		if absf(o.position.x - me.end.x) < 2.0 and y1 > y0:
			out["east"].append([y0, y1])
		if absf(o.end.y - me.position.y) < 2.0 and x1 > x0:
			out["north"].append([x0, x1])
		if absf(o.position.y - me.end.y) < 2.0 and x1 > x0:
			out["south"].append([x0, x1])
	return out


## Boundary walls as local rectangles: closed edges at the bound, open ones OPEN_WALL beyond.
static func walls(region_id: String, thickness: float = 40.0) -> Array:
	var b := local_bounds(region_id)
	var open := open_edges(region_id)
	var out := []
	for side in ["west", "east", "north", "south"]:
		var vertical: bool = side in ["west", "east"]
		var lo := b.position.y if vertical else b.position.x
		var hi := b.end.y if vertical else b.end.x
		var spans: Array = (open[side] as Array).duplicate()
		spans.sort_custom(func(a, c): return a[0] < c[0])
		var closed := []
		var cur := lo - OPEN_WALL
		for s in spans:
			if float(s[0]) > cur:
				closed.append([cur, float(s[0])])
			cur = maxf(cur, float(s[1]))
		if cur < hi + OPEN_WALL:
			closed.append([cur, hi + OPEN_WALL])
		var edge := 0.0
		match side:
			"west": edge = b.position.x - thickness
			"east": edge = b.end.x
			"north": edge = b.position.y - thickness
			"south": edge = b.end.y
		for c in closed:
			out.append(_wall(vertical, edge, float(c[0]), float(c[1]), thickness))
		for s2 in spans:
			var far := edge + (-OPEN_WALL if side in ["west", "north"] else OPEN_WALL)
			out.append(_wall(vertical, far, float(s2[0]) - OPEN_WALL, float(s2[1]) + OPEN_WALL, thickness))
			# caps across the ends of the span, so an open edge is a short channel, not a gap into nowhere
			var lo2 := minf(edge, far)
			var hi2 := maxf(edge, far) + thickness
			for at in [float(s2[0]) - thickness, float(s2[1])]:
				var inside_other := false
				for s3 in spans:
					if at + thickness * 0.5 > float(s3[0]) and at + thickness * 0.5 < float(s3[1]):
						inside_other = true
				if not inside_other:
					out.append(Rect2(lo2, at, hi2 - lo2, thickness) if vertical else Rect2(at, lo2, thickness, hi2 - lo2))
	return out


static func _wall(vertical: bool, edge: float, a: float, b2: float, t: float) -> Rect2:
	return Rect2(edge, a, t, b2 - a) if vertical else Rect2(a, edge, b2 - a, t)


# ---------------------------------------------------------------- exploration

static func cell_key(world_pos: Vector2) -> String:
	return "%d:%d" % [floori(world_pos.x / EXPLORE_CELL), floori(world_pos.y / EXPLORE_CELL)]


static func explored(world: WorldState) -> Dictionary:
	if not (world.meta.get("explored") is Dictionary):
		world.meta["explored"] = {}
	return world.meta["explored"]


## Marks the cells around a world point explored. Returns how many were new.
static func explore(world: WorldState, world_pos: Vector2) -> int:
	var ex := explored(world)
	var cx := floori(world_pos.x / EXPLORE_CELL)
	var cy := floori(world_pos.y / EXPLORE_CELL)
	var n := 0
	for dy in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
		for dx in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
			var k := "%d:%d" % [cx + dx, cy + dy]
			if not ex.has(k):
				ex[k] = 1
				n += 1
	return n


## Host, every tick: once a second each player's surroundings become explored
## (indoors: the building's spot on the surface). New cells are published with
## the world meta at most every few seconds. Saves from before iteration 015 get
## the settlements they had already discovered marked explored (migration).
static func step(world: WorldState, ticks: int) -> Array:
	var every := Simulation.TICK_RATE
	if (world.tick / every) == ((world.tick - ticks) / every):
		return []
	if not world.meta.has("explored"):
		seed_from_discoveries(world)
	var fresh := 0
	for p in world.online_players():
		var sp := surface_world(world, p.region_id, p.position)
		if sp != Vector2.INF:
			fresh += explore(world, sp)
	if fresh > 0:
		world.meta["explored_dirty"] = true
	if bool(world.meta.get("explored_dirty", false)) and world.tick - int(world.meta.get("explored_sent", -1000)) >= 3 * Simulation.TICK_RATE:
		world.meta.erase("explored_dirty")
		world.meta["explored_sent"] = world.tick
		return [{"ok": true, "reason": "", "reason_args": [], "changes": [], "meta": true}]
	return []


## A region position on the world map (interiors: their surface door). INF when unknown (bunkers).
static func surface_world(world: WorldState, region_id: String, pos: Vector2, guard: int = 0) -> Vector2:
	var def := world.region_def(region_id)
	if is_outdoor(def):
		return to_world(region_id, pos)
	if def.has("surface") and guard < 6:
		var sp: Dictionary = def["surface"]
		var at: Array = sp.get("position", [0, 0])
		return surface_world(world, str(sp.get("region", "")), Vector2(float(at[0]), float(at[1])), guard + 1)
	return Vector2.INF


static func seed_from_discoveries(world: WorldState) -> void:
	var ex := explored(world)
	var found: Dictionary = world.meta.get("discoveries", {})
	for rid in outdoor_ids():
		var key := str(Content.region_def(rid).get("discovery", ""))
		if key == "" or not found.has(key) or bool(Content.region_def(rid).get("wilderness", false)):
			continue
		var r := world_rect(rid)
		var x := r.position.x
		while x < r.end.x:
			var y := r.position.y
			while y < r.end.y:
				ex[cell_key(Vector2(x, y))] = 1
				y += EXPLORE_CELL
			x += EXPLORE_CELL


static func is_explored(world: WorldState, world_pos: Vector2) -> bool:
	return explored(world).has(cell_key(world_pos))
