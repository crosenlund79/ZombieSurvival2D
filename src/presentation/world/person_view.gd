class_name PersonView
extends Node2D
## Shows one faction member from world data (iteration 015 F): interpolated
## position, facing art (char.<role>, _up, _side), a name label for friendly
## people and an Interactable that opens their panel (trade, repairs, missions,
## talk). Hostile raiders have no prompt; like Burnt Ones they fade out when the
## local player cannot see them (PlayerSight). Muzzle flashes and tracers come
## from "person_shot" events (RegionView). Presentation only; FactionSim decides.

var person_id := ""
var _sprite: Sprite2D
var _label: Label
var _interact: Interactable
var _shown := ""
var _last := Vector2.ZERO
var _walk := 0.0
var _sight := 1.0
var _mode := "talk"           # panel page: talk / trade / sell / repair / missions


static func create(p: PersonState) -> PersonView:
	var v := PersonView.new()
	v.person_id = p.person_id
	v.name = "Person_" + p.person_id.replace(".", "_")
	v.position = p.position
	v._last = p.position
	return v


func state() -> PersonState:
	return Session.world.people.get(person_id) if Session.world != null else null


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	Assets.reloaded.connect(func() -> void: _shown = "")
	var p := state()
	if p == null:
		return
	if str(FactionSim.fdef(p.faction).get("kind", "")) != "hostile":
		_label = UITheme.small(tr("ROLE_" + p.role.to_upper()), 12)
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_label.add_theme_constant_override("outline_size", 4)
		_label.position = Vector2(-60, -180)
		_label.size = Vector2(120, 18)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_label)
		_interact = Interactable.new()
		_interact.entity_id = person_id
		_interact.reach = 110.0
		_interact.prompt_key = "PROMPT_TALK_TO"
		_interact.prompt_args = [tr("ROLE_" + p.role.to_upper())]
		_interact.on_activate = _open_panel
		_interact.position = Vector2(0, -10)
		add_child(_interact)


func _process(delta: float) -> void:
	var p := state()
	if p == null:
		return
	var hostile := str(FactionSim.fdef(p.faction).get("kind", "")) == "hostile" or FactionSim.hostile_to(Session.world, p, Session.local_player_id)
	if hostile and PlayerSight.current != null:
		_sight = move_toward(_sight, PlayerSight.current.visibility(global_position), delta * 3.0)
	else:
		_sight = move_toward(_sight, 1.0, delta * 3.0)
	modulate.a = _sight
	if _interact != null:
		_interact.enabled = not hostile
	if position.distance_to(p.position) > 300.0:
		position = p.position
	position = position.lerp(p.position, 1.0 - exp(-10.0 * delta))
	var moved := position.distance_to(_last) / maxf(delta, 0.001)
	_last = position
	var f := p.facing
	var id := "char." + p.role
	if absf(f.x) >= absf(f.y) * 0.8:
		id += "_side"
		_sprite.flip_h = f.x < 0.0
	else:
		_sprite.flip_h = false
		if f.y < 0.0:
			id += "_up"
	if id != _shown and AssetCatalog.has(id):
		_shown = id
		Assets.apply_to_sprite(_sprite, id)
	if moved > 12.0:
		_walk += delta * 6.0
		_sprite.position.y = -absf(sin(_walk * PI)) * 1.5
	else:
		_sprite.position.y = 0.0
	if p.activity == "alert" or p.activity == "shoot":
		_sprite.modulate = Color(1.0, 0.9, 0.85)
	else:
		_sprite.modulate = Color.WHITE


# ------------------------------------------------------------------ the panel

func _open_panel() -> void:
	_mode = "talk"
	MachinePanel.open(self, Session.local_player().region_id if Session.local_player() != null else "", person_id, panel_data, _panel_request)
	Audio.play("sfx.voice_trust", global_position, -6.0)


func _panel_request(action: String, arg: String) -> void:
	if action.begins_with("__"):
		_mode = action.substr(2)
		return
	Session.request_faction(person_id, action, arg)


