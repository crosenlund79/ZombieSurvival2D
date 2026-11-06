class_name Build
extends RefCounted
## Construction rules (host-side; clients use the read-only checks for the
## placement preview). Built structures and ground piles are persistent
## *objects* stored per region in RegionState.objects:
##   {"def": "barricade", "tier": 0, "x": .., "y": .., "hp": .., "stage": "building"|"built",
##    "started", "ticks"                (while building)
##    "open"                            (doors)
##    "items": {}, "gear": []           (crates and ground piles)
##    "crop", "water", "grow"           (planters, see FarmSim)
##    "stored"                          (rain collectors)}
## Definitions come from content/buildables.json. Positions are the base
## line (bottom centre) of the footprint, like props. In bunker levels with
## an excavation grid every structure occupies exactly one open cell.
##
## Authored entities can also be structures: a content "structure" block
## ({hp, armor, repair}) makes a door/gate damageable; when it breaks it
## stays open until repaired.

const PATH := "res://content/buildables.json"
const BUILD_REACH := 200.0
const ATTACK_GAP := 40.0       # how close (px) a zombie must be to a structure's edge to hit it
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"defs": {}}
	return _data


static func defs() -> Dictionary:
	return data().get("defs", {})


static func def(id: String) -> Dictionary:
	return defs().get(id, {})


static func menu() -> Array:
	return data().get("menu", [])


static func tier_of(o: Dictionary) -> Dictionary:
	var tiers: Array = def(str(o.get("def", ""))).get("tiers", [])
	if tiers.is_empty():
		return {}
	return tiers[clampi(int(o.get("tier", 0)), 0, tiers.size() - 1)]


static func max_hp(o: Dictionary) -> float:
	return float(tier_of(o).get("hp", 1))


static func is_pile(o: Dictionary) -> bool:
	return str(o.get("def", "")) == "pile"


static func is_built(o: Dictionary) -> bool:
	return str(o.get("stage", "built")) == "built"


## Iteration 013: does a finished heater (the wood stove) stand in this region?
static func heated(world: WorldState, region_id: String) -> bool:
	var region := world.region(region_id) if world != null else null
	if region == null:
		return false
	for oid in region.objects:
		var o: Dictionary = region.objects[oid]
		if is_built(o) and bool(def(str(o.get("def", ""))).get("heater", false)):
			return true
	return false


## Returns "" when a saved object dictionary is usable.
static func validate_object(o) -> String:
	if not (o is Dictionary):
		return "not an object"
	var d := str(o.get("def", ""))
	if d != "pile" and def(d).is_empty():
		return "unknown definition " + d
	if not (o.get("x") is float or o.get("x") is int) or not (o.get("y") is float or o.get("y") is int):
		return "missing position"
	return ""


# ---------------------------------------------------------------- geometry

## "surface", "bunker" or "" (no building allowed in this region).
static func zone_kind(world: WorldState, region_id: String) -> String:
	var r := world.region(region_id)
	if r == null:
		return ""
	if not BunkerState.parse_region_id(region_id).is_empty():
		return "bunker"
	if r.definition().has("build_zones"):
		return "surface"
	return ""


static func cell_mode(region: RegionState) -> bool:
	return Terrain.has_terrain(region)


## Snaps a requested position to where the structure would actually stand.
static func snap(region: RegionState, pos: Vector2) -> Vector2:
	if cell_mode(region):
		var rect := Terrain.cell_rect(region, Terrain.cell_of(region, pos))
		return Vector2(rect.get_center().x, rect.end.y - 6.0)
	return Vector2(roundf(pos.x / 16.0) * 16.0, roundf(pos.y / 16.0) * 16.0)


static func pos_of(o: Dictionary) -> Vector2:
	return Vector2(float(o.get("x", 0)), float(o.get("y", 0)))


static func footprint_at(region: RegionState, def_id: String, pos: Vector2) -> Rect2:
	if def_id == "pile":
		return Rect2(pos - Vector2(18, 16), Vector2(36, 20))
	if cell_mode(region):
		return Terrain.cell_rect(region, Terrain.cell_of(region, pos + Vector2(0, -8)))
	var s: Array = def(def_id).get("size", [48, 24])
	return Rect2(pos - Vector2(float(s[0]) * 0.5, float(s[1])), Vector2(float(s[0]), float(s[1])))


