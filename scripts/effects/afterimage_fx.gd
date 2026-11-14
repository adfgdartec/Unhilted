extends Node2D

var _age := 0.0
const DURATION := 0.22


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_age += delta
	modulate.a = 0.55 * (1.0 - _age / DURATION)
	if _age >= DURATION:
		queue_free()
