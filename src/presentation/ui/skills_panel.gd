class_name SkillsPanel
extends PanelContainer
## Skills screen (K, iteration 013). Shows each active skill of the local player:
## level, XP, XP to the next level, a progress bar and what the level does (for
## Scavenging: how long an ordinary search takes now). Read-only; the host owns XP.
## The world keeps running while it is open.

var _body: VBoxContainer
var _sig := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -260
	offset_right = 260
	offset_top = -170
	offset_bottom = 170
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UITheme.heading(tr("SKILLS_TITLE"), 20))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	v.add_child(_body)
	var hint := UITheme.small(tr("SKILLS_HINT"), 12)
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
	var rows := rows_for(me)
	var sig := JSON.stringify(rows)
	if sig == _sig:
		return
	_sig = sig
	for c in _body.get_children():
		c.queue_free()
	for r in rows:
		_body.add_child(UITheme.heading(str(r["title"]), 16))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = float(r["fraction"])
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.09, 0.08, 0.9)
		bg.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.86, 0.74, 0.46)
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		_body.add_child(bar)
		for line in r["lines"]:
			_body.add_child(UITheme.small(str(line), 14))


## Text for each active skill (also used by tests and the autotest driver).
static func rows_for(p: PlayerState) -> Array:
	var out := []
	for skill in SkillSim.ACTIVE:
		var pr := SkillSim.progress(p, skill)
		var title := UITheme.fmt("SKILLS_LEVEL", [TranslationServer.translate(str(SkillSim.cfg(skill).get("display_key", skill))), pr["level"], SkillSim.max_level(skill)])
		var lines: Array = []
		if pr["max"]:
			lines.append(UITheme.fmt("SKILLS_XP_MAX", [pr["xp"]]))
		else:
			lines.append(UITheme.fmt("SKILLS_XP", [pr["xp"], pr["next_total"], int(pr["needed"]) - int(pr["into"])]))
		if skill == "scavenging":
			var now := SkillSim.search_seconds_at("shelf", int(pr["level"]))
			var base := SkillSim.search_seconds_at("shelf", 1)
			lines.append(UITheme.fmt("SKILLS_SCAV_EFFECT", ["%.1f" % now, roundi((1.0 - now / base) * 100.0)]))
			if not pr["max"]:
				lines.append(UITheme.fmt("SKILLS_SCAV_NEXT", ["%.1f" % SkillSim.search_seconds_at("shelf", int(pr["level"]) + 1)]))
		var frac := 1.0 if pr["max"] else float(pr["into"]) / maxf(1.0, float(pr["needed"]))
		out.append({"skill": skill, "title": title, "lines": lines, "fraction": frac, "level": pr["level"], "xp": pr["xp"]})
	return out
