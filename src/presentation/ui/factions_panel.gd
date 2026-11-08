class_name FactionsPanel
extends PanelContainer
## Factions screen (J, iteration 015 F). For the local player: each faction met
## (or heard of) with its standing — reputation, tier and a bar — trade credit,
## law standing at Hearth Gate (strikes, banishment) and every active or finished
## mission with its objective progress. Read-only; the host owns all of it.
## The world keeps running while it is open.

var _body: VBoxContainer
var _sig := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -300
	offset_right = 300
	offset_top = -240
	offset_bottom = 240
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UITheme.heading(tr("FACTIONS_TITLE"), 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	var hint := UITheme.small(tr("FACTIONS_HINT"), 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	var close := Button.new()
	close.text = tr("MENU_CLOSE")
	close.pressed.connect(hide)
	v.add_child(close)


func _process(_delta: float) -> void:
	if not visible or not Session.in_world():
		return
	var me := Session.local_player()
	if me == null:
		return
	var rows := rows_for(Session.world, me.player_id)
	var sig := JSON.stringify(rows)
	if sig == _sig:
		return
	_sig = sig
	for c in _body.get_children():
		c.queue_free()
	for r in rows:
		_body.add_child(UITheme.heading(str(r["title"]), 16))
		var desc := UITheme.small(str(r["desc"]), 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.modulate = Color(1, 1, 1, 0.75)
		_body.add_child(desc)
		if r.has("rep"):
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 12)
			bar.show_percentage = false
			bar.min_value = -100
			bar.max_value = 100
			bar.value = int(r["rep"])
			_body.add_child(bar)
		for line in r["lines"]:
			var l := UITheme.small(str(line), 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(l)


## Plain rows for the screen (and tests): [{title, desc, rep?, lines}].
static func rows_for(w: WorldState, pid: String) -> Array:
	var out: Array = []
	var ids := (FactionSim.data().get("factions", {}) as Dictionary).keys()
	ids.sort()
	for fid in ids:
		var f := FactionSim.fdef(str(fid))
		var row := {"title": TranslationServer.translate(str(f.get("name_key", ""))), "desc": TranslationServer.translate(str(f.get("desc_key", ""))), "lines": []}
		if str(f.get("kind", "")) == "hostile":
			row["lines"].append(TranslationServer.translate("FACTION_ALWAYS_HOSTILE"))
			var kills := int((FactionSim.store(w)["kills"].get(pid, {}) as Dictionary).get(str(fid), 0))
			if kills > 0:
				row["lines"].append(UITheme.fmt("FACTION_KILLS", [kills]))
		else:
			var r := FactionSim.rep(w, pid, str(fid))
			row["rep"] = r
			row["lines"].append(UITheme.fmt("FACTION_REP_LINE", [TranslationServer.translate(str(FactionSim.tier(str(fid), r).get("key", "REP_NEUTRAL"))), r]))
			if f.has("trader"):
				row["lines"].append(UITheme.fmt("FACTION_CREDIT", [FactionSim.credit(w, pid)]))
			var law: Dictionary = (FactionSim.store(w)["law"].get(pid, {}) as Dictionary).get(str(fid), {})
			if FactionSim.banished(w, pid, str(fid)):
				row["lines"].append(TranslationServer.translate("LAW_YOU_ARE_BANISHED"))
			elif int(law.get("strikes", 0)) > 0:
				row["lines"].append(UITheme.fmt("LAW_STRIKES", [int(law["strikes"])]))
			for m in f.get("missions", []):
				var mid := str(m.get("id", ""))
				var st := FactionSim.mission_state(w, pid, mid)
				if st == "active":
					var pr := FactionSim.progress(w, pid, mid)
					row["lines"].append(UITheme.fmt("MISSION_LINE_ACTIVE", [TranslationServer.translate(str(m.get("title_key", ""))),
						TranslationServer.translate(str(m.get("desc_key", ""))), int(pr[0]), int(pr[1])]))
				elif st == "done":
					row["lines"].append(UITheme.fmt("MISSION_LINE_DONE", [TranslationServer.translate(str(m.get("title_key", "")))]))
		out.append(row)
	return out
