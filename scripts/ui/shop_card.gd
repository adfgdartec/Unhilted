class_name ShopCard
extends Button
## One item in the shop: a riveted iron plate with brass corner brackets, the
## item sitting in a round brass well (like a port socket), its name, and a
## paper price tag with the currency icon. Can't afford it: the price goes red.
## Sold out or owned: the plate goes dull and gets an ink stamp instead of a tag.
## All frames are 9-slice pixel textures from tools/art/build_ui.py.

var icon_tex: Texture2D
var swatch := Color.TRANSPARENT  ## used when there is no icon yet
var title := ""
var price := 0
var currency_icon: Texture2D
var affordable := true
var stamp := ""                  ## "SOLD OUT" / "OWNED" / ""
var subtitle := ""               ## shown instead of a price (wardrobe slots, etc.)
var flash := 0.0

const FONT := preload("res://art/fonts/Silkscreen.ttf")
const PLATE := preload("res://art/ui/card.png")
const PLATE_SEL := preload("res://art/ui/card_sel.png")
const PLATE_OFF := preload("res://art/ui/card_off.png")
const WELL := preload("res://art/ui/well.png")
const TAG := preload("res://art/ui/tag.png")
const STAMP := preload("res://art/ui/stamp.png")

const INK := Color8(40, 26, 24)
const INK_RED := Color8(168, 40, 34)
const STAMP_RED := Color8(220, 70, 58)
const STAMP_GREEN := Color8(110, 200, 120)

static var _boxes := {}


static func box(tex: Texture2D, l: int, t: int, r: int, b: int) -> StyleBoxTexture:
	var key := "%s:%d%d%d%d" % [tex.resource_path, l, t, r, b]
	if not _boxes.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = l
		sb.texture_margin_top = t
		sb.texture_margin_right = r
		sb.texture_margin_bottom = b
		_boxes[key] = sb
	return _boxes[key]


## A price tag with its currency icon, as drawn on cards (also used by the detail panel).
static func draw_tag(ci: CanvasItem, at: Vector2, cur_icon: Texture2D, text: String, col: Color) -> float:
	var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var iw := (cur_icon.get_width() + 2.0) if cur_icon else 0.0
	var w := 9.0 + iw + tw + 4.0
	ci.draw_style_box(box(TAG, 7, 3, 2, 3), Rect2(at, Vector2(w, 11)))
	var x := at.x + 8.0
	if cur_icon:
		ci.draw_texture(cur_icon, Vector2(x, at.y + 5 - cur_icon.get_height() * 0.5).round())
		x += iw
	ci.draw_string(FONT, Vector2(x, at.y + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	return w


static func draw_stamp(ci: CanvasItem, at: Vector2, text: String, color := Color(0, 0, 0, 0)) -> void:
	var col := color if color.a > 0.0 else (STAMP_GREEN if text == "OWNED" else STAMP_RED)
	var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var key := "stamp:%s:%s" % [text, col.to_html()]
	if not _boxes.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = STAMP
		sb.set_texture_margin_all(4)
		sb.modulate_color = col
		_boxes[key] = sb
	ci.draw_style_box(_boxes[key], Rect2(at, Vector2(tw + 8, 12)))
	ci.draw_string(FONT, at + Vector2(4, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _init() -> void:
	custom_minimum_size = Vector2(150, 44)
	focus_mode = Control.FOCUS_ALL
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(grab_focus)
	focus_entered.connect(queue_redraw)
	focus_entered.connect(func(): AudioManager.sfx(&"ui_move", -10.0, 0.02))
	focus_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(flash - delta * 2.5, 0.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sel := has_focus()
	var done := stamp != ""
	draw_style_box(box(PLATE_SEL if sel else (PLATE_OFF if done else PLATE), 7, 7, 7, 7), r)
	# the item in its well
	var well_at := Vector2(5, roundf((size.y - 34) * 0.5))
	draw_texture(WELL, well_at)
	var c := well_at + Vector2(17, 17)
	var tint := Color.WHITE if not done else Color(0.55, 0.55, 0.6)
	if icon_tex:
		var s := icon_tex.get_size()
		var k := 1.0 if maxf(s.x, s.y) <= 32 else 32.0 / maxf(s.x, s.y)
		var d := (s * k).round()
		draw_texture_rect(icon_tex, Rect2((c - d * 0.5).round(), d), false, tint)
	elif swatch.a > 0.0:
		draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), swatch * tint)
	# name
	var text_col := Color(0.93, 0.9, 0.84) if not done else Color(0.52, 0.5, 0.52)
	if sel:
		text_col = Color.WHITE
	var lines := _wrap(clean_name(title).to_upper(), size.x - 50.0)
	if subtitle != "":
		lines = lines.slice(0, 1)
	for i in mini(lines.size(), 2):
		draw_string(FONT, Vector2(44, 15 + i * 9), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_col)
	# price tag, or a stamp
	if subtitle != "":
		draw_string(FONT, Vector2(44, size.y - 9), subtitle.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50.0, 8, Color(1.0, 0.72, 0.3) if not sel else UIKit.AMBER)
	elif done:
		draw_stamp(self, Vector2(43, size.y - 18), stamp)
	else:
		draw_tag(self, Vector2(42, size.y - 17), currency_icon, str(price), INK if affordable else INK_RED)
	if flash > 0.0:
		draw_rect(r.grow(-3), Color(0.6, 1.0, 1.0, flash * 0.35))
	if sel:
		queue_redraw()


## "Magnet Coil (chip)" -> "Magnet Coil": the card already says what kind it is.
static func clean_name(t: String) -> String:
	var i := t.find(" (")
	return t.substr(0, i) if i > 0 else t


func _wrap(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if FONT.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
