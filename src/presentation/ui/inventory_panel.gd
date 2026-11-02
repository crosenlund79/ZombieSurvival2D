class_name InventoryPanel
extends PanelContainer
## The local player's inventory (I / Tab): what is equipped, stackable items
## and gear with descriptions and stats, and Use / Equip / Drop buttons.
## Every button is a host request (Session.request_inventory); the panel only
## displays the replicated inventory. Local UI: it never pauses the world.

var _title: Label
var _list: VBoxContainer
var _sig := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 20
	offset_right = 460
	offset_top = -300
	offset_bottom = 300
	var v := VBoxContainer.new()
	add_child(v)
	_title = UITheme.heading("", 20)
	v.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = tr("MENU_CLOSE")
	close.pressed.connect(hide)
	v.add_child(close)
	visibility_changed.connect(func() -> void: _sig = "")


func _process(_delta: float) -> void:
	if not visible:
		return
	var me := Session.local_player() if Session.in_world() else null
	if me == null:
		hide()
		return
	var sig := JSON.stringify([me.carried, me.gear, me.equipped, me.health, me.hunger, me.hydration])
	if sig == _sig:
		return
	_sig = sig
	_rebuild(me)


func _rebuild(me: PlayerState) -> void:
	_title.text = UITheme.fmt("INV_TITLE", [Inv.slots_used(me), Items.carry_slots()])
	for c in _list.get_children():
		c.queue_free()
	_section(tr("INV_EQUIPPED"))
	for slot in ["hand", "body"]:
		var g := me.equipped_gear(slot)
		var row := _row(UITheme.fmt("INV_SLOT_" + slot.to_upper(), [_gear_label(g) if not g.is_empty() else tr("INV_EMPTY_SLOT")]))
		if not g.is_empty():
			_button(row, tr("INV_UNEQUIP"), "unequip", slot)
	if me.gear.size() > 0:
		_section(tr("INV_GEAR"))
	for g2 in me.gear:
		var info := Items.info(str(g2["item"]))
		var row2 := _row(_gear_label(g2), _stats(str(g2["item"])))
		var slot2 := str(info.get("slot", ""))
		var equipped := str(me.equipped.get(slot2, "")) == str(g2["uid"])
		if slot2 != "" and not equipped:
			_button(row2, tr("INV_EQUIP"), "equip", str(g2["uid"]))
		if str(info.get("use", "")) != "":
			_button(row2, tr("INV_USE_" + str(info["use"]).to_upper()), "use", str(g2["uid"]))
		_button(row2, tr("INV_DROP"), "drop", str(g2["uid"]))
	_section(tr("INV_ITEMS"))
	if me.carried.is_empty():
		_list.add_child(UITheme.small(tr("INV_NOTHING"), 14))
	var keys := me.carried.keys()
	keys.sort()
	for item in keys:
		var info2 := Items.info(item)
		var row3 := _row("%s × %d" % [tr(Items.name_key(item)), me.carrying(item)], tr(Items.desc_key(item)))
		if str(info2.get("use", "")) != "":
			_button(row3, tr("INV_USE_" + str(info2["use"]).to_upper()), "use", item)
		_button(row3, tr("INV_DROP"), "drop", item)


func _gear_label(g: Dictionary) -> String:
	var info := Items.info(str(g.get("item", "")))
	var name := tr(Items.name_key(str(g.get("item", ""))))
	if info.has("durability"):
		var pct := roundi(float(g.get("cond", 0)) / maxf(1.0, float(info["durability"])) * 100.0)
		return UITheme.fmt("INV_GEAR_COND", [name, pct]) if pct > 0 else UITheme.fmt("INV_GEAR_BROKEN", [name])
	return name


func _stats(item: String) -> String:
	var info := Items.info(item)
	var bits: Array[String] = [tr(Items.desc_key(item))]
	if info.has("damage"):
		bits.append(UITheme.fmt("INV_STATS_WEAPON", [int(info["damage"]), int(info.get("range", 0)), int(info.get("chop", 1))]))
	if info.has("armor"):
		bits.append(UITheme.fmt("INV_STATS_ARMOR", [roundi(float(info["armor"]) * 100.0)]))
	return "\n".join(bits)


func _section(text: String) -> void:
	var l := UITheme.heading(text, 15)
	_list.add_child(l)


func _row(text: String, detail: String = "") -> HBoxContainer:
	var box := VBoxContainer.new()
	var l := UITheme.small(text, 15)
	box.add_child(l)
	if detail != "":
		var d := UITheme.small(detail, 12)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.modulate = Color(1, 1, 1, 0.75)
		box.add_child(d)
	var h := HBoxContainer.new()
	box.add_child(h)
	_list.add_child(box)
	return h


func _button(row: HBoxContainer, text: String, action: String, arg: String) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Audio.play("ui.click")
		Session.request_inventory(action, arg))
	row.add_child(b)
