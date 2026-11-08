class_name Firearms
extends RefCounted
## Shared firearms framework (iteration 014). Host-authoritative: who fires,
## what is hit, damage, rounds in the weapon and reloading are decided here and
## published like every other action.
##
## A firearm is gear with a "firearm" block in content/items.json:
##   {"ammo": item id, "capacity": n, "damage": hp, "range": px, "cone": cos,
##    "pellets": n, "cooldown_ticks": n, "reload_ticks": n, "noise": category,
##    "sound": sfx id, "magazine": item id (optional: a loaded magazine refills it at once)}
## The rounds in the weapon live in that gear item ("loaded"), so they travel with
## it through drops, trunks and saves. Firing makes a loud noise through the
## ordinary noise system (Burnt Ones hear it from far away, and from the street
## when fired indoors). Melee weapons keep using WorldActions.request_attack.

static func spec(item: String) -> Dictionary:
	return Items.info(item).get("firearm", {})


static func is_firearm(item: String) -> bool:
	return not spec(item).is_empty()


## The firearm in the player's hand (its gear dict), or {}.
static func held(p: PlayerState) -> Dictionary:
	var g := p.equipped_gear("hand")
	if g.is_empty() or not is_firearm(str(g.get("item", ""))):
		return {}
	return g


static func loaded(g: Dictionary) -> int:
	return int(g.get("loaded", 0))


## Rounds the player could still load: loose rounds (+ magazines × capacity).
static func spare(p: PlayerState, g: Dictionary) -> int:
	var s := spec(str(g.get("item", "")))
	var n := p.carrying(str(s.get("ammo", "")))
	if str(s.get("magazine", "")) != "":
		n += p.carrying(str(s["magazine"])) * int(s.get("capacity", 1))
	return n


