class_name StructureView
extends Node2D
## Shows one player-built structure or ground pile (RegionState.objects) from
## world data: art by definition/tier/state, collision while it blocks, a
## condition bar when damaged, a progress bar while being built, and one
## Interactable. Every action is a host request (Session.request_object);
## nothing here changes the world. Created and removed by RegionView.

var region_id := ""
var oid := ""
var interact: Interactable
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _flash := 0.0
var _rect := Rect2()
var _side := false


static func create(rid: String, id: String) -> StructureView:
	var v := StructureView.new()
	v.region_id = rid
	v.oid = id
	v.name = "Obj_" + id
	return v


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var body := StaticBody2D.new()
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	body.add_child(_shape)
	add_child(body)
	interact = Interactable.new()
	interact.entity_id = oid
	interact.focus_changed.connect(func(f: bool) -> void:
		_sprite.modulate = Color(1.25, 1.18, 1.0, _sprite.modulate.a) if f else Color(1, 1, 1, _sprite.modulate.a))
	interact.on_activate = _activate
	interact.on_repair = func() -> void: Session.request_object(oid, "repair")
	add_child(interact)
	Session.object_changed.connect(_on_object_changed)
	Assets.reloaded.connect(refresh)
	refresh()


func data() -> Dictionary:
	if Session.world == null or Session.world.region(region_id) == null:
		return {}
	return Session.world.region(region_id).objects.get(oid, {})


func _on_object_changed(rid: String, id: String) -> void:
	if rid == region_id and id == oid:
		refresh()


## Which picture represents the object's current state.
static func art_for(region: RegionState, o: Dictionary) -> String:
	if Build.is_pile(o):
		return "build.pile"
	var tier := Build.tier_of(o)
	var d := Build.def(str(o.get("def", "")))
	if Build.cell_mode(region) and tier.has("bunker_art"):
		return str(tier["bunker_art"])
	if bool(d.get("openable", false)) and bool(o.get("open", false)) and tier.has("art_open"):
		return str(tier["art_open"])
	if d.has("trap") and float(o.get("hp", 1)) <= 0.0 and tier.has("art_worn"):
		return str(tier["art_worn"])
	if bool(d.get("farm", false)):
		match str(o.get("crop", "")):
			"growing":
				return str(tier.get("art_growing", tier.get("art", "")))
			"ripe":
				return str(tier.get("art_ripe", tier.get("art", "")))
	if bool(d.get("collector", false)) and int(o.get("stored", 0)) > 0:
		return str(tier.get("art_full", tier.get("art", "")))
	return str(tier.get("art", ""))


func refresh() -> void:
	var o := data()
	if o.is_empty():
		queue_free()
		return
	var region := Session.world.region(region_id)
	position = Build.pos_of(o)
	var view := RegionView.find_for(self)
	_side = view != null and view.side
	if _side:
		position = SideArt.rest_screen(region, Build.pos_of(o))
	var d := Build.def(str(o.get("def", "")))
	Assets.apply_to_sprite(_sprite, SideArt.map(art_for(region, o)) if _side else art_for(region, o))
	var building := not Build.is_built(o)
	_sprite.modulate.a = 0.5 if building else 1.0
	_update_glow(bool(d.get("heater", false)) and not building)
	z_index = -1 if bool(d.get("floor", false)) or Build.is_pile(o) else 0
	_rect = Build.footprint(region, o)
	var local := Rect2(_rect.position - position, _rect.size)
	(_shape.shape as RectangleShape2D).size = local.size
	_shape.position = local.get_center()
	_shape.set_deferred("disabled", not Build.blocks(o))
	interact.position = local.get_center()
	interact.reach = 70.0 + maxf(local.size.x, local.size.y) * 0.5
	if _side:  # side view: no plan collision; reach the object from the floor beside it
		_shape.set_deferred("disabled", true)
		interact.position = Vector2(0, -24)
		interact.reach = 90.0
	interact.enabled = not building or not Build.is_pile(o)
	interact.prompt_args = [TranslationServer.translate(str(d.get("name_key", "")))]
	interact.prompt_key = _prompt_key(o, d)
	var damaged := not Build.is_pile(o) and Build.is_built(o) and float(o.get("hp", 0)) < Build.max_hp(o)
	interact.secondary_key = "PROMPT_REPAIR" if damaged else ""
	interact.secondary_args = [Items.describe({str(Build.tier_of(o).get("repair_item", "wood")): 1})]
	queue_redraw()


