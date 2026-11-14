class_name UIKit
extends RefCounted

const CYAN := Color("38f2ff")
const AMBER := Color("ffb347")
const TEXT := Color(0.92, 0.9, 0.86)
const QUIET := Color(0.6, 0.62, 0.68)

static var _theme: Theme
static var _heading_font: FontFile


static func _pixel_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


const THEME_PATH := "res://art/ui/theme.tres"


static func theme() -> Theme:
	if _theme:
		return _theme
	if ResourceLoader.exists(THEME_PATH):
		_theme = load(THEME_PATH)
		_heading_font = _pixel_font("res://art/fonts/Silkscreen.ttf")
		return _theme
	return build_theme()


static func build_theme() -> Theme:
	var t := Theme.new()
	_heading_font = _pixel_font("res://art/fonts/Silkscreen.ttf")
	t.default_font = _heading_font
	t.default_font_size = 8

	t.set_stylebox("panel", "PanelContainer", box("res://art/ui/frame.png", 10, 10, 10, 10, 14, 14, 14, 14))

	var normal := box("res://art/ui/card.png", 7, 7, 7, 7, 10, 4, 10, 4)
	var focus := box("res://art/ui/card_sel.png", 7, 7, 7, 7, 10, 4, 10, 4)
	var off := box("res://art/ui/card_off.png", 7, 7, 7, 7, 10, 4, 10, 4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("disabled", "Button", off)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		t.set_stylebox(state, "Button", focus)
	t.set_color("font_color", "Button", Color(0.82, 0.8, 0.76))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.45))
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "VBoxContainer", 3)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color8(140, 100, 40)
	var track := StyleBoxFlat.new()
	track.bg_color = Color8(30, 20, 22)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	_theme = t
	return t


static func box(path: String, l: int, tp: int, r: int, b: int, cl := 0, ct := 0, cr := 0, cb := 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = l
	sb.texture_margin_top = tp
	sb.texture_margin_right = r
	sb.texture_margin_bottom = b
	sb.content_margin_left = cl
	sb.content_margin_top = ct
	sb.content_margin_right = cr
	sb.content_margin_bottom = cb
	return sb


static func heading(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("res://art/ui/nameplate.png", 6, 6, 6, 6, 12, 3, 12, 3))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := label(text, 16, Color8(70, 44, 18))
	p.add_child(l)
	return p


static func case_panel(margin := 9) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("res://art/ui/case.png", 7, 7, 7, 7, margin, margin - 1, margin, margin - 1))
	return p


static func card_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("res://art/ui/card.png", 7, 7, 7, 7, 10, 7, 10, 7))
	return p


static func pedestal() -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://art/ui/pedestal.png")
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return t


static func prose_font() -> FontFile:
	return _pixel_font("res://art/fonts/PixelifySans.ttf")


static func _snap(size: int) -> int:
	return 16 if size >= 14 else 8


static func panel(min_size := Vector2(360, 220)) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func label(text: String, size := 8, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	var s := _snap(size)
	if s == 16:
		theme()
		l.add_theme_font_override("font", _heading_font)
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, _size := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(on_press)
	b.pressed.connect(func(): AudioManager.sfx(&"ui_select", -6.0, 0.0))
	b.focus_entered.connect(func(): AudioManager.sfx(&"ui_move", -10.0, 0.02))
	return b


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c
