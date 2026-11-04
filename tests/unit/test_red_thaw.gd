extends TestCase
## Iteration 010 (Red Thaw): the opening kit, items, threats off by default,
## developer Burnt One hunts and the deterministic atmospheric omens.

const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"
const BAG := "homestead.starter_bag"


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _step(w: WorldState, seconds: float) -> void:
	for i in int(seconds * Simulation.TICK_RATE):
		w.tick += 1
		ZombieSim.step(w, 1)


func test_new_players_start_by_the_burned_shed_beside_the_bag() -> void:
	var bag := Content.entity_position(Content.entity_def("homestead", BAG))
	for sp in Content.region_def("homestead").get("spawn_points", []):
		check(Vector2(float(sp[0]), float(sp[1])).distance_to(bag) <= 80.0, "every spawn point is within reach of the bag")


func test_starter_bag_gives_each_player_one_kit_once() -> void:
	var w := WorldState.create_new("w_bag", 5)
	var bag := Content.entity_position(Content.entity_def("homestead", BAG))
	var a := _player(w, PID, "homestead", bag + Vector2(10, 20))
	var b := _player(w, PID2, "homestead", bag + Vector2(-10, 20))
	var r := WorldActions.request_interact(w, PID, BAG, 0)
	check(r["ok"], "first player takes the kit")
	eq(a.carrying("water_bottle"), 1, "large bottle of water")
	eq(a.carrying("crackers"), 1, "crackers")
	eq(a.gear.filter(func(g): return g["item"] == "field_map").size(), 1, "a field map")
	var again := WorldActions.request_interact(w, PID, BAG, w.region("homestead").rev(BAG))
	check(not again["ok"], "the same player cannot take a second kit")
	eq(a.carrying("water_bottle"), 1, "no duplicate water")
	var rb := WorldActions.request_interact(w, PID2, BAG, w.region("homestead").rev(BAG))
	check(rb["ok"], "a second (or joining) player gets their own kit")
	eq(b.carrying("crackers"), 1, "second player's crackers")
	# saved and loaded: claims persist, no kit is handed out twice after a reload
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	eq((w2.region("homestead").entity_state(BAG).get("taken_by", []) as Array).size(), 2, "both claims saved")
	var a2 := _player(w2, PID, "homestead", bag + Vector2(10, 20))
	a2.carried = {}
	check(not WorldActions.request_interact(w2, PID, BAG, w2.region("homestead").rev(BAG))["ok"], "still refused after reload")


func test_kit_items_work_with_the_survival_systems() -> void:
	var w := WorldState.create_new("w_kit", 6)
	var p := _player(w, PID, "homestead", Vector2(400, 1130))
	p.carried = {"water_bottle": 1, "crackers": 1}
	p.gear.append(Inv.new_gear(w, "field_map"))
	p.hydration = 20.0
	p.hunger = 30.0
	check(WorldActions.request_drink(w, PID)["ok"], "the drink key drinks from the bottle when there is no clean water")
	eq(p.hydration, 90.0, "a long drink (+70)")
	eq(p.carrying("water_bottle"), 0, "bottle used")
	check(Inv.request(w, PID, "use", "crackers")["ok"], "crackers can be eaten")
	eq(p.hunger, 55.0, "+25 food")
	var uid := str(p.gear[0]["uid"])
	check(Inv.request(w, PID, "use", uid)["ok"], "reading the map is allowed")
	eq(p.gear.size(), 1, "the map is not used up")


func test_no_automatic_threats_by_default() -> void:
	var w := WorldState.create_new("w_quiet", 7)
	_player(w, PID, "homestead", Vector2(400, 1130))
	check(not w.threat.ambient, "automatic threats are off by default")
	eq(ZombieSim.ensure_population(w), 0, "no base population")
	w.tick = int(EventSim.c("first_siege_after_minutes", 15)) * 60 * Simulation.TICK_RATE + 10
	w.meta["home_heat"] = 99.0
	for i in 50:
		w.tick += 1
		EventSim.step(w, 1)
	eq(str(EventSim.siege(w).get("phase", "idle")), "idle", "high heat does not start an attack on its own")
	for i in 30:
		ZombieSim.make_noise(w, "homestead", Vector2(1150, 760), "fell")
	_step(w, 6.0)
	eq(w.zombies.size(), 0, "noise alone does not spawn anyone")