func _prompt_key(o: Dictionary, d: Dictionary) -> String:
	if Build.is_pile(o):
		return "PROMPT_PICK_UP"
	if not Build.is_built(o):
		return "PROMPT_UNDER_CONSTRUCTION"
	if bool(d.get("openable", false)):
		return "PROMPT_CLOSE_DOOR" if bool(o.get("open", false)) else "PROMPT_OPEN_DOOR"
	if d.has("container_slots"):
		return "PROMPT_OPEN_CRATE"
	if str(d.get("station", "")) == "workbench":
		return "PROMPT_WORKBENCH"
	if bool(d.get("farm", false)):
		return "PROMPT_PLANTER"
	if bool(d.get("collector", false)):
		return "PROMPT_COLLECTOR"
	return "PROMPT_INSPECT"


func _activate() -> void:
	var o := data()
	if o.is_empty():
		return
	var d := Build.def(str(o.get("def", "")))
	if Build.is_pile(o):
		Session.request_object(oid, "pickup")
	elif bool(d.get("openable", false)) and Build.is_built(o):
		Session.request_object(oid, "toggle")
	elif str(d.get("station", "")) == "workbench" and Build.is_built(o):
		CraftPanel.open_for(self, region_id, oid)
	else:
		MachinePanel.open(self, region_id, oid, panel_data, func(action: String, arg: String) -> void:
			Session.request_object(oid, action, arg))


## Panel contents: condition, what it does, and the actions available now.
func panel_data() -> Dictionary:
	var o := data()
	if o.is_empty():
		return {"title": "", "lines": [], "buttons": []}
	var d := Build.def(str(o.get("def", "")))
	var tier := Build.tier_of(o)
	var me := Session.local_player()
	var lines: Array = []
	var buttons: Array = []
	lines.append(UITheme.fmt("STRUCT_CONDITION", [roundi(float(o.get("hp", 0))), roundi(Build.max_hp(o)),
		TranslationServer.translate(str(tier.get("name_key", ""))), int(tier.get("armor", 0))]))
	lines.append(TranslationServer.translate(str(d.get("desc_key", ""))))
	if not Build.is_built(o):
		lines.append(TranslationServer.translate("STRUCT_BUILDING"))
	if d.has("container_slots"):
		lines.append(UITheme.fmt("STRUCT_CONTAINS", [Hud.bag_text(o.get("items", {})) + Hud.gear_text(o.get("gear", [])),
			Items.total(o.get("items", {})) + (o.get("gear", []) as Array).size(), int(d["container_slots"])]))
		for item in me.carried:
			buttons.append([UITheme.fmt("STRUCT_STORE", [me.carrying(item), TranslationServer.translate(Items.name_key(item))]), "store", item, true])
		for g in me.gear:
			buttons.append([UITheme.fmt("STRUCT_STORE", [1, TranslationServer.translate(Items.name_key(str(g["item"])))]), "store", str(g["uid"]), true])
		for item2 in o.get("items", {}):
			buttons.append([UITheme.fmt("STRUCT_TAKE", [int(o["items"][item2]), TranslationServer.translate(Items.name_key(item2))]), "take", item2, true])
		for g2 in o.get("gear", []):
			buttons.append([UITheme.fmt("STRUCT_TAKE", [1, TranslationServer.translate(Items.name_key(str(g2["item"])))]), "take", str(g2["uid"]), true])
	if bool(d.get("collector", false)):
		lines.append(UITheme.fmt("STRUCT_COLLECTOR", [int(o.get("stored", 0)), int(Build.data().get("rain_collector", {}).get("capacity", 4)),
			TranslationServer.translate("WEATHER_RAIN" if EnvSim.is_raining(Session.world) else "WEATHER_CLEAR")]))
		buttons.append([TranslationServer.translate("STRUCT_COLLECT"), "collect", "", int(o.get("stored", 0)) > 0])
	if bool(d.get("farm", false)):
		lines.append(_planter_line(o))
		buttons.append([UITheme.fmt("STRUCT_WATER_PLANTER", [Inv.available(Inv.sources(Session.world, me), "water_clean")]), "water", "",
			int(o.get("water", 0)) < int(FarmSim.c("tank_capacity", 3))])
		buttons.append([TranslationServer.translate("STRUCT_HARVEST"), "harvest", "", str(o.get("crop", "")) == "ripe"])
	if Build.is_built(o) and float(o.get("hp", 0)) < Build.max_hp(o):
		buttons.append([UITheme.fmt("STRUCT_REPAIR", [Items.describe({str(tier.get("repair_item", "wood")): 1})]), "repair", "", true])
	var tiers: Array = d.get("tiers", [])
	var next := int(o.get("tier", 0)) + 1
	if Build.is_built(o) and next < tiers.size():
		buttons.append([UITheme.fmt("STRUCT_UPGRADE", [TranslationServer.translate(str(tiers[next].get("name_key", ""))),
			Items.describe(tiers[next].get("cost", {}))]), "upgrade", "", true])
	buttons.append([TranslationServer.translate("STRUCT_DISMANTLE" if Build.is_built(o) else "STRUCT_CANCEL_BUILD"), "dismantle", "", true])
	var title := TranslationServer.translate(str(d.get("name_key", "")))
	return {"title": title, "lines": lines, "buttons": buttons}


