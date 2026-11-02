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


func _ready() -> void:
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
	if Paths.has_arg("autotest"):
		var driver := AutotestDriver.new()
		driver.main = self
		add_child(driver)


func _process(_delta: float) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	PlayerAvatar.input_blocked = pause_menu.visible or settings_panel != null or menu.visible \
		or (focus is LineEdit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_overlay"):
		dev_overlay.visible = not dev_overlay.visible
	elif event.is_action_pressed("screenshot"):
		take_screenshot("")
	elif not Session.in_world():
		return
	elif event.is_action_pressed("pause_menu") and settings_panel == null:
		pause_menu.visible = not pause_menu.visible
	elif event.is_action_pressed("quick_save"):
		Session.save_world()


func _on_world_started() -> void:
	menu.hide()
	pause_menu.hide()
	build_region_view()


func _on_world_ended(reason_key: String) -> void:
	clear_region_view()
	pause_menu.hide()
	Audio.stop_all_loops()
	menu.show()
	menu.on_session_ended(reason_key)


func build_region_view() -> void:
	clear_region_view()
	var me := Session.local_player()
	if me == null:
		return
	var scene_path := str(Content.region_def(me.region_id).get("scene", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		SessionLog.error("view", "region_scene_missing", {"region": me.region_id, "scene": scene_path})
		return
	region_view = packed.instantiate() as RegionView
	world_layer.add_child(region_view)


func clear_region_view() -> void:
	if region_view != null and is_instance_valid(region_view):
		world_layer.remove_child(region_view)
		region_view.free()
	region_view = null


## Frees and rebuilds the region presentation from world data (scene independence).
func rebuild_view() -> void:
	SessionLog.info("view", "rebuild_requested", {})
	build_region_view()


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