## Fire toward `aim` (host). Called by WorldActions.request_attack when a firearm is held.
static func fire(world: WorldState, p: PlayerState, g: Dictionary, aim: Vector2) -> Dictionary:
	var s := spec(str(g["item"]))
	var key := p.player_id + ":attack"
	if world.tick < int(world.cooldowns.get(key + "_ready", 0)):
		return WorldActions._fail("ACTION_TOO_FAST")
	if float(g.get("cond", 100.0)) <= 0.0:
		return WorldActions._fail("ACTION_GUN_JAMMED")
	var res := WorldActions._ok()
	if loaded(g) <= 0:
		world.cooldowns[key + "_ready"] = world.tick + 4
		res["events"] = [{"kind": "dry_fire", "player_id": p.player_id, "region_id": p.region_id, "x": p.position.x, "y": p.position.y}]
		res["private_notice"] = {"player_id": p.player_id, "key": "GUN_EMPTY", "args": []}
		return res
	g["loaded"] = loaded(g) - 1
	g["cond"] = maxf(0.0, float(g.get("cond", 100.0)) - float(s.get("wear", 0.5)))
	world.cooldowns[key + "_ready"] = world.tick + int(s.get("cooldown_ticks", 5))
	aim = aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	var region := world.region(p.region_id)
	var side := SideSection.always_side(region) or (SideSection.is_level(p.region_id) and p.bunker_view == "side")
	if side:
		aim = Vector2(signf(aim.x) if absf(aim.x) > 0.01 else 1.0, 0)  # side view: along the floor
	var reach := float(s.get("range", 600))
	var cone := float(s.get("cone", 0.985))
	var targets: Array = []
	for z in world.zombies.values():
		if z.region_id != p.region_id or z.is_dead():
			continue
		var to: Vector2 = z.position - p.position
		var d := to.length()
		if d > reach or d < 1.0:
			continue
		if aim.dot(to / d) < cone:
			if not (side and SideSection.same_floor(region, p.position, z.position) and signf(to.x) == signf(aim.x)):
				continue
		elif side and not SideSection.same_floor(region, p.position, z.position):
			continue
		if not side:
			var grid := NavGrid.for_def(region.def_id)
			if not grid.clear_line(p.position, z.position, NavGrid.dynamic_blocked(world, p.region_id, grid)):
				continue
		targets.append([d, z])
	targets.sort_custom(func(a, b): return a[0] < b[0])
	var pellets := int(s.get("pellets", 1))
	var hits := 0
	var end := p.position + aim * reach
	var events: Array = [{"kind": "shot", "player_id": p.player_id, "region_id": p.region_id, "item": str(g["item"]),
		"x": p.position.x, "y": p.position.y, "tx": end.x, "ty": end.y}]
	for t in targets:
		if hits >= pellets:
			break
		var z: ZombieState = t[1]
		var falloff := 1.0 - 0.4 * clampf(float(t[0]) / reach, 0.0, 1.0)
		var dmg := float(s.get("damage", 60)) * falloff / float(maxi(1, pellets) if pellets > 1 else 1) * (1.6 if pellets > 1 else 1.0)
		var hit := ZombieSim.damage_zombie(world, z, dmg, p, aim * 22.0)
		events.append_array(hit["events"])
		if hits == 0:
			events[0]["tx"] = z.position.x
			events[0]["ty"] = z.position.y - 40.0
		hits += 1
	var law: Array = []
	if hits < pellets and not side:
		# iteration 015 F: a person in the line of fire
		var pe := FactionSim.target_for(world, p, aim, reach, cone)
		if pe != null:
			var falloff3 := 1.0 - 0.4 * clampf(p.position.distance_to(pe.position) / reach, 0.0, 1.0)
			if hits == 0:
				events[0]["tx"] = pe.position.x
				events[0]["ty"] = pe.position.y - 40.0
			for fr in FactionSim.damage(world, pe, float(s.get("damage", 60)) * falloff3, p):
				if fr.has("kind"):
					events.append(fr)
				else:
					law.append(fr)
			hits += 1
	if hits < pellets and not side:
		# iteration 015 E: an animal in the line of fire
		var an := WildlifeSim.target_for(world, p, aim, reach, cone)
		if an != null:
			var falloff2 := 1.0 - 0.4 * clampf(p.position.distance_to(an.position) / reach, 0.0, 1.0)
			if hits == 0:
				events[0]["tx"] = an.position.x
				events[0]["ty"] = an.position.y - 30.0
			events.append_array(WildlifeSim.damage(world, an, float(s.get("damage", 60)) * falloff2, p))
	ZombieSim.make_noise(world, p.region_id, p.position, str(s.get("noise", "gunshot")))
	law.append_array(FactionSim.noted_gunfire(world, p))  # iteration 015 F: gunfire inside a community fence
	for lr in law:
		events.append_array(lr.get("events", []))
		if lr.has("private_notice"):
			res["private_notice"] = lr["private_notice"]
		res["meta"] = true
	res["events"] = events
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	SessionLog.info("combat", "shot", {"player": p.player_id.substr(0, 6), "item": g["item"], "loaded": loaded(g), "hits": hits})
	return res


## Reload the held firearm from the player's ammunition (host).
static func reload_held(world: WorldState, p: PlayerState) -> Dictionary:
	var g := held(p)
	if g.is_empty():
		return WorldActions._fail("ACTION_NO_FIREARM")
	var s := spec(str(g["item"]))
	var cap := int(s.get("capacity", 1))
	if loaded(g) >= cap:
		return WorldActions._fail("ACTION_GUN_FULL")
	var mag := str(s.get("magazine", ""))
	var ammo := str(s.get("ammo", ""))
	if mag != "" and p.carrying(mag) > 0:
		# a loaded magazine swaps in at once; the rounds left in the old one go back to the pocket
		p.carried[mag] = p.carrying(mag) - 1
		if int(p.carried[mag]) <= 0:
			p.carried.erase(mag)
		if loaded(g) > 0:
			p.carried[ammo] = p.carrying(ammo) + loaded(g)
		g["loaded"] = cap
	else:
		var n := mini(cap - loaded(g), p.carrying(ammo))
		if n <= 0:
			return WorldActions._fail("ACTION_NO_AMMO", [TranslationServer.translate(Items.name_key(ammo))])
		p.carried[ammo] = p.carrying(ammo) - n
		if int(p.carried[ammo]) <= 0:
			p.carried.erase(ammo)
		g["loaded"] = loaded(g) + n
	world.cooldowns[p.player_id + ":attack_ready"] = world.tick + int(s.get("reload_ticks", 16))
	var res := WorldActions._ok()
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	res["events"] = [{"kind": "reload", "player_id": p.player_id, "region_id": p.region_id, "x": p.position.x, "y": p.position.y}]
	return res
