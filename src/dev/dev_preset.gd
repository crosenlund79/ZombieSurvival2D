class_name DevPreset
extends RefCounted
## "Developer Test World": a prepared world for checking systems quickly
## (shelter dug and open, a larger first chamber, generator running, purifier
## and planter, a workbench, stocked storage, tools, the survivor at home with
## a job). Applied once by the host right after creating a new world; marked in
## world.meta so it is never mistaken for a normal game.

const SITE := "homestead.farmhouse.shelter"


static func apply(world: WorldState, player_id: String) -> void:
	var p: PlayerState = world.players.get(player_id)
	var fh := world.region("homestead.farmhouse")
	fh.set_fields(SITE, {"stage": "built", "open": true})
	var b := world.create_bunker(SITE, "homestead.farmhouse", "bunker_earth")
	var reg := world.region(b.level_region(-1))
	var dug := {}
	for c in range(9, 13):
		for r in range(11, 15):
			dug["%d,%d" % [c, r]] = true
	reg.terrain["dug"] = dug
	reg.terrain["supports"] = {"11,12": {"stage": "reinforced"}}
	reg.set_fields("generator", {"fuel": 4.0, "running": true})
	reg.set_fields("purifier", {"input": 2, "output": 1})
	b.resources = {"wood": 30, "scrap_metal": 12, "cement": 4, "fuel": 6, "water_dirty": 6, "water_clean": 4,
		"canned_food": 4, "potato": 3, "cloth": 6, "electrical_parts": 3, "timber_frame": 1, "spike_kit": 2, "grow_light": 1}
	_place(world, reg, "workbench", Terrain.cell_center(reg, Vector2i(10, 12)))
	var planter := _place(world, reg, "planter", Terrain.cell_center(reg, Vector2i(10, 14)))
	reg.objects[planter]["water"] = 2
	if p != null:
		p.carried = {"wood": 10, "scrap_metal": 4, "canned_food": 2, "water_clean": 2, "bandage": 2}
		for item in ["hatchet", "machete", "padded_jacket"]:
			p.gear.append(Inv.new_gear(world, item))
		p.equipped = {"hand": p.gear[1]["uid"], "body": p.gear[2]["uid"]}
	NpcSim.ensure(world)
	NpcSim.dev_recruit(world, "mara")
	if world.npcs.has("mara"):
		world.npcs["mara"].job = "water"
	world.meta["dev_world"] = true
	SessionLog.info("dev", "test_world_prepared", {"world": world.world_id})


static func _place(world: WorldState, reg: RegionState, def_id: String, pos: Vector2) -> String:
	var oid := world.new_uid("o")
	var p := Build.snap(reg, pos)
	reg.objects[oid] = {"def": def_id, "tier": 0, "x": p.x, "y": p.y, "hp": Build.max_hp({"def": def_id, "tier": 0}), "stage": "built"}
	return oid


## Writes a short plain-text problem report (build, world, where you are, nearby
## systems, the defence event, recent log lines) to user://reports/. Local file;
## returns its absolute path.
static func write_report(world: WorldState, player_id: String) -> String:
	var dir := Paths.ensure_dir(Paths.user_root() + "reports/")
	var path := dir + "report_%s.txt" % Time.get_datetime_string_from_system().replace(":", "-")
	var p: PlayerState = world.players.get(player_id)
	var lines: Array[String] = []
	lines.append(BuildInfo.GAME_TITLE + " problem report")
	lines.append(BuildInfo.label())
	lines.append("world %s · seed %d · tick %d · day %d %s · weather %s" % [world.world_id, world.world_seed, world.tick,
		EnvSim.day_number(world), EnvSim.clock_text(world), EnvSim.weather(world)])
	if p != null:
		lines.append("player %s in %s at (%d, %d) · health %d water %d food %d · holding '%s'" % [p.display_name, p.region_id,
			p.position.x, p.position.y, p.health, p.hydration, p.hunger, p.weapon])
		lines.append("carrying: %s" % JSON.stringify(p.carried))
		var r := world.region(p.region_id)
		if r != null:
			var near: Array[String] = []
			for oid in r.objects:
				var o: Dictionary = r.objects[oid]
				if Build.pos_of(o).distance_to(p.position) < 500.0:
					near.append("%s %s hp %s %s" % [oid, o.get("def"), o.get("hp", "-"), o.get("stage", "")])
			lines.append("nearby structures: " + (", ".join(near) if not near.is_empty() else "none"))
	lines.append("defence event: %s · heat %s · home heat %.1f" % [JSON.stringify(EventSim.siege(world)), JSON.stringify(world.meta.get("heat", {})), EventSim.home_heat(world)])
	lines.append("zombies: %d · survivors: %s" % [world.zombies.size(), JSON.stringify(NpcState.encode_all(world))])
	lines.append("")
	lines.append("recent log:")
	for e in SessionLog.recent(60):
		lines.append(JSON.stringify(e))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	SessionLog.info("dev", "report_written", {"path": ProjectSettings.globalize_path(path)})
	return ProjectSettings.globalize_path(path)
