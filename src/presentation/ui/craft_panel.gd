class_name CraftPanel
extends RefCounted
## Workbench panel contents (shown in a MachinePanel): the current job and its
## progress, finished goods to collect, every recipe with its materials and
## time (locked ones say so), and repair buttons for worn gear you carry.
## Buttons only send requests (Session.request_object); the host decides.


static func open_for(anchor: StructureView, rid: String, oid: String) -> void:
	MachinePanel.open(anchor, rid, oid, func() -> Dictionary: return data(rid, oid, anchor), func(action: String, arg: String) -> void:
		Session.request_object(oid, action, arg))


static func data(rid: String, oid: String, anchor: StructureView) -> Dictionary:
	var w := Session.world
	var me := Session.local_player()
	var o: Dictionary = w.region(rid).objects.get(oid, {}) if w != null and w.region(rid) != null else {}
	if o.is_empty() or me == null:
		return {"title": "", "lines": [], "buttons": []}
	var lines: Array = []
	var buttons: Array = []
	var out: Dictionary = o.get("output", {})
	var ready := Hud.bag_text(out.get("items", {})) if not (out.get("items", {}) as Dictionary).is_empty() else ""
	ready += Hud.gear_text(out.get("gear", [])).trim_prefix(" · ") if ready == "" else Hud.gear_text(out.get("gear", []))
	if o.get("job") is Dictionary:
		var job: Dictionary = o["job"]
		var frac := clampf(float(w.tick - int(job.get("started", 0))) / maxf(1.0, float(job.get("ticks", 1))), 0.0, 1.0)
		lines.append(UITheme.fmt("CRAFT_WORKING", [_out_name(str(job.get("recipe", ""))), roundi(frac * 100.0)]))
	elif ready != "":
		lines.append(UITheme.fmt("CRAFT_READY", [ready]))
	else:
		lines.append(TranslationServer.translate("CRAFT_IDLE"))
	if ready != "":
		buttons.append([TranslationServer.translate("CRAFT_COLLECT"), "collect", "", true])
	var bags := Inv.sources(w, me)
	for id in Craft.order():
		var r := Craft.recipe(id)
		var name := _out_name(id)
		if not Craft.unlocked(w, id):
			buttons.append([UITheme.fmt("CRAFT_LOCKED", [name]), "craft", id, false])
			continue
		var ok := Inv.missing(bags, r.get("in", {})).is_empty() and not o.has("job") and ready == ""
		buttons.append([UITheme.fmt("CRAFT_RECIPE", [name, Items.describe(r.get("in", {})), int(r.get("seconds", 5))]), "craft", id, ok])
	for g in me.gear:
		var info := Items.info(str(g["item"]))
		if info.has("durability") and float(g.get("cond", 0)) < float(info["durability"]):
			buttons.append([UITheme.fmt("CRAFT_REPAIR", [TranslationServer.translate(Items.name_key(str(g["item"]))), Items.describe(info.get("repair", {}))]),
				"repair_gear", str(g["uid"]), true])
	if Build.is_built(o) and float(o.get("hp", 0)) < Build.max_hp(o):
		buttons.append([UITheme.fmt("STRUCT_REPAIR", [Items.describe({str(Build.tier_of(o).get("repair_item", "wood")): 1})]), "repair", "", true])
	buttons.append([TranslationServer.translate("STRUCT_DISMANTLE"), "dismantle", "", not o.has("job")])
	return {"title": TranslationServer.translate("CRAFT_TITLE"), "lines": lines, "buttons": buttons}


static func _out_name(recipe_id: String) -> String:
	var outs: Dictionary = Craft.recipe(recipe_id).get("out", {})
	var bits: Array[String] = []
	for item in outs:
		bits.append(("%d× " % int(outs[item]) if int(outs[item]) > 1 else "") + TranslationServer.translate(Items.name_key(item)))
	return ", ".join(bits)
