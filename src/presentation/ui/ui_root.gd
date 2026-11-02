class_name UIRoot
extends Control
## Root of all interface panels. Applies the shared theme and the player's UI
## scale independently of the world camera, and always fills the viewport —
## so anchored panels work at 16:9, 21:9, 32:9 or any window size.


func _ready() -> void:
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(func(section: String, key: String) -> void:
		if section == "display" and key == "ui_scale":
			_fit())
	_fit()


func _fit() -> void:
	var s := Settings.ui_scale()
	var vp := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	scale = Vector2(s, s)
	size = vp / s
