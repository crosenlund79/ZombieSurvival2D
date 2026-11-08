class_name FactionSim
extends RefCounted
## Three factions (iteration 015 F), host-authoritative. Content: content/factions.json
## (written by tools/build_wilderness.py with the places it lays out).
##
##  * The Cinder Crew (hostile): an armed encampment in the Greyhollow Pass. Raiders
##    patrol the camp and open fire on any player they can see within range (hit
##    chance falls with distance; every shot is a loud noise). They can be killed;
##    a dead raider stays dead for `respawn_days` game days. Always hostile.
##  * Hearth Gate (community): a fenced settlement on the Stillwater road — a
##    corrugated fence, a guarded gate, watchtowers, cabins. Its trader buys and
##    sells for credit (persistent shared stock, slow daily restock, prices by
##    reputation), its mechanic repairs gear for credit, its elder gives missions
##    with objectives, rewards and host-side completion checks. Community law:
##    assault, theft from community stores and gunfire inside the fence are crimes
##    — but only if a member sees it (witness radius + line of sight). Graded:
##    a warning, then a fine, then banishment (the gate is barred to you and the
##    guards shoot) for a game day. Strikes fade, one per quiet day.
##  * The Lantern Circle (reputation): a radio shack under the Halden coast mast.
##    Its keeper gives missions; reputation tiers unlock map knowledge and a gift.
##
## Reputation, credit, missions and law standing are PER PLAYER (each player has
## their own standing; the trader's stock is shared). All of it lives in
## world.meta["factions"] and is saved; people themselves are rebuilt from content.

const PATH := "res://content/factions.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"factions": {}, "people": []}
	return _data


static func fdef(fid: String) -> Dictionary:
	return data().get("factions", {}).get(fid, {})


static func pdef(person_id: String) -> Dictionary:
	for p in data().get("people", []):
		if str(p.get("id", "")) == person_id:
			return p
	return {}


static func mission(mid: String) -> Dictionary:
	for fid in data().get("factions", {}):
		for m in fdef(fid).get("missions", []):
			if str(m.get("id", "")) == mid:
				var out: Dictionary = m.duplicate(true)
				out["faction"] = fid
				return out
	return {}


# ------------------------------------------------------------------ persistent state

static func store(world: WorldState) -> Dictionary:
	if not world.meta.has("factions") or not (world.meta["factions"] is Dictionary):
		world.meta["factions"] = {}
	var s: Dictionary = world.meta["factions"]
	for k in ["rep", "credit", "stock", "missions", "law", "dead", "kills", "unlocked"]:
		if not s.has(k) or not (s[k] is Dictionary):
			s[k] = {}
	return s


static func rep(world: WorldState, pid: String, fid: String) -> int:
	var base := int(fdef(fid).get("start_rep", 0))
	return int((store(world)["rep"].get(pid, {}) as Dictionary).get(fid, base))


static func add_rep(world: WorldState, pid: String, fid: String, amount: int) -> int:
	var s := store(world)
	if not s["rep"].has(pid):
		s["rep"][pid] = {}
	var v := clampi(rep(world, pid, fid) + amount, -100, 100)
	s["rep"][pid][fid] = v
	return v


static func credit(world: WorldState, pid: String) -> int:
	return int(store(world)["credit"].get(pid, 0))


static func _add_credit(world: WorldState, pid: String, amount: int) -> void:
	store(world)["credit"][pid] = maxi(0, credit(world, pid) + amount)


## Reputation tier index for a value (tiers: [{"min", "key"}] ascending).
static func tier(fid: String, value: int) -> Dictionary:
	var best := {}
	for t in fdef(fid).get("tiers", []):
		if value >= int(t.get("min", 0)):
			best = t
	return best


static func stock(world: WorldState, fid: String) -> Dictionary:
	var s := store(world)
	if not s["stock"].has(fid):
		s["stock"][fid] = (fdef(fid).get("trader", {}).get("stock", {}) as Dictionary).duplicate()
	return s["stock"][fid]


static func value_of(item: String) -> int:
	var v: Dictionary = data().get("values", {})
	if v.get("items", {}).has(item):
		return int(v["items"][item])
	return int(v.get("categories", {}).get(str(Items.info(item).get("cat", "")), v.get("default", 3)))


