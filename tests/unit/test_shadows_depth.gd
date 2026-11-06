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
