@tool
class_name GroundPatch
extends Polygon2D
## Flat ground surface (grass, dirt, road) drawn as a polygon filled with a
## tiling texture from an asset ID. Edit the shape with the polygon tool in
## the Godot editor. Presentation only — no collision.

@export var asset_id := "env.ground_grass":
	set(v):
		asset_id = v
		_refresh()
@export var texture_scale_factor := 1.0:
	set(v):
		texture_scale_factor = v
		_refresh()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_refresh()
	if not Engine.is_editor_hint():
		Assets.reloaded.connect(_refresh)


func _refresh() -> void:
	if not is_inside_tree() or asset_id == "":
		return
	var tex: Texture2D
	if Engine.is_editor_hint():
		var path := AssetCatalog.template_path(asset_id)
		tex = load(path) as Texture2D if ResourceLoader.exists(path) else null
	else:
		tex = Assets.texture(asset_id)
	if tex == null:
		return
	texture = tex
	# Map the texture so one tile covers its manifest display size, whatever the file resolution.
	var box := AssetCatalog.display_size(asset_id) * texture_scale_factor
	texture_scale = tex.get_size() / box
