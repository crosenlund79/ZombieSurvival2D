class_name Inv
extends RefCounted
## Host-side inventory transactions. Stackable items live in plain
## {item: amount} dictionaries (a player's `carried`, a bunker's shared
## `resources`, a crate's or ground pile's `items`). Gear items (tools,
## weapons, clothing, unique finds) are individual {uid, item, cond} records
## in `gear` arrays. Every transfer changes source and destination in the same
## host step, so concurrent requests cannot duplicate or lose anything.
##
## Paying for something uses the player's own bag first, then the shared
## storage of the bunker they are in (bunker levels and the building that
## holds the bunker entrance). On the open surface only carried items count.


static func slots_used(p: PlayerState) -> int:
	return Items.slots(p.carried) + p.gear.size()


## Slots the player can fill: the base pocket space plus worn carriers (a backpack).
static func capacity(p: PlayerState) -> int:
	var n := Items.carry_slots()
	for slot in p.equipped:
		var g := p.equipped_gear(str(slot))
		if not g.is_empty():
			n += int(Items.info(str(g.get("item", ""))).get("carry", 0))
	return n


static func free_slots(p: PlayerState) -> int:
	return maxi(0, capacity(p) - slots_used(p))


## Units of a stackable item the player can still pick up.
static func room_for(p: PlayerState, item: String) -> int:
	return Items.room_for(p.carried, item, free_slots(p))


## Total weight carried (kg; shown, it does not slow anyone down).
static func weight(p: PlayerState) -> float:
	var w := 0.0
	for item in p.carried:
		w += Items.weight(str(item)) * int(p.carried[item])
	for g in p.gear:
		w += Items.weight(str(g.get("item", "")))
	return w


## Slots a container holds ({"items": {}, "gear": []}).
static func box_used(box: Dictionary) -> int:
	return Items.slots(box.get("items", {})) + (box.get("gear", []) as Array).size()


## Bags that may pay for something this player does, in spending order.
static func sources(world: WorldState, p: PlayerState) -> Array:
	var out: Array = [p.carried]
	var b := world.bunker_for_region(p.region_id)
	if b != null:
		out.append(b.resources)
	return out


static func available(bags: Array, item: String) -> int:
	var n := 0
	for bag in bags:
		n += Items.amount(bag, item)
	return n


## What is missing to pay `cost` ({} = affordable).
static func missing(bags: Array, cost: Dictionary) -> Dictionary:
	var out := {}
	for item in cost:
		var short := int(cost[item]) - available(bags, item)
		if short > 0:
			out[item] = short
	return out


## Spends `cost` from the bags in order. Call only after missing() is empty.
static func pay(bags: Array, cost: Dictionary) -> void:
	for item in cost:
		var left := int(cost[item])
		for bag in bags:
			if left <= 0:
				break
			var take := mini(left, Items.amount(bag, item))
			if take > 0:
				bag[item] = Items.amount(bag, item) - take
				if int(bag[item]) == 0:
					bag.erase(item)
				left -= take


## True when paying would touch shared storage (so the bunker must be published).
static func uses_storage(p: PlayerState, cost: Dictionary) -> bool:
	for item in cost:
		if p.carrying(item) < int(cost[item]):
			return true
	return false


static func new_gear(world: WorldState, item: String) -> Dictionary:
	var g := {"uid": world.new_uid("g"), "item": item, "cond": float(Items.info(item).get("durability", 100))}
	if Firearms.is_firearm(item):
		g["loaded"] = 0  # found empty; loot may put a few rounds in (LootSim)
	return g


## Gives stackable items to a player; whatever does not fit lands in a ground
## pile at their feet. Returns the oid of the pile used ("" if none).
static func give_stack(world: WorldState, p: PlayerState, item: String, amount: int) -> String:
	var fit := mini(amount, room_for(p, item))
	if fit > 0:
		p.carried[item] = p.carrying(item) + fit
	if amount - fit > 0:
		return drop_into_pile(world, p.region_id, p.position, {item: amount - fit}, [])
	return ""


static func give_gear(world: WorldState, p: PlayerState, g: Dictionary) -> String:
	if free_slots(p) > 0:
		p.gear.append(g)
		return ""
	return drop_into_pile(world, p.region_id, p.position, {}, [g])


## Adds items to a ground pile near `pos` (merging with a close pile).
static func drop_into_pile(world: WorldState, region_id: String, pos: Vector2, items: Dictionary, gear: Array) -> String:
	var r := world.region(region_id)
	if r == null or (items.is_empty() and gear.is_empty()):
		return ""
	var oid := ""
	for k in r.objects:
		var o: Dictionary = r.objects[k]
		if str(o.get("def", "")) == "pile" and Vector2(float(o["x"]), float(o["y"])).distance_to(pos) < 40.0:
			oid = k
			break
	if oid == "":
		oid = world.new_uid("o")
		r.objects[oid] = {"def": "pile", "x": snappedf(pos.x, 0.1), "y": snappedf(pos.y + 6.0, 0.1), "items": {}, "gear": []}
	var pile: Dictionary = r.objects[oid]
	for item in items:
		pile["items"][item] = Items.amount(pile["items"], item) + int(items[item])
	for g in gear:
		pile["gear"].append(g)
	return oid