func panel_data() -> Dictionary:
	var p := state()
	var w := Session.world
	var me := Session.local_player()
	if p == null or w == null or me == null:
		return {"title": "", "lines": [], "buttons": []}
	var fid := p.faction
	var f := FactionSim.fdef(fid)
	var r := FactionSim.rep(w, me.player_id, fid)
	var t := FactionSim.tier(fid, r)
	var lines: Array[String] = []
	var buttons := []
	lines.append(UITheme.fmt("FACTION_STANDING", [tr(str(f.get("name_key", ""))), tr(str(t.get("key", "REP_NEUTRAL"))), r]))
	if f.has("trader") or f.has("repair"):
		lines.append(UITheme.fmt("FACTION_CREDIT", [FactionSim.credit(w, me.player_id)]))
	if FactionSim.banished(w, me.player_id, fid):
		lines.append(tr("LAW_YOU_ARE_BANISHED"))
	match _mode:
		"trade":
			var st := FactionSim.stock(w, fid)
			var keys := st.keys()
			keys.sort()
			for item in keys:
				if str(item).begins_with("_") or int(st[item]) <= 0:
					continue
				var cost := FactionSim.price(w, me.player_id, fid, str(item), false)
				buttons.append([UITheme.fmt("TRADE_BUY_LINE", [tr(Items.name_key(str(item))), int(st[item]), cost]), "buy", str(item), FactionSim.credit(w, me.player_id) >= cost])
			buttons.append([tr("TRADE_SELL_TAB"), "__sell", "", true])
			buttons.append([tr("PANEL_BACK"), "__talk", "", true])
		"sell":
			for item in me.carried:
				buttons.append([UITheme.fmt("TRADE_SELL_LINE", [tr(Items.name_key(str(item))), int(me.carried[item]), FactionSim.price(w, me.player_id, fid, str(item), true)]), "sell", str(item), true])
			for g in me.gear:
				if str(me.equipped.get("hand", "")) == str(g.get("uid", "")):
					continue
				buttons.append([UITheme.fmt("TRADE_SELL_LINE", [tr(Items.name_key(str(g["item"]))), 1, FactionSim.price(w, me.player_id, fid, str(g["item"]), true)]), "sell", str(g.get("uid", "")), true])
			buttons.append([tr("TRADE_BUY_TAB"), "__trade", "", true])
			buttons.append([tr("PANEL_BACK"), "__talk", "", true])
		"repair":
			for g in me.gear:
				var cost2 := FactionSim.repair_cost(w, me.player_id, fid, g)
				if cost2 > 0:
					buttons.append([UITheme.fmt("REPAIR_LINE", [tr(Items.name_key(str(g["item"]))), cost2]), "repair", str(g.get("uid", "")), FactionSim.credit(w, me.player_id) >= cost2])
			if buttons.is_empty():
				lines.append(tr("REPAIR_NOTHING"))
			buttons.append([tr("PANEL_BACK"), "__talk", "", true])
		"missions":
			for m in f.get("missions", []):
				var mid := str(m.get("id", ""))
				var ms := FactionSim.mission_state(w, me.player_id, mid)
				var title := tr(str(m.get("title_key", "")))
				if ms == "done":
					lines.append(UITheme.fmt("MISSION_LINE_DONE", [title]))
				elif ms == "active":
					var pr := FactionSim.progress(w, me.player_id, mid)
					lines.append(UITheme.fmt("MISSION_LINE_ACTIVE", [title, tr(str(m.get("desc_key", ""))), int(pr[0]), int(pr[1])]))
					buttons.append([UITheme.fmt("MISSION_TURN_IN", [title]), "turn_in", mid, FactionSim.complete(w, me.player_id, mid)])
				else:
					var ok := r >= int(m.get("min_rep", -100))
					lines.append(UITheme.fmt("MISSION_LINE_OFFER", [title, tr(str(m.get("desc_key", "")))]))
					buttons.append([UITheme.fmt("MISSION_ACCEPT", [title]) if ok else UITheme.fmt("MISSION_NEEDS_REP", [int(m.get("min_rep", 0))]), "accept", mid, ok])
			buttons.append([tr("PANEL_BACK"), "__talk", "", true])
		_:
			lines.append(tr("SAY_" + fid.to_upper() + "_" + p.role.to_upper()))
			match p.role:
				"trader":
					buttons.append([tr("TRADE_BUY_TAB"), "__trade", "", true])
					buttons.append([tr("TRADE_SELL_TAB"), "__sell", "", true])
				"mechanic":
					buttons.append([tr("REPAIR_TAB"), "__repair", "", true])
				"elder", "contact":
					buttons.append([tr("MISSIONS_TAB"), "__missions", "", true])
	return {"title": tr("ROLE_" + p.role.to_upper()) + " · " + tr(str(f.get("name_key", ""))), "lines": lines, "buttons": buttons}
