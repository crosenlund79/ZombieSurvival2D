class_name NavGrid
extends RefCounted
## Host-side walkability grid for one region definition, used by zombie
## navigation and line of sight. Built from *authored collision data* in the
## region scene (Prop footprints, FenceLine strips, static rectangle shapes,
## the region bounds) — read without adding the scene to the tree, so it does
## not depend on what anyone is viewing. Dynamic blockers (standing trees,
## closed doors/gates) come from world state at query time.

const CELL := 24.0
const AGENT_RADIUS := 10.0

static var _cache := {}  # def_id -> NavGrid

var def_id := ""
var origin := Vector2.ZERO
var w := 0
var h := 0
var blocked := PackedByteArray()   # static obstacles


static func for_def(def_id: String) -> NavGrid:
	if not _cache.has(def_id):
		_cache[def_id] = NavGrid.build(def_id)
	return _cache[def_id]


static func clear_cache() -> void:
	_cache.clear()


static func build(def_id: String) -> NavGrid:
	var g := NavGrid.new()
	g.def_id = def_id
	var def := Content.region_def(def_id)
	var b: Array = def.get("bounds", [0, 0, 1600, 1100])
	g.origin = Vector2(float(b[0]), float(b[1]))
	g.w = int(ceil(float(b[2]) / CELL))
	g.h = int(ceil(float(b[3]) / CELL))
	g.blocked.resize(g.w * g.h)
	# Iteration 015: generated wilderness regions list their obstacles as data.
	for o in def.get("obstacles", []):
		g.block_rect(Rect2(float(o[0]), float(o[1]), float(o[2]), float(o[3])))
	var scene_path := str(def.get("scene", ""))
	if ResourceLoader.exists(scene_path):
		var root := (load(scene_path) as PackedScene).instantiate()
		g._collect(root, Vector2.ZERO)
		root.free()
	return g


func _collect(node: Node, offset: Vector2) -> void:
	var pos := offset
	if node is Node2D:
		pos = offset + (node as Node2D).position
	if node is Prop:
		var p := node as Prop
		if p.footprint.x > 0 and p.footprint.y > 0 and p.nav_block:
			block_rect(Rect2(pos + p.footprint_offset + Vector2(-p.footprint.x * 0.5, -p.footprint.y), p.footprint))
	elif node is FenceLine:
		var f := node as FenceLine
		if f.vertical:
			block_rect(Rect2(pos + Vector2(-f.thickness * 0.5, minf(0, f.end_point.y)), Vector2(f.thickness, absf(f.end_point.y))))
		else:
			block_rect(Rect2(pos + Vector2(minf(0, f.end_point.x), -f.thickness), Vector2(absf(f.end_point.x), f.thickness)))
	elif node is CollisionShape2D and (node as CollisionShape2D).shape is RectangleShape2D:
		var size := ((node as CollisionShape2D).shape as RectangleShape2D).size
		block_rect(Rect2(pos - size * 0.5, size))
	for c in node.get_children():
		_collect(c, pos)


func block_rect(r: Rect2) -> void:
	var rr := r.grow(AGENT_RADIUS)
	var c0 := to_cell(rr.position)
	var c1 := to_cell(rr.end)
	for y in range(maxi(0, c0.y), mini(h - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(w - 1, c1.x) + 1):
			blocked[y * w + x] = 1


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


## Dynamic blockers for a region: standing trees, closed doors and solid
## player-built structures (cell indices).
static func dynamic_blocked(world: WorldState, region_id: String, grid: NavGrid) -> Dictionary:
	var out := {}
	var r := world.region(region_id)
	if r == null:
		return out
	var rects: Array = Build.blocking_rects(world, region_id)
	for eid in Content.entity_ids(r.def_id):
		var d := r.entity_def(eid)
		var t := str(d.get("type", ""))
		var rect := Rect2()
		if t == "tree" and not bool(r.entity_state(eid).get("felled", false)):
			rect = Rect2(Content.entity_position(d) + Vector2(-16, -14), Vector2(32, 14))
		elif t == "door" and not bool(r.entity_state(eid).get("open", false)) and d.has("blocker"):
			var bs: Array = d["blocker"]
			rect = Rect2(Content.entity_position(d) + Vector2(-float(bs[0]) * 0.5, -float(bs[1])), Vector2(float(bs[0]), float(bs[1])))
		if rect.has_area():
			rects.append(rect)
	for rect2 in rects:
		if true:
			var rr := (rect2 as Rect2).grow(AGENT_RADIUS)
			var c0 := grid.to_cell(rr.position)
			var c1 := grid.to_cell(rr.end)
			for y in range(c0.y, c1.y + 1):
				for x in range(c0.x, c1.x + 1):
					out[y * grid.w + x] = true
	return out


func is_blocked(c: Vector2i, dyn: Dictionary) -> bool:
	if not in_grid(c):
		return true
	var i := c.y * w + c.x
	return blocked[i] == 1 or dyn.has(i)


## Line of sight / straight walkability between two points (grid ray march).
func clear_line(a: Vector2, b: Vector2, dyn: Dictionary) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / (CELL * 0.5)) + 1
	for i in range(1, steps):
		if is_blocked(to_cell(a.lerp(b, float(i) / steps)), dyn):
			return false
	return true