func _planter_line(o: Dictionary) -> String:
	var powered := InfraSim.is_powered(Session.world, region_id)
	var key := "PLANTER_EMPTY"
	match str(o.get("crop", "")):
		"growing":
			key = "PLANTER_GROWING" if powered else "PLANTER_NO_POWER"
		"ripe":
			key = "PLANTER_RIPE"
	if key == "PLANTER_EMPTY":
		return UITheme.fmt(key, [int(o.get("water", 0)), int(FarmSim.c("tank_capacity", 3))])
	return UITheme.fmt(key, [roundi(float(o.get("grow", 0)) * 100.0), int(o.get("water", 0)), int(FarmSim.c("tank_capacity", 3))])


func hit_flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	var o := data()
	if not o.is_empty() and not Build.is_built(o):
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_sprite.self_modulate = Color(1, 1, 1).lerp(Color(1.6, 0.7, 0.6), _flash)
		var base := SideArt.rest_screen(Session.world.region(region_id), Build.pos_of(o)) if _side and not o.is_empty() else Build.pos_of(o)
		position = base + Vector2(sin(_flash * 40.0) * 3.0 * _flash, 0) if not o.is_empty() else position


## The visible picture in local coordinates (falls back to a small box).
func _art_rect() -> Rect2:
	if _sprite != null and _sprite.texture != null:
		var sz := _sprite.texture.get_size() * _sprite.scale
		var tl := _sprite.position - (sz * 0.5 if _sprite.centered else Vector2.ZERO)
		return Rect2(tl, sz)
	return Rect2(-30, -50, 60, 50)


func _draw() -> void:
	var o := data()
	if o.is_empty() or Build.is_pile(o):
		return
	# Iteration 014: anchored to the drawn picture (the footprint is in plan
	# coordinates, which differ from the screen in the side view).
	var art: Rect2 = _art_rect()
	var w := clampf(art.size.x, 40.0, 70.0)
	var at := Vector2(art.get_center().x - w * 0.5, art.position.y - 14.0)
	var frac := -1.0
	var col := Color("#7FA55A")
	if not Build.is_built(o):
		var ticks := maxi(1, int(o.get("ticks", 1)))
		frac = clampf(float(Session.world.tick - int(o.get("started", 0))) / ticks, 0.0, 1.0)
		col = UITheme.PAPER
	elif float(o.get("hp", 0)) < Build.max_hp(o):
		frac = float(o.get("hp", 0)) / Build.max_hp(o)
		col = Color("#B5543A") if frac < 0.35 else (Color("#C9A23A") if frac < 0.7 else Color("#7FA55A"))
	if frac < 0.0:
		return
	draw_rect(Rect2(at, Vector2(w, 6)).grow(2), Color(0.06, 0.05, 0.04, 0.8))
	draw_rect(Rect2(at, Vector2(w * frac, 6)), col)


## Iteration 013: a lit wood stove glows (presentation only).
var _glow: PointLight2D
func _update_glow(on: bool) -> void:
	if on and _glow == null:
		_glow = PointLight2D.new()
		_glow.set_script(LightSpot)
		_glow.color = Color(1.0, 0.62, 0.3)
		_glow.energy = 0.9
		_glow.texture_scale = 2.2
		_glow.position = Vector2(0, -26)
		add_child(_glow)
	if _glow != null:
		_glow.visible = on