## Price the trader asks (buy) / pays (sell) for one, by the player's standing.
static func price(world: WorldState, pid: String, fid: String, item: String, selling: bool) -> int:
	var t: Dictionary = fdef(fid).get("trader", {})
	var r := rep(world, pid, fid)
	var disc := clampf(float(r) / 100.0, -0.5, 0.6) * float(t.get("rep_discount", 0.3))
	if selling:
		return maxi(1, int(round(value_of(item) * float(t.get("sell_rate", 0.5)) * (1.0 + disc))))
	return maxi(1, int(round(value_of(item) * float(t.get("buy_rate", 1.4)) * (1.0 - disc))))


# ------------------------------------------------------------------ people

## Creates the people content asks for (alive ones), at their posts. Host.
static func ensure(world: WorldState) -> int:
	var added := 0
	var dead: Dictionary = store(world)["dead"]
	for d in data().get("people", []):
		var id := str(d.get("id", ""))
		if world.people.has(id) or world.region(str(d.get("region", ""))) == null:
			continue
		if dead.has(id) and world.tick < int(dead[id]):
			continue
		dead.erase(id)
		var p := PersonState.new()
		p.person_id = id
		p.faction = str(d.get("faction", ""))
		p.role = str(d.get("role", "villager"))
		p.region_id = str(d.get("region", ""))
		p.post = Vector2(float(d["post"][0]), float(d["post"][1]))
		p.position = p.post
		p.goal = p.post
		for wp in d.get("patrol", []):
			p.patrol.append(Vector2(float(wp[0]), float(wp[1])))
		p.health = float(d.get("health", 100))
		p.timer = world.make_rng("person:" + id).randf_range(0.5, 4.0)
		world.people[id] = p
		added += 1
	return added


static func hostile_to(world: WorldState, person: PersonState, pid: String) -> bool:
	var f := fdef(person.faction)
	if str(f.get("kind", "")) == "hostile":
		return true
	if person.role == "guard":
		return banished(world, pid, person.faction)
	return false


static func banished(world: WorldState, pid: String, fid: String) -> bool:
	var l: Dictionary = (store(world)["law"].get(pid, {}) as Dictionary).get(fid, {})
	return world.tick < int(l.get("banished_until", 0))


## Host step: people think a few times a second (cheap: a handful of people,
## only in regions someone is in; the rest stand at their posts).
static func step(world: WorldState, ticks: int) -> Array:
	var out: Array = []
	var last := int(world.cooldowns.get("_factions_last", world.tick - 3))
	if world.tick - last < 3:
		return out
	world.cooldowns["_factions_last"] = world.tick
	var dt := float(mini(world.tick - last, 30)) / Simulation.TICK_RATE
	var slow := int(world.cooldowns.get("_factions_slow", 0))
	if world.tick >= slow:
		world.cooldowns["_factions_slow"] = world.tick + int(Simulation.TICK_RATE * 10)
		ensure(world)  # respawns when their time has come
		_law_decay(world)
		_restock(world)
	var occupied := {}
	for pl in world.online_players():
		if not pl.dead:
			occupied[pl.region_id] = true
	var events: Array = []
	for p in world.people.values():
		p.attack_cd = maxf(0.0, p.attack_cd - dt)
		if p.activity == "down" or not occupied.has(p.region_id):
			continue
		_think(world, p, dt, events, out)
	if not events.is_empty():
		var r := WorldActions._ok()
		r["events"] = events
		out.append(r)
	return out


