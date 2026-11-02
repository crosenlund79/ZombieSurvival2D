class_name AssetResolver
extends Node
## Sprite Workshop runtime (autoload `Assets`): resolves logical asset IDs to
## textures and audio streams with creator overrides.
##
## Priority (first valid wins):
##   1. external  user://overrides/<rel>/<name>.<ext>   (works in exported builds)
##   2. bundled   res://assets/overrides/<rel>/<name>.<ext>
##   3. template  res://assets/templates/<rel>/template_<name>.<ext>
##   4. fallback  generated magenta checker / silence (logged as missing)
##
## Results are cached. Folders are only scanned when an asset is first used or
## after reload() (Settings → "Reload art & sound", or restart).
## Gameplay never reads image sizes: views scale every texture into the
## manifest's display_size, so replacements cannot change collision or rules.

signal reloaded

const MAX_FILE_BYTES := 16 * 1024 * 1024
const MAX_DIMENSION := 4096
const MIN_DIMENSION := 4
const ASPECT_WARN := 0.12

var _textures := {}  # id -> Texture2D
var _streams := {}   # id -> AudioStream (or null when missing)
var source := {}     # id -> "external" | "bundled" | "template" | "fallback"
var _fallback_tex: Texture2D


func _ready() -> void:
	AssetCatalog.reload()
	for p in AssetCatalog.problems:
		SessionLog.error("assets", "manifest_problem", {"detail": p})
	Paths.overrides_dir()
	SessionLog.info("assets", "catalog_loaded", {"count": AssetCatalog.ids().size(),
		"external_dir": ProjectSettings.globalize_path(AssetCatalog.EXTERNAL_ROOT)})


func reload() -> void:
	_textures.clear()
	_streams.clear()
	source.clear()
	AssetCatalog.reload()
	SessionLog.info("assets", "reloaded")
	reloaded.emit()


func info(id: String) -> Dictionary:
	return AssetCatalog.entry(id)


func display_size(id: String) -> Vector2:
	return AssetCatalog.display_size(id)


func pivot(id: String) -> Vector2:
	return AssetCatalog.pivot(id)


func source_of(id: String) -> String:
	return str(source.get(id, "unresolved"))


func override_count() -> int:
	var n := 0
	for id in source:
		if source[id] == "external" or source[id] == "bundled":
			n += 1
	return n


# ---------------- textures ----------------

func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var tex := _resolve_texture(id)
	_textures[id] = tex
	return tex


func _resolve_texture(id: String) -> Texture2D:
	if not AssetCatalog.has(id):
		SessionLog.error("assets", "unknown_asset_id", {"id": id})
		source[id] = "fallback"
		return _fallback()
	for path in AssetCatalog.external_candidates(id):
		if FileAccess.file_exists(path):
			var t := _load_external_image(id, path)
			if t != null:
				source[id] = "external"
				SessionLog.info("assets", "override_used", {"id": id, "path": path})
				return t
	for path in AssetCatalog.bundled_candidates(id):
		var t := _load_project_texture(id, path, true)
		if t != null:
			source[id] = "bundled"
			SessionLog.info("assets", "override_used", {"id": id, "path": path})
			return t
	var tpl := AssetCatalog.template_path(id)
	var t2 := _load_project_texture(id, tpl, false)
	if t2 != null:
		source[id] = "template"
		return t2
	SessionLog.error("assets", "missing_required_art", {"id": id, "template": tpl})
	source[id] = "fallback"
	return _fallback()


func _load_project_texture(id: String, path: String, is_override: bool) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D and _dimensions_ok(id, res.get_size(), path):
			return res
		if is_override:
			SessionLog.warn("assets", "override_rejected", {"id": id, "path": path})
		return null
	# Not imported yet (e.g. file just dropped in while the editor is closed).
	if FileAccess.file_exists(path):
		return _load_external_image(id, path)
	return null


func _load_external_image(id: String, path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var size := f.get_length()
	f.close()
	if size > MAX_FILE_BYTES:
		SessionLog.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "file larger than 16 MB"})
		return null
	var img := Image.new()
	var err := img.load(path) if not path.begins_with("res://") else img.load(ProjectSettings.globalize_path(path))
	if err != OK or img.is_empty():
		SessionLog.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "not a readable PNG (%s)" % error_string(err)})
		return null
	if not _dimensions_ok(id, Vector2(img.get_width(), img.get_height()), path):
		return null
	return ImageTexture.create_from_image(img)


