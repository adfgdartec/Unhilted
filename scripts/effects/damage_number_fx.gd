extends Node2D

const FONT := preload("res://art/fonts/Silkscreen.ttf")

var amount := 1
var word := ""
var word_color := Color(0.45, 0.95, 1.0)
var _age := 0.0
var _drift := 0.0
const LIFE := 0.6
const WORD_LIFE := 0.9


func _ready() -> void:
	z_index = 40
	_drift = randf_range(-14.0, 14.0) if word == "" else 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= (WORD_LIFE if word != "" else LIFE):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / (WORD_LIFE if word != "" else LIFE)
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t * 6.0)
	var size := 16 if amount >= 2 or word != "" else 8
	var col := word_color if word != "" else (Color(1.0, 0.85, 0.4) if amount >= 2 else Color(1.0, 1.0, 1.0))
	var rise := -18.0 * (1.0 - pow(1.0 - t, 2.0))
	var a := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
	var text := word if word != "" else str(amount)
	draw_set_transform(Vector2(_drift * t, rise - 10.0), 0.0, Vector2(pop, pop))
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, 0)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(FONT, pos + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.05, 0.04, 0.08, a))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))
