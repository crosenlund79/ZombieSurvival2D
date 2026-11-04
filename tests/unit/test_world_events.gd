extends TestCase
## Iteration 008: regional heat, bunker noise leaking through the hatch,
## the homestead defence event (trigger, warning, attack, outcome, cooldown,
## persistence without duplication), day/night and weather (shared, seeded,
## affecting zombie senses and rain collectors), the service station:
## unique discovery loot, discovery records, the carburetor upgrade.

const SITE := "homestead.farmhouse.shelter"
const INTERIOR := "homestead.farmhouse"
const LEVEL := "bunker:homestead.farmhouse.shelter:-1"
const PID := "aaaaaaaaaaaaaaaa"
const YARD := Vector2(1300, 800)


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _step(w: WorldState, ticks: int) -> void:
	for i in ticks:
		Simulation.advance(w, 1)


func test_noise_builds_heat_and_heat_decays() -> void:
	var w := WorldState.create_new("w_heat", 21)
	_player(w, PID, "homestead", Vector2(300, 1300))
	for i in 20:
		ZombieSim.make_noise(w, "homestead", Vector2(300, 1300), "chop")
		Simulation.advance(w, 1)
	var h := EventSim.heat(w, "homestead")
	check(h > 10.0, "sustained noise raises regional heat (%s)" % h)
	eq(EventSim.home_heat(w) < 1.0, true, "noise far from the homestead does not count as home heat")
	Simulation.advance(w, int(EventSim.c("heat_half_life_minutes", 10)) * 60 * Simulation.TICK_RATE)
	check(absf(EventSim.heat(w, "homestead") - h * 0.5) < h * 0.1, "half-life decay")


func test_bunker_noise_leaks_less_through_steel() -> void:
	var w := WorldState.create_new("w_leak", 22)
	var site := Content.entity_position(Content.entity_def(INTERIOR, SITE))
	_player(w, PID, INTERIOR, site + Vector2(0, 40))
	WorldActions.request_interact(w, PID, SITE, 0)
	Simulation.advance(w, 2000)
	var wood: Array = EventSim.leak_target(w, LEVEL)
	eq(str(wood[0]), "homestead", "leaks to the homestead surface")
	w.region(INTERIOR).set_fields(SITE, {"tier": "steel"})
	var steel: Array = EventSim.leak_target(w, LEVEL)
	check(float(steel[2]) < float(wood[2]) * 0.5, "steel hatch keeps most noise in (%s vs %s)" % [steel[2], wood[2]])
	w.threat.queue.clear()
	ZombieSim.make_noise(w, LEVEL, Vector2(500, 500), "dig")
	var leaked := false
	for ev in w.threat.queue:
		leaked = leaked or ev["region_id"] == "homestead"
	check(leaked, "digging below is heard (faintly) at the farmhouse")


func test_defence_event_lifecycle() -> void:
	var w := WorldState.create_new("w_siege", 23)
	w.threat.ambient = true  # automatic attacks only happen with the old loop switched on
	_player(w, PID, INTERIOR, Vector2(300, 500))  # safe indoors
	w.tick = int(EventSim.c("first_siege_after_minutes", 15)) * 60 * Simulation.TICK_RATE + 10
	w.meta["home_heat"] = float(EventSim.c("siege_threshold", 55)) + 5.0
	_step(w, 2)
	eq(EventSim.phase(w), "warning", "warning first")
	var id := int(EventSim.siege(w)["id"])
	_step(w, int(EventSim.c("siege_warning_seconds", 60)) * Simulation.TICK_RATE)
	eq(EventSim.phase(w), "active", "then the horde comes")
	var horde := 0
	for z in w.zombies.values():
		if z.siege:
			horde += 1
	eq(horde, int(EventSim.c("siege_size", 6)), "a horde of the configured size")
	# Save mid-attack: the horde resumes after loading, without duplicating.
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	var w2: WorldState = res["world"]
	EventSim.resume_after_load(w2)
	EventSim.resume_after_load(w2)
	var again := 0
	for z2 in w2.zombies.values():
		if z2.siege:
			again += 1
	eq(again, horde, "resumed once with the saved remaining count")
	eq(int(EventSim.siege(w2)["id"]), id, "same event, not a new one")
	for z3 in w.zombies.values():
		if z3.siege:
			ZombieSim.damage_zombie(w, z3, 999.0, null, Vector2.ZERO)
	_step(w, 2)
	eq(EventSim.phase(w), "idle", "beaten horde ends the event")
	eq(str(EventSim.siege(w)["outcome"]), "repelled", "outcome recorded")
	check(EventSim.home_heat(w) < float(EventSim.c("siege_threshold", 55)), "home heat drops")
	w.meta["home_heat"] = 99.0
	_step(w, 5)
	eq(EventSim.phase(w), "idle", "cooldown prevents an immediate repeat")


