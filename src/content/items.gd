class_name Items
extends RefCounted
## Item catalogue (res://content/items.json): stable item ids and display name
## keys. Quantities live in plain dictionaries {item_id: amount}: the
## player's `carried` and each bunker's shared `resources` (its storage).
## Carrying capacity is simple: every unit takes one slot.

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


static func total(bag: Dictionary) -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


static func free_slots(bag: Dictionary) -> int:
	return maxi(0, carry_slots() - total(bag))


static func amount(bag: Dictionary, item: String) -> int:
	return int(bag.get(item, 0))


## Moves up to `qty` of `item` from one bag to another (capacity on `to` if
## limit >= 0). Returns the amount moved. Both bags change in the same step,
## so nothing can be duplicated or lost.
static func move(from: Dictionary, to: Dictionary, item: String, qty: int, to_limit: int = -1) -> int:
	var n := mini(qty, amount(from, item))
	if to_limit >= 0:
		n = mini(n, maxi(0, to_limit - total(to)))
	if n <= 0:
		return 0
	from[item] = amount(from, item) - n
	if int(from[item]) == 0:
		from.erase(item)
	to[item] = amount(to, item) + n
	return n