static func _think(world: WorldState, p: PersonState, dt: float, events: Array, out: Array) -> void:
	var d := pdef(p.person_id)
	var w: Dictionary = d.get("weapon", {})
	# a threat in sight?
	var foe: PlayerState = null
	if not w.is_empty() and world.threat.enabled:
		var best := float(w.get("range", 500))
		var grid := NavGrid.for_def(world.region(p.region_id).def_id)
		for pl in world.online_players():
			if pl.region_id != p.region_id or pl.dead or not hostile_to(world, p, pl.player_id):
				continue
			var dist: float = pl.position.distance_to(p.position)
			if dist < best and (grid == null or grid.clear_line(p.position, pl.position, {})):
				best = dist
				foe = pl
	if foe != null:
		p.target = foe.player_id
		p.facing = (foe.position - p.position).normalized()
		if p.activity != "alert" and p.activity != "shoot":
			p.activity = "alert"
			p.timer = float(w.get("aim_seconds", 0.8))
			events.append({"kind": "person_alert", "region_id": p.region_id, "person_id": p.person_id, "x": p.position.x, "y": p.position.y})
			return
		p.timer -= dt
		if p.timer <= 0.0 and p.attack_cd <= 0.0:
			_shoot(world, p, foe, w, events, out)
		return
	if p.activity in ["alert", "shoot"]:
		p.activity = "walk"
		p.goal = p.post
		p.target = ""
	# routine: patrol or idle near the post
	match p.activity:
		"walk":
			var to := p.goal - p.position
			if to.length() < 12.0:
				p.activity = "idle"
				p.timer = world.make_rng("idle:%s:%d" % [p.person_id, world.tick]).randf_range(2.0, 6.0)
			else:
				_move(world, p, to.normalized(), float(d.get("speed", 55)), dt)
		_:
			p.activity = "idle"
			p.timer -= dt
			if p.timer <= 0.0:
				if not p.patrol.is_empty():
					p.patrol_i = (p.patrol_i + 1) % p.patrol.size()
					p.goal = p.patrol[p.patrol_i]
				else:
					var rng := world.make_rng("mill:%s:%d" % [p.person_id, world.tick])
					p.goal = p.post + Vector2(rng.randf_range(-70, 70), rng.randf_range(-40, 40))
				p.activity = "walk"


static func _shoot(world: WorldState, p: PersonState, foe: PlayerState, w: Dictionary, events: Array, out: Array) -> void:
	p.activity = "shoot"
	p.attack_cd = float(w.get("cooldown", 1.8))
	var dist := foe.position.distance_to(p.position)
	var rng := world.make_rng("shot:%s:%d" % [p.person_id, world.tick])
	var chance := float(w.get("accuracy", 0.6)) * (1.0 - 0.6 * clampf(dist / float(w.get("range", 500)), 0.0, 1.0))
	if foe.vehicle_id != "":
		chance *= 0.5
	var hit := rng.randf() < chance
	var end := foe.position + Vector2(0, -30) if hit else foe.position + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 40))
	events.append({"kind": "person_shot", "region_id": p.region_id, "person_id": p.person_id, "x": p.position.x, "y": p.position.y - 30.0,
		"tx": end.x, "ty": end.y, "sound": str(w.get("sound", "sfx.gun_rifle")), "hit": hit})
	ZombieSim.make_noise(world, p.region_id, p.position, "gunshot")
	if hit:
		out.append(ZombieSim.damage_player(world, foe, float(w.get("damage", 9)), p.role))


static func _move(world: WorldState, p: PersonState, dir: Vector2, speed: float, dt: float) -> void:
	var next := p.position + dir * speed * dt
	var r := world.region(p.region_id)
	var grid := NavGrid.for_def(r.def_id) if r != null else null
	if grid != null and grid.is_blocked(grid.to_cell(next), {}):
		p.goal = p.position
		return
	p.position = next
	p.facing = dir


## The person a melee swing or a shot would hit (host).
static func target_for(world: WorldState, pl: PlayerState, aim: Vector2, reach: float, cone: float) -> PersonState:
	var best: PersonState = null
	var bd := INF
	for p in world.people.values():
		if p.region_id != pl.region_id or p.activity == "down":
			continue
		var to: Vector2 = p.position - pl.position
		var dd := to.length()
		if dd > reach or (dd > 30.0 and aim.dot(to / dd) < cone):
			continue
		if dd < bd:
			bd = dd
			best = p
	return best


