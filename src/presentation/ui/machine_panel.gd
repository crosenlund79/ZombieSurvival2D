class_name MachinePanel
extends PanelContainer
## Small local panel for a machine or container (storage locker, generator,
## purifier). Shows status lines and action buttons; every button only sends
## a request to the host (Session.request_entity_action). Closes when the
## player walks away, presses Esc/E again, or the view is rebuilt. Never pauses.

static var current: MachinePanel

var region_id := ""
var entity_id := ""
var _title: Label
var _lines: Label
var _buttons: VBoxContainer
var _builder: Callable   # func() -> {"title", "lines": [..], "buttons": [[label, action, arg, enabled], ..]}
## func(action, arg) sending the request; default: Session.request_entity_action(entity_id, ...).
var _request: Callable
var _anchor: Node2D
var _sig := ""


static func open(anchor: Node2D, rid: String, eid: String, builder: Callable, request: Callable = Callable()) -> void:
	close_current()
	var p := MachinePanel.new()
	p._request = request
	p.region_id = rid
	p.entity_id = eid
	p._builder = builder
	p._anchor = anchor
	var ui := anchor.get_tree().root.get_node_or_null("Main/CanvasLayer/UIRoot")
	if ui == null:
		for n in anchor.get_tree().get_nodes_in_group("ui_root"):
			ui = n
	if ui == null:
		return
	ui.add_child(p)
	current = p


static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null


const WIDTH := 400.0
const GAP := 26.0

var _pointer: TextureRect
var _grid_box: GridContainer
var _progress: ProgressBar
var _grid_sig := ""
var _scroll: ScrollContainer


func _ready() -> void:
	# Iteration 015: anchored beside the object it belongs to (not a centred dialog):
	# positioned every frame from the object's screen position, flipped near the
	# screen edges and away from the player, with a pointer to the object.
	top_level = true
	custom_minimum_size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UITheme.heading("", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(close_current)
	head.add_child(close)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 10)
	_progress.show_percentage = false
	_progress.visible = false
	v.add_child(_progress)
	_grid_box = GridContainer.new()
	_grid_box.columns = 5
	_grid_box.add_theme_constant_override("h_separation", 6)
	_grid_box.add_theme_constant_override("v_separation", 6)
	_grid_box.visible = false
	v.add_child(_grid_box)
	_lines = UITheme.small("", 14)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lines)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(0, 40)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_buttons)
	_pointer = TextureRect.new()
	_pointer.texture = Assets.texture("ui.pointer") if AssetCatalog.has("ui.pointer") else null
	_pointer.size = Vector2(32, 24)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.top_level = true
	add_child(_pointer)
	_refresh()
	_place()


func _process(_delta: float) -> void:
	var me := Session.local_player()
	if me == null or me.region_id != region_id or not is_instance_valid(_anchor) or me.dead:
		close_current()
		return
	# Measured where the player is drawn (also correct in the side-view bunker, iteration 012).
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var at: Vector2 = avatar.global_position if avatar != null else me.position
	if at.distance_to(_anchor.global_position) > 170.0:
		close_current()
		return
	_refresh()
	_place()


