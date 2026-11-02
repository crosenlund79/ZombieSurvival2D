class_name Craft
extends RefCounted
## Workbench crafting (host-side rules). Recipes: content/recipes.json.
## A bench runs one job at a time, stored in the bench object:
##   o["job"] = {"recipe", "by", "started", "ticks"}    while working
##   o["output"] = {"items": {}, "gear": []}             finished goods, until collected
## Inputs are paid in the same step that starts the job (so they can never be
## spent twice); a saved job finishes after loading, exactly once (world jobs
## "craft:<oid>"). Worn gear is repaired at the bench for its repair cost.
## Unlocks (world.meta.unlocks) are shared by everyone in the world.

const PATH := "res://content/recipes.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"recipes": {}}
	return _data


static func recipes() -> Dictionary:
	return data().get("recipes", {})


static func recipe(id: String) -> Dictionary:
	return recipes().get(id, {})


static func order() -> Array:
	return data().get("order", recipes().keys())


static func unlocked(world: WorldState, id: String) -> bool:
	var need := str(recipe(id).get("requires", ""))
	return need == "" or bool(world.meta.get("unlocks", {}).get(need, false))


static func unlock(world: WorldState, key: String) -> void:
	var u: Dictionary = world.meta.get("unlocks", {})
	u[key] = true
	world.meta["unlocks"] = u


static func is_bench(o: Dictionary) -> bool:
	return str(Build.def(str(o.get("def", ""))).get("station", "")) == "workbench"


## Bench actions: craft <recipe>, collect, repair_gear <uid>.
static func object_action(world: WorldState, p: PlayerState, region: RegionState, oid: String, o: Dictionary,
		action: String, arg: String, res: Dictionary) -> Dictionary:
	match action:
		"craft":
			var r := recipe(arg)
			if r.is_empty():
				return WorldActions._fail("ACTION_NOT_SUPPORTED")
			if not unlocked(world, arg):
				return WorldActions._fail("ACTION_RECIPE_LOCKED")
			if o.has("job"):
				return WorldActions._fail("ACTION_BUSY")
			if not (o.get("output", {}) as Dictionary).is_empty() and (not (o["output"].get("items", {}) as Dictionary).is_empty() or not (o["output"].get("gear", []) as Array).is_empty()):
				return WorldActions._fail("ACTION_COLLECT_FIRST")
			var bags := Inv.sources(world, p)
			var short := Inv.missing(bags, r.get("in", {}))
			if not short.is_empty():
				return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe(short)])
			if Inv.uses_storage(p, r.get("in", {})):
				res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
			Inv.pay(bags, r.get("in", {}))
			var ticks := Simulation.seconds_to_ticks(float(r.get("seconds", 5)))
			o["job"] = {"recipe": arg, "by": p.player_id, "started": world.tick, "ticks": ticks}
			world.add_job(region.region_id, "craft:" + oid, world.tick + ticks)
			ZombieSim.make_noise(world, region.region_id, Build.pos_of(o), "build", 0.6)
			res["events"] = [{"kind": "craft_started", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
			return res
		"collect":
			var out: Dictionary = o.get("output", {})
			var items: Dictionary = out.get("items", {})
			var gear: Array = out.get("gear", [])
			if items.is_empty() and gear.is_empty():
				return WorldActions._fail("ACTION_NOTHING_THERE")
			var got := 0
			for item in items.keys():
				var n := mini(int(items[item]), Inv.free_slots(p))
				if n > 0:
					p.carried[item] = p.carrying(item) + n
					items[item] = int(items[item]) - n
					got += n
				if int(items[item]) <= 0:
					items.erase(item)
			while not gear.is_empty() and Inv.free_slots(p) > 0:
				var g: Dictionary = gear.pop_front()
				p.gear.append(g)
				_auto_equip(p, g)
				got += 1
			if got == 0:
				return WorldActions._fail("ACTION_CARRY_FULL", [Items.carry_slots()])
			if items.is_empty() and gear.is_empty():
				o.erase("output")
			res["vitals"] = [p.player_id]
			res["events"] = [{"kind": "craft_collected", "region_id": region.region_id, "oid": oid, "player_id": p.player_id}]
			return res
		"repair_gear":
			var i := p.find_gear(arg)
			if i < 0:
				return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
			var g2: Dictionary = p.gear[i]
			var info := Items.info(str(g2["item"]))
			var full := float(info.get("durability", 100))
			if float(g2.get("cond", full)) >= full:
				return WorldActions._fail("ACTION_NOT_DAMAGED")
			var cost: Dictionary = info.get("repair", {"wood": 1})
			var bags2 := Inv.sources(world, p)
			var short2 := Inv.missing(bags2, cost)
			if not short2.is_empty():
				return WorldActions._fail("ACTION_NEED_MATERIALS", [Items.describe(short2)])
			if Inv.uses_storage(p, cost):
				res["bunkers"] = [world.bunker_for_region(p.region_id).bunker_id]
			Inv.pay(bags2, cost)
			g2["cond"] = full
			res["vitals"] = [p.player_id]
			res["events"] = [{"kind": "repaired", "region_id": region.region_id, "oid": oid, "x": float(o["x"]), "y": float(o["y"])}]
			return res
	return WorldActions._fail("ACTION_NOT_SUPPORTED")


## Puts newly made gear in an empty matching slot (convenience; never swaps).
static func _auto_equip(p: PlayerState, g: Dictionary) -> void:
	var slot := str(Items.info(str(g.get("item", ""))).get("slot", ""))
	if slot != "" and str(p.equipped.get(slot, "")) == "":
		p.equipped[slot] = str(g["uid"])


## Job completion (from Simulation.advance via world jobs "craft:<oid>").
static func complete(world: WorldState, region: RegionState, oid: String) -> Dictionary:
	var o: Dictionary = region.objects.get(oid, {})
	if o.is_empty() or not o.has("job"):
		return WorldActions._fail("ACTION_NOT_SUPPORTED")
	var job: Dictionary = o["job"]
	o.erase("job")
	var r := recipe(str(job.get("recipe", "")))
	var out: Dictionary = o.get("output", {"items": {}, "gear": []})
	var items: Dictionary = out.get("items", {})
	var gear: Array = out.get("gear", [])
	for item in r.get("out", {}):
		var n := int(r["out"][item])
		if Items.is_stack(item):
			items[item] = Items.amount(items, item) + n
		else:
			for k in n:
				gear.append(Inv.new_gear(world, item))
	out["items"] = items
	out["gear"] = gear
	o["output"] = out
	var res := WorldActions._ok()
	res["objects"] = [[region.region_id, oid]]
	res["events"] = [{"kind": "craft_done", "region_id": region.region_id, "oid": oid, "recipe": job.get("recipe", ""),
		"x": float(o["x"]), "y": float(o["y"])}]
	return res
