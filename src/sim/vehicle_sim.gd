class_name VehicleSim
extends RefCounted
## Host-authoritative vehicles (iteration 011).
##
## Types: res://content/vehicles.json. Placements: a region's "vehicles" list
## (created once per world by ensure()). Road exits: a region's
## "vehicle_exits" [{"rect": [x, y, w, h], "target": {"region", "position",
## "rotation"}}] — driving into the rectangle moves the vehicle, everyone in
## it and its trunk to the target region together. Other players are never moved.
##
## Driving is owner-predicted: the driver's client simulates the car with
## collision and submits poses (submit_pose); the host validates speed and
## bounds, commits them, keeps the occupants on the car and makes engine noise.
## Seats, engine and trunk changes go through request() and are published as
## result["vehicles"] (full state, reliable). There is no fuel, damage or key
## quest: every vehicle starts with its key in the ignition.

const PATH := "res://content/vehicles.json"
const POSE_SLACK := 60.0
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"vehicles": {}}
	return _data


static func def(def_id: String) -> Dictionary:
	return data().get("vehicles", {}).get(def_id, {})


static func vdef(v: VehicleState) -> Dictionary:
	return def(v.def_id)


static func heater_on(world: WorldState, vehicle_id: String) -> bool:
	var v: VehicleState = world.vehicles.get(vehicle_id)
	return v != null and v.engine_on


static func of_player(world: WorldState, p: PlayerState) -> VehicleState:
	if p == null or p.vehicle_id == "":
		return null
	return world.vehicles.get(p.vehicle_id)


static func in_region(world: WorldState, region_id: String) -> Array:
	var out := []
	for v in world.vehicles.values():
		if v.region_id == region_id:
			out.append(v)
	return out


## Creates the vehicles placed in region content that this world does not have
## yet (new worlds, and older saves that predate vehicles). Never duplicates.
static func ensure(world: WorldState) -> int:
	var added := 0
	for rid in Content.region_ids():
		for pl in Content.region_def(rid).get("vehicles", []):
			var id := str(pl.get("id", ""))
			if id == "" or world.vehicles.has(id) or def(str(pl.get("def", ""))).is_empty():
				continue
			var pos: Array = pl.get("position", [0, 0])
			var v := VehicleState.make(id, str(pl["def"]), rid, Vector2(float(pos[0]), float(pos[1])),
				deg_to_rad(float(pl.get("rotation", 0.0))), int(def(str(pl["def"])).get("seats", 2)))
			world.vehicles[id] = v
			added += 1
	if added > 0:
		SessionLog.info("vehicle", "placed", {"count": added})
	return added


## Seat consistency after loading a save: a seat only counts when that player
## exists and says they are in this vehicle; vehicles in missing regions return
## to their placement. Engines are left as saved.
static func validate(world: WorldState, warnings: Array) -> void:
	for id in world.vehicles.keys():
		var v: VehicleState = world.vehicles[id]
		var d := vdef(v)
		if d.is_empty():
			warnings.append("vehicle %s has unknown type %s; removed" % [id, v.def_id])
			world.vehicles.erase(id)
			continue
		while v.seats.size() < int(d.get("seats", 2)):
			v.seats.append("")
		v.seats.resize(int(d.get("seats", 2)))
		for i in v.seats.size():
			var pid := str(v.seats[i] if v.seats[i] != null else "")
			var p: PlayerState = world.players.get(pid)
			if pid != "" and (p == null or p.vehicle_id != id):
				v.seats[i] = ""
			elif v.seats[i] == null:
				v.seats[i] = ""
		if world.region(v.region_id) == null:
			warnings.append("vehicle %s was in missing region %s; returned to its placement" % [id, v.region_id])
			world.vehicles.erase(id)
	for p in world.players.values():
		if p.vehicle_id != "":
			var v2: VehicleState = world.vehicles.get(p.vehicle_id)
			if v2 == null or v2.seat_of(p.player_id) < 0:
				p.vehicle_id = ""


static func _result(v: VehicleState) -> Dictionary:
	var r := WorldActions._ok()
	r["vehicles"] = [v.vehicle_id]
	return r


