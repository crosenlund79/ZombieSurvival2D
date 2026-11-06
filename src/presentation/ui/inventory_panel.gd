class_name InventoryPanel
extends PanelContainer
## The local player's inventory (I / Tab): what is equipped (hand, body, head,
## face, hands, legs, feet, back), stackable items and gear with icons, a category
## filter, tooltips with every useful attribute, and Use / Equip / Drop buttons.
## Every button is a host request (Session.request_inventory); the panel only
## displays the replicated inventory. Local UI: it never pauses the world.

const SLOTS := ["hand", "body", "head", "face", "hands", "legs", "feet", "back"]

var _title: Label
var _filter: OptionButton
var _list: VBoxContainer
var _sig := ""
var _cat := ""  # "" = all categories
static var _uses: Dictionary = {}  # item -> [recipe / build name keys] (crafting uses, built once)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 20
	offset_right = 500
	offset_top = -320
	offset_bottom = 320
	var v := VBoxContainer.new()
	add_child(v)
	_title = UITheme.heading("", 20)
	v.add_child(_title)
	var fh := HBoxContainer.new()
	fh.add_child(UITheme.small(tr("INV_FILTER"), 14))
	_filter = OptionButton.new()
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.item_selected.connect(func(i: int) -> void:
		_cat = str(_filter.get_item_metadata(i))
		_sig = "")
	fh.add_child(_filter)
	v.add_child(fh)
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
	var sig := JSON.stringify([me.carried, me.gear, me.equipped, me.health, me.hunger, me.hydration, _cat])
	if sig == _sig:
		return
	_sig = sig
	_rebuild(me)


## Categories the player carries something of (for the filter), in catalogue order.
func _categories(me: PlayerState) -> Array:
	var have := {}
	for item in me.carried:
		have[Items.category(str(item))] = true
	for g in me.gear:
		have[Items.category(str(g.get("item", "")))] = true
	var out: Array = []
	for cat in Items.data().get("categories", {}):
		if have.has(cat):
			out.append(cat)
	return out


func _refresh_filter(me: PlayerState) -> void:
	var cats := _categories(me)
	if _cat != "" and not (_cat in cats):
		_cat = ""
	_filter.clear()
	_filter.add_item(tr("CAT_ALL"))
	_filter.set_item_metadata(0, "")
	for cat in cats:
		_filter.add_item(tr(str(Items.data()["categories"][cat])))
		_filter.set_item_metadata(_filter.item_count - 1, cat)
		if cat == _cat:
			_filter.select(_filter.item_count - 1)


func _rebuild(me: PlayerState) -> void:
	_title.text = UITheme.fmt("INV_TITLE", [Inv.slots_used(me), Inv.capacity(me)]) + "  ·  " + UITheme.fmt("INV_WEIGHT", ["%.1f" % Inv.weight(me)])
	_refresh_filter(me)
	for c in _list.get_children():
		c.queue_free()
	_section(tr("INV_EQUIPPED"))
	for slot in SLOTS:
		var g := me.equipped_gear(slot)
		if g.is_empty() and not (slot in ["hand", "body"]):
			continue  # only the slots in use (plus hand and body) to keep the list short
		var row := _row(UITheme.fmt("INV_SLOT_" + slot.to_upper(), [_gear_label(g) if not g.is_empty() else tr("INV_EMPTY_SLOT")]),
			"", str(g.get("item", "")), g)
		if not g.is_empty():
			_button(row, tr("INV_UNEQUIP"), "unequip", slot)
	var gear_rows: Array = []
	for g2 in me.gear:
		if _cat == "" or Items.category(str(g2["item"])) == _cat:
			gear_rows.append(g2)
	if gear_rows.size() > 0:
		_section(tr("INV_GEAR"))
	for g2 in gear_rows:
		var info := Items.info(str(g2["item"]))
		var row2 := _row(_gear_label(g2), _brief(str(g2["item"]), g2), str(g2["item"]), g2)
		var slot2 := str(info.get("slot", ""))
		var equipped := str(me.equipped.get(slot2, "")) == str(g2["uid"])
		if slot2 != "" and not equipped:
			_button(row2, tr("INV_EQUIP"), "equip", str(g2["uid"]))
		if str(info.get("use", "")) != "":
			_button(row2, tr("INV_USE_" + str(info["use"]).to_upper()), "use", str(g2["uid"]))
		_button(row2, tr("INV_DROP"), "drop", str(g2["uid"]))
	_section(tr("INV_ITEMS"))
	var keys: Array = []
	for item in me.carried:
		if _cat == "" or Items.category(str(item)) == _cat:
			keys.append(item)
	if keys.is_empty():
		_list.add_child(UITheme.small(tr("INV_NOTHING"), 14))
	keys.sort_custom(func(a, b): return [Items.category(a), tr(Items.name_key(a))] < [Items.category(b), tr(Items.name_key(b))])
	for item in keys:
		var info2 := Items.info(item)
		var n := me.carrying(item)
		var label := "%s × %d" % [tr(Items.name_key(item)), n]
		if Items.stack_limit(item) > 1:
			label += "  " + UITheme.fmt("INV_STACKS", [Items.slots_of(item, n)])
		var row3 := _row(label, _brief(item, {}), item, {})
		if str(info2.get("use", "")) != "":
			_button(row3, tr("INV_USE_" + str(info2["use"]).to_upper()), "use", item)
		_button(row3, tr("INV_DROP"), "drop", item)


