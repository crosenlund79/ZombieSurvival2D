class_name SurvivalSim
extends RefCounted
## Host-only player vitals on the shared clock: slow health recovery when not
## recently hurt, and respawn after defeat.
##
## Defeat rule (prototype, deliberately forgiving): a defeated player keeps
## everything they carried and, after RESPAWN_SECONDS, wakes up inside the
## farmhouse (the safe area) at RESPAWN_HEALTH. Nothing is dropped or lost.
##
## Cold exposure (iteration 011): outdoors, warmth falls with the region's
## ambient cold (EnvSim.cold: climate x night x weather), reduced by worn
## insulation (items "insulation", e.g. the padded jacket, the winter coat) and
## by a running vehicle's heater. Shelters recover it: the cabin (region
## "warmth"), a bunker (more with power). Below "chilled" there is a warning,
## below "freezing" no health recovery, and near zero a mild health loss down
## to a floor. Elapsed-time maths, so long clock jumps (sleep) are exact.

const RESPAWN_SECONDS := 5.0
const RESPAWN_HEALTH := 70.0
const RESPAWN_REGION := "homestead.farmhouse"
const REGEN_DELAY_SECONDS := 8.0
const REGEN_PER_SECOND := 1.5


static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	var seconds := float(ticks) / Simulation.TICK_RATE
	for p in world.online_players():
		if p.dead:
			if world.tick >= p.respawn_tick:
				results.append(respawn(world, p))
			continue
		_exposure(world, p, seconds, results)
		if p.flashlight and not p.has_gear_item("flashlight"):
			p.flashlight = false  # dropped, stored or traded away: the light goes with it
			var rf := WorldActions._ok()
			rf["vitals"] = [p.player_id]
			results.append(rf)
		# No recovery while thirsty, hungry or freezing: water, food and warmth matter.
		if p.health < 100.0 and not InfraSim.is_thirsty(p) and not InfraSim.is_hungry(p) and not is_freezing(p) and world.tick - p.last_hurt_tick >= int(REGEN_DELAY_SECONDS * Simulation.TICK_RATE):
			var before := floorf(p.health)
			p.health = minf(100.0, p.health + REGEN_PER_SECOND * seconds)
			if floorf(p.health) != before and int(p.health) % 5 == 0:
				var r := WorldActions._ok()
				r["vitals"] = [p.player_id]
				results.append(r)
	return results


static func ec(key: String, fallback: Variant) -> Variant:
	return EnvSim.c("exposure", {}).get(key, fallback)


static func is_chilled(p: PlayerState) -> bool:
	return p.warmth < float(ec("chilled_below", 40))


static func is_freezing(p: PlayerState) -> bool:
	return p.warmth < float(ec("freezing_below", 18))


## Worn insulation 0..0.8 (body slot item "insulation").
static func insulation(p: PlayerState) -> float:
	var g := p.equipped_gear("body")
	if g.is_empty():
		return 0.0
	return clampf(float(Items.info(str(g.get("item", ""))).get("insulation", 0.0)), 0.0, 0.8)


## Warmth change per minute where the player is now (+ recovers, - loses).
static func warmth_rate(world: WorldState, p: PlayerState) -> float:
	if p.vehicle_id != "" and VehicleSim.heater_on(world, p.vehicle_id):
		return float(ec("vehicle_heater_per_minute", 10))
	var cold := EnvSim.cold(world, p.region_id)
	if cold > 0.0:
		return -float(ec("loss_per_minute", 6.0)) * cold * (1.0 - insulation(p))
	var def := world.region_def(p.region_id)
	if world.bunker_for_region(p.region_id) != null:
		var rate := float(ec("bunker_powered_per_minute", 18)) if InfraSim.is_powered(world, p.region_id) else float(ec("bunker_per_minute", 7))
		if Build.heated(world, p.region_id):
			rate += float(ec("stove_per_minute", 12))  # iteration 013: the wood stove
		return rate
	return float(ec("shelter_per_minute", 10)) * float(def.get("warmth", 1.0))


static func _exposure(world: WorldState, p: PlayerState, seconds: float, results: Array) -> void:
	var before := p.warmth
	p.warmth = clampf(p.warmth + warmth_rate(world, p) * seconds / 60.0, 0.0, 100.0)
	if p.warmth <= float(ec("hurt_below", 6)):
		var floor_hp := float(ec("health_floor", 25))
		if p.health > floor_hp:
			p.health = maxf(floor_hp, p.health - float(ec("health_loss_per_minute", 2.0)) * seconds / 60.0)
	if floori(before / 2.0) != floori(p.warmth / 2.0):
		var r := WorldActions._ok()
		r["vitals"] = [p.player_id]
		results.append(r)
	# Thresholds crossed: a private inner-monologue line for that player.
	for th in [[float(ec("chilled_below", 40)), "COLD_CHILLED"], [float(ec("freezing_below", 18)), "COLD_FREEZING"]]:
		if before >= float(th[0]) and p.warmth < float(th[0]):
			var pr := WorldActions._ok()
			pr["private_notice"] = {"player_id": p.player_id, "key": th[1], "args": []}
			results.append(pr)


static func respawn(world: WorldState, p: PlayerState) -> Dictionary:
	p.dead = false
	p.health = RESPAWN_HEALTH
	p.last_hurt_tick = world.tick
	p.region_id = RESPAWN_REGION if world.region(RESPAWN_REGION) != null else Content.DEFAULT_REGION
	p.position = Content.spawn_point(world.region(p.region_id).def_id, 0)
	var r := WorldActions._ok()
	r["vitals"] = [p.player_id]
	r["events"] = [{"kind": "player_respawned", "player_id": p.player_id}]
	r["transition"] = {"player_id": p.player_id, "region_id": p.region_id, "position": p.position}
	return r
