class_name InventoryPanel
extends PanelContainer
## The local player's inventory (I / Tab). Iteration 015 redesign:
##   left    the equipment slots (hand, body, head, face, hands, legs, feet, back)
##   centre  a grid of item tiles — icon, quantity, condition — filtered by category
##   right   the selected item: large icon, name, every useful attribute and its
##           actions (Use / Equip / Put away / Drop)
## Hover any tile for the same details as a tooltip. Every action is a host
## request (Session.request_inventory); the panel only shows the replicated
## inventory. Local UI: it never pauses the world.

const SLOTS := ["hand", "body", "head", "face", "hands", "legs", "feet", "back"]
const TILE := 64.0
const COLS := 6

var _title: Label
var _filter: OptionButton
var _equip: VBoxContainer
var _grid: GridContainer
var _detail: VBoxContainer
var _sig := ""
var _cat := ""          # "" = all categories
var _selected := ""     # item id or gear uid
static var _uses: Dictionary = {}  # item -> [recipe / build name keys] (crafting uses, built once)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -560
	offset_right = 560
	offset_top = -330
	offset_bottom = 330
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UITheme.icon_rect("bag", 28))
	_title = UITheme.heading("", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(UITheme.small(tr("INV_FILTER"), 14))
	_filter = OptionButton.new()
	_filter.custom_minimum_size = Vector2(220, 0)
	_filter.item_selected.connect(func(i: int) -> void:
		_cat = str(_filter.get_item_metadata(i))
		_sig = "")
	head.add_child(_filter)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(hide)
	head.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	# equipment column
	var eq_scroll := ScrollContainer.new()
	eq_scroll.custom_minimum_size = Vector2(250, 0)
	eq_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(eq_scroll)
	_equip = VBoxContainer.new()
	_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq_scroll.add_child(_equip)
	# item grid
	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(COLS * (TILE + 6) + 16, 0)
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	grid_scroll.add_child(_grid)
	# detail pane
	var det := PanelContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_stylebox_override("panel", UITheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	body.add_child(det)
	_detail = VBoxContainer.new()
	det.add_child(_detail)
	visibility_changed.connect(func() -> void: _sig = "")


func _process(_delta: float) -> void:
	if not visible:
		return
	var me := Session.local_player() if Session.in_world() else null
	if me == null:
		hide()
		return
	var sig := JSON.stringify([me.carried, me.gear, me.equipped, me.health, me.hunger, me.hydration, _cat, _selected])
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
	for c in _equip.get_children() + _grid.get_children() + _detail.get_children():
		c.queue_free()
	# equipment slots
	_equip.add_child(UITheme.heading(tr("INV_EQUIPPED"), 15))
	for slot in SLOTS:
		var g := me.equipped_gear(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_equip.add_child(row)
		var t := _tile(str(g.get("item", "")), 0, g, str(g.get("uid", "")) if not g.is_empty() else "", 44.0)
		row.add_child(t)
		var lab := UITheme.small(UITheme.fmt("INV_SLOT_" + slot.to_upper(), [_gear_label(g) if not g.is_empty() else tr("INV_EMPTY_SLOT")]), 13)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
	# the grid: gear first, then stacks (one tile per stack slot's worth)
	var count := 0
	for g2 in me.gear:
		if _cat == "" or Items.category(str(g2["item"])) == _cat:
			var equipped := str(me.equipped.get(str(Items.info(str(g2["item"])).get("slot", "")), "")) == str(g2["uid"])
			var tile := _tile(str(g2["item"]), 0, g2, str(g2["uid"]))
			if equipped:
				tile.modulate = Color(0.75, 0.75, 0.75)
			_grid.add_child(tile)
			count += 1
	var keys: Array = []
	for item in me.carried:
		if _cat == "" or Items.category(str(item)) == _cat:
			keys.append(item)
	keys.sort_custom(func(a, b): return [Items.category(a), tr(Items.name_key(a))] < [Items.category(b), tr(Items.name_key(b))])
	for item in keys:
		_grid.add_child(_tile(item, me.carrying(item), {}, item))
		count += 1
	for k in range(count, maxi(count, Inv.capacity(me))):
		if _cat != "":
			break
		_grid.add_child(_tile("", 0, {}, ""))  # empty slots show how much room is left
	_fill_detail(me)


## One inventory tile: slot frame, icon, quantity / condition; click selects it.
func _tile(item: String, qty: int, g: Dictionary, key: String, px: float = TILE) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	var sel := key != "" and key == _selected
	var tex := Assets.texture("ui.slot_selected" if sel else "ui.slot") if AssetCatalog.has("ui.slot") else null
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(14)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
	if item != "":
		var ic := TextureRect.new()
		ic.texture = Assets.texture(Items.icon_id(item)) if AssetCatalog.has(Items.icon_id(item)) else null
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = px * 0.14
		ic.offset_top = px * 0.12
		ic.offset_right = -px * 0.14
		ic.offset_bottom = -px * 0.16
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var corner := ""
		if qty > 1:
			corner = str(qty)
		elif not g.is_empty() and Items.info(item).has("durability"):
			corner = "%d%%" % roundi(float(g.get("cond", 0)) / maxf(1.0, float(Items.info(item)["durability"])) * 100.0)
		if corner != "":
			var q := UITheme.small(corner, 12)
			q.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			q.add_theme_constant_override("outline_size", 4)
			q.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			q.offset_left = -px
			q.offset_right = -6
			q.offset_top = -20
			q.offset_bottom = -2
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(q)
		b.tooltip_text = tr(Items.name_key(item)) + "\n" + describe(item, g)
		b.pressed.connect(func() -> void:
			Audio.play("ui.click")
			_selected = key
			_sig = "")
	else:
		b.disabled = true
	return b


## The right-hand pane: the selected item in full, with its actions.
func _fill_detail(me: PlayerState) -> void:
	var gi := me.find_gear(_selected)
	var item := str(me.gear[gi]["item"]) if gi >= 0 else _selected
	if item == "" or (gi < 0 and me.carrying(item) <= 0):
		_selected = ""
		var hint := UITheme.small(tr("INV_SELECT_HINT"), 14)
		hint.add_theme_color_override("font_color", UITheme.CHARCOAL)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(hint)
		return
	var g: Dictionary = me.gear[gi] if gi >= 0 else {}
	var top := HBoxContainer.new()
	_detail.add_child(top)
	var big := TextureRect.new()
	big.texture = Assets.texture(Items.icon_id(item)) if AssetCatalog.has(Items.icon_id(item)) else null
	big.custom_minimum_size = Vector2(72, 72)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(big)
	var name := UITheme.heading(tr(Items.name_key(item)) + ("  × %d" % me.carrying(item) if gi < 0 and me.carrying(item) > 1 else ""), 18)
	name.add_theme_color_override("font_color", UITheme.CHARCOAL)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var d := UITheme.small(describe(item, g), 13)
	d.add_theme_color_override("font_color", UITheme.CHARCOAL)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(d)
	var row := HFlowContainer.new()
	_detail.add_child(row)
	var info := Items.info(item)
	var slot := str(info.get("slot", ""))
	if gi >= 0 and slot != "":
		if str(me.equipped.get(slot, "")) == _selected:
			_button(row, tr("INV_UNEQUIP"), "unequip", slot)
		else:
			_button(row, tr("INV_EQUIP"), "equip", _selected)
	if str(info.get("use", "")) != "":
		_button(row, tr("INV_USE_" + str(info["use"]).to_upper()), "use", _selected)
	_button(row, tr("INV_DROP"), "drop", _selected)


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


func _button(row: Container, text: String, action: String, arg: String) -> void:
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