## A one-line summary under the name (the full detail is the tooltip).
func _brief(item: String, g: Dictionary) -> String:
	var lines := describe(item, g).split("\n")
	return "\n".join(lines.slice(0, mini(2, lines.size())))


## Every useful attribute of an item, for tooltips (also used by container and trunk panels).
static func describe(item: String, g: Dictionary = {}) -> String:
	var info := Items.info(item)
	var tr_ := func(k: String) -> String: return TranslationServer.translate(k)
	var bits: Array[String] = []
	if Items.desc_key(item) != "":
		bits.append(tr_.call(Items.desc_key(item)))
	var cat_key := str(Items.data().get("categories", {}).get(Items.category(item), ""))
	bits.append(UITheme.fmt("INV_TIP_BASICS", [tr_.call(cat_key) if cat_key != "" else "", "%.2f" % Items.weight(item), Items.stack_limit(item)]))
	if not g.is_empty() and info.has("durability"):
		bits.append(UITheme.fmt("INV_TIP_COND", [roundi(float(g.get("cond", 0)) / maxf(1.0, float(info["durability"])) * 100.0)]))
	if info.has("food") and str(info.get("use", "")) in ["eat", "drink"]:
		bits.append(UITheme.fmt("INV_TIP_FOOD", ["%+d" % int(info["food"])]))
	if info.has("hydration") and str(info.get("use", "")) in ["eat", "drink"]:
		bits.append(UITheme.fmt("INV_TIP_WATER", ["%+d" % int(info["hydration"])]))
	if info.has("heal"):
		bits.append(UITheme.fmt("INV_TIP_HEAL", [int(info["heal"])]))
	if info.has("health"):
		bits.append(UITheme.fmt("INV_TIP_HEALTH", ["%+d" % int(info["health"])]))
	if info.has("warmth"):
		bits.append(UITheme.fmt("INV_TIP_WARMTH", ["%+d" % int(info["warmth"])]))
	if info.has("insulation"):
		bits.append(UITheme.fmt("INV_STATS_INSULATION", [roundi(float(info["insulation"]) * 100.0)]))
	if info.has("armor"):
		bits.append(UITheme.fmt("INV_STATS_ARMOR", [roundi(float(info["armor"]) * 100.0)]))
	if info.has("carry"):
		bits.append(UITheme.fmt("INV_TIP_CARRY", [int(info["carry"])]))
	var fa: Dictionary = info.get("firearm", {})
	if not fa.is_empty():
		bits.append(UITheme.fmt("INV_TIP_FIREARM", [int(fa.get("damage", 0)), int(fa.get("range", 0)), int(fa.get("capacity", 1)),
			tr_.call(Items.name_key(str(fa.get("ammo", ""))))]))
		if not g.is_empty():
			bits.append(UITheme.fmt("INV_TIP_LOADED", [Firearms.loaded(g), int(fa.get("capacity", 1))]))
	elif info.has("damage"):
		bits.append(UITheme.fmt("INV_STATS_WEAPON", [int(info["damage"]), int(info.get("range", 0)), int(info.get("chop", 1))]))
	for gun in Items.ids():
		var f2: Dictionary = Items.info(gun).get("firearm", {})
		if str(f2.get("ammo", "")) == item or str(f2.get("magazine", "")) == item:
			bits.append(UITheme.fmt("INV_TIP_AMMO_FOR", [tr_.call(Items.name_key(gun))]))
	if info.has("fixes"):
		bits.append(UITheme.fmt("INV_TIP_REPAIRS", [tr_.call("INV_TIP_FIXES_" + str(info.get("fixes", "melee")).to_upper()), int(info.get("repair", 0))]))
	if info.has("burn_seconds"):
		bits.append(UITheme.fmt("INV_TIP_BURNS", [roundi(float(info["burn_seconds"]) / 60.0)]))
	var uses := crafting_uses(item)
	if not uses.is_empty():
		var names: Array[String] = []
		for k in uses.slice(0, 4):
			names.append(tr_.call(str(k)))
		bits.append(UITheme.fmt("INV_TIP_USED_FOR", [", ".join(names)]))
	return "\n".join(bits)