## enter [seat], exit, engine, store <item|uid>, take <item|uid>.
static func request(world: WorldState, player_id: String, vehicle_id: String, action: String, arg: String = "") -> Dictionary:
	var p: PlayerState = world.players.get(player_id)
	var v: VehicleState = world.vehicles.get(vehicle_id)
	if p == null or not p.online:
		return WorldActions._fail("ACTION_UNKNOWN_PLAYER")
	if v == null:
		return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
	if p.dead:
		return WorldActions._fail("ACTION_DEAD")
	var d := vdef(v)
	var inside := v.seat_of(player_id) >= 0
	if not inside and (p.region_id != v.region_id or p.position.distance_to(v.position) > float(d.get("enter_range", 120)) + 40.0):
		return WorldActions._fail("ACTION_TOO_FAR")
	match action:
		"enter":
			if inside:
				return WorldActions._fail("VEHICLE_ALREADY_INSIDE")
			if p.vehicle_id != "":
				return WorldActions._fail("VEHICLE_ALREADY_INSIDE")
			if v.locked:
				return WorldActions._fail("VEHICLE_LOCKED")
			var seat := -1
			if arg.is_valid_int() and int(arg) >= 0 and int(arg) < v.seats.size() and str(v.seats[int(arg)]) == "":
				seat = int(arg)
			else:
				seat = v.seats.find("")
			if seat < 0:
				return WorldActions._fail("VEHICLE_FULL")
			v.seats[seat] = player_id
			p.vehicle_id = vehicle_id
			p.position = v.position
			SessionLog.info("vehicle", "entered", {"vehicle": vehicle_id, "by": player_id.substr(0, 6), "seat": seat})
			var r := _result(v)
			r["events"] = [{"kind": "vehicle_door", "region_id": v.region_id, "x": v.position.x, "y": v.position.y}]
			r["roster"] = true
			return r
		"exit":
			if not inside:
				return WorldActions._fail("VEHICLE_NOT_INSIDE")
			var r2 := eject(world, p)
			return r2
		"engine":
			if v.driver() != player_id:
				return WorldActions._fail("VEHICLE_NOT_DRIVER")
			v.engine_on = not v.engine_on
			SessionLog.info("vehicle", "engine", {"vehicle": vehicle_id, "on": v.engine_on})
			if v.engine_on:
				ZombieSim.make_noise(world, v.region_id, v.position, "engine_start")
			var r3 := _result(v)
			r3["events"] = [{"kind": "vehicle_engine", "region_id": v.region_id, "vehicle_id": vehicle_id, "on": v.engine_on,
				"x": v.position.x, "y": v.position.y}]
			return r3
		"store", "take":
			if inside:
				return WorldActions._fail("VEHICLE_FROM_OUTSIDE")
			var moved := Inv.transfer(p, v.cargo, action == "store", arg, int(d.get("cargo_slots", 10)))
			if moved <= 0:
				return WorldActions._fail("ACTION_NOTHING_THERE" if action == "take" else "VEHICLE_TRUNK_FULL")
			var r4 := _result(v)
			r4["players"] = [player_id]
			r4["vitals"] = [player_id]
			return r4
	return WorldActions._fail("ACTION_NOT_SUPPORTED")


## Takes a player out of their vehicle and stands them beside it (the first
## free side: driver's side, passenger side, behind, in front). Used by "exit",
## death and disconnects.
static func eject(world: WorldState, p: PlayerState) -> Dictionary:
	var v: VehicleState = world.vehicles.get(p.vehicle_id)
	p.vehicle_id = ""
	if v == null:
		return WorldActions._ok()
	var seat := v.seat_of(p.player_id)
	if seat >= 0:
		v.seats[seat] = ""
	if seat == 0:
		v.speed = 0.0
	var d := vdef(v)
	var side := v.heading().orthogonal()
	var half_w := float(d.get("width", 68)) * 0.5 + 30.0
	var half_l := float(d.get("length", 150)) * 0.5 + 30.0
	var spots := [v.position - side * half_w, v.position + side * half_w, v.position - v.heading() * half_l, v.position + v.heading() * half_l]
	if seat % 2 == 1:
		spots = [spots[1], spots[0], spots[2], spots[3]]
	var grid := NavGrid.for_def(world.region(v.region_id).def_id) if world.region(v.region_id) != null else null
	var dyn := NavGrid.dynamic_blocked(world, v.region_id, grid) if grid != null else {}
	var out: Vector2 = spots[0]
	var bounds := _bounds(world, v.region_id)
	for s in spots:
		var c: Vector2 = s
		if bounds.has_area() and not bounds.grow(-16.0).has_point(c):
			continue
		if grid == null or not grid.is_blocked(grid.to_cell(c), dyn):
			out = c
			break
	p.position = out
	SessionLog.info("vehicle", "exited", {"vehicle": v.vehicle_id, "by": p.player_id.substr(0, 6), "at": [roundi(out.x), roundi(out.y)]})
	var r := _result(v)
	r["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": out}
	r["events"] = [{"kind": "vehicle_door", "region_id": v.region_id, "x": v.position.x, "y": v.position.y}]
	return r


static func _bounds(world: WorldState, region_id: String) -> Rect2:
	var b: Array = world.region_def(region_id).get("bounds", [])
	return Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3])) if b.size() == 4 else Rect2()


