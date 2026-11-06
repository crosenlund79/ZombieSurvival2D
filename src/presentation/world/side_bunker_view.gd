class_name SideBunkerView
extends RegionView
## A bunker level drawn as a 2D side view / cross-section (iteration 012,
## experimental). Built in code from the level's data — the same region, the
## same entities, objects, terrain and players as the top-down scene, read as a
## cross-section (SideSection). The surface stays top-down; the original
## top-down bunker scenes are untouched and remain one key away (F7, developer).

## Which view script shows which entity type in the side view.
const VIEWS := {
	"portal": preload("res://src/presentation/world/portal_view.gd"),
	"stockpile": preload("res://src/presentation/world/stockpile_view.gd"),
	"support_site": preload("res://src/presentation/world/support_view.gd"),
	"storage": preload("res://src/presentation/world/machine_view.gd"),
	"generator": preload("res://src/presentation/world/machine_view.gd"),
	"purifier": preload("res://src/presentation/world/machine_view.gd"),
	"loot": preload("res://src/presentation/world/machine_view.gd"),
	"lamp": preload("res://src/presentation/world/lamp_view.gd"),
	"bed": preload("res://src/presentation/world/bed_view.gd"),
}
## Art per entity (the same ids as the top-down scenes; SideArt maps them).
const ART := {
	"ladder_up": "bunker.ladder_up", "ladder_down": "bunker.ladder_down_slab",
	"storage": "world.storage_locker", "generator": "world.generator_off", "purifier": "world.purifier_off",
}
const ART_ACTIVE := {"generator": "world.generator_on", "purifier": "world.purifier_on"}


func _init() -> void:
	side = true
	player_light = true
	ambience_id = "amb.underground"
	camera_limits = true
	name = "SideBunker"


func _ready() -> void:
	var r := Session.world.region(region_id) if Session.world != null else null
	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	var terrain := SideTerrain.new()
	terrain.name = "SideTerrain"
	add_child(terrain)
	add_child(ysort)
	if r != null:
		for eid in Content.entity_ids(r.def_id):
			var d := r.entity_def(eid)
			var t := str(d.get("type", ""))
			if not VIEWS.has(t):
				continue
			var v: Node2D = (VIEWS[t] as GDScript).new()
			v.set("entity_id", eid)
			var short: String = eid.get_slice(".", eid.get_slice_count(".") - 1)
			if ART.has(short):
				v.set("art_asset", ART[short])
			if ART_ACTIVE.has(short):
				v.set("art_active_asset", ART_ACTIVE[short])
			if short == "ladder_down":
				v.set("floor_art", true)
			if short == "ladder_up":
				v.set("hide_when_unavailable", false)
			v.name = "E_" + short
			ysort.add_child(v)
		var atm := Atmosphere.new()
		atm.name = "Atmosphere"
		atm.tint = Color(0.42, 0.4, 0.38)
		atm.warm = true
		atm.saturation = 0.85
		atm.vignette_strength = 0.45
		atm.drift_amount = 0
		atm.fog_strength = 0.0
		atm.area = screen_bounds()
		add_child(atm)
	super._ready()
	SessionLog.info("view", "side_view_built", {"region": region_id})
