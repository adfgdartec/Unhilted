extends Node2D
## Landing dust puff: 4 frames over 0.24 s.

const TEX := preload("res://art/fx/dust.png")
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.24:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := mini(int(_age / 0.06), 3)
	draw_texture_rect_region(TEX, Rect2(-6, -7, 12, 7), Rect2(f * 12, 0, 12, 7))
