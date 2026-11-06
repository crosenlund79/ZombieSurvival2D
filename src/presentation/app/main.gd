extends Node
## App shell. Switches between the menu and the local player's region view
## and routes UI panels. Holds no game state: if the region view is freed
## and rebuilt, the world is untouched (try F3 → "Rebuild view").

var world_layer: Node2D
var region_view: RegionView
var ui: UIRoot
var menu: MainMenu
var hud: Hud
var pause_menu: PauseMenu
var dev_overlay: DevOverlay
var build_label: Label
var settings_panel: SettingsPanel
var map_panel: MapPanel
var build_mode: BuildMode
var inventory_panel: InventoryPanel
var guide: Guide
var settlement_panel: SettlementPanel


func _ready() -> void:
	get_window().title = BuildInfo.GAME_TITLE
	world_layer = Node2D.new()
	world_layer.name = "WorldLayer"
	add_child(world_layer)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = UIRoot.new()
	ui.name = "UIRoot"
	layer.add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	menu = MainMenu.new()
	menu.open_settings.connect(open_settings)
	ui.add_child(menu)
	pause_menu = PauseMenu.new()
	pause_menu.open_settings.connect(open_settings)
	pause_menu.leave_requested.connect(func() -> void: Session.leave())
	pause_menu.hide()
	ui.add_child(pause_menu)
	dev_overlay = DevOverlay.new()
	dev_overlay.rebuild_view_requested.connect(rebuild_view)
	dev_overlay.screenshot_requested.connect(func() -> void: take_screenshot(""))
	dev_overlay.hide()
	ui.add_child(dev_overlay)
	map_panel = MapPanel.new()
	map_panel.hide()
	ui.add_child(map_panel)
	build_mode = BuildMode.new()
	build_mode.main = self
	ui.add_child(build_mode)
	inventory_panel = InventoryPanel.new()
	inventory_panel.hide()
	ui.add_child(inventory_panel)
	settlement_panel = SettlementPanel.new()
	settlement_panel.hide()
	ui.add_child(settlement_panel)
	guide = Guide.new()
	ui.add_child(guide)
	ui.add_child(guide.card())
	build_label = UITheme.small(BuildInfo.label(), 11)
	build_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_label.offset_right = -8
	build_label.offset_bottom = -4
	build_label.modulate = Color(1, 1, 1, 0.55)
	build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(build_label)
	Session.world_started.connect(_on_world_started)
	Session.world_ended.connect(_on_world_ended)
	Audio.play_loop("music", "music.theme", 2.0)  # main-menu theme (audio inbox)
	Session.local_region_changed.connect(_on_local_region_changed)
	if Paths.has_arg("autotest"):
		var driver := AutotestDriver.new()
		driver.main = self
		add_child(driver)


