class_name BuildMode
extends Control
## Construction UI for the local player (B). A small menu lists what can be
## built here and what it costs; choosing an entry shows a placement preview
## that follows the mouse (green = allowed, red = the reason it is not).
## Placing only sends a request; the host validates and spends materials.
## Uses the same read-only rules as the host (Build.placement_problem), so the
## preview and the outcome agree. Movement stays free while placing.

## Definition being placed ("" = not placing). Read by the avatar and the sensor.
static var placing := ""
## Tests can pin the preview to a world position instead of the mouse.
static var forced_pos := Vector2.INF

var main: Node
var _menu: PanelContainer
var _list: VBoxContainer
var _ghost: Node2D
var _ghost_sprite: Sprite2D
var problem := ""
var problem_args: Array = []
var ghost_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_menu.offset_left = -360
	_menu.offset_right = -20
	_menu.offset_top = -260
	_menu.offset_bottom = 260
	var v := VBoxContainer.new()
	_menu.add_child(v)
	v.add_child(UITheme.heading(tr("BUILD_MENU_TITLE"), 20))
	var hint := UITheme.small(tr("BUILD_MENU_HINT"), 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = tr("MENU_CLOSE")
	close.pressed.connect(close_menu)
	v.add_child(close)
	_menu.hide()
	add_child(_menu)
	Session.world_ended.connect(func(_r: String) -> void: cancel())
	Session.local_region_changed.connect(func(_r: String) -> void: cancel())


func menu_open() -> bool:
	return _menu.visible


func toggle_menu() -> void:
	if placing != "":
		cancel()
		return
	if _menu.visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	_fill_menu()
	_menu.show()


func close_menu() -> void:
	_menu.hide()


func _fill_menu() -> void:
	for c in _list.get_children():
		c.queue_free()
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var kind := Build.zone_kind(w, me.region_id)
	var bags := Inv.sources(w, me)
	for id in Build.menu():
		var name := ""
		var cost := {}
		var allowed := false
		if id == "support":
			name = tr("BUILD_SUPPORT")
			cost = {"wood": int(Terrain.cfg(w.region(me.region_id)).get("support_wood", 4))} if w.region(me.region_id) != null else {"wood": 4}
			allowed = Terrain.has_terrain(w.region(me.region_id))
			bags = [w.bunker_for_region(me.region_id).resources] if allowed and w.bunker_for_region(me.region_id) != null else []
		else:
			var d := Build.def(id)
			name = tr(str(d.get("name_key", id)))
			cost = (d.get("tiers", [{}])[0] as Dictionary).get("cost", {})
			allowed = kind != "" and kind in d.get("where", [])
			bags = Inv.sources(w, me)
		var short := Inv.missing(bags, cost)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s — %s" % [name, Items.describe(cost)]
		if not allowed:
			b.text += "  (" + tr("BUILD_NOT_HERE_SHORT") + ")"
		elif not short.is_empty():
			b.text += "  (" + UITheme.fmt("BUILD_MISSING_SHORT", [Items.describe(short)]) + ")"
		b.disabled = not allowed
		b.tooltip_text = tr(str(Build.def(id).get("desc_key", "BUILD_SUPPORT_DESC")))
		var pick: String = id
		b.pressed.connect(func() -> void: start(pick))
		_list.add_child(b)


func start(def_id: String) -> void:
	close_menu()
	placing = def_id
	_ghost = Node2D.new()
	_ghost.name = "BuildGhost"
	_ghost.z_index = 5
	_ghost_sprite = Sprite2D.new()
	_ghost.add_child(_ghost_sprite)
	_ghost.draw.connect(_draw_ghost)
	if main.region_view != null:
		main.region_view.add_child(_ghost)
	SessionLog.info("build", "placing", {"def": def_id})


func cancel() -> void:
	placing = ""
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	close_menu()


func _process(_delta: float) -> void:
	if placing == "":
		return
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null or main.region_view == null or _ghost == null or not is_instance_valid(_ghost):
		cancel()
		return
	var region := w.region(me.region_id)
	var want: Vector2 = forced_pos if forced_pos != Vector2.INF else main.region_view.get_global_mouse_position()
	var off: Vector2 = want - me.position
	if off.length() > Build.BUILD_REACH - 16.0:
		want = me.position + off.normalized() * (Build.BUILD_REACH - 16.0)
	if placing == "support":
		var cell := Terrain.cell_of(region, want)
		ghost_pos = Terrain.cell_center(region, cell)
		problem = Terrain.support_problem(region, cell) if Terrain.has_terrain(region) else "ACTION_BUILD_NOT_HERE"
		var b := w.bunker_for_region(me.region_id)
		var need := int(Terrain.cfg(region).get("support_wood", 4))
		problem_args = []
		if problem == "" and (b == null or b.amount("wood") < need):
			problem = "ACTION_NEED_MATERIALS"
			problem_args = [Items.describe({"wood": need - (b.amount("wood") if b != null else 0)})]
		_ghost_sprite.texture = null
	else:
		ghost_pos = Build.snap(region, want)
		problem = Build.placement_problem(w, me.region_id, placing, ghost_pos)
		var cost: Dictionary = (Build.def(placing).get("tiers", [{}])[0] as Dictionary).get("cost", {})
		problem_args = []
		var short := Inv.missing(Inv.sources(w, me), cost)
		if problem == "" and not short.is_empty():
			problem = "ACTION_NEED_MATERIALS"
			problem_args = [Items.describe(short)]
		Assets.apply_to_sprite(_ghost_sprite, StructureView.art_for(region, {"def": placing, "tier": 0}))
	_ghost.position = ghost_pos
	_ghost_sprite.modulate = Color(0.7, 1.0, 0.7, 0.62) if problem == "" else Color(1.0, 0.55, 0.5, 0.55)
	_ghost.queue_redraw()


func _draw_ghost() -> void:
	var w := Session.world
	var me := Session.local_player()
	if w == null or me == null:
		return
	var region := w.region(me.region_id)
	var rect := Rect2()
	if placing == "support":
		rect = Terrain.cell_rect(region, Terrain.cell_of(region, ghost_pos))
	else:
		rect = Build.footprint_at(region, placing, ghost_pos)
	var col := Color(0.55, 0.9, 0.5, 0.9) if problem == "" else Color(0.95, 0.4, 0.3, 0.9)
	_ghost.draw_rect(Rect2(rect.position - ghost_pos, rect.size), col, false, 2.0)


## The hint line the HUD shows while placing.
func hint_text() -> String:
	if placing == "":
		return ""
	var name := tr("BUILD_SUPPORT") if placing == "support" else tr(str(Build.def(placing).get("name_key", "")))
	var status := tr("BUILD_OK") if problem == "" else UITheme.fmt(problem, problem_args).strip_edges().trim_suffix(".")
	return UITheme.fmt("BUILD_PLACING_HINT", [name, status])


func place() -> void:
	if placing == "" or problem != "":
		if problem != "":
			Session.notice.emit(problem, problem_args)
		return
	if placing == "support":
		var region := Session.world.region(Session.local_player().region_id)
		Session.request_terrain("support", Terrain.cell_of(region, ghost_pos))
	else:
		Session.request_build(placing, ghost_pos)


func _unhandled_input(event: InputEvent) -> void:
	if not Session.in_world():
		return
	if event.is_action_pressed("build_menu") and not main.pause_menu.visible and not main.map_panel.visible:
		toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if _menu.visible and event.is_action_pressed("pause_menu"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if placing == "":
		return
	if event.is_action_pressed("pause_menu") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		place()
		get_viewport().set_input_as_handled()
