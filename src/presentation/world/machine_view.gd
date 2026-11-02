class_name MachineView
extends EntityView
## Storage locker, generator, water purifier and scavenging spots.
## Machines and storage open a MachinePanel (local UI; every button is a host
## request). Scavenging spots ("loot") are searched directly with E.
## Art by state: generator on/off, purifier working/idle, loot full/empty.

@export var art_asset := ""
@export var art_active_asset := ""   # e.g. running generator / working purifier
var _type := ""
var _hum_loop := false


func _build() -> void:
	_type = str(def.get("type", ""))
	Session.vitals_changed.connect(func(_p: String) -> void: _refresh("vitals"))
	Session.player_resources_changed.connect(func(_p: String) -> void: _refresh("carried"))


func _ready() -> void:
	super._ready()
	if interact != null and _type in ["storage", "generator", "purifier"]:
		interact.on_activate = func() -> void: MachinePanel.open(self, region_id, entity_id, panel_data)


func _exit_tree() -> void:
	if _hum_loop:
		Audio.stop_loop("machine", 0.4)


func _refresh(cause: String) -> void:
	var st := state()
	var active := false
	match _type:
		"generator":
			active = bool(st.get("running", false))
			if interact != null:
				interact.prompt_key = "PROMPT_GENERATOR"
		"purifier":
			active = int(st.get("input", 0)) > 0 and InfraSim.is_powered(Session.world, region_id)
			if interact != null:
				interact.prompt_key = "PROMPT_PURIFIER"
		"storage":
			if interact != null:
				interact.prompt_key = "PROMPT_STORAGE"
		"loot":
			var ready := WorldActions.loot_ready(Session.world, region_state(), entity_id)
			if interact != null:
				interact.enabled = ready
				interact.prompt_key = str(def.get("prompt_key", "PROMPT_SEARCH"))
			active = ready
	if art_asset != "":
		show_art("Main", art_active_asset if active and art_active_asset != "" else art_asset)
	if _type == "generator":
		if active and not _hum_loop:
			Audio.play_loop("machine", "amb.generator", 0.6)
			_hum_loop = true
		elif not active and _hum_loop:
			Audio.stop_loop("machine", 0.8)
			_hum_loop = false
	match cause:
		"out_of_fuel":
			Session.notice.emit("GENERATOR_EMPTY", [])
		"purified":
			Audio.play("sfx.water_pour", global_position)
		"looted":
			Audio.play("sfx.rummage", global_position)


## Panel content for storage / generator / purifier.
func panel_data() -> Dictionary:
	var st := state()
	var me := Session.local_player()
	var carried: Dictionary = me.carried if me != null else {}
	var b := Session.world.bunker_for_region(region_id)
	var store: Dictionary = b.resources if b != null else {}
	var lines: Array[String] = []
	var buttons := []
	match _type:
		"storage":
			lines.append(UITheme.fmt("PANEL_CARRY", [Items.total(carried), Items.carry_slots()]))
			for item in Items.ids():
				var have := Items.amount(carried, item)
				var stored := Items.amount(store, item)
				if have == 0 and stored == 0:
					continue
				var nm := TranslationServer.translate(Items.name_key(item))
				lines.append(UITheme.fmt("PANEL_ITEM_LINE", [nm, stored, have]))
				buttons.append([UITheme.fmt("PANEL_STORE_ALL", [nm, have]), "store", item, have > 0])
				buttons.append([UITheme.fmt("PANEL_TAKE", [nm]), "take", item, stored > 0 and Items.free_slots(carried) > 0])
			if lines.size() == 1:
				lines.append(TranslationServer.translate("PANEL_EMPTY"))
			return {"title": TranslationServer.translate("PANEL_STORAGE"), "lines": lines, "buttons": buttons}
		"generator":
			var fuel := float(st.get("fuel", 0.0))
			var cap := float(InfraSim.c("generator_fuel_capacity", 4))
			var running := bool(st.get("running", false))
			var status := "GEN_RUNNING" if running else ("GEN_EMPTY" if fuel <= 0.0 else "GEN_STOPPED")
			lines.append(TranslationServer.translate(status))
			lines.append(UITheme.fmt("GEN_FUEL", [roundi(fuel / cap * 100.0), snappedf(fuel * float(InfraSim.c("generator_seconds_per_fuel", 180)) / 60.0, 0.1)]))
			lines.append(TranslationServer.translate("GEN_POWER_ON" if InfraSim.is_powered(Session.world, region_id) else "GEN_POWER_OFF"))
			var fuel_avail := Items.amount(carried, "fuel") + Items.amount(store, "fuel")
			buttons.append([UITheme.fmt("GEN_ADD_FUEL", [fuel_avail]), "fuel", "", fuel_avail > 0 and fuel <= cap - 1.0])
			buttons.append([TranslationServer.translate("GEN_STOP" if running else "GEN_START"), "toggle", "", running or fuel > 0.0])
			return {"title": TranslationServer.translate("PANEL_GENERATOR"), "lines": lines, "buttons": buttons}
		"purifier":
			var input := int(st.get("input", 0))
			var output := int(st.get("output", 0))
			var powered := InfraSim.is_powered(Session.world, region_id)
			var status2 := "PUR_NO_POWER"
			if powered:
				status2 = "PUR_WORKING" if input > 0 and output < int(InfraSim.c("purifier_output_capacity", 6)) else ("PUR_FULL" if input > 0 else "PUR_WAITING")
			lines.append(TranslationServer.translate(status2))
			lines.append(UITheme.fmt("PUR_LEVELS", [input, int(InfraSim.c("purifier_input_capacity", 6)), output, int(InfraSim.c("purifier_output_capacity", 6)), roundi(float(st.get("progress", 0.0)) * 100.0)]))
			var dirty := Items.amount(carried, "water_dirty") + Items.amount(store, "water_dirty")
			buttons.append([UITheme.fmt("PUR_FILL", [dirty]), "fill", "", dirty > 0 and input < int(InfraSim.c("purifier_input_capacity", 6))])
			buttons.append([TranslationServer.translate("PUR_COLLECT"), "collect", "", output > 0 and Items.free_slots(carried) > 0])
			buttons.append([TranslationServer.translate("PUR_DRINK"), "drink_tap", "", output > 0])
			return {"title": TranslationServer.translate("PANEL_PURIFIER"), "lines": lines, "buttons": buttons}
	return {"title": "", "lines": [], "buttons": []}