## Puts the panel beside its object on screen: above it if there is room (else below),
## kept inside the screen, moved aside if it would cover the player; the pointer
## always points at the object.
func _place() -> void:
	if not is_instance_valid(_anchor):
		return
	var vp := get_viewport().get_visible_rect().size
	var obj := _anchor.get_global_transform_with_canvas().origin
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var player := avatar.get_global_transform_with_canvas().origin if avatar != null else Vector2(-9999, -9999)
	var sz := get_combined_minimum_size()
	sz.x = maxf(sz.x, WIDTH)
	size = sz
	var above := obj.y - 120.0 - sz.y - GAP > 12.0
	var pos := Vector2(obj.x - sz.x * 0.5, (obj.y - 120.0 - sz.y - GAP) if above else (obj.y + GAP + 10.0))
	pos.x = clampf(pos.x, 12.0, vp.x - sz.x - 12.0)
	pos.y = clampf(pos.y, 12.0, vp.y - sz.y - 12.0)
	var r := Rect2(pos, sz)
	if r.grow(10.0).has_point(player + Vector2(0, -40)):
		# would cover the player: go to whichever side of the object has more room
		pos.x = (obj.x + 60.0) if obj.x < vp.x * 0.5 else (obj.x - 60.0 - sz.x)
		pos.x = clampf(pos.x, 12.0, vp.x - sz.x - 12.0)
	position = pos
	if _pointer.texture != null:
		var px := clampf(obj.x - 16.0, pos.x + 14.0, pos.x + sz.x - 46.0)
		var down := obj.y > pos.y + sz.y
		_pointer.flip_v = not down
		_pointer.position = Vector2(px, (pos.y + sz.y - 3.0) if down else (pos.y - 21.0))
		_pointer.visible = absf(obj.x - (pos.x + sz.x * 0.5)) < sz.x * 0.5 + 40.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact"):
		close_current()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var d: Dictionary = _builder.call()
	_title.text = str(d.get("title", ""))
	_lines.text = "\n".join(d.get("lines", []))
	_lines.visible = _lines.text != ""
	_progress.visible = d.has("progress")
	if d.has("progress"):
		_progress.value = clampf(float(d["progress"]), 0.0, 1.0) * 100.0
	_refresh_grid(d)
	var sig := JSON.stringify(d.get("buttons", []))
	if sig == _sig:
		return
	_sig = sig
	for c in _buttons.get_children():
		c.queue_free()
	# show up to about eight rows before scrolling
	_scroll.custom_minimum_size.y = clampf(float((d.get("buttons", []) as Array).size()) * 40.0, 40.0, 320.0)
	for b in d.get("buttons", []):
		var btn := Button.new()
		btn.text = str(b[0])
		btn.disabled = not bool(b[3])
		var action: String = b[1]
		var arg: Variant = b[2]
		btn.pressed.connect(func() -> void:
			Audio.play("ui.click")
			if _request.is_valid():
				_request.call(action, str(arg))
			else:
				Session.request_entity_action(entity_id, action, arg))
		_buttons.add_child(btn)


## Iteration 015 D: a grid of discovery slots (scavenging). Each cell:
## {"item", "qty", "state": "unknown" | "searching" | "revealed" | "empty", "take": arg}.
## Revealed cells show the real icon and quantity; clicking one takes it.
func _refresh_grid(d: Dictionary) -> void:
	var cells: Array = d.get("grid", [])
	_grid_box.visible = not cells.is_empty()
	var sig := JSON.stringify(cells)
	if sig == _grid_sig:
		return
	_grid_sig = sig
	for c in _grid_box.get_children():
		c.queue_free()
	for cell in cells:
		_grid_box.add_child(_grid_cell(cell, str(d.get("grid_action", "take"))))


func _grid_cell(cell: Dictionary, action: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 66)
	b.focus_mode = Control.FOCUS_NONE
	var st := str(cell.get("state", "unknown"))
	var tex := Assets.texture("ui.slot_selected" if st == "searching" else "ui.slot") if AssetCatalog.has("ui.slot") else null
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(14)
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, sb)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 10
	ic.offset_top = 8
	ic.offset_right = -10
	ic.offset_bottom = -12
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var item := str(cell.get("item", ""))
	match st:
		"revealed":
			ic.texture = Assets.texture(Items.icon_id(item)) if AssetCatalog.has(Items.icon_id(item)) else null
			if int(cell.get("qty", 1)) > 1:
				var q := UITheme.small(str(int(cell["qty"])), 12)
				q.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
				q.add_theme_constant_override("outline_size", 4)
				q.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				q.offset_left = -60
				q.offset_right = -6
				q.offset_top = -20
				q.offset_bottom = -2
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				q.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(q)
			b.tooltip_text = tr(Items.name_key(item)) + "\n" + InventoryPanel.describe(item, cell.get("gear", {}))
			var arg := str(cell.get("take", item))
			b.pressed.connect(func() -> void:
				Audio.play("ui.click")
				if _request.is_valid():
					_request.call(action, arg)
				else:
					Session.request_entity_action(entity_id, action, arg))
		"searching":
			ic.texture = UITheme.icon("search")
			ic.modulate = Color(1, 1, 1, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0))
			b.disabled = true
		"empty":
			b.disabled = true
		_:
			ic.texture = UITheme.icon("search")
			ic.modulate = Color(1, 1, 1, 0.12)
			b.disabled = true
	return b