func _process(_delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	PlayerAvatar.input_blocked = pause_menu.visible or settings_panel != null or menu.visible or map_panel.visible \
		or (MachinePanel.current != null and is_instance_valid(MachinePanel.current)) \
		or (focus is LineEdit) or (build_mode != null and build_mode.menu_open()) \
		or (guide != null and guide.visible) or (settlement_panel != null and settlement_panel.visible)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_overlay"):
		dev_overlay.visible = not dev_overlay.visible
	elif event.is_action_pressed("screenshot"):
		take_screenshot("")
	elif not Session.in_world():
		return
	elif event.is_action_pressed("bunker_view") and Session.in_world():
		toggle_bunker_view()
	elif event.is_action_pressed("world_map") and settings_panel == null and not pause_menu.visible:
		map_panel.visible = not map_panel.visible
	elif event.is_action_pressed("pause_menu") and map_panel.visible:
		map_panel.hide()
	elif event.is_action_pressed("pause_menu") and (inventory_panel.visible or guide.visible or settlement_panel.visible):
		inventory_panel.hide()
		guide.hide()
		settlement_panel.hide()
	elif event.is_action_pressed("pause_menu") and settings_panel == null:
		pause_menu.visible = not pause_menu.visible
	elif event.is_action_pressed("quick_save"):
		Session.save_world()
	elif event.is_action_pressed("drink") and not PlayerAvatar.input_blocked:
		Session.request_drink()
	elif event.is_action_pressed("eat") and not PlayerAvatar.input_blocked:
		Session.request_eat()
	elif event.is_action_pressed("inventory") and not pause_menu.visible:
		inventory_panel.visible = not inventory_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("guide") and not pause_menu.visible:
		guide.visible = not guide.visible
	elif event.is_action_pressed("settlement") and not pause_menu.visible:
		settlement_panel.visible = not settlement_panel.visible


func _on_world_started() -> void:
	Audio.stop_loop("music", 2.0)
	Session.request_bunker_view(Settings.bunker_view())
	menu.hide()
	pause_menu.hide()
	build_region_view()


func _on_world_ended(reason_key: String) -> void:
	clear_region_view()
	inventory_panel.hide()
	guide.hide()
	settlement_panel.hide()
	pause_menu.hide()
	map_panel.hide()
	Audio.stop_all_loops()
	Audio.play_loop("music", "music.theme", 2.0)
	menu.show()
	menu.on_session_ended(reason_key)


func build_region_view() -> void:
	clear_region_view()
	var me := Session.local_player()
	if me == null:
		return
	var region := Session.world.region(me.region_id)
	if region == null:
		SessionLog.error("view", "region_missing", {"region": me.region_id})
		return
	if SideSection.is_level(region.region_id) and Settings.bunker_view() == "side":
		# Iteration 012 (experiment): bunker levels as a side view, built from the same data.
		region_view = SideBunkerView.new()
		region_view.region_id = region.region_id
		region_view.def_id = region.def_id
		world_layer.add_child(region_view)
		return
	var scene_path := str(region.definition().get("scene", ""))
	var packed := load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
	if packed == null:
		SessionLog.error("view", "region_scene_missing", {"region": me.region_id, "scene": scene_path})
		return
	region_view = packed.instantiate() as RegionView
	# Bunker levels share one scene per template: tell the view which level it shows.
	region_view.region_id = region.region_id
	region_view.def_id = region.def_id
	world_layer.add_child(region_view)


func clear_region_view() -> void:
	MachinePanel.close_current()
	if build_mode != null:
		build_mode.cancel()
	if region_view != null and is_instance_valid(region_view):
		world_layer.remove_child(region_view)
		region_view.free()
	region_view = null


func _on_local_region_changed(region_id: String) -> void:
	if region_view == null or region_view.region_id != region_id:
		var me := Session.local_player()
		if me == null or me.vehicle_id == "":
			Audio.play("sfx.ladder")
		# Deferred: the request that moved us may still be running inside the old view.
		build_region_view.call_deferred()


## Frees and rebuilds the region presentation from world data (scene independence).
func rebuild_view() -> void:
	SessionLog.info("view", "rebuild_requested", {})
	build_region_view()


## Developer comparison (iteration 012): switch bunker levels between the new
## side view and the original top-down view. Both show the same bunker.
func toggle_bunker_view() -> void:
	var next := "top" if Settings.bunker_view() == "side" else "side"
	Settings.set_value("dev", "bunker_view", next)
	Session.request_bunker_view(next)
	SessionLog.info("view", "bunker_view_toggled", {"view": next})
	var me := Session.local_player()
	if me != null and SideSection.is_level(me.region_id):
		build_region_view.call_deferred()
	hud.show_notice("DEV_BUNKER_VIEW_" + next.to_upper(), [])


func open_settings() -> void:
	if settings_panel != null:
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(func() -> void: settings_panel = null)
	ui.add_child(settings_panel)


func take_screenshot(path: String, announce: bool = true) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	if path == "":
		path = Paths.screenshots_dir() + "shot_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	SessionLog.info("dev", "screenshot", {"path": ProjectSettings.globalize_path(path), "ok": err == OK})
	if announce:
		Session.notice.emit("DEV_SCREENSHOT_SAVED", [ProjectSettings.globalize_path(path)])
	return path