func _dimensions_ok(id: String, size: Vector2, path: String) -> bool:
	if size.x < MIN_DIMENSION or size.y < MIN_DIMENSION or size.x > MAX_DIMENSION or size.y > MAX_DIMENSION:
		SessionLog.warn("assets", "override_rejected", {"id": id, "path": path,
			"reason": "size %dx%d outside %d..%d px" % [size.x, size.y, MIN_DIMENSION, MAX_DIMENSION]})
		return false
	var want := AssetCatalog.display_size(id)
	var want_ratio := want.x / maxf(want.y, 1.0)
	var ratio := size.x / maxf(size.y, 1.0)
	if absf(ratio - want_ratio) / want_ratio > ASPECT_WARN:
		SessionLog.warn("assets", "aspect_mismatch", {"id": id, "path": path,
			"got": "%dx%d" % [size.x, size.y], "expected_ratio": snappedf(want_ratio, 0.01),
			"note": "image is fitted inside the display box without stretching"})
	return true


func _fallback() -> Texture2D:
	if _fallback_tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var on := ((x / 4) + (y / 4)) % 2 == 0
				img.set_pixel(x, y, Color(1, 0, 1) if on else Color(0.1, 0.1, 0.1))
		_fallback_tex = ImageTexture.create_from_image(img)
	return _fallback_tex


## Places a Sprite2D so the texture fits the asset's display box (aspect kept)
## with the manifest pivot at the node origin.
func apply_to_sprite(sprite: Sprite2D, id: String) -> void:
	var tex := texture(id)
	sprite.texture = tex
	sprite.centered = false
	var box := display_size(id)
	var tsize := tex.get_size()
	var s := minf(box.x / tsize.x, box.y / tsize.y)
	sprite.scale = Vector2(s, s)
	var drawn := tsize * s
	var piv := pivot(id)
	# Fitted image is centred horizontally and bottom-aligned inside the box.
	var box_origin := -Vector2(box.x * piv.x, box.y * piv.y)
	var offset_in_box := Vector2((box.x - drawn.x) * 0.5, box.y - drawn.y)
	sprite.position = box_origin + offset_in_box


# ---------------- audio ----------------

func audio_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var s := _resolve_audio(id)
	_streams[id] = s
	return s


func _resolve_audio(id: String) -> AudioStream:
	if not AssetCatalog.has(id):
		SessionLog.error("assets", "unknown_sound_id", {"id": id})
		source[id] = "fallback"
		return null
	var e := AssetCatalog.entry(id)
	var loop := bool(e.get("loop", false))
	for path in AssetCatalog.external_candidates(id):
		if FileAccess.file_exists(path):
			var s := _load_audio_file(id, path, loop)
			if s != null:
				source[id] = "external"
				SessionLog.info("assets", "override_used", {"id": id, "path": path})
				return s
	for path in AssetCatalog.bundled_candidates(id):
		var s2 := _load_project_audio(id, path, loop, true)
		if s2 != null:
			source[id] = "bundled"
			SessionLog.info("assets", "override_used", {"id": id, "path": path})
			return s2
	var s3 := _load_project_audio(id, AssetCatalog.template_path(id), loop, false)
	if s3 != null:
		source[id] = "template"
		return s3
	source[id] = "fallback"
	SessionLog.warn("assets", "missing_sound", {"id": id})
	return null


func _load_project_audio(id: String, path: String, loop: bool, is_override: bool) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return _set_loop(res.duplicate(), loop)
		if is_override:
			SessionLog.warn("assets", "override_rejected", {"id": id, "path": path})
		return null
	if FileAccess.file_exists(path):
		return _load_audio_file(id, ProjectSettings.globalize_path(path), loop)
	return null


func _load_audio_file(id: String, path: String, loop: bool) -> AudioStream:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var size := f.get_length()
	f.close()
	if size > MAX_FILE_BYTES * 2:
		SessionLog.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "file larger than 32 MB"})
		return null
	var stream: AudioStream = null
	if path.get_extension().to_lower() == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(path)
	elif path.get_extension().to_lower() == "wav":
		stream = AudioStreamWAV.load_from_file(path)
	if stream == null:
		SessionLog.warn("assets", "override_rejected", {"id": id, "path": path, "reason": "not a readable WAV/OGG"})
		return null
	return _set_loop(stream, loop)


func _set_loop(stream: AudioStream, loop: bool) -> AudioStream:
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		if loop:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_end = w.data.size() / bytes_per_frame if w.format != AudioStreamWAV.FORMAT_IMA_ADPCM else w.data.size() * 2
		else:
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	return stream