## Recipes and buildables that consume this item (name keys).
static func crafting_uses(item: String) -> Array:
	if _uses.is_empty():
		_uses["_built"] = []
		var recipes := Craft.recipes()
		for rid in recipes:
			var r: Dictionary = recipes[rid]
			var outs: Array = (r.get("out", {}) as Dictionary).keys()
			var key := Items.name_key(str(outs[0])) if not outs.is_empty() else str(rid)
			for i in r.get("in", {}):
				_add_use(str(i), key)
		var defs := Build.defs()
		for bid in defs:
			var d: Dictionary = defs[bid]
			for t in d.get("tiers", []):
				for i2 in (t as Dictionary).get("cost", {}):
					_add_use(str(i2), str(d.get("name_key", bid)))
			for i3 in d.get("cost", {}):
				_add_use(str(i3), str(d.get("name_key", bid)))
	return _uses.get(item, [])


static func _add_use(item: String, key: String) -> void:
	var a: Array = _uses.get(item, [])
	if not (key in a):
		a.append(key)
	_uses[item] = a


## True when arg (item id or gear uid) is a map: reading it opens the map locally.
func _is_map(arg: String) -> bool:
	var me := Session.local_player()
	if me == null:
		return false
	var gi := me.find_gear(arg)
	var item := str(me.gear[gi]["item"]) if gi >= 0 else arg
	return str(Items.info(item).get("use", "")) == "map"


func _gear_label(g: Dictionary) -> String:
	var info := Items.info(str(g.get("item", "")))
	var name := tr(Items.name_key(str(g.get("item", ""))))
	if info.has("durability"):
		var pct := roundi(float(g.get("cond", 0)) / maxf(1.0, float(info["durability"])) * 100.0)
		return UITheme.fmt("INV_GEAR_COND", [name, pct]) if pct > 0 else UITheme.fmt("INV_GEAR_BROKEN", [name])
	return name


func _section(text: String) -> void:
	var l := UITheme.heading(text, 15)
	_list.add_child(l)


func _row(text: String, detail: String = "", item: String = "", g: Dictionary = {}) -> HBoxContainer:
	var outer := HBoxContainer.new()
	if item != "":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Assets.texture(Items.icon_id(item)) if AssetCatalog.has(Items.icon_id(item)) else null
		outer.add_child(icon)
		outer.tooltip_text = describe(item, g)
		icon.tooltip_text = outer.tooltip_text
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(box)
	var l := UITheme.small(text, 15)
	box.add_child(l)
	if detail != "":
		var d := UITheme.small(detail, 12)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.modulate = Color(1, 1, 1, 0.75)
		box.add_child(d)
	var h := HBoxContainer.new()
	box.add_child(h)
	_list.add_child(outer)
	return h


func _button(row: HBoxContainer, text: String, action: String, arg: String) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		Audio.play("ui.click")
		if action == "use" and _is_map(arg) and MapPanel.instance != null:
			hide()
			MapPanel.instance.show()
			return
		Session.request_inventory(action, arg))
	row.add_child(b)
