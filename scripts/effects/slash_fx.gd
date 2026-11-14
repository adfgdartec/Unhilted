extends Node2D

var color := Color(0.45, 0.9, 1.0)
var reach := 24.0
var _age := 0.0
const DURATION := 0.13


var flip := false


func _ready() -> void:
	if flip:
		scale.y = -1.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / DURATION
	var sweep := lerpf(-1.1, 1.1, minf(t * 1.6, 1.0))
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var a := lerpf(-1.1, sweep, float(i) / steps)
		pts.append(Vector2.from_angle(a) * reach)
	for i in range(steps, -1, -1):
		var a := lerpf(-1.1, sweep, float(i) / steps)
		var thick := sin(PI * float(i) / steps) * 9.0 * (1.0 - t * 0.5)
		pts.append(Vector2.from_angle(a) * (reach - thick))
	if pts.size() >= 3:
		draw_colored_polygon(pts, Color(color, 0.7 * (1.0 - t)))
