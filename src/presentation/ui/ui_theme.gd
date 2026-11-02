class_name UITheme
extends RefCounted
## One shared interface theme (colours from the approved visual direction:
## charcoal panels, straw text, rust accents). Every UI node inherits it from
## the UI root, so changing it here restyles the whole interface.

const CHARCOAL := Color("#212120")
const SOOT := Color("#2b2a26")
const STRAW := Color("#CFB88D")
const PAPER := Color("#e8dcc0")
const RUST := Color("#954C33")
const MOSS := Color("#7A733F")
const CYAN := Color("#59C0C2")
const WARN := Color("#d9a441")
const ERROR := Color("#d0603f")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	var panel := _box(Color(CHARCOAL, 0.94), Color(STRAW, 0.35), 2, 6)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var normal := _box(SOOT, Color(STRAW, 0.30), 1, 4)
	var hover := _box(Color("#3a382f"), Color(STRAW, 0.7), 1, 4)
	var pressed := _box(Color(RUST, 0.85), STRAW, 1, 4)
	var disabled := _box(Color(SOOT, 0.5), Color(STRAW, 0.1), 1, 4)
	var focus := _box(Color(0, 0, 0, 0), Color(CYAN, 0.8), 2, 4)
	for b in [normal, hover, pressed, disabled]:
		b.set_content_margin_all(8)
		b.content_margin_left = 14
		b.content_margin_right = 14
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, PAPER)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(PAPER, 0.35))
	var edit := _box(Color("#141413"), Color(STRAW, 0.4), 1, 3)
	edit.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _box(Color("#141413"), CYAN, 1, 3))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_stylebox("normal", "SpinBox", edit)
	t.set_color("font_color", "Label", PAPER)
	return t


static func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s


static func heading(text_key: String, size: int = 26) -> Label:
	var l := Label.new()
	l.text = text_key
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", STRAW)
	return l


static func small(text: String, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


## Translate a key with optional "%s" arguments.
static func fmt(key: String, args: Array = []) -> String:
	var s := TranslationServer.translate(key)
	if args.is_empty() or not "%s" in s:
		return s
	var count := s.count("%s")
	var use := args.slice(0, count)
	while use.size() < count:
		use.append("")
	return s % use
