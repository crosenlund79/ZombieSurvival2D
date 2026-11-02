extends TestCase
## Iteration 003 milestone A: zombies, noise, attention, hordes, combat.

const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"


func _world() -> WorldState:
	var w := WorldState.create_new("w_threat", 3)
	return w


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _zombie(w: WorldState, pos: Vector2, facing: Vector2 = Vector2.DOWN, persistent: bool = true) -> ZombieState:
	var z := ZombieSim.spawn(w, "homestead", pos, persistent)
	z.facing = facing
	return z


func test_navgrid_blocks_farmhouse_and_finds_path_around() -> void:
	var g := NavGrid.for_def("homestead")
	check(g.is_blocked(g.to_cell(Vector2(1150, 600)), {}), "farmhouse footprint is blocked")
	check(not g.is_blocked(g.to_cell(Vector2(1150, 1100)), {}), "driveway is open")
	check(not g.clear_line(Vector2(1150, 450), Vector2(1150, 720), {}), "no line of sight through the house")
	var path := g.find_path(Vector2(1150, 450), Vector2(1150, 720), {})
	check(path.size() >= 2, "path around the house found")


func test_sight_needs_cone_and_line_of_sight() -> void:
	var w := _world()
	_player(w, PID, "homestead", Vector2(600, 1100))
	var z := _zombie(w, Vector2(600, 900), Vector2.DOWN)
	ZombieSim.step(w, 1)
	eq(z.state_name(), "CHASE", "player in front within range is seen")
	var w2 := _world()
	_player(w2, PID, "homestead", Vector2(600, 1100))
	var z2 := _zombie(w2, Vector2(600, 900), Vector2.UP)
	ZombieSim.step(w2, 1)
	check(z2.state_name() != "CHASE", "player behind (outside cone, beyond all-round range) not seen")
	var w3 := _world()
	_player(w3, PID, "homestead", Vector2(1150, 450))
	var z3 := _zombie(w3, Vector2(1150, 720), Vector2.UP)
	ZombieSim.step(w3, 1)
	check(z3.state_name() != "CHASE", "no sight through the farmhouse")


func test_noise_sends_zombies_to_the_location_not_the_player() -> void:
	var w := _world()
	_player(w, PID, "homestead", Vector2(1150, 1250))
	var near := _zombie(w, Vector2(400, 1250), Vector2.LEFT)
	var far := _zombie(w, Vector2(2300, 300), Vector2.LEFT)
	ZombieSim.make_noise(w, "homestead", Vector2(700, 1250), "chop")
	ZombieSim.step(w, 1)
	eq(near.state_name(), "INVESTIGATE", "zombie in earshot investigates")
	check(near.last_known.distance_to(Vector2(700, 1250)) < 1.0, "it heads for the noise location")
	eq(near.target_player, "", "hearing does not reveal who made the noise")
	eq(far.state_name(), "WANDER", "zombie out of earshot keeps wandering")


func test_attention_grows_and_decays() -> void:
	var w := _world()
	for i in 4:
		ZombieSim.make_noise(w, "homestead", Vector2(700, 700), "chop")
	ZombieSim.step(w, 1)
	var a1 := w.threat.attention_at("homestead", Vector2(700, 700))
	check(a1 > 3.5, "repeated chopping builds attention (%.2f)" % a1)
	ZombieSim.step(w, 10)
	Simulation.advance(w, 600)  # one minute of quiet
	var a2 := w.threat.attention_at("homestead", Vector2(700, 700))
	check(a2 < a1 * 0.25, "attention decays when it is quiet (%.2f -> %.2f)" % [a1, a2])


func test_escalation_recruits_then_reinforces_within_limits() -> void:
	var w := _world()
	_player(w, PID, "homestead", Vector2(1200, 1000))
	var idle := _zombie(w, Vector2(1200, 300), Vector2.UP)
	w.threat.zones[ThreatState.zone_key("homestead", Vector2(1200, 1000))] = 4.0
	ZombieSim.step(w, 1)
	eq(idle.state_name(), "INVESTIGATE", "idle zombie nearby recruited first")
	var transient := 0
	for z in w.zombies.values():
		if not z.persistent:
			transient += 1
			check(z.position.distance_to(Vector2(1200, 1000)) >= 700.0, "reinforcement enters far from the player")
	check(transient >= 1, "reinforcements arrive when nearby zombies are not enough")
	# Hammer the zone for a long time: never more than the configured caps.
	for i in 300:
		w.threat.zones[ThreatState.zone_key("homestead", Vector2(1200, 1000))] = 20.0
		ZombieSim.step(w, 1)
	var t2 := 0
	for z in w.zombies.values():
		if not z.persistent:
			t2 += 1
	check(t2 <= int(ZombieSim.c("max_reinforcements", 8)), "reinforcement cap respected (%d)" % t2)
	check(w.zombies.size() <= int(ZombieSim.c("max_active", 16)) + 1, "active cap respected")


func _arm(w: WorldState, p: PlayerState, item: String) -> void:
	var g := Inv.new_gear(w, item)
	p.gear.append(g)
	p.equipped["hand"] = g["uid"]