static func footprint(region: RegionState, o: Dictionary) -> Rect2:
	return footprint_at(region, str(o.get("def", "")), pos_of(o))


## True while the object stops movement (players, zombies, line of sight).
static func blocks(o: Dictionary) -> bool:
	var d := def(str(o.get("def", "")))
	if not bool(d.get("blocks", false)):
		return false
	if bool(d.get("openable", false)) and bool(o.get("open", false)) and is_built(o):
		return false
	return true


## Rectangles of blocking objects in a region (navigation, connectivity).
static func blocking_rects(world: WorldState, region_id: String) -> Array:
	var out := []
	var r := world.region(region_id)
	if r == null:
		return out
	for oid in r.objects:
		var o: Dictionary = r.objects[oid]
		if blocks(o):
			out.append(footprint(r, o))
	return out


# ---------------------------------------------------------------- placement

static func _zone_rects(region: RegionState) -> Array:
	return region.definition().get("build_zones", [])


## Why `def_id` cannot be placed at `pos` ("" = it can, materials permitting).
## Read-only: the placement preview runs the same check on clients.
static func placement_problem(world: WorldState, region_id: String, def_id: String, pos: Vector2) -> String:
	var d := def(def_id)
	var region := world.region(region_id)
	if d.is_empty() or region == null:
		return "ACTION_NOT_SUPPORTED"
	var kind := zone_kind(world, region_id)
	if kind == "" or not (kind in d.get("where", [])):
		return "ACTION_BUILD_NOT_HERE"
	pos = snap(region, pos)
	var rect := footprint_at(region, def_id, pos)
	var center := rect.get_center()
	if cell_mode(region):
		var cell := Terrain.cell_of(region, center)
		if not Terrain.is_open(region, cell) or region.terrain.get("digging", {}).has(Terrain.key(cell)):
			return "ACTION_BUILD_NEEDS_FLOOR"
		var sup: Dictionary = region.terrain.get("supports", {})
		if sup.has(Terrain.key(cell)):
			return "ACTION_BUILD_OCCUPIED"
	else:
		var inside := false
		for z in _zone_rects(region):
			if Rect2(float(z[0]), float(z[1]), float(z[2]), float(z[3])).encloses(rect):
				inside = true
		if not inside:
			return "ACTION_BUILD_OUTSIDE_ZONE"
		var grid := NavGrid.for_def(region.def_id)
		if grid.blocked[clampi(grid.to_cell(center).y, 0, grid.h - 1) * grid.w + clampi(grid.to_cell(center).x, 0, grid.w - 1)] == 1:
			return "ACTION_BUILD_OCCUPIED"
	for oid in region.objects:
		var o: Dictionary = region.objects[oid]
		if is_pile(o):
			continue
		if footprint(region, o).grow(-1.0).intersects(rect):
			return "ACTION_BUILD_OCCUPIED"
	var clear := float(data().get("keep_clear_radius", 90)) * (0.75 if cell_mode(region) else 1.0)
	for eid in Content.entity_ids(region.def_id):
		var ed := region.entity_def(eid)
		var t := str(ed.get("type", ""))
		if not ed.has("interact_range") and t != "lamp":
			continue
		if t == "lamp" and cell_mode(region):
			continue  # iteration 012: bunker lamps hang from the ceiling; they never block the floor
		var r2 := clear * (1.15 if t == "portal" or t == "door" else 1.0)
		if t == "lamp" or t == "tree":
			r2 = 40.0
		if _rect_distance(rect, Content.entity_position(ed)) < r2:
			return "ACTION_BUILD_BLOCKS_ACCESS"
	for p in world.online_players():
		if p.region_id == region_id and rect.grow(16.0).has_point(p.position):
			return "ACTION_BUILD_PLAYER_IN_WAY"
	for z in world.zombies.values():
		if z.region_id == region_id and not z.is_dead() and rect.grow(10.0).has_point(z.position):
			return "ACTION_BUILD_PLAYER_IN_WAY"
	if cell_mode(region) and bool(d.get("blocks", false)) and not bool(d.get("openable", false)):
		if _would_trap(world, region, Terrain.cell_of(region, center)):
			return "ACTION_BUILD_WOULD_TRAP"
	return ""


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var cx := clampf(p.x, r.position.x, r.end.x)
	var cy := clampf(p.y, r.position.y, r.end.y)
	return Vector2(cx, cy).distance_to(p)


