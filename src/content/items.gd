class_name Items
extends RefCounted
## Item catalogue (res://content/items.json): stable item ids and display name
## keys. Quantities live in plain dictionaries {item_id: amount}: the
## player's `carried` and each bunker's shared `resources` (its storage).
## Carrying capacity counts slots: a slot holds up to an item's "stack_limit"
## units (1 for most bulky things, e.g. 30 pistol rounds or 10 matches share one).

const PATH := "res://content/items.json"
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = SafeFile.read_json(PATH)
		_data = d if d is Dictionary else {"items": {}, "carry_slots": 30}
	return _data


static func ids() -> Array:
	return data().get("items", {}).keys()


static func exists(item: String) -> bool:
	return data().get("items", {}).has(item)


static func name_key(item: String) -> String:
	return str(data().get("items", {}).get(item, {}).get("name_key", item))


static func carry_slots() -> int:
	return int(data().get("carry_slots", 30))


## Units in a bag (all items together).
static func total(bag: Dictionary) -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


static func stack_limit(item: String) -> int:
	return maxi(1, int(info(item).get("stack_limit", 1)))


## Slots `n` units of `item` take.
static func slots_of(item: String, n: int) -> int:
	if n <= 0:
		return 0
	var lim := stack_limit(item)
	return int((n + lim - 1) / lim)


## Slots a bag of stacks takes.
static func slots(bag: Dictionary) -> int:
	var n := 0
	for k in bag:
		n += slots_of(str(k), int(bag[k]))
	return n


static func free_slots(bag: Dictionary) -> int:
	return maxi(0, carry_slots() - slots(bag))


## Units of `item` that still fit in `bag` with `free` empty slots left
## (the room in its last part-filled stack plus whole new stacks).
static func room_for(bag: Dictionary, item: String, free: int) -> int:
	var lim := stack_limit(item)
	var have := amount(bag, item)
	var partial := (lim - have % lim) % lim
	return partial + maxi(0, free) * lim


static func weight(item: String) -> float:
	return float(info(item).get("weight", 0.0))


static func amount(bag: Dictionary, item: String) -> int:
	return int(bag.get(item, 0))


## Moves up to `qty` of `item` from one bag to another (capacity on `to` if
## limit >= 0). Returns the amount moved. Both bags change in the same step,
## so nothing can be duplicated or lost.
static func move(from: Dictionary, to: Dictionary, item: String, qty: int, to_limit: int = -1) -> int:
	var n := mini(qty, amount(from, item))
	if to_limit >= 0:
		n = mini(n, room_for(to, item, to_limit - slots(to)))
	if n <= 0:
		return 0
	from[item] = amount(from, item) - n
	if int(from[item]) == 0:
		from.erase(item)
	to[item] = amount(to, item) + n
	return n


static func info(item: String) -> Dictionary:
	return data().get("items", {}).get(item, {})


static func category(item: String) -> String:
	return str(info(item).get("cat", "misc"))


static func icon_id(item: String) -> String:
	return str(info(item).get("icon", "icon." + item))


static func is_stack(item: String) -> bool:
	return bool(info(item).get("stack", true))


static func desc_key(item: String) -> String:
	return str(info(item).get("desc_key", ""))


static func bare_hands() -> Dictionary:
	return data().get("bare_hands", {"damage": 12, "range": 54, "cooldown_ticks": 5, "chop": 1})


## "2 Wood, 1 Scrap metal" for a {item: amount} dictionary.
static func describe(bag: Dictionary) -> String:
	var parts: Array[String] = []
	var keys := bag.keys()
	keys.sort()
	for k in keys:
		if int(bag[k]) > 0:
			parts.append("%d %s" % [int(bag[k]), TranslationServer.translate(name_key(str(k)))])
	return ", ".join(parts)