func test_developer_hunt_pursues_and_attacks() -> void:
	var w := WorldState.create_new("w_hunt", 8)
	var p := _player(w, PID, "homestead", Vector2(1150, 1060))
	var res := ZombieSim.start_hunt(w, PID)
	check(res["ok"], "hunt starts")
	var z: ZombieState = w.zombies[res["zombie_id"]]
	check(z.hunter, "it is a hunter")
	check(z.position.distance_to(p.position) >= 480.0, "it starts out of sight, away from the player")
	var d0 := z.position.distance_to(p.position)
	_step(w, 8.0)
	check(z.position.distance_to(p.position) < d0 - 150.0, "it closes in on the player")
	var hp := p.health
	_step(w, 25.0)
	check(p.health < hp or p.dead, "it reaches and attacks the player")
	var lines := ZombieSim.hunt_lines(w)
	eq(lines.size(), 1, "diagnostics list the hunt")


func test_hunt_is_refused_indoors_and_ends() -> void:
	var w := WorldState.create_new("w_hunt2", 9)
	_player(w, PID, "homestead_farmhouse", Vector2(300, 480))
	var r := ZombieSim.start_hunt(w, PID)
	check(not r["ok"], "no hunt inside the cabin (protected shelter boundary)")
	eq(str(r["reason"]), "HUNT_TARGET_SHELTERED", "clear reason")
	var p := w.players[PID] as PlayerState
	p.region_id = "homestead"
	p.position = Vector2(400, 1130)
	var r2 := ZombieSim.start_hunt(w, PID)
	check(r2["ok"], "outside it works")
	var z: ZombieState = w.zombies[r2["zombie_id"]]
	p.region_id = "homestead_farmhouse"  # player goes inside: it can never follow
	_step(w, 5.0)
	eq(z.region_id, "homestead", "the hunter stays outside")
	check(z.target_player == "" or z.target_player == PID and z.ai != ZombieState.AI.WINDUP, "no attack through the boundary")
	w.tick = z.hunt_until
	_step(w, 0.2)
	check(not z.hunter and z.leaving, "after hunt_seconds it gives up and leaves")
	var saved := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	eq((saved["world"] as WorldState).zombies.size(), 0, "hunters are transient (never saved)")


func test_omens_are_deterministic_and_follow_day_and_night() -> void:
	var w := WorldState.create_new("w_omen", 1234)
	var w2 := WorldState.create_new("w_omen_b", 1234)
	var laughs := 0
	var shadows := 0
	var slots := 400
	for s in slots:
		var a := OmenSim.laugh(w, "service_station", s)
		if s < 3:
			eq(a, OmenSim.laugh(w2, "service_station", s), "same seed, same laugh (slot %d)" % s)
		if not a.is_empty():
			laughs += 1
			check(EnvSim.daylight_at(w, int(a["tick"])) >= 0.55, "laughter only by day")
		var sh := OmenSim.shadow(w, "service_station", s)
		if not sh.is_empty():
			shadows += 1
			check(EnvSim.daylight_at(w, int(sh["tick"])) <= 0.25, "shadows only at night")
	check(laughs > 10 and laughs < slots / 2, "laughter is occasional, not constant (%d of %d)" % [laughs, slots])
	check(shadows > 3 and shadows < slots / 3, "shadows are infrequent (%d of %d)" % [shadows, slots])
	var w3 := WorldState.create_new("w_omen_c", 99)
	var differ := false
	for s in 40:
		if OmenSim.laugh(w3, "service_station", s) != OmenSim.laugh(w, "service_station", s):
			differ = true
	check(differ, "another world seed gives a different schedule")
	eq(OmenSim.laugh(w, "homestead", 5), {}, "no laughter where no laugh spots are authored")
