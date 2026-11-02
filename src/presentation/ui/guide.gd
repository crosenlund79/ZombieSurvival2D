class_name Guide
extends PanelContainer
## Lightweight player guidance (local presentation only):
##  * contextual tips: one short card the first time something becomes
##    relevant (movement, noise, combat, retreating, building, digging,
##    crafting, power and water, food, survivors, a horde warning). Each tip is
##    shown once per installation and can be switched off in the guide.
##  * the survival guide (H): every topic, plus an objectives overview read
##    from the shared world (what the group has achieved so far).
## Reads world data; never changes it.

const TOPICS: Array[String] = ["MOVE", "GATHER", "NOISE", "COMBAT", "RETREAT", "BUILD", "DIG", "CRAFT", "POWER", "FOOD", "SURVIVOR", "SIEGE"]

var _card: PanelContainer
var _card_text: Label
var _body: RichTextLabel
var _current := ""
var _check := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -360
	offset_right = 360
	offset_top = -290
	offset_bottom = 290
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(UITheme.heading(tr("GUIDE_TITLE"), 20))
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 14)
	_body.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(_body)
	var row := HBoxContainer.new()
	v.add_child(row)
	var toggle := CheckBox.new()
	toggle.text = tr("GUIDE_TIPS_ON")
	toggle.button_pressed = tips_enabled()
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value("guide", "tips", on))
	row.add_child(toggle)
	var close := Button.new()
	close.text = tr("MENU_CLOSE")
	close.pressed.connect(hide)
	row.add_child(close)
	hide()
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_card.offset_left = -440
	_card.offset_right = -14
	_card.offset_top = -200
	_card.offset_bottom = -30
	var cv := VBoxContainer.new()
	_card.add_child(cv)
	_card_text = UITheme.small("", 14)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_card_text)
	var ok := Button.new()
	ok.text = tr("GUIDE_GOT_IT")
	ok.pressed.connect(dismiss)
	cv.add_child(ok)
	_card.hide()
	visibility_changed.connect(func() -> void:
		if visible:
			_body.text = guide_text())


## Added next to (not inside) this panel so the card shows while the guide is closed.
func card() -> Control:
	return _card


static func tips_enabled() -> bool:
	return bool(Settings.get_value("guide", "tips", true))


static func seen(key: String) -> bool:
	return bool(Settings.get_value("guide_seen", key, false))


func dismiss() -> void:
	if _current != "":
		Settings.set_value("guide_seen", _current, true)
	_current = ""
	_card.hide()


func show_tip(key: String) -> void:
	if not tips_enabled() or seen(key) or _current == key:
		return
	_current = key
	_card_text.text = tr("TIP_" + key)
	_card.show()


func _process(delta: float) -> void:
	if not Session.in_world():
		_card.hide()
		return
	_check += delta
	if _check < 1.0 or (_card.visible and _current != ""):
		return
	_check = 0.0
	var key := relevant_tip()
	if key != "":
		show_tip(key)


## The first unseen tip whose situation applies right now ("" = none).
func relevant_tip() -> String:
	var w := Session.world
	var me := Session.local_player()
	if me == null:
		return ""
	var underground := not BunkerState.parse_region_id(me.region_id).is_empty()
	var sensor := get_tree().get_first_node_in_group("local_sensor") as InteractionSensor
	var focus := sensor.focused if sensor != null else null
	var conditions := {
		"MOVE": true,
		"GATHER": focus != null and str(Content.entity_def(w.region(me.region_id).def_id if w.region(me.region_id) != null else "", focus.entity_id).get("type", "")) == "tree",
		"NOISE": w.region_def(me.region_id).has("zombies") and w.threat.local_attention(me.region_id, me.position) >= 0.6,
		"COMBAT": _zombie_near(w, me, 260.0),
		"RETREAT": me.health < 50.0 and not me.dead,
		"BUILD": not underground and me.carrying("wood") >= 3,
		"DIG": underground,
		"CRAFT": me.carrying("scrap_metal") >= 1 or (focus != null and focus.prompt_key == "PROMPT_WORKBENCH"),
		"POWER": underground and not InfraSim.is_powered(w, me.region_id),
		"FOOD": me.hunger < 60.0,
		"SURVIVOR": _survivor_known(w),
		"SIEGE": EventSim.phase(w) == "warning",
	}
	for k in TOPICS:
		if bool(conditions.get(k, false)) and not seen(k):
			return k
	return ""


static func _zombie_near(w: WorldState, me: PlayerState, r: float) -> bool:
	for z in w.zombies.values():
		if z.region_id == me.region_id and not z.is_dead() and z.position.distance_to(me.position) < r:
			return true
	return false


static func _survivor_known(w: WorldState) -> bool:
	for n in w.npcs.values():
		if n.recruit != "waiting":
			return true
	return false


## Objectives read from the shared world: [translation key, done].
static func objectives(w: WorldState) -> Array:
	var b: BunkerState = null
	if not w.bunkers.is_empty():
		var ids := w.bunkers.keys()
		ids.sort()
		b = w.bunkers[ids[0]]
	var built := {}
	for rid in w.regions:
		for oid in w.regions[rid].objects:
			built[str(w.regions[rid].objects[oid].get("def", ""))] = true
	var tool := false
	for p in w.players.values():
		for g in p.gear:
			if str(g.get("item", "")) in ["hatchet", "machete", "felling_axe", "padded_jacket"]:
				tool = true
	var recruited := false
	for n in w.npcs.values():
		recruited = recruited or n.recruit in ["home", "travelling"]
	var level := b.level_region(-1) if b != null else ""
	var disc: Dictionary = w.meta.get("discoveries", {})
	var hatch := w.region("homestead.farmhouse")
	return [
		["OBJ_SHELTER", b != null],
		["OBJ_DEFENCES", built.has("barricade") or built.has("spike_trap")],
		["OBJ_POWER", level != "" and InfraSim.is_powered(w, level)],
		["OBJ_WATER", b != null and b.amount("water_clean") > 0],
		["OBJ_WORKBENCH", built.has("workbench")],
		["OBJ_TOOL", tool],
		["OBJ_FOOD", built.has("planter")],
		["OBJ_EXPLORE", disc.has("service_station")],
		["OBJ_DISCOVERY", disc.has("workshop_locker")],
		["OBJ_HATCH", hatch != null and str(hatch.entity_state("homestead.farmhouse.shelter").get("tier", "wood")) == "steel"],
		["OBJ_SURVIVOR", recruited],
		["OBJ_SIEGE", str(EventSim.siege(w).get("outcome", "")) != ""],
	]


func guide_text() -> String:
	var lines: Array[String] = []
	if Session.world != null:
		lines.append("[b]" + tr("GUIDE_OBJECTIVES") + "[/b]")
		for o in objectives(Session.world):
			lines.append(("☑ " if o[1] else "☐ ") + tr(o[0]))
		lines.append("")
	for k in TOPICS:
		lines.append("[b]" + tr("GUIDE_" + k) + "[/b]")
		lines.append(tr("TIP_" + k))
		lines.append("")
	return "\n".join(lines)