## Moves items between a player and a container ({"items": {}, "gear": []}).
## store: all of a stack (or one gear uid) from the player, up to the
## container's free slots. take: as much of a stack as the player can carry
## (or one gear uid). Returns how many units moved.
static func transfer(p: PlayerState, box: Dictionary, store: bool, what: String, box_slots: int) -> int:
	var items: Dictionary = box.get("items", {})
	var gear: Array = box.get("gear", [])
	box["items"] = items
	box["gear"] = gear
	var box_free := maxi(0, box_slots - box_used(box))
	if store:
		var gi := p.find_gear(what)
		if gi >= 0:
			if box_free <= 0:
				return 0
			unequip_uid(p, what)
			gear.append(p.gear[gi])
			p.gear.remove_at(gi)
			return 1
		return Items.move(p.carried, items, what, mini(p.carrying(what), Items.room_for(items, what, box_free)))
	for i in gear.size():
		if str(gear[i].get("uid", "")) == what:
			if free_slots(p) <= 0:
				return 0
			p.gear.append(gear[i])
			gear.remove_at(i)
			return 1
	return Items.move(items, p.carried, what, mini(Items.amount(items, what), room_for(p, what)))


static func unequip_uid(p: PlayerState, uid: String) -> void:
	for slot in p.equipped.keys():
		if str(p.equipped[slot]) == uid:
			p.equipped.erase(slot)


## Player inventory actions (host): equip <uid>, unequip <slot>, drop <item|uid>,
## use <item|uid> (eat / drink / heal / read). Returns a WorldActions result.
static func request(world: WorldState, player_id: String, action: String, arg: String) -> Dictionary:
	var p: PlayerState = world.players.get(player_id, null)
	if p == null or not p.online:
		return WorldActions._fail("ACTION_UNKNOWN_PLAYER")
	if p.dead:
		return WorldActions._fail("ACTION_DEAD")
	var res := WorldActions._ok()
	res["players"] = [p.player_id]
	res["vitals"] = [p.player_id]
	match action:
		"equip":
			var i := p.find_gear(arg)
			if i < 0:
				return WorldActions._fail("ACTION_UNKNOWN_OBJECT")
			var slot := str(Items.info(str(p.gear[i]["item"])).get("slot", ""))
			if slot == "":
				return WorldActions._fail("ACTION_CANT_USE")
			p.equipped[slot] = arg
		"unequip":
			if not p.equipped.has(arg):
				return WorldActions._fail("ACTION_NOTHING_THERE")
			p.equipped.erase(arg)
		"drop":
			var gi := p.find_gear(arg)
			var pile := ""
			if gi >= 0:
				var g: Dictionary = p.gear[gi]
				unequip_uid(p, arg)
				p.gear.remove_at(gi)
				pile = drop_into_pile(world, p.region_id, p.position, {}, [g])
			else:
				var n := p.carrying(arg)
				if n <= 0:
					return WorldActions._fail("ACTION_NOTHING_THERE")
				p.carried.erase(arg)
				pile = drop_into_pile(world, p.region_id, p.position, {arg: n}, [])
			res["objects"] = [[p.region_id, pile]]
		"use":
			return _use(world, p, arg, res)
		"flashlight":
			return toggle_flashlight(world, p, res)
		"reload":
			return Firearms.reload_held(world, p)
		_:
			return WorldActions._fail("ACTION_NOT_SUPPORTED")
	return res


