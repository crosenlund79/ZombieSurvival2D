extends TestCase
## Iteration 012 "Shadows & Depth": thawed blood (and, below, the side-view bunker).

const PID := "aaaaaaaaaaaaaaaa"


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _blood_steps(w: WorldState, seconds: float) -> void:
	for i in int(seconds * Simulation.TICK_RATE):
		w.tick += 1
		BloodSim.step(w, 1)


func test_no_blood_without_warmth() -> void:
	var w := WorldState.create_new("w_b1", 81)
	EnvSim.set_weather(w, "clear")
	var z := ZombieSim.spawn(w, "homestead", Vector2(300, 1300), false)  # far from the cabin
	_blood_steps(w, 120.0)
	eq(z.thaw, 0.0, "cold away from heat")
	eq(w.blood.size(), 0, "walking around never leaves blood on its own")


func test_warmth_thaws_and_drips_a_few_small_marks() -> void:
	var w := WorldState.create_new("w_b2", 82)
	EnvSim.set_weather(w, "clear")
	var z := ZombieSim.spawn(w, "homestead", Vector2(1160, 760), false)  # lingering by the cabin
	_blood_steps(w, 60.0)
	check(z.thaw > 0.5, "the cabin's warmth thaws the blood in its clothes")
	var n := w.blood.size()
	check(n >= 1, "it drips now and then")
	check(n <= 12, "intermittent, never a stream (%d marks in a minute)" % n)
	for b in w.blood:
		check(float(b[5]) <= 1.0, "small marks")
		check(Vector2(float(b[2]), float(b[3])).distance_to(z.position) < 20.0, "where it stood")
	# away from the heat it refreezes and stops dripping
	z.position = Vector2(300, 1300)
	_blood_steps(w, 90.0)
	var after := w.blood.size()
	_blood_steps(w, 60.0)
	eq(w.blood.size(), after, "refrozen: no more drops")
	check(z.thaw < 0.3, "refrozen")


func test_running_engine_is_a_heat_source() -> void:
	var w := WorldState.create_new("w_b3", 83)
	VehicleSim.ensure(w)
	var v: VehicleState = w.vehicles["wagon"]
	check(BloodSim.heat_at(BloodSim.heat_sources(w, v.region_id), v.position + Vector2(60, 0)) == 0.0, "a cold car warms nobody")
	v.engine_on = true
	check(BloodSim.heat_at(BloodSim.heat_sources(w, v.region_id), v.position + Vector2(60, 0)) > 0.3, "a running engine does")


func _mark(w: WorldState) -> Array:
	BloodSim.drip(w, "homestead", Vector2(800, 1300))
	return w.blood[w.blood.size() - 1]


func test_weather_erases_and_hides_marks_systemically() -> void:
	var lifetimes := {}
	for kind in ["clear", "snow", "blizzard", "heavy_rain"]:
		var w := WorldState.create_new("w_b4" + kind, 84)
		EnvSim.set_weather(w, kind)
		w.env["until"] = 1 << 30
		_mark(w)
		var t := 0.0
		while not w.blood.is_empty() and t < 1800.0:
			_blood_steps(w, 10.0)
			t += 10.0
		lifetimes[kind] = t
	check(lifetimes["heavy_rain"] < lifetimes["clear"], "rain washes marks away quickly %s" % [lifetimes])
	check(lifetimes["snow"] < lifetimes["clear"], "falling snow buries them")
	check(lifetimes["blizzard"] < lifetimes["snow"], "a blizzard buries them faster")
	check(lifetimes["clear"] >= 600.0, "on a calm day they last long enough to be noticed")
	# visibility: fog and blizzards make a fresh mark hard to make out, distance matters
	var w2 := WorldState.create_new("w_b5", 85)
	var b := _mark(w2)
	var near := Vector2(float(b[2]) + 150, float(b[3]))
	EnvSim.set_weather(w2, "clear")
	var clear_vis := BloodSim.visibility(w2, b, near)
	EnvSim.set_weather(w2, "fog")
	var fog_vis := BloodSim.visibility(w2, b, near)
	var fog_far := BloodSim.visibility(w2, b, near + Vector2(500, 0))
	EnvSim.set_weather(w2, "blizzard")
	var bliz_vis := BloodSim.visibility(w2, b, near)
	check(clear_vis > 0.9, "discernible on a calm day")
	check(fog_vis < clear_vis * 0.7, "fog makes it hard to identify")
	eq(fog_far, 0.0, "and hides it beyond a short range")
	check(bliz_vis < fog_vis, "a blizzard makes it hardest")