## Bunker rule: a solid structure may never cut off open floor from the ladder.
static func _would_trap(world: WorldState, region: RegionState, extra: Vector2i) -> bool:
	var before := _reachable_cells(world, region, Vector2i(-999, -999))
	var after := _reachable_cells(world, region, extra)
	return after < before - 1


static func _reachable_cells(world: WorldState, region: RegionState, extra: Vector2i) -> int:
	var solid := {}
	for oid in region.objects:
		var o: Dictionary = region.objects[oid]
		var d := def(str(o.get("def", "")))
		if bool(d.get("blocks", false)) and not bool(d.get("openable", false)):
			solid[Terrain.cell_of(region, footprint(region, o).get_center())] = true
	solid[extra] = true
	var start := Terrain.cell_of(region, Content.entity_position(region.entity_def("ladder_up")) + Vector2(0, 64))
	if not Terrain.is_open(region, start) or solid.has(start):
		return 0
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n) or solid.has(n) or not Terrain.is_open(region, n):
				continue
			seen[n] = true
			queue.append(n)
	return seen.size()


# ---------------------------------------------------------------- requests

static func request_build(world: WorldState, player_id: String, def_id: String, pos: Vector2) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online:
		return WorldActions._fail("ACTION_UNKNOWN_PLAYER")
	if p.dead:
		return WorldActions._fail("ACTION_DEAD")
	var region := world.region(p.region_id)
	var d := def(def_id)
	if region == null or d.is_empty():
		return WorldActions._fail("ACTION_NOT_SUPPORTED")
	pos = snap(region, pos)
	if not SideSection.in_reach(region, p.position, footprint_at(region, def_id, pos).get_center(), BUILD_REACH):
		return WorldActions._fail("ACTION_TOO_FAR")
	var problem := placement_problem(world, p.region_id, def_id, pos)
	if problem != "":
		return WorldActions._fail(problem)
	var cost: Dictionary = (d.get("tiers", [{}])[0] as Dictionary).get("cost", {})
	var bags := Inv.sources(world, p)
	var short := Inv.missing(bags, cost)
	if not short.is_empty():
		return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe(short)])
	var touched_storage := Inv.uses_storage(p, cost)
	Inv.pay(bags, cost)  # spent in the same step that creates the object: never twice
	var oid := world.new_uid("o")
	var ticks := Simulation.seconds_to_ticks(float(d.get("build_seconds", 3)))
	var o := {"def": def_id, "tier": 0, "x": snappedf(pos.x, 0.1), "y": snappedf(pos.y, 0.1),
		"hp": max_hp({"def": def_id, "tier": 0}), "stage": "building", "started": world.tick, "ticks": ticks}
	if d.has("container_slots"):
		o["items"] = {}
		o["gear"] = []
	region.objects[oid] = o
	world.add_job(region.region_id, "object:" + oid, world.tick + ticks)
	ZombieSim.make_noise(world, region.region_id, pos, "build")
	var res := WorldActions._ok()
	res["objects"] = [[region.region_id, oid]]
	res["players"] = [p.player_id]
	if touched_storage:
		res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
	res["events"] = [{"kind": "build_started", "region_id": region.region_id, "oid": oid, "x": pos.x, "y": pos.y}]
	return res


