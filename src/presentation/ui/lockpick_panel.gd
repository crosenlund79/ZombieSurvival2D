class_name LockpickPanel
extends PanelContainer
## A locked door or container (iteration 015 D, LockSim). Anchored beside the
## object like MachinePanel. Offers "Use key" when the player carries the lock's
## key, and the lockpicking game when they carry a lockpick:
##   * the dial is the lock's face; move the mouse across it (or ← / →) to set
##     the pick's angle, click (or Space) to turn;
##   * the host decides every turn: a set pin clicks and lights a pin marker; a
##     miss rattles, tells you how close you were (the needle and its colour) and
##     wears the pick; a worn-out pick snaps and the pins drop;
##   * the panel never knows the answer — it only shows what the host replied.
## Movement is blocked while it is open; Esc / E closes it. Never pauses.

static var current: LockpickPanel

const WIDTH := 380.0
const GAP := 26.0
const DIAL := Vector2(340, 196)

var region_id := ""
var entity_id := ""
var _anchor: Node2D
var _title: Label
var _info: Label
var _status: Label
var _dial: Control
var _key_btn: Button
var _angle := 0.5
var _last := {}          # last host reply {set, pins, closeness, result}
var _shake := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _hint_angle := -1.0  # where the last miss was tried
var _pending := false


static func open(anchor: Node2D, rid: String, eid: String) -> void:
	close_current()
	MachinePanel.close_current()
	var p := LockpickPanel.new()
	p.region_id = rid
	p.entity_id = eid
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


static func is_open() -> bool:
	return current != null and is_instance_valid(current)


