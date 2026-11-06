class_name SideSection
extends RefCounted
## Cross-section reading of a bunker level (iteration 012, experimental side view).
##
## A bunker level's excavation grid is already a cross-section: columns run
## left-right, rows run up-down (the shaft cells above the room lead up to the
## hatch). The side view reads the very same data that way — nothing is
## converted or stored twice. Things rest on the floor beneath them (the lowest
## open cell of the open run they are in); lamps hang from the ceiling. Levels
## without a grid (concrete levels, the Ashgrove cellar) are one room
## (template "side_room", else the first build zone, else the bounds).
##
## Rules here are shared by the host (floor snapping, reach) and the side view
## (drawing, walking, climbing). The original top-down view keeps reading the
## grid as a floor plan, so both perspectives consume one authoritative state.
## ROW_SCALE is presentation only: a 64 px row is drawn 40 px tall so rooms get
## human proportions; plan coordinates never change.

const ROW_SCALE := 0.625
const FEET := 3.0              # stand this far above the floor edge (plan px)
const REACH_ROWS := 4          # side-view reach upward/downward, in rows


static func is_level(region_id: String) -> bool:
	return not BunkerState.parse_region_id(region_id).is_empty()


static func has_grid(region: RegionState) -> bool:
	return Terrain.has_terrain(region)


static func bounds(region: RegionState) -> Rect2:
	var b: Array = region.definition().get("bounds", [0, 0, 1000, 700])
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))


## The room of a level without an excavation grid (plan rect).
static func room_rect(region: RegionState) -> Rect2:
	var d := region.definition()
	var r: Array = d.get("side_room", [])
	if r.size() == 4:
		return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var z: Array = d.get("build_zones", [])
	if not z.is_empty():
		var a: Array = z[0]
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return bounds(region).grow(-40.0)


static func row_h(region: RegionState) -> float:
	return Terrain.cell_size(region) if has_grid(region) else 64.0


static func open_cell(region: RegionState, c: Vector2i) -> bool:
	return Terrain.is_open(region, c)


## Open space at a plan point (walkable air of the cross-section).
static func open_at(region: RegionState, pos: Vector2) -> bool:
	if has_grid(region):
		return Terrain.is_open(region, Terrain.cell_of(region, pos))
	return room_rect(region).has_point(pos)


## The open run (top row, bottom row) of a column that contains `row`, or the
## nearest one in that column (Vector2i(-1, -1) if the column is solid).
static func run_of(region: RegionState, col: int, row: int) -> Vector2i:
	var g := Terrain.grid_size(region)
	var r := clampi(row, 0, g.y - 1)
	if not open_cell(region, Vector2i(col, r)):
		var found := -1
		for d in range(1, g.y):
			if open_cell(region, Vector2i(col, r + d)):
				found = r + d
				break
			if open_cell(region, Vector2i(col, r - d)):
				found = r - d
				break
		if found < 0:
			return Vector2i(-1, -1)
		r = found
	var top := r
	while open_cell(region, Vector2i(col, top - 1)):
		top -= 1
	var bottom := r
	while open_cell(region, Vector2i(col, bottom + 1)):
		bottom += 1
	return Vector2i(top, bottom)


## Plan y of the floor under a point (where feet rest).
static func floor_y(region: RegionState, x: float, near_y: float) -> float:
	if not has_grid(region):
		return room_rect(region).end.y - FEET
	var c := Terrain.cell_of(region, Vector2(x, near_y))
	var run := run_of(region, c.x, c.y)
	if run.x < 0:
		return near_y
	return Terrain.cell_rect(region, Vector2i(c.x, run.y)).end.y - FEET


## Plan y of the ceiling over a point.
static func ceiling_y(region: RegionState, x: float, near_y: float) -> float:
	if not has_grid(region):
		return room_rect(region).position.y
	var c := Terrain.cell_of(region, Vector2(x, near_y))
	var run := run_of(region, c.x, c.y)
	if run.x < 0:
		return near_y
	return Terrain.cell_rect(region, Vector2i(c.x, run.x)).position.y


## Where something at `pos` rests in the cross-section (on the floor beneath it).
static func rest(region: RegionState, pos: Vector2) -> Vector2:
	if region == null:
		return pos
	return Vector2(pos.x, floor_y(region, pos.x, pos.y))