## A player hurts a person (host). Hostile raiders fight back and can die; hurting
## a community member is assault (community law).
static func damage(world: WorldState, p: PersonState, amount: float, attacker: PlayerState) -> Array:
	if p.health <= 0.0 or not world.people.has(p.person_id):
		return []
	p.health = maxf(0.0, p.health - amount)
	var ev := {"kind": "person_hit", "region_id": p.region_id, "person_id": p.person_id, "x": p.position.x, "y": p.position.y, "amount": amount}
	var out: Array = [ev]
	if attacker != null and str(fdef(p.faction).get("kind", "")) != "hostile":
		out.append_array(crime(world, attacker, p.faction, "assault", p.position))
	if attacker != null:
		p.target = attacker.player_id
	if p.health <= 0.0:
		p.activity = "down"
		ev["kind"] = "person_killed"
		world.people.erase(p.person_id)
		var days := float(fdef(p.faction).get("respawn_days", 2))
		store(world)["dead"][p.person_id] = world.tick + int(days * float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
		if attacker != null:
			var k: Dictionary = store(world)["kills"]
			if not k.has(attacker.player_id):
				k[attacker.player_id] = {}
			k[attacker.player_id][p.faction] = int(k[attacker.player_id].get(p.faction, 0)) + 1
			for fid in data().get("factions", {}):
				var bonus: Dictionary = fdef(str(fid)).get("rep_for_kill", {})
				if bonus.has(p.faction):
					add_rep(world, attacker.player_id, str(fid), int(bonus[p.faction]))
		SessionLog.info("faction", "killed", {"person": p.person_id, "by": attacker.player_id.substr(0, 6) if attacker != null else ""})
	return out


# ------------------------------------------------------------------ community law

## Is `pos` inside faction `fid`'s fence?
static func inside(fid: String, region_id: String, pos: Vector2) -> bool:
	var f := fdef(fid)
	if str(f.get("region", "")) != region_id or not f.has("area"):
		return false
	var a: Array = f["area"]
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3])).has_point(pos)


## Who saw it: a living member of the faction within the witness radius with a clear line.
static func witness(world: WorldState, fid: String, region_id: String, pos: Vector2) -> PersonState:
	var radius := float(fdef(fid).get("law", {}).get("witness_radius", 520))
	var grid := NavGrid.for_def(world.region(region_id).def_id) if world.region(region_id) != null else null
	for p in world.people.values():
		if p.faction != fid or p.region_id != region_id or p.activity == "down":
			continue
		if p.position.distance_to(pos) <= radius and (grid == null or grid.clear_line(p.position, pos, {})):
			return p
	return null


