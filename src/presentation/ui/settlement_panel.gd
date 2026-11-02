class_name SettlementPanel
extends PanelContainer
## Settlement overview (N): inhabitants, their jobs and what blocks them,
## food / water / fuel in shared storage, power, and what the bunker needs.
## Assigning work here is a host request; the panel never pauses the world.

var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _sig := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -320
	offset_right = 320
	offset_top = -260
	offset_bottom = 260
	var v := VBoxContainer.new()
	add_child(v)
	_title = UITheme.heading(tr("SETTLEMENT_TITLE"), 20)
	v.add_child(_title)
	_body = UITheme.small("", 14)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_body)
	_buttons = VBoxContainer.new()
	v.add_child(_buttons)
	var close := Button.new()
	close.text = tr("MENU_CLOSE")
	close.pressed.connect(hide)
	v.add_child(close)


func _process(_delta: float) -> void:
	if not visible or not Session.in_world():
		return
	var d := overview(Session.world)
	_body.text = "\n".join(d["lines"])
	var sig := JSON.stringify(d["buttons"])
	if sig == _sig:
		return
	_sig = sig
	for c in _buttons.get_children():
		c.queue_free()
	for b in d["buttons"]:
		var btn := Button.new()
		btn.text = str(b[0])
		btn.disabled = not bool(b[3])
		var npc: String = b[1]
		var job: String = b[2]
		btn.pressed.connect(func() -> void:
			Audio.play("ui.click")
			Session.request_npc(npc, "assign", job))
		_buttons.add_child(btn)


## Text lines and job buttons [label, npc_id, job, enabled] for the overview.
static func overview(w: WorldState) -> Dictionary:
	var lines: Array = []
	var buttons: Array = []
	var b: BunkerState = null
	if not w.bunkers.is_empty():
		var ids := w.bunkers.keys()
		ids.sort()
		b = w.bunkers[ids[0]]
	if b == null:
		lines.append(TranslationServer.translate("SETTLEMENT_NO_SHELTER"))
		return {"lines": lines, "buttons": buttons}
	var food := b.amount("potato") + b.amount("canned_food")
	lines.append(UITheme.fmt("SETTLEMENT_SUPPLIES", [food, b.amount("water_clean"), b.amount("water_dirty"), b.amount("fuel")]))
	var level := b.level_region(-1)
	lines.append(TranslationServer.translate("SETTLEMENT_POWER_ON" if InfraSim.is_powered(w, level) else "SETTLEMENT_POWER_OFF"))
	var people := 0
	for n in w.npcs.values():
		if n.recruit in ["home", "travelling"]:
			people += 1
			lines.append("")
			lines.append(UITheme.fmt("SETTLEMENT_PERSON", [n.name, TranslationServer.translate("JOB_" + (n.job if n.job != "" else "NONE").to_upper()),
				TranslationServer.translate("NPC_ACT_" + n.activity.to_upper())]))
			if n.status != "":
				lines.append("   " + TranslationServer.translate(n.status))
			if not n.fed:
				lines.append("   " + TranslationServer.translate("NPC_STATUS_UNFED"))
			for job in NpcSim.JOBS:
				buttons.append([UITheme.fmt("SETTLEMENT_ASSIGN", [n.name, TranslationServer.translate("JOB_" + (job if job != "" else "NONE").to_upper())]),
					n.npc_id, job, n.job != job])
	if people == 0:
		lines.append(TranslationServer.translate("SETTLEMENT_NOBODY"))
	var needs: Array[String] = []
	if food < people * 2:
		needs.append(TranslationServer.translate("NEED_FOOD"))
	if b.amount("water_clean") < people * 2:
		needs.append(TranslationServer.translate("NEED_WATER"))
	if b.amount("fuel") == 0 and not InfraSim.is_powered(w, level):
		needs.append(TranslationServer.translate("NEED_FUEL"))
	lines.append("")
	lines.append(UITheme.fmt("SETTLEMENT_NEEDS", [", ".join(needs) if not needs.is_empty() else TranslationServer.translate("NEED_NOTHING")]))
	return {"lines": lines, "buttons": buttons}


## The survivor's own panel (talking to them at home).
static func npc_panel(npc_id: String) -> Dictionary:
	var w := Session.world
	var n: NpcState = w.npcs.get(npc_id)
	if n == null:
		return {"title": "", "lines": [], "buttons": []}
	var lines: Array = [TranslationServer.translate(n.desc_key),
		UITheme.fmt("SETTLEMENT_PERSON", [n.name, TranslationServer.translate("JOB_" + (n.job if n.job != "" else "NONE").to_upper()),
			TranslationServer.translate("NPC_ACT_" + n.activity.to_upper())])]
	if n.status != "":
		lines.append(TranslationServer.translate(n.status))
	if not n.fed:
		lines.append(TranslationServer.translate("NPC_STATUS_UNFED"))
	var buttons: Array = []
	for job in NpcSim.JOBS:
		buttons.append([TranslationServer.translate("JOB_ASSIGN_" + (job if job != "" else "NONE").to_upper()), "assign", job, n.job != job])
	return {"title": n.name, "lines": lines, "buttons": buttons}
