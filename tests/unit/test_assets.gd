extends TestCase

const FIX := "res://tests/fixtures/overrides/"
const DST := "user://overrides/characters/player/survivor_down.png"
const SND_DST := "user://overrides/audio/world/door_open.wav"


func _copy(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var data := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _clean() -> void:
	for p in [DST, SND_DST]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_override_paths_follow_convention() -> void:
	eq(AssetCatalog.override_stem("res://assets/templates/characters/player/template_survivor_down.png"),
		"characters/player/survivor_down", "prefix removed, folders kept")
	eq(AssetCatalog.override_stem("res://assets/templates/x/no_prefix.png"), "", "missing template_ prefix rejected")
	eq(AssetCatalog.override_stem("res://assets/templates/../secret/template_a.png"), "", "path traversal rejected")
	eq(AssetCatalog.override_stem("res://elsewhere/template_a.png"), "", "outside template root rejected")
	eq(AssetCatalog.bundled_candidates("char.player"), ["res://assets/overrides/characters/player/survivor_down.png"], "bundled path")
	eq(AssetCatalog.external_candidates("sfx.door_open"),
		["user://overrides/audio/world/door_open.ogg", "user://overrides/audio/world/door_open.wav"], "audio accepts ogg/wav")


func test_resolution_priority_and_fallback() -> void:
	_clean()
	var r := AssetResolver.new()
	var t := r.texture("char.player")
	eq(r.source_of("char.player"), "template", "template by default")
	_copy(FIX + "characters/player/survivor_down.png", DST)
	r = AssetResolver.new()
	var t2 := r.texture("char.player")
	eq(r.source_of("char.player"), "external", "external override wins")
	check(t2.get_image().get_pixel(52, 90) != t.get_image().get_pixel(52, 90), "override pixels differ")
	_copy(FIX + "characters/player/corrupt_survivor_down.png", DST)
	r = AssetResolver.new()
	r.texture("char.player")
	eq(r.source_of("char.player"), "template", "corrupt override -> template")
	var big := Image.create(5000, 8, false, Image.FORMAT_RGBA8)
	big.save_png(DST)
	r = AssetResolver.new()
	r.texture("char.player")
	eq(r.source_of("char.player"), "template", "oversized override -> template")
	_clean()
	r = AssetResolver.new()
	var missing := r.texture("no.such_asset")
	eq(r.source_of("no.such_asset"), "fallback", "unknown id -> diagnostic fallback")
	check(missing != null, "fallback texture is never null")
	r.free()


func test_audio_override_and_missing() -> void:
	_clean()
	var r := AssetResolver.new()
	check(r.audio_stream("sfx.door_open") != null, "template sound loads")
	eq(r.source_of("sfx.door_open"), "template", "template sound")
	_copy(FIX + "audio/world/door_open.wav", SND_DST)
	r = AssetResolver.new()
	check(r.audio_stream("sfx.door_open") is AudioStreamWAV, "external WAV loads")
	eq(r.source_of("sfx.door_open"), "external", "external sound wins")
	_clean()
	check(r.audio_stream("sfx.not_there") == null, "missing sound -> null (silent, logged)")
	r.free()


func test_sprite_fit_keeps_display_box() -> void:
	var r := AssetResolver.new()
	var s := Sprite2D.new()
	r.apply_to_sprite(s, "char.player")
	var drawn := s.texture.get_size() * s.scale
	var box := AssetCatalog.display_size("char.player")
	var piv := AssetCatalog.pivot("char.player")
	check(absf(drawn.y - box.y) < 0.01 and drawn.x <= box.x + 0.01, "drawn inside the display box")
	check(absf(s.position.y + box.y * piv.y) < 0.01, "manifest pivot (feet) at the node origin")
	s.free()
	r.free()
