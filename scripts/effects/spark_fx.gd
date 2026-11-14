extends Node2D

const LIFETIME := 0.16
var color := Color.WHITE
var count := 6
var _age := 0.0
var _offset := 0.0


func _ready() -> void:
	_offset = randf() * TAU
	z_index = 10


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	for i in count:
		var dir := Vector2.from_angle(_offset + TAU * i / count)
		draw_line(dir * (2.0 + 8.0 * t), dir * (5.0 + 12.0 * t), Color(color, 1.0 - t), 1.0)
