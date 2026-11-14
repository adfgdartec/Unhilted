extends Node2D

var color := Color.WHITE
var radius := 24.0
var duration := 0.35
var width := 2.0
var _age := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / duration
	var e := 1.0 - pow(1.0 - t, 3.0)
	draw_arc(Vector2.ZERO, maxf(radius * e, 1.0), 0.0, TAU, 40, Color(color, 1.0 - t), maxf(width * (1.0 - t), 0.5))
