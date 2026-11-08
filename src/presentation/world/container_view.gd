class_name ContainerView
extends EntityView
## A searchable container (iteration 013, ScavengeSim). Presentation only:
##  * art by state — the authored "art" until searched, then "art_searched"
##  * a progress bar over it while anyone searches it (from the shared clock,
##    so every player sees the same search)
##  * E: start / stop searching; once searched, E opens a small panel to take
##    what is left. Every action is a host request.
##  * iteration 015 D: E opens the discovery grid (MachinePanel "grid") that fills
##    slot by slot as the host reveals them; locked containers open the
##    LockpickPanel first (Interactable).

const BAR_W := 90.0
var _bar: Node2D
var _rummage := 0.0


func _build() -> void:
	_bar = Node2D.new()
	_bar.name = "SearchBar"
	_bar.z_index = 30
	_bar.visible = false
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	Session.player_resources_changed.connect(func(_p: String) -> void: _refresh("carried"))


func _ready() -> void:
	super._ready()
	if interact != null:
		interact.on_activate = _activate


func _activate() -> void:
	var st := state()
	if bool(st.get("searched", false)):
		MachinePanel.open(self, region_id, entity_id, panel_data, _panel_request)
		return
	# Iteration 015 D: E starts (or resumes) the search and opens the discovery grid
	# beside the container; E on your own running search stops it (progress kept).
	var mine := ScavengeSim.searching(st) == Session.local_player_id
	Session.request_interact(entity_id)
	if not mine:
		MachinePanel.open(self, region_id, entity_id, panel_data, _panel_request)


func _refresh(cause: String) -> void:
	var st := state()
	var searched := bool(st.get("searched", false))
	var art := str(def.get("art_searched" if searched else "art", ""))
	if art != "":
		show_art("Main", art)  # vehicles and other scenery-backed containers have none
	if interact != null:
		var by := ScavengeSim.searching(st)
		var me := Session.local_player_id
		interact.enabled = true
		interact.prompt_args = []
		if searched:
			var n := Inv.box_used(st)
			interact.prompt_key = "PROMPT_CONTAINER_CONTENTS" if n > 0 else "PROMPT_CONTAINER_EMPTY"
			interact.prompt_args = [n]
		elif by == me:
			interact.prompt_key = "PROMPT_STOP_SEARCH"
		elif by != "":
			interact.prompt_key = "PROMPT_BEING_SEARCHED"
			interact.enabled = false
		else:
			interact.prompt_key = str(def.get("prompt_key", "PROMPT_SEARCH_SHELF"))
	match cause:
		"search_started":
			Audio.play("sfx.rummage", global_position)
		"searched":
			Audio.play("sfx.rummage", global_position)
		"search_revealed":
			Audio.play("sfx.rummage", global_position, -4.0)
		"unlocked":
			Audio.play("sfx.door_open" if AssetCatalog.has("sfx.door_open") else "ui.click", global_position)
	set_process(true)


func _process(delta: float) -> void:
	super._process(delta)
	if _bar == null or Session.world == null:
		return
	var st := state()
	var on := ScavengeSim.searching(st) != "" and not bool(st.get("searched", false))
	_bar.visible = on
	if on:
		_bar.position = Vector2(0, _art_top() - 14.0)
		_bar.queue_redraw()
		# soft rummaging while the search lasts (the noise itself is the host's)
		_rummage -= delta
		if _rummage <= 0.0:
			_rummage = 1.6
			Audio.play("sfx.rummage", global_position, -8.0)


func _art_top() -> float:
	var main: Sprite2D = _art_root.get_node_or_null("Main") if _art_root != null else null
	if main == null or main.texture == null:
		return -60.0
	return main.position.y


func _draw_bar() -> void:
	var p := ScavengeSim.progress(Session.world, state())
	var r := Rect2(-BAR_W * 0.5, 0, BAR_W, 9)
	_bar.draw_rect(r.grow(2.0), Color(0.05, 0.05, 0.06, 0.85))
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color(0.86, 0.8, 0.62, 0.95))


## Panel: the discovery grid while searching / once searched (iteration 015 D),
## what is visible can be taken (one stack, or everything).
func panel_data() -> Dictionary:
	var st := state()
	var total := int(st.get("total", 0))
	if total > 0 or not bool(st.get("searched", false)):
		return _grid_data(st, total)
	return _list_data(st)