## Where something hangs from the ceiling above `pos` (lamps).
static func hang(region: RegionState, pos: Vector2) -> Vector2:
	return Vector2(pos.x, ceiling_y(region, pos.x, pos.y))


## Host reach for bunker levels: either plan distance (the top-down reading) or
## a side-view reach — horizontally within `reach` and a few rows up or down.
static func in_reach(region: RegionState, from: Vector2, to: Vector2, reach: float) -> bool:
	if from.distance_to(to) <= reach:
		return true
	if region == null or not is_level(region.region_id):
		return false
	if absf(from.x - to.x) > reach:
		return false
	# anything in the same open space, from floor to ceiling (plus a little), is in reach
	var top := ceiling_y(region, from.x, from.y - 4.0) - reach * 0.5
	var bottom := floor_y(region, from.x, from.y - 4.0) + reach * 0.5
	if to.y >= top and to.y <= bottom:
		return true
	return absf(from.y - to.y) <= row_h(region) * float(REACH_ROWS) * 0.5


## Presentation projection (plan -> side-view screen) and back.
static func top_y(region: RegionState) -> float:
	return bounds(region).position.y


static func to_screen(region: RegionState, plan: Vector2) -> Vector2:
	var oy := top_y(region)
	return Vector2(plan.x, oy + (plan.y - oy) * ROW_SCALE)


static func to_plan(region: RegionState, screen: Vector2) -> Vector2:
	var oy := top_y(region)
	return Vector2(screen.x, oy + (screen.y - oy) / ROW_SCALE)


static func screen_rect(region: RegionState, plan: Rect2) -> Rect2:
	var a := to_screen(region, plan.position)
	var b := to_screen(region, plan.end)
	return Rect2(a, b - a)


## Is the column under `pos` climbable (a ladder or a reinforced timber support)?
static func climbable(world: WorldState, region: RegionState, pos: Vector2) -> bool:
	if region == null:
		return false
	var half := row_h(region) * 0.45
	for eid in Content.entity_ids(region.def_id):
		var d := region.entity_def(eid)
		var t := str(d.get("type", ""))
		var p := Content.entity_position(d)
		if absf(p.x - pos.x) > half:
			continue
		if t == "portal" and (eid.ends_with("ladder_up") or eid.ends_with("ladder_down")):
			return true
		if t == "support_site" and str(region.entity_state(eid).get("stage", "")) == "reinforced":
			return true
	if has_grid(region):
		var c := Terrain.cell_of(region, pos)
		var sup: Dictionary = region.terrain.get("supports", {})
		for k in sup:
			var sc := Terrain.parse_key(k)
			if sc.x == c.x and str(sup[k].get("stage", "")) == "reinforced":
				var run := run_of(region, c.x, c.y)
				if sc.y >= run.x and sc.y <= run.y:
					return true
	return false


## Plan cells blocked for walking by a built object (closed doors, barricades).
static func blocked_cell(world: WorldState, region: RegionState, c: Vector2i) -> bool:
	if not has_grid(region):
		return false
	for oid in region.objects:
		var o: Dictionary = region.objects[oid]
		if Build.blocks(o) and Terrain.cell_of(region, Build.pos_of(o)) == c:
			return true
	return false


## Side-view walking: from feet position `from` step horizontally by dx.
## Returns the new feet position (floor-following, one-row steps up or down,
## blocked by solid earth and blocking structures). No jumping.
static func walk(world: WorldState, region: RegionState, from: Vector2, dx: float) -> Vector2:
	if dx == 0.0:
		return from
	var to_x := from.x + dx
	if not has_grid(region):
		var rr := room_rect(region)
		return Vector2(clampf(to_x, rr.position.x + 18.0, rr.end.x - 18.0), from.y)
	var s := Terrain.cell_size(region)
	var here := Terrain.cell_of(region, from + Vector2(0, -2))
	var probe_x := to_x + signf(dx) * 14.0
	var col := Terrain.cell_of(region, Vector2(probe_x, from.y)).x
	if col == here.x:
		return Vector2(to_x, from.y)
	for dr in [0, -1, 1]:
		var row: int = here.y + dr
		var c := Vector2i(col, row)
		if open_cell(region, c) and not blocked_cell(world, region, c):
			var run := run_of(region, col, row)
			# land on that run's floor only if it is a single step away
			if absi(run.y - here.y) <= 1:
				return Vector2(to_x, Terrain.cell_rect(region, Vector2i(col, run.y)).end.y - FEET)
	return from
