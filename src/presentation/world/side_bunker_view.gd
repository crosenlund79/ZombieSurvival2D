class_name SideBunkerView
extends RegionView
## A region drawn as a 2D side view / cross-section, built in code from the
## region's data — the same entities, objects, terrain and players the host
## simulates, read as a cross-section (SideSection).
##  * Iteration 012: bunker levels (experimental; F7 compares with the original
##    top-down bunker scenes).
##  * Iteration 014: building interiors (the hunter's cabin, houses, shops, the
##    multi-storey block) and the mine are always side views (region "view":
##    "side"); their walls, rooms and furniture come from the region definition
##    ("section", "side_props"), written by tools/build_side_interiors.py.
## The outdoor world stays top-down.

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
	"container": preload("res://src/presentation/world/container_view.gd"),
	"shelter_site": preload("res://src/presentation/world/shelter_site_view.gd"),
	"weapon_rack": preload("res://src/presentation/world/weapon_rack_view.gd"),
	"starter_bag": preload("res://src/presentation/world/starter_bag_view.gd"),
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
		var d := r.definition()
		ambience_id = str(d.get("ambience", ambience_id))
		ambience2_id = str(d.get("ambience2", ""))
		_add_props(r, ysort)
		for eid in Content.entity_ids(r.def_id):
			var ed := r.entity_def(eid)
			var t := str(ed.get("type", ""))
			if t == "stairs":
				_add_stairs(r, ed, ysort)
				continue
			if not VIEWS.has(t):
				continue
			var v: Node2D = (VIEWS[t] as GDScript).new()
			v.set("entity_id", eid)
			var short: String = eid.get_slice(".", eid.get_slice_count(".") - 1)
			if ART.has(short):
				v.set("art_asset", ART[short])
			if ART_ACTIVE.has(short):
				v.set("art_active_asset", ART_ACTIVE[short])
			if ed.has("side_art"):
				v.set("art_asset", str(ed["side_art"]))
			if short == "ladder_down":
				v.set("floor_art", true)
			if short == "ladder_up" or (t == "portal" and ed.has("side_art")):
				v.set("hide_when_unavailable", false)
			v.name = "E_" + short
			ysort.add_child(v)
		_add_windows(r)
		var atm := Atmosphere.new()
		atm.name = "Atmosphere"
		var tint: Array = d.get("tint", [0.42, 0.4, 0.38])
		atm.tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
		atm.warm = bool(d.get("warm", not SideSection.always_side(r)))
		atm.saturation = 0.85
		atm.vignette_strength = 0.45
		atm.drift_amount = 0
		atm.fog_strength = 0.0
		atm.follow_daylight = str(d.get("style", "")) == "building"
		atm.area = screen_bounds()
		add_child(atm)
	super._ready()
	SessionLog.info("view", "side_view_built", {"region": region_id})


## Furniture and dressing that is not an entity: rests on the floor beneath it
## (or hangs from the ceiling with "hang": true). Plan coordinates.
func _add_props(r: RegionState, parent: Node2D) -> void:
	for pr in r.definition().get("side_props", []):
		var aid := str(pr.get("asset", ""))
		if not AssetCatalog.has(aid):
			continue
		var plan := Vector2(float(pr.get("x", 0)), float(pr.get("y", 0)))
		var sp := Sprite2D.new()
		Assets.apply_to_sprite(sp, aid)
		var at := SideSection.hang(r, plan) if bool(pr.get("hang", false)) else SideSection.rest(r, plan)
		var holder := Node2D.new()
		holder.position = SideSection.to_screen(r, at)
		if bool(pr.get("back", false)):
			holder.z_index = -2  # hangs on the back wall: always behind people
		holder.add_child(sp)
		if bool(pr.get("flip", false)):
			sp.flip_h = true
		parent.add_child(holder)


## A staircase flight between two floors (entity type "stairs"); climbable via SideSection.
func _add_stairs(r: RegionState, ed: Dictionary, parent: Node2D) -> void:
	var p := Content.entity_position(ed)
	var bottom := SideSection.to_screen(r, Vector2(p.x, p.y))
	var top := SideSection.to_screen(r, Vector2(p.x, float(ed.get("top", p.y - 320.0))))
	var sp := Sprite2D.new()
	Assets.apply_to_sprite(sp, "side.ladder" if str(ed.get("style", "")) == "ladder" else "side.stairs")
	var h := maxf(40.0, bottom.y - top.y)
	var k := h / maxf(1.0, sp.texture.get_size().y * sp.scale.y)
	sp.position.y *= k
	sp.scale.y *= k
	if bool(ed.get("flip", false)):
		sp.flip_h = true
	var holder := Node2D.new()
	holder.position = bottom
	holder.z_index = -2
	holder.add_child(sp)
	parent.add_child(holder)


## Daylight through the windows of a building (follows the shared clock).
func _add_windows(r: RegionState) -> void:
	var sec: Dictionary = r.definition().get("section", {})
	for w in sec.get("windows", []):
		var plan := Vector2(float(w[0]), float(w[1]))
		var boarded: bool = w.size() > 2 and str(w[2]) == "boarded"
		var sp := Sprite2D.new()
		Assets.apply_to_sprite(sp, "side.window_boarded" if boarded else "side.window")
		var holder := Node2D.new()
		holder.position = SideSection.to_screen(r, plan)
		holder.z_index = -3
		holder.add_child(sp)
		add_child(holder)
		if not boarded:
			var l := PointLight2D.new()
			l.set_script(LightSpot)
			l.color = Color(0.9, 0.94, 1.0)
			l.energy = 0.55
			l.texture_scale = 2.6
			l.set("daylight", true)
			l.position = holder.position + Vector2(0, 30)
			add_child(l)
