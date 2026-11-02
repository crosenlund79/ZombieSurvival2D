class_name SaveCodec
extends RefCounted
## Converts WorldState <-> save dictionaries. Validates before anything is
## applied, fills safe defaults for missing optional fields, and runs
## migrations for older schema versions.
##
## Layout (schema 2):
## {
##   "schema_version": 1, "game": "Aftergrowth", "saved_unix": ..., "build": {...},
##   "world":   {"world_id", "seed", "tick", "created_unix", "content_fingerprint",
##               "regions": {region_id: {"def_id"?, "entities": {entity_id: {"state": {...}, "rev": n}}}},
##               "bunkers": {bunker_id: {"entrance_region", "entrance_entity",
##                           "levels": {"-1": template_id, ...}, "resources": {"wood": n}}}},
##   "players": {player_id: {"name", "region_id", "position": [x, y], "facing", "last_seen_unix",
##               "carried": {"wood": n}}}
## }
## Schema history: 1 = iteration 001 (no bunkers/carried). 2 = iteration 002.
## World identity (world) and player identity (players) are separate blocks.

const SCHEMA_VERSION := 2
const GAME_ID := "Aftergrowth"

## Migration extension point: from_version -> Callable(Dictionary) -> Dictionary
## returning data upgraded to from_version + 1.
static var MIGRATIONS := {
	1: SaveCodec._migrate_1_to_2,
}


## 1 -> 2: worlds from iteration 001 get an empty bunker table and empty
## carried resources. Nothing else changes; region ids stay valid.
static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	d["world"]["bunkers"] = d["world"].get("bunkers", {})
	for pid in d.get("players", {}):
		d["players"][pid]["carried"] = d["players"][pid].get("carried", {})
	d["schema_version"] = 2
	return d


static func encode(world: WorldState) -> Dictionary:
	var regions := {}
	for rid in world.regions:
		regions[rid] = (world.regions[rid] as RegionState).to_dict()
	var bunkers := {}
	for bid in world.bunkers:
		bunkers[bid] = (world.bunkers[bid] as BunkerState).to_dict()
	var players := {}
	for pid in world.players:
		players[pid] = (world.players[pid] as PlayerState).to_dict()
	return {
		"schema_version": SCHEMA_VERSION,
		"game": GAME_ID,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"build": BuildInfo.as_dict(),
		"world": {
			"world_id": world.world_id,
			"seed": world.world_seed,
			"tick": world.tick,
			"created_unix": world.created_unix,
			"content_fingerprint": world.content_fingerprint,
			"regions": regions,
			"bunkers": bunkers,
		},
		"players": players,
	}


## Returns "" when the dictionary is structurally valid for the current schema.
static func validate(d: Dictionary) -> String:
	if str(d.get("game", "")) != GAME_ID:
		return "not an %s save" % GAME_ID
	var v = d.get("schema_version")
	if not (v is float or v is int):
		return "missing schema_version"
	if int(v) > SCHEMA_VERSION:
		return "save is from a newer game version (schema %d, this build reads up to %d)" % [int(v), SCHEMA_VERSION]
	if int(v) < 1:
		return "unknown schema_version %d" % int(v)
	var w = d.get("world")
	if not (w is Dictionary):
		return "missing world block"
	if str(w.get("world_id", "")) == "":
		return "missing world_id"
	for key in ["seed", "tick"]:
		if not (w.get(key) is float or w.get(key) is int):
			return "world.%s missing or not a number" % key
	if int(w.get("tick")) < 0:
		return "world.tick is negative"
	if w.has("regions") and not (w["regions"] is Dictionary):
		return "world.regions is not an object"
	if w.has("bunkers") and not (w["bunkers"] is Dictionary):
		return "world.bunkers is not an object"
	if d.has("players") and not (d["players"] is Dictionary):
		return "players is not an object"
	for pid in d.get("players", {}):
		var p = d["players"][pid]
		if not (p is Dictionary):
			return "player %s is not an object" % pid
		var pos = p.get("position", [0, 0])
		if not (pos is Array) or pos.size() != 2:
			return "player %s has an invalid position" % pid
	return ""


static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema_version", SCHEMA_VERSION))
	while v < SCHEMA_VERSION:
		if not MIGRATIONS.has(v):
			return {"ok": false, "error": "no migration from schema %d" % v}
		d = MIGRATIONS[v].call(d)
		v = int(d.get("schema_version", v + 1))
	return {"ok": true, "data": d}


## Returns {ok, world, error, warnings}.
static func decode(d: Dictionary) -> Dictionary:
	var problem := validate(d)
	if problem != "":
		return {"ok": false, "error": problem, "warnings": []}
	var m := migrate(d.duplicate(true))
	if not m["ok"]:
		return {"ok": false, "error": m["error"], "warnings": []}
	var data: Dictionary = m["data"]
	problem = validate(data)
	if problem != "":
		return {"ok": false, "error": "after migration: " + problem, "warnings": []}
	var warnings: Array = []
	var wd: Dictionary = data["world"]
	var w := WorldState.new()
	w.world_id = str(wd["world_id"])
	w.world_seed = int(wd["seed"])
	w.tick = int(wd["tick"])
	w.created_unix = int(wd.get("created_unix", 0))
	w.content_fingerprint = str(wd.get("content_fingerprint", ""))
	if w.content_fingerprint != "" and w.content_fingerprint != Content.fingerprint():
		warnings.append("content changed since this world was saved (%s -> %s)" % [w.content_fingerprint, Content.fingerprint()])
	w.content_fingerprint = Content.fingerprint()
	var bunkers: Dictionary = wd.get("bunkers", {})
	for bid in bunkers:
		var b := BunkerState.from_dict(str(bid), bunkers[bid])
		for depth in b.levels.keys():
			if Content.region_def(Content.level_def_id(b.levels[depth])).is_empty():
				warnings.append("bunker %s level %d uses unknown template %s; level dropped" % [bid, depth, b.levels[depth]])
				b.levels.erase(depth)
		w.bunkers[str(bid)] = b
	w.ensure_bunker_regions()
	var regions: Dictionary = wd.get("regions", {})
	for rid in regions:
		var def_id := str(regions[rid].get("def_id", rid))
		if Content.region_def(def_id).is_empty() or (def_id != rid and not w.regions.has(rid)):
			warnings.append("region %s no longer exists; its changes were dropped" % rid)
			continue
		w.regions[rid] = RegionState.from_dict(rid, regions[rid], warnings)
	for rid in Content.region_ids():
		w.ensure_region(rid)
	var players: Dictionary = data.get("players", {})
	for pid in players:
		var p := PlayerState.from_dict(pid, players[pid])
		if not w.regions.has(p.region_id):
			warnings.append("player %s was in missing region %s; moved to spawn" % [pid, p.region_id])
			p.region_id = Content.DEFAULT_REGION
			p.position = Content.spawn_point(p.region_id, 0)
		w.players[pid] = p
	w.rebuild_jobs()
	return {"ok": true, "world": w, "error": "", "warnings": warnings}