static func complete(world: WorldState, region: RegionState, oid: String) -> Dictionary:
	var o: Dictionary = region.objects.get(oid, {})
	if o.is_empty() or str(o.get("stage", "")) != "building":
		return WorldActions._fail("ACTION_NOT_SUPPORTED")
	o.erase("started")
	o.erase("ticks")
	o["stage"] = "built"
	var res := WorldActions._ok()
	res["objects"] = [[region.region_id, oid]]
	res["events"] = [{"kind": "build_done", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
	return res


## Actions on an existing object: toggle (doors), repair, upgrade, dismantle,
## pickup (ground piles), store / take (crates; arg = item id or gear uid).
static func request_object(world: WorldState, player_id: String, oid: String, action: String, arg: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online:
		return WorldActions._fail("ACTION_UNKNOWN_PLAYER")
	if p.dead:
		return WorldActions._fail("ACTION_DEAD")
	var region := world.region(p.region_id)
	if region == null or not region.objects.has(oid):
		return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
	var o: Dictionary = region.objects[oid]
	var rect := footprint(region, o)
	var reach := float(data().get("interact_reach", 110))
	if _rect_distance(rect, p.position) > reach and not SideSection.in_reach(region, p.position, rect.get_center(), reach + rect.size.x * 0.5):
		return WorldActions._fail("ACTION_TOO_FAR")
	var d := def(str(o.get("def", "")))
	var res := WorldActions._ok()
	res["objects"] = [[region.region_id, oid]]
	res["players"] = [p.player_id]
	if action in ["toggle", "repair", "upgrade", "store", "take", "collect", "plant", "water", "harvest", "craft", "repair_gear"] and not is_built(o):
		return WorldActions._fail("ACTION_BUSY")
	match action:
		"toggle":
			if not bool(d.get("openable", false)):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if bool(o.get("open", false)):
				for pl in world.online_players():
					if pl.region_id == region.region_id and rect.grow(6.0).has_point(pl.position):
						return WorldActions._fail("ACTION_BUILD_PLAYER_IN_WAY")
				for z in world.zombies.values():
					if z.region_id == region.region_id and not z.is_dead() and rect.grow(6.0).has_point(z.position):
						return WorldActions._fail("ACTION_BUILD_PLAYER_IN_WAY")
			o["open"] = not bool(o.get("open", false))
			ZombieSim.make_noise(world, region.region_id, pos_of(o), "door")
			res["events"] = [{"kind": "door_toggled", "region_id": region.region_id, "oid": oid, "open": o["open"],
				"x": float(o["x"]), "y": float(o["y"])}]
			res["players"] = []
		"repair":
			var mh := max_hp(o)
			if float(o.get("hp", mh)) >= mh:
				return WorldActions._fail("ACTION_NOT_DAMAGED")
			var item := str(tier_of(o).get("repair_item", "wood"))
			var bags := Inv.sources(world, p)
			if Inv.available(bags, item) < 1:
				return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe({item: 1})])
			if Inv.uses_storage(p, {item: 1}):
				res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
			Inv.pay(bags, {item: 1})
			o["hp"] = minf(mh, float(o.get("hp", 0)) + mh * float(d.get("repair_fraction", 0.5)))
			res["events"] = [{"kind": "repaired", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
		"upgrade":
			var tiers: Array = d.get("tiers", [])
			var next := int(o.get("tier", 0)) + 1
			if next >= tiers.size():
				return WorldActions._fail("ACTION_ALREADY_DONE")
			var cost: Dictionary = (tiers[next] as Dictionary).get("cost", {})
			var bags2 := Inv.sources(world, p)
			var short := Inv.missing(bags2, cost)
			if not short.is_empty():
				return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe(short)])
			if Inv.uses_storage(p, cost):
				res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
			Inv.pay(bags2, cost)
			o["tier"] = next
			o["hp"] = max_hp(o)
			ZombieSim.make_noise(world, region.region_id, pos_of(o), "build")
			res["events"] = [{"kind": "upgraded", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
		"dismantle":
			if o.has("job"):
				return WorldActions._fail("ACTION_BUSY")
			var refund := {}
			var cost2: Dictionary = tier_of(o).get("cost", {})
			var share := 1.0 if not is_built(o) else float(d.get("refund", 0.5))
			for item2 in cost2:
				var n := floori(int(cost2[item2]) * share)
				if n > 0:
					refund[item2] = n
			region.objects.erase(oid)
			for item3 in refund:
				Inv.give_stack(world, p, item3, int(refund[item3]))
			# Container contents are never lost: they stay on the ground.
			var pile := Inv.drop_into_pile(world, region.region_id, pos_of(o), o.get("items", {}), o.get("gear", []))
			if pile != "":
				res["objects"].append([region.region_id, pile])
			var made: Dictionary = o.get("output", {})
			var pile2 := Inv.drop_into_pile(world, region.region_id, pos_of(o), made.get("items", {}), made.get("gear", []))
			if pile2 != "" and not [region.region_id, pile2] in res["objects"]:
				res["objects"].append([region.region_id, pile2])
			for k in region.objects:  # piles created by give_stack
				if is_pile(region.objects[k]) and not [region.region_id, k] in res["objects"]:
					res["objects"].append([region.region_id, k])
			res["events"] = [{"kind": "dismantled", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
			res["notice"] = {"key": "BUILD_DISMANTLED", "args": [Items.describe(refund) if not refund.is_empty() else "—"]}
		"pickup":
			if not is_pile(o):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var got := 0
			var items: Dictionary = o.get("items", {})
			for item4 in items.keys():
				var n2 := mini(int(items[item4]), Inv.free_slots(p))
				if n2 > 0:
					p.carried[item4] = p.carrying(item4) + n2
					items[item4] = int(items[item4]) - n2
					got += n2
				if int(items[item4]) <= 0:
					items.erase(item4)
			var gear: Array = o.get("gear", [])
			while not gear.is_empty() and Inv.free_slots(p) > 0:
				p.gear.append(gear.pop_front())
				got += 1
			if got == 0:
				return WorldActions._fail("ACTION_CARRY_FULL", [Items.carry_slots()])
			if items.is_empty() and gear.is_empty():
				region.objects.erase(oid)
			res["events"] = [{"kind": "picked_up", "region_id": region.region_id, "oid": oid, "player_id": p.player_id}]
		"store", "take":
			if not d.has("container_slots"):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var moved := Inv.transfer(p, o, action == "store", arg, int(d.get("container_slots", 20)))
			if moved <= 0:
				return WorldActions._fail("ACTION_NOTHING_THERE" if action == "take" else "ACTION_CARRY_FULL", [Items.carry_slots()])
		_:
			if Craft.is_bench(o):
				return Craft.object_action(world, p, region, oid, o, action, arg, res)
			return FarmSim.object_action(world, p, region, oid, o, action, arg, res)
	return res


# ---------------------------------------------------------------- damage

## Zombie (or event) damage to a built object. Armor reduces every hit.
static func damage_object(world: WorldState, region: RegionState, oid: String, amount: float) -> Dictionary:
	var res := WorldActions._ok()
	var o: Dictionary = region.objects.get(oid, {})
	if o.is_empty() or is_pile(o):
		return res
	var armor := float(tier_of(o).get("armor", 0))
	var dmg := maxf(1.0, amount - armor)
	o["hp"] = maxf(0.0, float(o.get("hp", max_hp(o))) - dmg)
	res["objects"] = [[region.region_id, oid]]
	var ev := {"kind": "struct_hit", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"]),
		"hp": o["hp"], "max": max_hp(o)}
	if float(o["hp"]) <= 0.0:
		ev["kind"] = "struct_destroyed"
		region.objects.erase(oid)
		var pile := Inv.drop_into_pile(world, region.region_id, pos_of(o), o.get("items", {}), o.get("gear", []))
		if pile != "":
			res["objects"].append([region.region_id, pile])
		SessionLog.info("world", "structure_destroyed", {"region": region.region_id, "oid": oid, "def": o.get("def")})
	res["events"] = [ev]
	return res


## Damageable authored entities (doors/gates with a "structure" block).
static func entity_structure(region: RegionState, eid: String) -> Dictionary:
	return region.entity_def(eid).get("structure", {})


static func entity_hp(region: RegionState, eid: String) -> float:
	var s := entity_structure(region, eid)
	return float(region.entity_state(eid).get("hp", s.get("hp", 0)))


static func damage_entity(world: WorldState, region: RegionState, eid: String, amount: float) -> Dictionary:
	var s := entity_structure(region, eid)
	var res := WorldActions._ok()
	if s.is_empty() or bool(region.entity_state(eid).get("broken", false)):
		return res
	var hp := maxf(0.0, entity_hp(region, eid) - maxf(1.0, amount - float(s.get("armor", 0))))
	var pos := Content.entity_position(region.entity_def(eid))
	var ev := {"kind": "struct_hit", "region_id": region.region_id, "eid": eid, "x": pos.x, "y": pos.y, "hp": hp, "max": float(s.get("hp", 1))}
	if hp <= 0.0:
		region.set_fields(eid, {"hp": 0.0, "broken": true, "open": true})
		ev["kind"] = "struct_destroyed"
		res = WorldActions._changed(region, eid, "broken")
	else:
		region.set_fields(eid, {"hp": hp})
		res = WorldActions._changed(region, eid, "damaged")
	res["events"] = [ev]
	return res


## Repairs an authored structure (one repair cost restores it fully).
static func repair_entity(world: WorldState, p: PlayerState, region: RegionState, eid: String) -> Dictionary:
	var s := entity_structure(region, eid)
	if s.is_empty():
		return WorldActions._fail("ACTION_NOT_SUPPORTED")
	if entity_hp(region, eid) >= float(s.get("hp", 0)) and not bool(region.entity_state(eid).get("broken", false)):
		return WorldActions._fail("ACTION_NOT_DAMAGED")
	var cost: Dictionary = s.get("repair", {"wood": 2})
	var bags := Inv.sources(world, p)
	var short := Inv.missing(bags, cost)
	if not short.is_empty():
		return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe(short)])
	var touched := Inv.uses_storage(p, cost)
	Inv.pay(bags, cost)
	region.set_fields(eid, {"hp": float(s.get("hp", 0)), "broken": false})
	var res := WorldActions._changed(region, eid, "repaired")
	res["players"] = [p.player_id]
	if touched:
		res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
	var pos := Content.entity_position(region.entity_def(eid))
	res["events"] = [{"kind": "repaired", "region_id": region.region_id, "eid": eid, "x": pos.x, "y": pos.y}]
	return res


## The blocking structure a stuck zombie should break through: the closest
## blocking object or closed damageable gate near it, preferring ones that lie
## toward where it wants to go. Returns "o:<oid>", "e:<eid>" or "".
static func breach_target(world: WorldState, region_id: String, from: Vector2, toward: Vector2, max_dist: float = 260.0) -> String:
	var r := world.region(region_id)
	if r == null:
		return ""
	var best := ""
	var best_score := INF
	var dir := (toward - from).normalized() if toward.distance_to(from) > 1.0 else Vector2.ZERO
	for oid in r.objects:
		var o: Dictionary = r.objects[oid]
		if not blocks(o):
			continue
		var rect := footprint(r, o)
		var dd := _rect_distance(rect, from)
		if dd > max_dist:
			continue
		var score := dd - 80.0 * dir.dot((rect.get_center() - from).normalized())
		if score < best_score:
			best_score = score
			best = "o:" + oid
	for eid in Content.entity_ids(r.def_id):
		var ed := r.entity_def(eid)
		if not ed.has("structure") or bool(r.entity_state(eid).get("open", false)):
			continue
		var ep := Content.entity_position(ed)
		var dd2 := ep.distance_to(from)
		if dd2 > max_dist:
			continue
		var score2 := dd2 - 80.0 * dir.dot((ep - from).normalized())
		if score2 < best_score:
			best_score = score2
			best = "e:" + eid
	return best


## World rectangle of a breach target, or an empty Rect2 when it no longer blocks.
static func target_rect(world: WorldState, region_id: String, target: String) -> Rect2:
	var r := world.region(region_id)
	if r == null or target.length() < 3:
		return Rect2()
	var id := target.substr(2)
	if target.begins_with("o:"):
		var o: Dictionary = r.objects.get(id, {})
		return footprint(r, o) if not o.is_empty() and blocks(o) else Rect2()
	if not r.has_entity(id) or bool(r.entity_state(id).get("open", false)):
		return Rect2()
	var ed := r.entity_def(id)
	var bs: Array = ed.get("blocker", [64, 14])
	var p := Content.entity_position(ed)
	return Rect2(p + Vector2(-float(bs[0]) * 0.5, -float(bs[1])), Vector2(float(bs[0]), float(bs[1])))


static func damage_target(world: WorldState, region_id: String, target: String, amount: float) -> Dictionary:
	var r := world.region(region_id)
	if r == null:
		return WorldActions._ok()
	if target.begins_with("o:"):
		return damage_object(world, r, target.substr(2), amount)
	return damage_entity(world, r, target.substr(2), amount)


static func edge_distance(rect: Rect2, p: Vector2) -> float:
	return _rect_distance(rect, p)