## A* over 8-connected cells (binary heap). Returns waypoints or [] if unreachable.
func find_path(from: Vector2, to: Vector2, dyn: Dictionary, max_nodes: int = 2500) -> Array:
	var start := to_cell(from)
	var goal := to_cell(to)
	if not in_grid(start):
		return []
	if is_blocked(goal, dyn):
		goal = _nearest_open(goal, dyn)
		if goal.x < 0:
			return []
	var si := start.y * w + start.x
	var gi := goal.y * w + goal.x
	var g := {si: 0.0}
	var came := {}
	var closed := {}
	var heap_f: Array[float] = [0.0]
	var heap_i: Array[int] = [si]
	var visited := 0
	while not heap_i.is_empty() and visited < max_nodes:
		var cur := _heap_pop(heap_f, heap_i)
		if closed.has(cur):
			continue
		if cur == gi:
			return _rebuild(came, cur, from, to, dyn)
		closed[cur] = true
		visited += 1
		var cx := cur % w
		var cy := cur / w
		for dir in DIRS:
			var nx: int = cx + dir.x
			var ny: int = cy + dir.y
			var nc := Vector2i(nx, ny)
			if is_blocked(nc, dyn):
				continue
			if dir.x != 0 and dir.y != 0 and (is_blocked(Vector2i(cx + dir.x, cy), dyn) or is_blocked(Vector2i(cx, cy + dir.y), dyn)):
				continue
			var ni := ny * w + nx
			var ng: float = g[cur] + (1.4142 if dir.x != 0 and dir.y != 0 else 1.0)
			if not g.has(ni) or ng < g[ni]:
				g[ni] = ng
				came[ni] = cur
				_heap_push(heap_f, heap_i, ng + Vector2(nx, ny).distance_to(Vector2(goal)), ni)
	return []


const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func _heap_push(f: Array[float], idx: Array[int], key: float, val: int) -> void:
	f.append(key)
	idx.append(val)
	var i := f.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if f[p] <= f[i]:
			break
		var tf := f[p]; f[p] = f[i]; f[i] = tf
		var ti := idx[p]; idx[p] = idx[i]; idx[i] = ti
		i = p


static func _heap_pop(f: Array[float], idx: Array[int]) -> int:
	var top := idx[0]
	var last_f: float = f.pop_back()
	var last_i: int = idx.pop_back()
	if not f.is_empty():
		f[0] = last_f
		idx[0] = last_i
		var i := 0
		var n := f.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and f[l] < f[m]:
				m = l
			if r < n and f[r] < f[m]:
				m = r
			if m == i:
				break
			var tf := f[m]; f[m] = f[i]; f[i] = tf
			var ti := idx[m]; idx[m] = idx[i]; idx[i] = ti
			i = m
	return top


func _nearest_open(c: Vector2i, dyn: Dictionary) -> Vector2i:
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if not is_blocked(n, dyn):
					return n
	return Vector2i(-1, -1)


func _rebuild(came: Dictionary, cur: int, from: Vector2, to: Vector2, dyn: Dictionary) -> Array:
	var cells := [cur]
	while came.has(cur):
		cur = came[cur]
		cells.push_front(cur)
	var pts := []
	for c in cells:
		pts.append(cell_center(Vector2i(c % w, c / w)))
	if not pts.is_empty():
		pts[pts.size() - 1] = to if not is_blocked(to_cell(to), dyn) else pts[pts.size() - 1]
	# String-pull: drop waypoints that can be skipped in a straight line.
	var out := []
	var anchor := from
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not clear_line(anchor, pts[j], dyn):
			j -= 1
		out.append(pts[j])
		anchor = pts[j]
		i = j + 1
	return out
