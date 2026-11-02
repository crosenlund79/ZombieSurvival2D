class_name BunkerState
extends RefCounted
## One underground shelter (plain data).
##
## bunker_id is the persistent identity of the shelter entrance it belongs to
## (the shelter_site entity id, e.g. "homestead.farmhouse.shelter"); the
## entrance lives in entrance_region. Levels are keyed by signed depth
## (-1, -2, -3, …) with no design maximum; each level is an ordinary region
## ("bunker:<bunker_id>:<depth>") created from a level template. Adjacent
## levels are connected by ladders. resources is the shared shelter stockpile.

var bunker_id := ""
var entrance_region := ""
var entrance_entity := ""
var levels := {}        # depth (int) -> template_id (String)
var resources := {}     # resource id -> amount (int), e.g. {"wood": 12}


static func region_id_for(id: String, depth: int) -> String:
	return "bunker:%s:%d" % [id, depth]


## Parses "bunker:<id>:<depth>" -> {"bunker_id", "depth"} or {} if not a bunker region.
static func parse_region_id(region_id: String) -> Dictionary:
	if not region_id.begins_with("bunker:"):
		return {}
	var rest := region_id.substr(7)
	var cut := rest.rfind(":")
	if cut <= 0 or not rest.substr(cut + 1).is_valid_int():
		return {}
	return {"bunker_id": rest.substr(0, cut), "depth": rest.substr(cut + 1).to_int()}


func level_region(depth: int) -> String:
	return region_id_for(bunker_id, depth)


func deepest() -> int:
	var d := 0
	for k in levels:
		d = mini(d, int(k))
	return d


func has_level(depth: int) -> bool:
	return levels.has(depth)


func amount(resource: String) -> int:
	return int(resources.get(resource, 0))


func to_dict() -> Dictionary:
	var lv := {}
	for k in levels:
		lv[str(k)] = levels[k]
	return {"entrance_region": entrance_region, "entrance_entity": entrance_entity,
		"levels": lv, "resources": resources.duplicate()}


static func from_dict(id: String, d: Dictionary) -> BunkerState:
	var b := BunkerState.new()
	b.bunker_id = id
	b.entrance_region = str(d.get("entrance_region", ""))
	b.entrance_entity = str(d.get("entrance_entity", id))
	var lv: Dictionary = d.get("levels", {})
	for k in lv:
		if str(k).is_valid_int():
			b.levels[str(k).to_int()] = str(lv[k])
	var res: Dictionary = d.get("resources", {})
	for k in res:
		b.resources[str(k)] = maxi(0, int(res[k]))
	return b