func test_horde_attacks_exposed_structures() -> void:
	var w := WorldState.create_new("w_siege2", 24)
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 3, "scrap_metal": 2}
	var r := Build.request_build(w, PID, "rain_collector", YARD + Vector2(0, -80))
	var oid := str(r["objects"][0][1])
	Simulation.advance(w, 100)
	a.region_id = INTERIOR
	a.position = Vector2(300, 500)
	w.zombies.clear()
	EventSim.start_warning(w, 0.1, [])
	_step(w, 3)
	eq(EventSim.phase(w), "active", "active")
	var o: Dictionary = w.region("homestead").objects[oid]
	for i in 6000:
		Simulation.advance(w, 1)
		if not w.region("homestead").objects.has(oid) or float(o.get("hp", 90)) < 60.0:
			break
	check(not w.region("homestead").objects.has(oid) or float(o["hp"]) < 90.0, "the horde damages the exposed rain collector")


func test_day_night_and_weather_are_shared_and_seeded() -> void:
	var w := WorldState.create_new("w_env", 25)
	eq(EnvSim.daylight(w), 1.0, "starts in daylight")
	var day := float(EnvSim.c("day_seconds", 1440))
	w.tick = int(day * (23.0 - float(EnvSim.c("start_hour", 8.0))) / 24.0 * Simulation.TICK_RATE)
	check(EnvSim.is_night(w), "night at 23:00")
	check(EnvSim.sight_scale(w) < 0.8, "zombies see less at night")
	var w2 := WorldState.create_new("w_env", 25)
	var w3 := WorldState.create_new("w_env", 25)
	var seq2: Array = []
	var seq3: Array = []
	for i in 6:
		w2.tick += 20000
		w3.tick += 20000
		EnvSim.step(w2, 1)
		EnvSim.step(w3, 1)
		seq2.append([EnvSim.weather(w2), w2.env["until"]])
		seq3.append([EnvSim.weather(w3), w3.env["until"]])
	eq(seq2, seq3, "same world, same weather history")
	EnvSim.set_weather(w, "rain")
	check(EnvSim.hearing_scale(w) < 1.0, "rain masks noise")
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	eq(EnvSim.weather(res["world"]), "rain", "weather persists")


func test_rain_fills_collectors_faster() -> void:
	var w := WorldState.create_new("w_rain", 26)
	w.threat.enabled = false
	var a := _player(w, PID, "homestead", YARD)
	a.carried = {"wood": 6, "scrap_metal": 4}
	var o1 := str(Build.request_build(w, PID, "rain_collector", YARD + Vector2(100, -80))["objects"][0][1])
	Simulation.advance(w, 100)
	EnvSim.set_weather(w, "rain")
	w.env["until"] = w.tick + 100000
	Simulation.advance(w, 60 * Simulation.TICK_RATE)
	var wet := int(w.region("homestead").objects[o1].get("stored", 0))
	check(wet >= 2, "rain fills it (%d)" % wet)
	a.position = YARD + Vector2(100, -20)
	var rc := Build.request_object(w, PID, o1, "collect", "")
	check(rc["ok"], "collect: " + str(rc["reason"]))
	eq(a.carrying("water_dirty"), wet, "dirty water collected")


func test_service_station_discovery_and_unique_loot() -> void:
	var w := WorldState.create_new("w_poi", 27)
	w.threat.enabled = false
	var a := _player(w, PID, "homestead", Vector2(2350, 1400))
	var r := WorldActions.request_interact(w, PID, "homestead.road_east", 0)
	check(r["ok"], "road east: " + str(r["reason"]))
	eq(a.region_id, "service_station", "travelled")
	check(w.meta.get("discoveries", {}).has("service_station"), "discovery recorded")
	a.position = Vector2(2000, 570)
	r = WorldActions.request_interact(w, PID, "service_station.tool_locker", 0)
	check(r["ok"], "locker opened: " + str(r["reason"]))
	var items: Array = a.gear.map(func(g): return g["item"])
	check("carburetor" in items and "workshop_manual" in items, "unique finds: " + str(items))
	Simulation.advance(w, 10 * 60 * 60 * Simulation.TICK_RATE)
	eq(WorldActions.request_interact(w, PID, "service_station.tool_locker", 0)["reason"], "ACTION_LOOT_GONE", "never restocks (no duplicates)")
	check(w.meta.get("discoveries", {}).has("workshop_locker"), "find recorded")


func test_carburetor_halves_fuel_use() -> void:
	var w := WorldState.create_new("w_carb", 28)
	w.threat.enabled = false
	var site := Content.entity_position(Content.entity_def(INTERIOR, SITE))
	var a := _player(w, PID, INTERIOR, site + Vector2(0, 40))
	WorldActions.request_interact(w, PID, SITE, 0)
	Simulation.advance(w, 2000)
	a.region_id = LEVEL
	a.position = Content.entity_position(w.region(LEVEL).entity_def("generator")) + Vector2(0, 40)
	eq(WorldActions.request_entity_action(w, PID, "generator", "fit_part", "")["reason"], "ACTION_NEED_PART", "needs the part")
	a.gear.append(Inv.new_gear(w, "carburetor"))
	check(WorldActions.request_entity_action(w, PID, "generator", "fit_part", "")["ok"], "fitted")
	eq(a.gear.size(), 0, "part used")
	var reg := w.region(LEVEL)
	reg.set_fields("generator", {"fuel": 2.0, "running": true})
	Simulation.advance(w, int(InfraSim.c("generator_seconds_per_fuel", 180)) * Simulation.TICK_RATE)
	check(absf(float(reg.entity_state("generator")["fuel"]) - 1.5) < 0.02, "half a unit per period")
