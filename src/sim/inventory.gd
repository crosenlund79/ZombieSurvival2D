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
	return Items.total(p.carried) + p.gear.size()


static func free_slots(p: PlayerState) -> int:
	return maxi(0, Items.carry_slots() - slots_used(p))


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
	return {"uid": world.new_uid("g"), "item": item, "cond": float(Items.info(item).get("durability", 100))}


## Gives stackable items to a player; whatever does not fit lands in a ground
## pile at their feet. Returns the oid of the pile used ("" if none).
static func give_stack(world: WorldState, p: PlayerState, item: String, amount: int) -> String:
	var fit := mini(amount, free_slots(p))
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
	var box_free := maxi(0, box_slots - Items.total(items) - gear.size())
	if store:
		var gi := p.find_gear(what)
		if gi >= 0:
			if box_free <= 0:
				return 0
			unequip_uid(p, what)
			gear.append(p.gear[gi])
			p.gear.remove_at(gi)
			return 1
		return Items.move(p.carried, items, what, mini(p.carrying(what), box_free))
	for i in gear.size():
		if str(gear[i].get("uid", "")) == what:
			if free_slots(p) <= 0:
				return 0
			p.gear.append(gear[i])
			gear.remove_at(i)
			return 1
	return Items.move(items, p.carried, what, mini(Items.amount(items, what), free_slots(p)))


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
	match str(info.get("use", "")):
		"eat":
			p.hunger = minf(100.0, p.hunger + float(info.get("food", 20)))
			res["notice"] = {"key": "ATE", "args": [int(info.get("food", 20))]}
			res["events"] = [{"kind": "ate", "player_id": p.player_id}]
		"drink":
			p.hydration = minf(100.0, p.hydration + float(info.get("hydration", 40)))
			res["events"] = [{"kind": "drank", "player_id": p.player_id}]
		"heal":
			if p.health >= 100.0:
				return WorldActions._fail("ACTION_NOT_HURT")
			p.health = minf(100.0, p.health + float(info.get("heal", 30)))
			res["events"] = [{"kind": "healed", "player_id": p.player_id}]
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


## Eats the most filling food carried (the eat key).
static func best_food(p: PlayerState) -> String:
	var best := ""
	for item in p.carried:
		if str(Items.info(item).get("use", "")) == "eat":
			if best == "" or float(Items.info(item).get("food", 0)) > float(Items.info(best).get("food", 0)):
				best = item
	return best