## A crime against a community (host). Unwitnessed crimes have no consequence.
static func crime(world: WorldState, pl: PlayerState, fid: String, kind: String, pos: Vector2) -> Array:
	var f := fdef(fid)
	if str(f.get("kind", "")) != "community":
		return []
	var who := witness(world, fid, pl.region_id, pos)
	SessionLog.info("faction", "crime", {"faction": fid, "kind": kind, "player": pl.player_id.substr(0, 6), "witness": who.person_id if who != null else ""})
	if who == null:
		return []
	var s := store(world)
	if not s["law"].has(pl.player_id):
		s["law"][pl.player_id] = {}
	var l: Dictionary = s["law"][pl.player_id].get(fid, {"strikes": 0})
	l["strikes"] = int(l.get("strikes", 0)) + 1
	l["last"] = world.tick
	var law: Dictionary = f.get("law", {})
	var key := "LAW_WARNING"
	var args: Array = []
	match int(l["strikes"]):
		1:
			add_rep(world, pl.player_id, fid, -int(law.get("warning_rep", 5)))
		2:
			var fine := int(law.get("fine", 20))
			args = [fine]
			key = "LAW_FINE"
			if credit(world, pl.player_id) >= fine:
				_add_credit(world, pl.player_id, -fine)
			else:
				add_rep(world, pl.player_id, fid, -int(law.get("fine_rep", 10)))
			add_rep(world, pl.player_id, fid, -int(law.get("fine_rep", 10)))
		_:
			key = "LAW_BANISHED"
			add_rep(world, pl.player_id, fid, -int(law.get("banish_rep", 30)))
			l["banished_until"] = world.tick + int(float(law.get("banish_days", 1)) * float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	s["law"][pl.player_id][fid] = l
	var r := WorldActions._ok()
	r["players"] = [pl.player_id]
	r["private_notice"] = {"player_id": pl.player_id, "key": key, "args": args}
	r["events"] = [{"kind": "law", "region_id": pl.region_id, "person_id": who.person_id, "player_id": pl.player_id, "crime": kind, "strikes": l["strikes"]}]
	r["meta"] = true
	return [r]


## A gunshot by a player: inside a community fence it is a crime (Firearms).
static func noted_gunfire(world: WorldState, pl: PlayerState) -> Array:
	for fid in data().get("factions", {}):
		if inside(str(fid), pl.region_id, pl.position):
			return crime(world, pl, str(fid), "gunfire", pl.position)
	return []


## Taking from a container that belongs to a community (ScavengeSim): theft.
static func noted_take(world: WorldState, pl: PlayerState, def: Dictionary) -> Array:
	var owner := str(def.get("owner", ""))
	if owner == "":
		return []
	return crime(world, pl, owner, "theft", pl.position)  # seen where the thief stands


## May this player open the community gate?
static func gate_denied(world: WorldState, pl: PlayerState, def: Dictionary) -> bool:
	var fid := str(def.get("gate_of", ""))
	return fid != "" and banished(world, pl.player_id, fid)


static func _law_decay(world: WorldState) -> void:
	var day := int(float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	for pid in store(world)["law"]:
		for fid in store(world)["law"][pid]:
			var l: Dictionary = store(world)["law"][pid][fid]
			if int(l.get("strikes", 0)) > 0 and world.tick - int(l.get("last", 0)) > day and world.tick >= int(l.get("banished_until", 0)):
				l["strikes"] = int(l["strikes"]) - 1
				l["last"] = world.tick


static func _restock(world: WorldState) -> void:
	var day := int(float(EnvSim.c("day_seconds", 1440)) * Simulation.TICK_RATE)
	var s := store(world)
	for fid in data().get("factions", {}):
		var t: Dictionary = fdef(str(fid)).get("trader", {})
		if t.is_empty():
			continue
		var last := int(s["stock"].get("_restocked_" + str(fid), 0))
		if world.tick - last < day:
			continue
		s["stock"]["_restocked_" + str(fid)] = world.tick
		var st := stock(world, str(fid))
		var base: Dictionary = t.get("stock", {})
		for item in base:  # one of each back toward the base stock, never above it
			if int(st.get(item, 0)) < int(base[item]):
				st[item] = int(st.get(item, 0)) + 1


# ------------------------------------------------------------------ requests (host)

static func request(world: WorldState, pid: String, person_id: String, action: String, arg: String) -> Dictionary:
	var pl: PlayerState = world.players.get(pid)
	if pl == null or pl.dead or not pl.online:
		return WorldActions._fail("ACTION_UNKNOWN_PLAYER")
	var p: PersonState = world.people.get(person_id)
	if p == null or p.region_id != pl.region_id or p.activity == "down":
		return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
	if hostile_to(world, p, pid):
		return WorldActions._fail("FACTION_WONT_TALK")
	if p.position.distance_to(pl.position) > 190.0:
		return WorldActions._fail("ACTION_TOO_FAR")
	var fid := p.faction
	if rep(world, pid, fid) <= -60:
		return WorldActions._fail("FACTION_WONT_TALK")
	var res := WorldActions._ok()
	res["players"] = [pid]
	res["meta"] = true
	match action:
		"sell":
			if p.role != "trader":
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var item := arg
			var uid := ""
			for g in pl.gear:
				if str(g.get("uid", "")) == arg:
					item = str(g.get("item", ""))
					uid = arg
			if uid == "" and pl.carrying(item) <= 0:
				return WorldActions._fail("ACTION_NOTHING_THERE")
			if uid != "":
				for i in pl.gear.size():
					if str(pl.gear[i].get("uid", "")) == uid:
						pl.gear.remove_at(i)
						break
				Inv.unequip_uid(pl, uid)
			else:
				Items.move(pl.carried, {}, item, 1)
			var gain := price(world, pid, fid, item, true)
			_add_credit(world, pid, gain)
			var st := stock(world, fid)
			st[item] = int(st.get(item, 0)) + 1
			res["vitals"] = [pid]
			res["private_notice"] = {"player_id": pid, "key": "TRADE_SOLD", "args": [TranslationServer.translate(Items.name_key(item)), gain]}
		"buy":
			if p.role != "trader":
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var st2 := stock(world, fid)
			if int(st2.get(arg, 0)) <= 0:
				return WorldActions._fail("TRADE_OUT_OF_STOCK")
			var cost := price(world, pid, fid, arg, false)
			if credit(world, pid) < cost:
				return WorldActions._fail("TRADE_NOT_ENOUGH", [cost])
			if Inv.free_slots(pl) <= 0 and (not Items.is_stack(arg) or Inv.room_for(pl, arg) <= 0):
				return WorldActions._fail("ACTION_CARRY_FULL", [Items.carry_slots()])
			st2[arg] = int(st2[arg]) - 1
			_add_credit(world, pid, -cost)
			if Items.is_stack(arg):
				pl.carried[arg] = pl.carrying(arg) + 1
			else:
				pl.gear.append(Inv.new_gear(world, arg))
			res["vitals"] = [pid]
			res["private_notice"] = {"player_id": pid, "key": "TRADE_BOUGHT", "args": [TranslationServer.translate(Items.name_key(arg)), cost]}
		"repair":
			if p.role != "mechanic":
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var g := {}
			for gg in pl.gear:
				if str(gg.get("uid", "")) == arg:
					g = gg
			if g.is_empty() or not Items.info(str(g["item"])).has("durability"):
				return WorldActions._fail("ACTION_NOTHING_THERE")
			var top := float(Items.info(str(g["item"]))["durability"])
			var cost2 := repair_cost(world, pid, fid, g)
			if cost2 <= 0:
				return WorldActions._fail("REPAIR_NOT_NEEDED")
			if credit(world, pid) < cost2:
				return WorldActions._fail("TRADE_NOT_ENOUGH", [cost2])
			_add_credit(world, pid, -cost2)
			g["cond"] = top
			res["vitals"] = [pid]
			res["private_notice"] = {"player_id": pid, "key": "REPAIR_DONE", "args": [TranslationServer.translate(Items.name_key(str(g["item"]))), cost2]}
		"accept":
			var m := mission(arg)
			if m.is_empty() or str(m["faction"]) != fid or not (p.role in ["elder", "contact"]):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if mission_state(world, pid, arg) != "":
				return WorldActions._fail("MISSION_ALREADY")
			if rep(world, pid, fid) < int(m.get("min_rep", -100)):
				return WorldActions._fail("MISSION_LOCKED")
			_missions_of(world, pid)[arg] = {"state": "active", "started": world.tick,
				"kills_at": int((store(world)["kills"].get(pid, {}) as Dictionary).get(str(m.get("target", "")), 0))}
			res["private_notice"] = {"player_id": pid, "key": "MISSION_ACCEPTED", "args": [TranslationServer.translate(str(m.get("title_key", "")))]}
		"turn_in":
			var m2 := mission(arg)
			if m2.is_empty() or mission_state(world, pid, arg) != "active" or str(m2["faction"]) != fid:
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if not complete(world, pid, arg):
				return WorldActions._fail("MISSION_NOT_DONE")
			if str(m2.get("kind", "")) == "deliver":
				Items.move(pl.carried, {}, str(m2["item"]), int(m2.get("qty", 1)))
			var rw: Dictionary = m2.get("reward", {})
			_add_credit(world, pid, int(rw.get("credit", 0)))
			add_rep(world, pid, fid, int(rw.get("rep", 0)))
			for item in rw.get("items", {}):
				if Items.is_stack(str(item)):
					pl.carried[item] = pl.carrying(str(item)) + int(rw["items"][item])
				else:
					for k in int(rw["items"][item]):
						pl.gear.append(Inv.new_gear(world, str(item)))
			_missions_of(world, pid)[arg]["state"] = "done"
			res["vitals"] = [pid]
			res["private_notice"] = {"player_id": pid, "key": "MISSION_DONE", "args": [TranslationServer.translate(str(m2.get("title_key", "")))]}
			res["events"] = [{"kind": "mission_done", "player_id": pid, "mission": arg, "faction": fid}]
			_unlocks(world, pid, fid, res)
		_:
			return WorldActions._fail("ACTION_NOT_SUPPORTED")
	SessionLog.info("faction", action, {"person": person_id, "arg": arg, "player": pid.substr(0, 6)})
	return res


static func repair_cost(world: WorldState, pid: String, fid: String, g: Dictionary) -> int:
	var info := Items.info(str(g.get("item", "")))
	if not info.has("durability"):
		return 0
	var top := float(info["durability"])
	var worn := 1.0 - clampf(float(g.get("cond", top)) / top, 0.0, 1.0)
	if worn < 0.02:
		return 0
	var r: Dictionary = fdef(fid).get("repair", {})
	var disc := clampf(float(rep(world, pid, fid)) / 100.0, -0.5, 0.6) * 0.3
	return maxi(1, int(ceil((float(r.get("base", 2)) + value_of(str(g["item"])) * float(r.get("rate", 0.6)) * worn) * (1.0 - disc))))


static func _missions_of(world: WorldState, pid: String) -> Dictionary:
	var s := store(world)
	if not s["missions"].has(pid):
		s["missions"][pid] = {}
	return s["missions"][pid]


static func mission_state(world: WorldState, pid: String, mid: String) -> String:
	return str((store(world)["missions"].get(pid, {}) as Dictionary).get(mid, {}).get("state", ""))


## Objective progress [have, need] for an active mission (host and clients — the
## data is replicated with world meta).
static func progress(world: WorldState, pid: String, mid: String) -> Array:
	var m := mission(mid)
	var pl: PlayerState = world.players.get(pid)
	var need := int(m.get("qty", m.get("count", 1)))
	match str(m.get("kind", "")):
		"deliver":
			return [mini(pl.carrying(str(m["item"])) if pl != null else 0, need), need]
		"kill":
			var st: Dictionary = (store(world)["missions"].get(pid, {}) as Dictionary).get(mid, {})
			var now := int((store(world)["kills"].get(pid, {}) as Dictionary).get(str(m.get("target", "")), 0))
			return [mini(now - int(st.get("kills_at", 0)), need), need]
		"visit":
			var keys = world.meta.get("discoveries", {})
			return [1 if (keys is Dictionary or keys is Array) and keys.has(str(m.get("discovery", ""))) else 0, 1]
	return [0, need]


static func complete(world: WorldState, pid: String, mid: String) -> bool:
	var pr := progress(world, pid, mid)
	return int(pr[0]) >= int(pr[1])


## Reputation tiers that unlock something (once per player).
static func _unlocks(world: WorldState, pid: String, fid: String, res: Dictionary) -> void:
	var s := store(world)
	if not s["unlocked"].has(pid):
		s["unlocked"][pid] = {}
	var pl: PlayerState = world.players[pid]
	for t in fdef(fid).get("tiers", []):
		var key := fid + ":" + str(t.get("key", ""))
		if rep(world, pid, fid) < int(t.get("min", 0)) or s["unlocked"][pid].has(key):
			continue
		var u: Dictionary = t.get("unlock", {})
		if u.is_empty():
			continue
		s["unlocked"][pid][key] = world.tick
		for disc in u.get("discoveries", []):
			WorldActions.discover(world, str(disc))
		for item in u.get("items", {}):
			if Items.is_stack(str(item)):
				pl.carried[item] = pl.carrying(str(item)) + int(u["items"][item])
			else:
				pl.gear.append(Inv.new_gear(world, str(item)))
		res["private_notice"] = {"player_id": pid, "key": str(u.get("notice", "FACTION_TIER_UP")), "args": [TranslationServer.translate(str(t.get("key", "")))]}


# ------------------------------------------------------------------ replication

static func rows(world: WorldState) -> Array:
	var out := []
	for p in world.people.values():
		out.append(p.row())
	return out


static func apply_rows(world: WorldState, rows_in: Array) -> void:
	var seen := {}
	for row in rows_in:
		var id := str(row[0])
		seen[id] = true
		var p: PersonState = world.people.get(id)
		if p == null:
			p = PersonState.new()
			p.person_id = id
			world.people[id] = p
		p.faction = str(row[1])
		p.role = str(row[2])
		p.region_id = str(row[3])
		p.position = Vector2(float(row[4]), float(row[5]))
		p.facing = Vector2(float(row[6]), float(row[7]))
		p.activity = str(row[8])
		p.health = float(row[9])
	for id in world.people.keys():
		if not seen.has(id):
			world.people.erase(id)