func test_player_attack_damages_and_kills_with_cooldown() -> void:
	var w := _world()
	var p := _player(w, PID, "homestead", Vector2(600, 1100))
	_arm(w, p, "club")
	var z := _zombie(w, Vector2(640, 1100), Vector2.LEFT)
	var r := WorldActions.request_attack(w, PID, Vector2.RIGHT)
	check(r["ok"], "swing ok")
	check(z.health < 100.0, "zombie damaged by club")
	eq(WorldActions.request_attack(w, PID, Vector2.RIGHT)["reason"], "ACTION_TOO_FAST", "cooldown enforced")
	var hits := 1
	while not z.is_dead() and hits < 10:
		w.tick += 10
		z.position = Vector2(640, 1100)
		WorldActions.request_attack(w, PID, Vector2.RIGHT)
		hits += 1
	check(z.is_dead(), "zombie dies")
	eq(hits, 3, "three club hits kill a zombie")
	var z2 := _zombie(w, Vector2(600, 1060), Vector2.LEFT)
	w.tick += 10
	WorldActions.request_attack(w, PID, Vector2.DOWN)
	eq(z2.health, 100.0, "no hit outside the swing arc")


func test_no_attacks_through_walls() -> void:
	var w := _world()
	var p := _player(w, PID, "homestead", Vector2(830, 925))
	_arm(w, p, "club")
	var z := _zombie(w, Vector2(860, 860))  # behind the yard fence
	WorldActions.request_attack(w, PID, (z.position - p.position).normalized())
	eq(z.health, 100.0, "fence blocks the swing")


func test_zombie_attack_windup_damage_and_respawn() -> void:
	var w := _world()
	var p := _player(w, PID, "homestead", Vector2(600, 1100))
	var z := _zombie(w, Vector2(600, 1070), Vector2.DOWN)
	ZombieSim.step(w, 1)
	eq(z.state_name(), "WINDUP", "close zombie winds up first (readable warning)")
	eq(p.health, 100.0, "no damage before the wind-up ends")
	Simulation.advance(w, int(float(ZombieSim.c("attack_windup", 0.7)) * Simulation.TICK_RATE) + 2)
	check(p.health < 100.0, "damage after the wind-up")
	p.health = 1.0
	z.attack_cooldown = 0.0
	z.ai = ZombieState.AI.CHASE
	Simulation.advance(w, 20)
	check(p.dead, "player defeated")
	Simulation.advance(w, int(SurvivalSim.RESPAWN_SECONDS * Simulation.TICK_RATE) + 2)
	check(not p.dead and p.region_id == SurvivalSim.RESPAWN_REGION, "respawned inside the farmhouse")
	eq(p.health, SurvivalSim.RESPAWN_HEALTH, "respawn health")


func test_farmhouse_boundary() -> void:
	var w := _world()
	var p := _player(w, PID, "homestead", Vector2(1160, 700))
	var z := _zombie(w, Vector2(1160, 820), Vector2.UP)
	ZombieSim.step(w, 1)
	eq(z.state_name(), "CHASE", "chasing at the door")
	p.region_id = "homestead.farmhouse"
	p.position = Vector2(480, 560)
	Simulation.advance(w, 50)
	check(z.state_name() != "CHASE" and z.target_player == "", "target lost when the player goes inside")
	eq(z.region_id, "homestead", "zombie never leaves the surface region")
	var g := NavGrid.for_def("homestead")
	check(not g.is_blocked(g.to_cell(z.position), {}), "zombie stays on walkable ground (outside the house)")
	var r := WorldActions.request_attack(w, PID, Vector2.DOWN)
	check(r["events"].size() == 1, "no hits on zombies from inside the house")


func test_persistence_policy() -> void:
	var w := _world()
	var base := _zombie(w, Vector2(300, 600), Vector2.DOWN, true)
	base.health = 55.0
	_zombie(w, Vector2(400, 600), Vector2.DOWN, false)
	w.threat.zones["homestead|1|1"] = 5.0
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(w))))
	check(res["ok"], "decodes")
	var w2: WorldState = res["world"]
	eq(w2.zombies.size(), 1, "only the persistent zombie is saved")
	eq((w2.zombies.values()[0] as ZombieState).health, 55.0, "its health is kept")
	eq(w2.threat.zones.size(), 0, "attention is not saved (world reloads calm)")
	eq(w2.next_zombie, w.next_zombie, "id counter kept (no id reuse)")


func test_base_population_topped_up_away_from_players() -> void:
	var w := _world()
	_player(w, PID, "homestead", Vector2(1150, 1000))
	ZombieSim.ensure_population(w)
	var want := int(w.region_def("homestead")["zombies"]["base_population"])
	var home := w.zombies.values().filter(func(z): return z.region_id == "homestead")
	eq(home.size(), want, "base population created")
	for z in home:
		check(z.position.distance_to(Vector2(1150, 1000)) >= 700.0, "spawned far from the player")
	eq(ZombieSim.ensure_population(w), 0, "no duplicates when topped up again")