func test_blood_marks_are_saved() -> void:
	var w := WorldState.create_new("w_b6", 86)
	_mark(w)
	_mark(w)
	w.blood[0][6] = 0.4
	var r := SaveCodec.decode(SaveCodec.encode(w))
	check(r["ok"], "round trip")
	var w2: WorldState = r["world"]
	eq(w2.blood.size(), 2, "marks persist")
	check(absf(float(w2.blood[0][6]) - 0.4) < 0.001, "with how buried they were")


# ---------------------------------------------------------------- side-view bunker (one state, two readings)

func _bunker_world() -> Array:
	var w := WorldState.create_new("w_side", 91)
	var b := w.create_bunker("homestead.farmhouse.shelter", "homestead.farmhouse", "bunker_earth")
	var rid := b.level_region(-1)
	return [w, w.region(rid)]


func test_cross_section_floor_ceiling_and_rest() -> void:
	var a := _bunker_world()
	var w: WorldState = a[0]
	var r: RegionState = a[1]
	var room_floor := Terrain.cell_rect(r, Vector2i(20, 16)).end.y
	var room_ceiling := Terrain.cell_rect(r, Vector2i(20, 10)).position.y
	check(absf(SideSection.floor_y(r, 600, 300) - (room_floor - SideSection.FEET)) < 0.1, "the floor is the bottom of the dug room")
	eq(SideSection.ceiling_y(r, 600, 500), room_ceiling, "the ceiling is its top")
	var storage := Content.entity_position(r.entity_def("storage"))
	eq(SideSection.rest(r, storage).x, storage.x, "things keep their place along the room")
	check(absf(SideSection.rest(r, storage).y - (room_floor - SideSection.FEET)) < 0.1, "and rest on the floor beneath them")
	var p := SideSection.to_screen(r, Vector2(300, 600))
	check(SideSection.to_plan(r, p).distance_to(Vector2(300, 600)) < 0.01, "screen projection round-trips (presentation only)")
	var concrete := w.region(w.add_level(w.bunker("homestead.farmhouse.shelter"), -2, "bunker_concrete"))
	check(concrete != null and SideSection.floor_y(concrete, 500, 300) > 600.0, "a level without a grid is one room with a floor")


func test_side_walking_steps_and_walls() -> void:
	var a := _bunker_world()
	var w: WorldState = a[0]
	var r: RegionState = a[1]
	var start := SideSection.rest(r, Vector2(600, 600))
	var moved := SideSection.walk(w, r, start, 40.0)
	eq(moved.y, start.y, "flat floor: walk along it")
	check(moved.x > start.x, "and move")
	# the room ends at column 26: earth beyond it blocks
	var at_wall := SideSection.rest(r, Vector2(Terrain.cell_rect(r, Vector2i(26, 16)).end.x - 16.0, 600))
	eq(SideSection.walk(w, r, at_wall, 30.0), at_wall, "solid earth is a wall")
	# dig one cell out beside the floor and one row down: a single step is walkable
	var dug: Dictionary = r.terrain.get("dug", {})
	dug["27,16"] = true
	dug["28,17"] = true
	dug["28,16"] = true
	r.terrain["dug"] = dug
	var p1 := SideSection.walk(w, r, at_wall, 30.0)
	check(p1.x > at_wall.x, "a dug opening can be walked into")
	var p2 := p1
	for i in 6:
		p2 = SideSection.walk(w, r, p2, 20.0)
	check(p2.y > p1.y + 10.0, "one row down is a step, not a jump")


