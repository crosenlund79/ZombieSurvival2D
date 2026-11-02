class_name InfraSim
extends RefCounted
## Host-only bunker infrastructure and hydration on the shared clock.
##
## Generator (entity type "generator", state {fuel, running}): burns fuel while
## running; stops itself when empty. Power is simple and logical: a bunker is
## powered while any of its generators runs. Consumers check bunker power:
## lamps ("lamp") and the water purifier ("purifier", state {input, output,
## progress}) which turns contaminated water into clean water over time.
## Hydration falls slowly for online players; drinking clean water restores it.
## Long clock jumps are handled with elapsed time, not per-tick loops.

const TUNING_PATH := "res://content/tuning/infrastructure.json"
static var _cfg: Dictionary = {}


static func c(key: String, fallback: Variant) -> Variant:
	if _cfg.is_empty():
		var d = SafeFile.read_json(TUNING_PATH)
		_cfg = d if d is Dictionary else {}
	return _cfg.get(key, fallback)


## True while any generator of the bunker that owns `region_id` is running.
static func is_powered(world: WorldState, region_id: String) -> bool:
	var b := world.bunker_for_region(region_id)
	if b == null:
		return false
	for depth in b.levels:
		var r := world.region(b.level_region(depth))
		if r == null:
			continue
		for eid in Content.entity_ids(r.def_id):
			if str(r.entity_def(eid).get("type", "")) == "generator":
				var st := r.entity_state(eid)
				if bool(st.get("running", false)) and float(st.get("fuel", 0.0)) > 0.0:
					return true
	return false


static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	var seconds := float(ticks) / Simulation.TICK_RATE
	for rid in world.regions:
		var r: RegionState = world.regions[rid]
		for eid in Content.entity_ids(r.def_id):
			var t := str(r.entity_def(eid).get("type", ""))
			if t == "generator":
				_generator(world, r, eid, seconds, results)
			elif t == "purifier":
				_purifier(world, r, eid, seconds, results)
	_hydration(world, seconds, results)
	return results


static func _generator(world: WorldState, r: RegionState, eid: String, seconds: float, results: Array) -> void:
	var st := r.entity_state(eid)
	if not bool(st.get("running", false)):
		return
	var fuel := float(st.get("fuel", 0.0))
	var before := fuel
	fuel = maxf(0.0, fuel - seconds / float(c("generator_seconds_per_fuel", 180)))
	var fields := {"fuel": snappedf(fuel, 0.0001)}
	var cause := ""
	if fuel <= 0.0:
		fields["running"] = false
		cause = "out_of_fuel"
	elif floori(before * 20.0) != floori(fuel * 20.0):
		cause = "fuel"  # publish in 5 % steps, not every tick
	r.set_fields(eid, fields)
	if fuel > 0.0 and int(world.tick) % 30 == 0:
		ZombieSim.make_noise(world, r.region_id, Content.entity_position(r.entity_def(eid)), "machine")
	if cause != "":
		var res := WorldActions._changed(r, eid, cause)
		results.append(res)


static func _purifier(world: WorldState, r: RegionState, eid: String, seconds: float, results: Array) -> void:
	var st := r.entity_state(eid)
	var input := int(st.get("input", 0))
	var output := int(st.get("output", 0))
	if input <= 0 or output >= int(c("purifier_output_capacity", 6)) or not is_powered(world, r.region_id):
		if float(st.get("progress", 0.0)) > 0.0 and input <= 0:
			r.set_fields(eid, {"progress": 0.0})
		return
	var per := float(c("purifier_seconds_per_unit", 20))
	var progress := float(st.get("progress", 0.0)) + seconds / per
	var made := 0
	while progress >= 1.0 and input > 0 and output < int(c("purifier_output_capacity", 6)):
		progress -= 1.0
		input -= 1
		output += 1
		made += 1
	var before_step := floori(float(st.get("progress", 0.0)) * 10.0)
	r.set_fields(eid, {"input": input, "output": output, "progress": snappedf(progress if input > 0 else 0.0, 0.001)})
	if made > 0:
		results.append(WorldActions._changed(r, eid, "purified"))
	elif floori(progress * 10.0) != before_step:
		results.append(WorldActions._changed(r, eid, "progress"))


static func _hydration(world: WorldState, seconds: float, results: Array) -> void:
	var loss := float(c("hydration_loss_per_minute", 2.5)) * seconds / 60.0
	for p in world.online_players():
		if p.dead:
			continue
		var before: float = p.hydration
		p.hydration = maxf(0.0, p.hydration - loss)
		if p.hydration <= 0.0:
			var floor_hp := float(c("dehydrated_health_floor", 25))
			if p.health > floor_hp:
				p.health = maxf(floor_hp, p.health - float(c("dehydrated_health_loss_per_minute", 3)) * seconds / 60.0)
		if floori(before / 2.0) != floori(p.hydration / 2.0):
			var res := WorldActions._ok()
			res["vitals"] = [p.player_id]
			results.append(res)


static func is_thirsty(p: PlayerState) -> bool:
	return p.hydration < float(c("thirsty_below", 25))