func _grid_data(st: Dictionary, total: int) -> Dictionary:
	var me := Session.local_player()
	var items: Dictionary = st.get("items", {})
	var gear: Array = st.get("gear", [])
	var searched := bool(st.get("searched", false))
	var by := ScavengeSim.searching(st)
	var revealed := total if searched else int(st.get("revealed", 0))
	var cells: Array = []
	var keys := items.keys()
	keys.sort()
	for item in keys:
		cells.append({"item": str(item), "qty": int(items[item]), "state": "revealed", "take": str(item)})
	for g in gear:
		cells.append({"item": str(g.get("item", "")), "qty": 1, "state": "revealed", "take": str(g.get("uid", "")), "gear": g})
	for _i in maxi(0, revealed - cells.size()):
		cells.append({"state": "empty"})
	var shown := maxi(total, cells.size())
	if not searched:
		if by != "" and cells.size() < shown:
			cells.append({"state": "searching"})
		while cells.size() < shown:
			cells.append({"state": "unknown"})
	var lines: Array[String] = []
	var free := Inv.free_slots(me) if me != null else 0
	lines.append(UITheme.fmt("PANEL_CARRY", [Inv.slots_used(me) if me != null else 0, Inv.capacity(me) if me != null else Items.carry_slots()]))
	var buttons := []
	if not items.is_empty() or not gear.is_empty():
		buttons.append([TranslationServer.translate("CONTAINER_TAKE_ALL"), "take", "*", free > 0])
	var d := {"title": TranslationServer.translate("CONTAINER_" + str(def.get("kind", "shelf")).to_upper()), "grid": cells, "grid_action": "take"}
	if searched:
		lines.append(TranslationServer.translate("SEARCH_GRID_DONE" if not cells.filter(func(c: Dictionary) -> bool: return c["state"] == "revealed").is_empty() else "CONTAINER_NOTHING_LEFT"))
	elif by == Session.local_player_id:
		d["progress"] = (float(revealed) + ScavengeSim.progress(Session.world, st)) / float(maxi(1, total))
		lines.append(UITheme.fmt("SEARCH_GRID_PROGRESS", [revealed, total]))
		buttons.append([TranslationServer.translate("SEARCH_STOP"), "__stop", "", true])
	elif by != "":
		lines.append(TranslationServer.translate("PROMPT_BEING_SEARCHED"))
	else:
		lines.append(UITheme.fmt("SEARCH_GRID_PAUSED", [revealed, total]) if revealed > 0 else TranslationServer.translate("SEARCH_GRID_START"))
		buttons.append([TranslationServer.translate("SEARCH_RESUME" if revealed > 0 else "SEARCH_START"), "__stop", "", true])
	d["lines"] = lines
	d["buttons"] = buttons
	return d


## Grid button actions: "__stop" toggles the search (host request_interact).
func _panel_request(action: String, arg: String) -> void:
	if action == "__stop":
		Session.request_interact(entity_id)
	else:
		Session.request_entity_action(entity_id, action, arg)


func _list_data(st: Dictionary) -> Dictionary:
	var me := Session.local_player()
	var lines: Array[String] = []
	var buttons := []
	var items: Dictionary = st.get("items", {})
	var gear: Array = st.get("gear", [])
	var free := Inv.free_slots(me) if me != null else 0
	lines.append(UITheme.fmt("PANEL_CARRY", [Inv.slots_used(me) if me != null else 0, Inv.capacity(me) if me != null else Items.carry_slots()]))
	for item in items:
		var nm := TranslationServer.translate(Items.name_key(str(item)))
		lines.append(UITheme.fmt("CONTAINER_ITEM_LINE", [nm, int(items[item])]))
		buttons.append([UITheme.fmt("PANEL_TAKE", [nm]), "take", str(item), free > 0])
	for g in gear:
		var gn := TranslationServer.translate(Items.name_key(str(g.get("item", ""))))
		lines.append(gn)
		buttons.append([UITheme.fmt("PANEL_TAKE", [gn]), "take", str(g.get("uid", "")), free > 0])
	if items.is_empty() and gear.is_empty():
		lines.append(TranslationServer.translate("CONTAINER_NOTHING_LEFT"))
	else:
		buttons.push_front([TranslationServer.translate("CONTAINER_TAKE_ALL"), "take", "*", free > 0])
	return {"title": TranslationServer.translate("CONTAINER_" + str(def.get("kind", "shelf")).to_upper()), "lines": lines, "buttons": buttons}