func _ready() -> void:
	top_level = true
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UITheme.heading("", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(close_current)
	head.add_child(close)
	_info = UITheme.small("", 13)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	_dial = Control.new()
	_dial.custom_minimum_size = DIAL
	_dial.mouse_filter = Control.MOUSE_FILTER_STOP
	_dial.draw.connect(_draw_dial)
	_dial.gui_input.connect(_dial_input)
	v.add_child(_dial)
	_status = UITheme.small("", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	_key_btn = Button.new()
	_key_btn.pressed.connect(func() -> void:
		Audio.play("ui.click")
		Session.request_entity_action(entity_id, "key", ""))
	v.add_child(_key_btn)
	Session.lock_feedback.connect(_on_feedback)
	Session.request_entity_action(entity_id, "status", "")
	_refresh()
	_place()


func _exit_tree() -> void:
	if current == self:
		current = null


func _region() -> RegionState:
	return Session.world.region(region_id) if Session.world != null else null


func _def() -> Dictionary:
	var r := _region()
	return r.entity_def(entity_id) if r != null else {}


func _has_pick() -> bool:
	var me := Session.local_player()
	return me != null and me.has_gear_item(LockSim.PICK_ITEM)


func _pick_cond() -> float:
	var me := Session.local_player()
	if me == null:
		return 0.0
	var top := float(Items.info(LockSim.PICK_ITEM).get("durability", 100))
	for g in me.gear:
		if str(g.get("item", "")) == LockSim.PICK_ITEM:
			return clampf(float(g.get("cond", top)) / top, 0.0, 1.0)
	return 0.0


func _key_item() -> String:
	return str(LockSim.lock_def(_def()).get("key", ""))


func _has_key() -> bool:
	var me := Session.local_player()
	var k := _key_item()
	return me != null and k != "" and (me.carrying(k) > 0 or me.has_gear_item(k))


func _refresh() -> void:
	var def := _def()
	var lvl := LockSim.level(def)
	_title.text = UITheme.fmt("LOCK_TITLE", [TranslationServer.translate("LOCK_LEVEL_%d" % lvl)])
	var k := _key_item()
	_key_btn.visible = k != ""
	if k != "":
		var kn := TranslationServer.translate(Items.name_key(k))
		_key_btn.text = UITheme.fmt("LOCK_USE_KEY", [kn]) if _has_key() else UITheme.fmt("LOCK_NEED_KEY", [kn])
		_key_btn.disabled = not _has_key()
	_dial.visible = _has_pick()
	if _has_pick():
		_info.text = UITheme.fmt("LOCK_PICK_INFO", [int(round(_pick_cond() * 100.0))])
	else:
		_info.text = TranslationServer.translate("LOCK_NO_PICK")
	if _status.text == "":
		_status.text = TranslationServer.translate("LOCK_HOW") if _has_pick() else ""


func _process(delta: float) -> void:
	var me := Session.local_player()
	var r := _region()
	if me == null or me.dead or me.region_id != region_id or r == null or not is_instance_valid(_anchor):
		close_current()
		return
	if not LockSim.is_locked(r, entity_id):
		close_current()
		return
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	var at: Vector2 = avatar.global_position if avatar != null else me.position
	if at.distance_to(_anchor.global_position) > 190.0:
		close_current()
		return
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_refresh()
	_place()
	_dial.queue_redraw()


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var obj := _anchor.get_global_transform_with_canvas().origin
	var sz := get_combined_minimum_size()
	sz.x = maxf(sz.x, WIDTH)
	size = sz
	var above := obj.y - 120.0 - sz.y - GAP > 12.0
	var pos := Vector2(obj.x - sz.x * 0.5, (obj.y - 120.0 - sz.y - GAP) if above else (obj.y + GAP + 10.0))
	pos.x = clampf(pos.x, 12.0, vp.x - sz.x - 12.0)
	pos.y = clampf(pos.y, 12.0, vp.y - sz.y - 12.0)
	var avatar := get_tree().get_first_node_in_group("local_avatar") as Node2D
	if avatar != null:
		var player := avatar.get_global_transform_with_canvas().origin
		if Rect2(pos, sz).grow(10.0).has_point(player + Vector2(0, -40)):
			pos.x = clampf((obj.x + 60.0) if obj.x < vp.x * 0.5 else (obj.x - 60.0 - sz.x), 12.0, vp.x - sz.x - 12.0)
	position = pos


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("interact"):
		close_current()
		get_viewport().set_input_as_handled()
		return
	if not _has_pick():
		return
	var k := event as InputEventKey
	if k != null and k.pressed:
		match k.keycode:
			KEY_LEFT, KEY_A:
				_angle = clampf(_angle - (0.005 if k.shift_pressed else 0.02), 0.0, 1.0)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_angle = clampf(_angle + (0.005 if k.shift_pressed else 0.02), 0.0, 1.0)
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER:
				_turn()
				get_viewport().set_input_as_handled()


func _dial_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		_angle = _angle_at(mm.position)
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_angle = _angle_at(mb.position)
		_turn()
		_dial.accept_event()


## Angle 0..1 = left to right across the dial's half circle.
func _angle_at(p: Vector2) -> float:
	var c := Vector2(DIAL.x * 0.5, DIAL.y - 16.0)
	var a := (p - c).angle()  # -PI (left) .. 0 (right), negative is up
	if a > 0.0:
		a = -PI if p.x < c.x else 0.0
	return clampf((a + PI) / PI, 0.0, 1.0)


func _turn() -> void:
	if _pending and Time.get_ticks_msec() < int(_last.get("_t", 0)) + 600:
		return
	_pending = true
	_last["_t"] = Time.get_ticks_msec()
	Audio.play("sfx.hit_metal", _anchor.global_position, -18.0)
	Session.request_entity_action(entity_id, "pick", "%.4f" % _angle)


func _on_feedback(info: Dictionary) -> void:
	if str(info.get("entity_id", "")) != entity_id:
		return
	_pending = false
	var t: int = int(_last.get("_t", 0))
	_last = info.duplicate()
	_last["_t"] = t
	match str(info.get("result", "")):
		"status":
			pass
		"set":
			Audio.play("ui.click", _anchor.global_position, 2.0)
			_flash = 1.0
			_flash_col = Color(0.62, 0.86, 0.55)
			_hint_angle = -1.0
			_status.text = UITheme.fmt("LOCK_PIN_SET", [int(info.get("set", 0)), int(info.get("pins", 0))])
		"open":
			Audio.play("sfx.door_open", _anchor.global_position)
			_status.text = TranslationServer.translate("UNLOCKED_PICK")
		"miss":
			Audio.play("sfx.hit_metal", _anchor.global_position, -8.0)
			_shake = 1.0
			_hint_angle = _angle
			var c := float(info.get("closeness", 0.0))
			_flash = 0.9
			_flash_col = Color(0.92, 0.72, 0.3).lerp(Color(0.85, 0.3, 0.22), 1.0 - c)
			_status.text = TranslationServer.translate("LOCK_CLOSE_3" if c > 0.75 else ("LOCK_CLOSE_2" if c > 0.5 else ("LOCK_CLOSE_1" if c > 0.25 else "LOCK_CLOSE_0")))
		"broken":
			Audio.play("sfx.struct_break", _anchor.global_position, -6.0)
			_shake = 1.6
			_flash = 1.0
			_flash_col = Color(0.85, 0.2, 0.18)
			_hint_angle = -1.0
			_status.text = TranslationServer.translate("LOCKPICK_BROKE")


func _draw_dial() -> void:
	var c := Vector2(DIAL.x * 0.5, DIAL.y - 16.0)
	c.x += sin(Time.get_ticks_msec() / 25.0) * 4.0 * _shake
	var r := DIAL.y - 52.0
	var ink := Color(0.12, 0.1, 0.09, 0.95)
	var paper := Color(0.82, 0.76, 0.62, 0.9)
	# the lock face: a worn brass half disc with tick marks, on a dark rim
	var rim := PackedVector2Array([c + Vector2(r + 8.0, 6.0), c + Vector2(-r - 8.0, 6.0)])
	for i in 41:
		rim.append(c + Vector2.from_angle(PI + PI * float(i) / 40.0) * (r + 8.0))
	_dial.draw_colored_polygon(rim, Color(0.08, 0.07, 0.06, 0.9))
	var face := PackedVector2Array([c])
	for i in 41:
		face.append(c + Vector2.from_angle(PI + PI * float(i) / 40.0) * r)
	_dial.draw_colored_polygon(face, Color(0.52, 0.42, 0.24).lerp(_flash_col, _flash * 0.45))
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		var l := 12.0 if i % 5 == 0 else 6.0
		_dial.draw_line(c + Vector2.from_angle(a) * (r - l), c + Vector2.from_angle(a) * (r - 1.0), ink, 2.0)
	# the keyway
	_dial.draw_rect(Rect2(c + Vector2(-5, -26), Vector2(10, 26)), ink)
	# the last miss: a faint mark where it was tried
	if _hint_angle >= 0.0:
		var ha := PI + PI * _hint_angle
		_dial.draw_line(c + Vector2.from_angle(ha) * 24.0, c + Vector2.from_angle(ha) * (r - 4.0), Color(_flash_col, 0.55), 3.0)
	# the pick
	var pa := PI + PI * _angle
	var tip := c + Vector2.from_angle(pa) * (r - 6.0)
	_dial.draw_line(c, tip, Color(0.08, 0.08, 0.09), 6.0)
	_dial.draw_line(c, tip, Color(0.72, 0.72, 0.7), 3.0)
	_dial.draw_circle(c, 7.0, Color(0.72, 0.72, 0.7))
	# pins: one marker per pin, lit once set
	var pins := LockSim.pins(_def())
	var set_n := int(_last.get("set", 0))
	for i in pins:
		var x := DIAL.x * 0.5 + (float(i) - (pins - 1) * 0.5) * 26.0
		var lit := i < set_n
		var pr := Rect2(Vector2(x - 8.0, 4.0), Vector2(16, 22))
		_dial.draw_rect(pr, Color(0.62, 0.86, 0.55) if lit else Color(0.1, 0.09, 0.08, 0.9))
		_dial.draw_rect(pr, paper, false, 2.0)
	# pick wear along the bottom edge
	var w := _pick_cond()
	_dial.draw_rect(Rect2(Vector2(6, DIAL.y - 5), Vector2(DIAL.x - 12, 4)), Color(0.08, 0.07, 0.06, 0.9))
	_dial.draw_rect(Rect2(Vector2(6, DIAL.y - 5), Vector2((DIAL.x - 12) * w, 4)), Color(0.85, 0.3, 0.22).lerp(paper, w))
