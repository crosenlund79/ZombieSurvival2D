class_name FarmSim
extends RefCounted
## Host-only production by built objects, on the shared clock:
##  * rain collector (surface): fills with dirty water, quickly while it rains,
##    slowly otherwise; players collect it.
##  * hydroponic planter (bunker): a crop cycle needs one clean water at the
##    start and power while it grows; a ripe crop is harvested as potatoes.
##    Without power the crop simply pauses (it does not die).
## Tuning: content/tuning/farming.json and the "rain_collector" block of
## content/buildables.json. Long clock jumps use elapsed time.

const TUNING_PATH := "res://content/tuning/farming.json"
static var _cfg: Dictionary = {}


static func c(key: String, fallback: Variant) -> Variant:
	if _cfg.is_empty():
		var d = SafeFile.read_json(TUNING_PATH)
		_cfg = d if d is Dictionary else {}
	return _cfg.get(key, fallback)


static func step(world: WorldState, ticks: int) -> Array:
	var results: Array = []
	var seconds := float(ticks) / Simulation.TICK_RATE
	var raining := EnvSim.is_raining(world)
	for rid in world.regions:
		var r: RegionState = world.regions[rid]
		for oid in r.objects:
			var o: Dictionary = r.objects[oid]
			if not Build.is_built(o):
				continue
			var d := Build.def(str(o.get("def", "")))
			if bool(d.get("collector", false)):
				_collector(r, oid, o, seconds, raining, results)
			elif bool(d.get("farm", false)):
				_planter(world, r, oid, o, seconds, results)
	return results


static func _collector(r: RegionState, oid: String, o: Dictionary, seconds: float, raining: bool, results: Array) -> void:
	var rc: Dictionary = Build.data().get("rain_collector", {})
	var cap := int(rc.get("capacity", 4))
	if float(o.get("hp", 1)) <= 0.0 or int(o.get("stored", 0)) >= cap:
		return
	var per := float(rc.get("seconds_per_unit_rain" if raining else "seconds_per_unit_dry", 240))
	var fill := float(o.get("fill", 0.0)) + seconds / per
	var made := floori(fill)
	o["fill"] = snappedf(fill - made, 0.001)
	if made > 0:
		o["stored"] = mini(cap, int(o.get("stored", 0)) + made)
		var res := WorldActions._ok()
		res["objects"] = [[r.region_id, oid]]
		results.append(res)


static func _planter(world: WorldState, r: RegionState, oid: String, o: Dictionary, seconds: float, results: Array) -> void:
	var crop := str(o.get("crop", ""))
	if crop == "ripe":
		return
	if crop == "":
		# Start a cycle when there is water in the tank.
		if int(o.get("water", 0)) <= 0:
			return
		o["water"] = int(o["water"]) - 1
		o["crop"] = "growing"
		o["grow"] = 0.0
		var res0 := WorldActions._ok()
		res0["objects"] = [[r.region_id, oid]]
		results.append(res0)
		return
	if not InfraSim.is_powered(world, r.region_id):
		return
	var before := float(o.get("grow", 0.0))
	var g := minf(1.0, before + seconds / float(c("grow_seconds", 150)))
	o["grow"] = snappedf(g, 0.0001)
	if g >= 1.0:
		o["crop"] = "ripe"
		o.erase("grow")
	if g >= 1.0 or floori(before * 10.0) != floori(g * 10.0):
		var res := WorldActions._ok()
		res["objects"] = [[r.region_id, oid]]
		if g >= 1.0:
			res["events"] = [{"kind": "crop_ripe", "region_id": r.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
		results.append(res)


## Object actions owned by production objects (called from Build.request_object).
static func object_action(world: WorldState, p: PlayerState, region: RegionState, oid: String, o: Dictionary,
		action: String, _arg: String, res: Dictionary) -> Dictionary:
	var d := Build.def(str(o.get("def", "")))
	match action:
		"collect":
			if not bool(d.get("collector", false)):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			var n := mini(int(o.get("stored", 0)), Inv.free_slots(p))
			if int(o.get("stored", 0)) <= 0:
				return WorldActions._fail("ACTION_NOTHING_THERE")
			if n <= 0:
				return WorldActions._fail("ACTION_CARRY_FULL", [Items.carry_slots()])
			o["stored"] = int(o.get("stored", 0)) - n
			p.carried["water_dirty"] = p.carrying("water_dirty") + n
			res["events"] = [{"kind": "water_collected", "region_id": region.region_id, "oid": oid, "player_id": p.player_id}]
			return res
		"water":
			if not bool(d.get("farm", false)):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if int(o.get("water", 0)) >= int(c("tank_capacity", 3)):
				return WorldActions._fail("ACTION_TANK_FULL")
			var bags := Inv.sources(world, p)
			if Inv.available(bags, "water_clean") < 1:
				return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe({"water_clean": 1})])
			if Inv.uses_storage(p, {"water_clean": 1}):
				res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
			Inv.pay(bags, {"water_clean": 1})
			o["water"] = int(o.get("water", 0)) + 1
			res["events"] = [{"kind": "watered", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
			return res
		"harvest":
			if not bool(d.get("farm", false)):
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if str(o.get("crop", "")) != "ripe":
				return WorldActions._fail("ACTION_NOT_RIPE")
			var amount := int(c("yield", 3))
			o["crop"] = ""
			Inv.give_stack(world, p, "potato", amount)
			res["notice"] = {"key": "HARVESTED", "args": [amount]}
			res["events"] = [{"kind": "harvested", "region_id": region.region_id, "oid": oid, "player_id": p.player_id}]
			for k in region.objects:
				if Build.is_pile(region.objects[k]):
					res["objects"].append([region.region_id, k])
			return res
	return WorldActions._fail("ACTION_NOT_SUPPORTED")


## Shared helpers for settlement automation (survivor jobs) — same rules, no free output.
static func harvest_to(world: WorldState, o: Dictionary, bag: Dictionary) -> int:
	if str(o.get("crop", "")) != "ripe":
		return 0
	var amount := int(c("yield", 3))
	o["crop"] = ""
	bag["potato"] = Items.amount(bag, "potato") + amount
	return amount