static func _use(world: WorldState, p: PlayerState, arg: String, res: Dictionary) -> Dictionary:
	var gi := p.find_gear(arg)
	var item := str(p.gear[gi]["item"]) if gi >= 0 else arg
	var info := Items.info(item)
	if str(info.get("use", "")) == "":
		return WorldActions._fail("ACTION_CANT_USE")
	if gi < 0 and p.carrying(item) <= 0:
		return WorldActions._fail("ACTION_NOTHING_THERE")
	if str(info.get("use", "")) == "map":
		return res  # reading the map is local (the map panel opens); nothing is used up
	if str(info.get("use", "")) == "flashlight":
		return toggle_flashlight(world, p, res, item)  # lamps are never used up; glow sticks and flares are
	match str(info.get("use", "")):
		"eat":
			p.hunger = minf(100.0, p.hunger + float(info.get("food", 20)))
			_side_effects(p, info)
			res["notice"] = {"key": "ATE", "args": [int(info.get("food", 20))]}
			res["events"] = [{"kind": "ate", "player_id": p.player_id}]
		"drink":
			p.hydration = clampf(p.hydration + float(info.get("hydration", 40)), 0.0, 100.0)
			_side_effects(p, info)
			res["events"] = [{"kind": "drank", "player_id": p.player_id}]
		"heal":
			if p.health >= 100.0:
				return WorldActions._fail("ACTION_NOT_HURT")
			p.health = minf(100.0, p.health + float(info.get("heal", 30)))
			res["events"] = [{"kind": "healed", "player_id": p.player_id}]
		"warm":
			# Heat packs are used up; a thermal blanket is kept; a portable stove burns fuel.
			var fuel: Dictionary = info.get("consumes", {})
			for f in fuel:
				if p.carrying(str(f)) < int(fuel[f]):
					return WorldActions._fail("ACTION_NO_AMMO", [TranslationServer.translate(Items.name_key(str(f)))])
			if p.warmth >= 99.5:
				return WorldActions._fail("ACTION_ALREADY_WARM")
			for f in fuel:
				p.carried[str(f)] = p.carrying(str(f)) - int(fuel[f])
				if int(p.carried[str(f)]) <= 0:
					p.carried.erase(str(f))
			p.warmth = minf(100.0, p.warmth + float(info.get("warmth", 20)))
			res["notice"] = {"key": "WARMED", "args": [int(info.get("warmth", 20))]}
			res["events"] = [{"kind": "warmed", "player_id": p.player_id}]
			if bool(info.get("reusable", false)):
				return res
		"repair_hand":
			# Gun oil / cleaning kit restore the held firearm, a whetstone the held blade.
			var h := p.equipped_gear("hand")
			if h.is_empty():
				return WorldActions._fail("ACTION_NOTHING_TO_REPAIR")
			var gun := Firearms.is_firearm(str(h.get("item", "")))
			if (str(info.get("fixes", "")) == "firearm") != gun:
				return WorldActions._fail("ACTION_WRONG_KIT")
			var top := float(Items.info(str(h["item"])).get("durability", 100))
			if float(h.get("cond", top)) >= top:
				return WorldActions._fail("ACTION_NOTHING_TO_REPAIR")
			h["cond"] = minf(top, float(h.get("cond", top)) + float(info.get("repair", 20)) * top / 100.0)
			res["events"] = [{"kind": "repaired", "player_id": p.player_id}]
		"read":
			var learned: Array[String] = []
			for key in info.get("unlocks", []):
				Craft.unlock(world, str(key))
				learned.append(TranslationServer.translate(Items.name_key(str(key))))
			res["meta"] = true
			res["notice"] = {"key": "RECIPES_LEARNED", "args": [", ".join(learned)]}
		_:
			return WorldActions._fail("ACTION_CANT_USE")
	if gi >= 0:
		unequip_uid(p, arg)
		p.gear.remove_at(gi)
	else:
		p.carried[item] = p.carrying(item) - 1
		if int(p.carried[item]) <= 0:
			p.carried.erase(item)
	return res


## Eating or drinking can also warm, chill, hurt or heal (coffee, frozen food, spoiled food).
static func _side_effects(p: PlayerState, info: Dictionary) -> void:
	if info.has("warmth"):
		p.warmth = clampf(p.warmth + float(info["warmth"]), 0.0, 100.0)
	if info.has("health"):
		p.health = clampf(p.health + float(info["health"]), 1.0, 100.0)
	if info.has("hydration") and str(info.get("use", "")) == "eat":
		p.hydration = clampf(p.hydration + float(info["hydration"]), 0.0, 100.0)


## Switches the player's light on/off (host). A carried lamp (flashlight,
## headlamp, lantern) toggles freely; otherwise switching on snaps a glow stick
## or lights a flare, which is used up and burns for its "burn_seconds".
static func toggle_flashlight(world: WorldState, p: PlayerState, res: Dictionary, prefer: String = "") -> Dictionary:
	if p.flashlight:
		p.flashlight = false
		p.light_until = 0
	elif p.has_lamp() and (prefer == "" or not Items.is_stack(prefer) or p.carrying(prefer) <= 0 or p.has_gear_item(prefer)):
		p.flashlight = true
		p.light_until = 0
	else:
		var stick := prefer if prefer != "" and p.carrying(prefer) > 0 else ""
		if stick == "":
			for item in p.carried:
				if str(Items.info(str(item)).get("use", "")) == "flashlight":
					stick = str(item)
					break
		if stick == "":
			p.flashlight = false
			return WorldActions._fail("FLASHLIGHT_NONE")
		p.carried[stick] = p.carrying(stick) - 1
		if int(p.carried[stick]) <= 0:
			p.carried.erase(stick)
		p.flashlight = true
		p.light_until = maxi(1, world.tick + int(float(Items.info(stick).get("burn_seconds", 300)) * Simulation.TICK_RATE))
	res["vitals"] = [p.player_id]
	res["players"] = [p.player_id]
	res["events"] = [{"kind": "flashlight", "player_id": p.player_id, "on": p.flashlight}]
	return res


## Eats the most filling food carried (the eat key).
static func best_food(p: PlayerState) -> String:
	var best := ""
	for item in p.carried:
		if str(Items.info(item).get("use", "")) == "eat":
			if best == "" or float(Items.info(item).get("food", 0)) > float(Items.info(best).get("food", 0)):
				best = item
	return best