func test_side_reach_covers_the_open_space_and_floor_snap_on_arrival() -> void:
	var a := _bunker_world()
	var w: WorldState = a[0]
	var r: RegionState = a[1]
	var ladder := Content.entity_position(r.entity_def("ladder_up"))
	var feet := SideSection.rest(r, ladder)
	check(feet.distance_to(ladder) > 200.0, "the ladder's plan point is near the ceiling")
	check(SideSection.in_reach(r, feet, ladder, 56.0), "but standing at its foot reaches it")
	check(not SideSection.in_reach(r, feet + Vector2(300, 0), ladder, 56.0), "horizontal distance still counts")
	check(not SideSection.in_reach(w.region("homestead"), Vector2.ZERO, Vector2(0, 200), 56.0), "the surface keeps plan distance")
	# a player arriving by the hatch in side view stands on the floor; in top view where the ladder is
	var p := _player(w, PID, "homestead.farmhouse", Content.entity_position(w.region("homestead.farmhouse").entity_def("homestead.farmhouse.shelter")))
	var house := w.region("homestead.farmhouse")
	house.set_fields("homestead.farmhouse.shelter", {"stage": "built", "open": true})
	check(WorldActions.request_interact(w, PID, "homestead.farmhouse.hatch_ladder", -1)["ok"], "climb down")
	check(absf(p.position.y - SideSection.floor_y(r, p.position.x, p.position.y - 4)) < 0.5, "side view: feet on the floor")
	p.bunker_view = "top"
	p.region_id = "homestead.farmhouse"
	p.position = Content.entity_position(house.entity_def("homestead.farmhouse.shelter"))
	WorldActions.request_interact(w, PID, "homestead.farmhouse.hatch_ladder", -1)
	check(p.position.y < SideSection.floor_y(r, p.position.x, p.position.y - 4) - 100.0, "top view: by the ladder, as before")


func test_supports_and_ladders_are_climbable() -> void:
	var a := _bunker_world()
	var w: WorldState = a[0]
	var r: RegionState = a[1]
	var lad := Content.entity_position(r.entity_def("ladder_up"))
	check(SideSection.climbable(w, r, lad), "the ladder up the shaft")
	var spot := Terrain.cell_center(r, Vector2i(16, 15))
	check(not SideSection.climbable(w, r, spot), "plain floor is not")
	var sup: Dictionary = {"16,15": {"stage": "reinforced"}}
	r.terrain["supports"] = sup
	check(SideSection.climbable(w, r, spot), "a reinforced timber support is scaffolding you can climb")


func test_step_off_a_ledge_but_never_climb_one() -> void:
	var a := _bunker_world()
	var w: WorldState = a[0]
	var r: RegionState = a[1]
	# a raised chamber two rows above the room floor, opening into the room's left wall
	var dug := {}
	for c in range(9, 13):
		for row in range(11, 15):
			dug["%d,%d" % [c, row]] = true
	r.terrain["dug"] = dug
	var ledge := Vector2(Terrain.cell_rect(r, Vector2i(12, 14)).end.x - 12.0, Terrain.cell_rect(r, Vector2i(12, 14)).end.y - SideSection.FEET)
	var off := SideSection.walk(w, r, ledge, 30.0)
	check(off.x > ledge.x, "you can step off the ledge into the room")
	eq(off.y, ledge.y, "and fall from where you stepped (the avatar drops to the floor)")
	var floor_pos := SideSection.rest(r, Vector2(Terrain.cell_rect(r, Vector2i(13, 16)).position.x + 10.0, 600))
	eq(SideSection.walk(w, r, floor_pos, -30.0), floor_pos, "but a two-row ledge cannot be walked up")
