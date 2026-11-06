extends TestCase
## Iteration 011 "The World Awakens": Burnt One hearing, screeches, alert
## limits and posture; later milestones add their own tests below.

const PID := "aaaaaaaaaaaaaaaa"
const PID2 := "bbbbbbbbbbbbbbbb"


func _player(w: WorldState, id: String, region: String, pos: Vector2) -> PlayerState:
	var p := PlayerState.new()
	p.player_id = id
	p.region_id = region
	p.position = pos
	p.online = true
	w.players[id] = p
	return p


func _z(w: WorldState, pos: Vector2, facing := Vector2.LEFT) -> ZombieState:
	var z := ZombieSim.spawn(w, "homestead", pos, false)
	z.facing = facing
	return z


func _run(w: WorldState, seconds: float) -> Array:
	var out: Array = []
	for i in int(seconds * Simulation.TICK_RATE):
		w.tick += 1
		out.append_array(ZombieSim.step(w, 1))
	return out


func _screeches(results: Array) -> Array:
	var s: Array = []
	for r in results:
		for ev in r.get("events", []):
			if str(ev.get("kind", "")) == "screech":
				s.append(ev)
	return s


func test_loud_noise_listen_then_screech_then_investigate() -> void:
	var w := WorldState.create_new("w_scr", 41)
	_player(w, PID, "homestead", Vector2(1150, 1300))
	var z := _z(w, Vector2(400, 1250))
	ZombieSim.make_noise(w, "homestead", Vector2(650, 1250), "fell")
	var r := _run(w, 0.2)
	eq(z.state_name(), "LISTEN", "it stops and listens")
	check(z.facing.dot((Vector2(650, 1250) - z.position).normalized()) > 0.0, "it turns toward the sound")
	r.append_array(_run(w, 2.0))
	eq(_screeches(r).size(), 1, "a significant disturbance makes it screech once")
	eq(z.state_name(), "INVESTIGATE", "then it goes to look")
	eq(z.target_player, "", "hearing never reveals the player")


func test_small_noise_no_screech() -> void:
	var w := WorldState.create_new("w_scr2", 42)
	_player(w, PID, "homestead", Vector2(1150, 1300))
	var z := _z(w, Vector2(400, 1250))
	ZombieSim.make_noise(w, "homestead", Vector2(500, 1250), "run")
	var r := _run(w, 3.0)
	eq(_screeches(r).size(), 0, "a tiny noise does not trigger a screech")
	check(z.state_name() in ["INVESTIGATE", "WANDER"], "at most it wanders over to look")


func test_screech_draws_few_and_never_chains() -> void:
	var w := WorldState.create_new("w_scr3", 43)
	_player(w, PID, "homestead", Vector2(2300, 1650))
	var caller := _z(w, Vector2(1000, 1000))
	var others: Array = []
	for i in 6:
		others.append(_z(w, Vector2(1000 + 70 * (i + 1), 1050)))
	var ev := ZombieSim.screech(w, caller)
	check(not ev.is_empty(), "the screech happens")
	var r := _run(w, 0.3)
	var drawn := others.filter(func(o): return o.state_name() == "INVESTIGATE")
	eq(drawn.size(), 3, "only the nearest three respond (response limit)")
	r.append_array(_run(w, 6.0))
	eq(_screeches(r).size(), 0, "responders never screech back (no chains)")
	check(ZombieSim.screech(w, caller).is_empty(), "the caller is on cooldown")
	var other: ZombieState = others[5]
	check(ZombieSim.screech(w, other).is_empty(), "a region-wide cooldown keeps silence the norm")


func test_postures_and_individual_temperament() -> void:
	var w := WorldState.create_new("w_post", 44)
	var p := _player(w, PID, "homestead", Vector2(1150, 1300))
	var seen := {}
	var bursts := 0
	var zs: Array = []
	for i in 6:
		var z := _z(w, Vector2(900 + i * 40, 1300), Vector2.RIGHT)
		z.ai = ZombieState.AI.CHASE
		z.target_player = PID
		zs.append(z)
	for t in 400:
		w.tick += 1
		ZombieSim.step(w, 1)
		p.position = Vector2(1150 + 600 * sin(t * 0.02), 1300)
		for z in zs:
			seen[z.posture] = true
			if z.burst > 0.0:
				bursts += 1
	check(seen.has(ZombieState.Posture.UPRIGHT), "they run upright")
	check(seen.has(ZombieState.Posture.CRAWL), "and drop to all fours")
	check(bursts > 0, "crawling bursts happen during pursuit")
	var temps := {}
	for z in zs:
		temps[snappedf(z.temperament().x, 0.01)] = true
	check(temps.size() >= 3, "individuals differ in pace (temperament)")


func test_lost_target_searches_ahead_then_around() -> void:
	var w := WorldState.create_new("w_search", 45)
	_player(w, PID, "homestead.farmhouse", Vector2(300, 480))
	var z := _z(w, Vector2(1000, 1100))
	z.ai = ZombieState.AI.CHASE
	z.target_player = PID
	z.last_known = Vector2(1150, 1000)
	z.last_dir = Vector2.RIGHT
	_run(w, 0.2)
	eq(z.state_name(), "INVESTIGATE", "target inside the cabin: it never follows, it searches")
	check(z.region_id == "homestead", "it stays outside")
