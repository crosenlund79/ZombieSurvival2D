extends TestCase

const GATE := "homestead.yard_gate"


func _sample() -> WorldState:
	var w := WorldState.create_new("world_unit_save", 1234)
	w.tick = 777
	w.region("homestead").set_fields(GATE, {"open": true})
	var p := PlayerState.new()
	p.player_id = "0123456789abcdef"
	p.display_name = "Tester"
	p.region_id = "homestead"
	p.position = Vector2(321.5, 654.25)
	w.players[p.player_id] = p
	return w


func test_roundtrip() -> void:
	var d := SaveCodec.encode(_sample())
	# Go through real JSON text like a file would.
	var parsed = JSON.parse_string(JSON.stringify(d))
	var res := SaveCodec.decode(parsed)
	check(res["ok"], "decodes: " + str(res.get("error")))
	var w: WorldState = res["world"]
	eq(w.world_id, "world_unit_save", "world id")
	eq(w.world_seed, 1234, "seed")
	eq(w.tick, 777, "tick")
	eq(w.region("homestead").entity_state(GATE), {"open": true}, "gate state")
	eq(w.region("homestead").rev(GATE), 1, "gate rev")
	var p: PlayerState = w.players["0123456789abcdef"]
	eq(p.position, Vector2(321.5, 654.25), "player position")
	eq(p.display_name, "Tester", "player name")
	check(not p.online, "online flag is not persisted")


func test_validation_rejects_bad_saves() -> void:
	var good := SaveCodec.encode(_sample())
	var bad := good.duplicate(true)
	bad["game"] = "Other"
	check(SaveCodec.validate(bad) != "", "wrong game id rejected")
	bad = good.duplicate(true)
	bad["schema_version"] = SaveCodec.SCHEMA_VERSION + 1
	check("newer" in SaveCodec.validate(bad), "newer schema rejected with clear message")
	bad = good.duplicate(true)
	bad["world"]["tick"] = -1
	check(SaveCodec.validate(bad) != "", "negative tick rejected")
	bad = good.duplicate(true)
	bad.erase("world")
	check(SaveCodec.validate(bad) != "", "missing world rejected")
	bad = good.duplicate(true)
	bad["players"]["0123456789abcdef"]["position"] = [1]
	check(SaveCodec.validate(bad) != "", "bad position rejected")
	eq(SaveCodec.validate(good), "", "good save valid")


func test_defaults_for_missing_optional_fields() -> void:
	var minimal := {"game": "Aftergrowth", "schema_version": 1,
		"world": {"world_id": "w_min", "seed": 5, "tick": 0}}
	var res := SaveCodec.decode(minimal)
	check(res["ok"], "minimal save loads")
	var w: WorldState = res["world"]
	check(w.region("homestead") != null, "regions filled from content")
	eq(w.players.size(), 0, "no players")


func test_removed_content_dropped_with_warning() -> void:
	var d := SaveCodec.encode(_sample())
	d["world"]["regions"]["homestead"]["entities"]["homestead.deleted_thing"] = {"state": {"open": true}, "rev": 3}
	d["world"]["regions"]["gone_region"] = {"entities": {}}
	var res := SaveCodec.decode(d)
	check(res["ok"], "still loads")
	eq(res["warnings"].size(), 2, "two warnings")


func test_historical_fixture_v1() -> void:
	var raw = SafeFile.read_json("res://tests/fixtures/saves/world_v1.json")
	check(raw is Dictionary, "fixture readable")
	var res := SaveCodec.decode(raw)
	check(res["ok"], "schema 1 fixture loads: " + str(res.get("error")))
	if res["ok"]:
		eq((res["world"] as WorldState).region("homestead").entity_state(GATE), {"open": true}, "fixture gate open")


func test_migration_extension_point() -> void:
	SaveCodec.MIGRATIONS[0] = func(d: Dictionary) -> Dictionary:
		d["schema_version"] = 1
		d["migrated"] = true
		return d
	var m := SaveCodec.migrate({"schema_version": 0})
	SaveCodec.MIGRATIONS.erase(0)
	check(m["ok"] and m["data"].get("migrated") == true, "migration callable runs in order")
	var m2 := SaveCodec.migrate({"schema_version": -3})
	check(not m2["ok"], "missing migration reported")


func test_safe_write_keeps_backup_and_survives_bad_write() -> void:
	var dir := Paths.ensure_dir("user://unit_test_safe/")
	var path := dir + "x.json"
	for f in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	eq(SafeFile.write_json(path, {"v": 1}), "", "first write")
	eq(SafeFile.write_json(path, {"v": 2}), "", "second write")
	eq(SafeFile.read_json(path)["v"], 2.0, "main has newest")
	eq(SafeFile.read_json(path + ".bak")["v"], 1.0, "backup has previous")
	var err := SafeFile.write_json(path, {"v": 3}, func(_d: Dictionary) -> String: return "simulated invalid")
	check(err != "", "invalid write reported")
	eq(SafeFile.read_json(path)["v"], 2.0, "last good file untouched after failed write")
	check(not FileAccess.file_exists(path + ".tmp"), "temp file cleaned up")


func test_save_service_falls_back_to_backup() -> void:
	var w := _sample()
	w.world_id = "world_unit_backup"
	check(Saves.save_world(w)["ok"], "first save")
	w.tick = 888
	check(Saves.save_world(w)["ok"], "second save")
	var f := FileAccess.open(Saves.world_file(w.world_id), FileAccess.WRITE)
	f.store_string("{ corrupted")
	f.close()
	var res := Saves.load_world(w.world_id)
	check(res["ok"] and res["used_backup"], "corrupt main save -> backup loaded")
	eq((res["world"] as WorldState).tick, 777, "backup holds previous save")
	for p in [Saves.world_file(w.world_id), Saves.world_file(w.world_id) + ".bak"]:
		DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(Saves.world_dir(w.world_id))


func test_save_service_rejects_unsafe_ids() -> void:
	check(not Saves.load_world("../../etc")["ok"], "path traversal id refused")
	var w := _sample()
	w.world_id = "a/b"
	check(not Saves.save_world(w)["ok"], "unsafe id cannot be saved")