## Driver pose report. Returns a WorldActions result (empty "vehicles" when
## nothing needs a reliable publish) or a failure with "correct" = true when the
## driver must be snapped back to the host's pose.
static func submit_pose(world: WorldState, player_id: String, vehicle_id: String, pos: Vector2, rot: float, speed: float,
		steer: float, dt: float) -> Dictionary:
	var v: VehicleState = world.vehicles.get(vehicle_id)
	var p: PlayerState = world.players.get(player_id)
	if v == null or p == null or v.driver() != player_id or p.dead:
		return WorldActions._fail("VEHICLE_NOT_DRIVER")
	var d := vdef(v)
	var max_step := float(d.get("max_speed", 430)) * dt * 1.5 + POSE_SLACK
	var bounds := _bounds(world, v.region_id)
	if v.position.distance_to(pos) > max_step or (bounds.has_area() and not bounds.grow(40.0).has_point(pos)) \
			or (not v.engine_on and v.position.distance_to(pos) > 30.0):
		SessionLog.warn("vehicle", "pose_rejected", {"vehicle": vehicle_id, "from": [roundi(v.position.x), roundi(v.position.y)],
			"to": [roundi(pos.x), roundi(pos.y)], "dt": snappedf(dt, 0.001)})
		var f := WorldActions._fail("VEHICLE_POSE_REJECTED")
		f["correct"] = true
		return f
	v.position = pos
	v.rotation = wrapf(rot, -PI, PI)
	v.speed = clampf(speed, -float(d.get("reverse_speed", 150)), float(d.get("max_speed", 430)))
	v.steer = clampf(steer, -1.0, 1.0)
	for pid in v.occupants():
		var o: PlayerState = world.players.get(pid)
		if o != null:
			o.position = pos
	# The road exit is reached with the front bumper (the region edge stops the body).
	var front := pos + v.heading() * (float(d.get("length", 170)) * 0.5 + 12.0)
	for ex in world.region_def(v.region_id).get("vehicle_exits", []):
		var rr: Array = ex.get("rect", [])
		if rr.size() == 4 and Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3])).has_point(front):
			return transfer(world, v, ex.get("target", {}))
	return WorldActions._ok()


## Moves a vehicle with its occupants and trunk to another region. Returns a
## result with one transition per occupant (only they change region).
static func transfer(world: WorldState, v: VehicleState, target: Dictionary) -> Dictionary:
	var to_region := str(target.get("region", ""))
	if world.region(to_region) == null:
		return WorldActions._fail("ACTION_NOT_AVAILABLE")
	var tp: Array = target.get("position", [0, 0])
	var from := v.region_id
	v.region_id = to_region
	v.position = Vector2(float(tp[0]), float(tp[1]))
	v.rotation = deg_to_rad(float(target.get("rotation", 0.0)))
	var r := _result(v)
	var transitions := []
	var occupants := v.occupants()
	for pid in occupants:
		var o: PlayerState = world.players.get(pid)
		if o == null:
			continue
		o.region_id = to_region
		o.position = v.position
		transitions.append({"player_id": pid, "region_id": to_region, "position": v.position})
	r["transitions"] = transitions
	r["roster"] = true
	var key := str(world.region_def(to_region).get("discovery", ""))
	if key != "" and WorldActions.discover(world, key):
		r["meta"] = true
		r["broadcast_notice"] = {"key": "DISCOVERED_REGION", "args": [TranslationServer.translate(str(world.region_def(to_region).get("display_key", "")))]}
	SessionLog.info("vehicle", "region_transfer", {"vehicle": v.vehicle_id, "from": from, "to": to_region,
		"occupants": occupants.size(), "cargo": Items.total(v.cargo.get("items", {})) + (v.cargo.get("gear", []) as Array).size()})
	return r


## Host, every tick: parked cars stop, running engines are heard.
static func step(world: WorldState, ticks: int) -> Array:
	var out := []
	for v in world.vehicles.values():
		for pid in v.occupants():
			var o: PlayerState = world.players.get(pid)
			if o == null:
				v.seats[v.seat_of(pid)] = ""
			elif o.dead:
				out.append(eject(world, o))  # a downed player slumps out of the car
		if v.driver() == "":
			v.speed = 0.0
			v.steer = 0.0
		if not v.engine_on:
			continue
		var every := maxi(1, int(float(vdef(v).get("engine_noise_every", 3.0)) * Simulation.TICK_RATE))
		if (world.tick / every) != ((world.tick - ticks) / every):
			var loud := 0.6 + 0.6 * clampf(absf(v.speed) / float(vdef(v).get("max_speed", 430)), 0.0, 1.0)
			ZombieSim.make_noise(world, v.region_id, v.position, "engine", loud)
	return out


static func rows(world: WorldState) -> Array:
	var out := []
	for v in world.vehicles.values():
		out.append(v.row())
	return out


## Client: applies the frequent pose rows (the local driver keeps its prediction).
static func apply_rows(world: WorldState, rows_in: Array, local_player: String) -> void:
	for row in rows_in:
		var v: VehicleState = world.vehicles.get(str(row[0]))
		if v == null:
			continue
		if v.driver() == local_player and local_player != "" and str(row[1]) == v.region_id:
			continue
		v.region_id = str(row[1])
		v.position = Vector2(float(row[2]), float(row[3]))
		v.rotation = float(row[4])
		v.speed = float(row[5])
		v.engine_on = bool(row[6])
		v.steer = float(row[7])


static func encode_all(world: WorldState) -> Dictionary:
	var out := {}
	for id in world.vehicles:
		out[id] = (world.vehicles[id] as VehicleState).to_dict()
	return out


static func decode_all(world: WorldState, d, _warnings: Array) -> void:
	if not (d is Dictionary):
		return
	for id in d:
		if d[id] is Dictionary:
			world.vehicles[str(id)] = VehicleState.from_dict(str(id), d[id])
