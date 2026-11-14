@tool
class_name Piston
extends Node2D

@export var direction := Vector2.UP
@export var travel := 80.0
@export var size := Vector2(40, 16)
@export var period := 3.0
@export var offset := 0.0

var _t := 0.0
var _out := 0.0
var _body: AnimatableBody2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_t = offset
	_body = AnimatableBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = _block_size()
	cs.shape = r
	_body.add_child(cs)
	add_child(_body)
	_place()


func _block_size() -> Vector2:
	return size if absf(direction.y) >= absf(direction.x) else Vector2(size.y, size.x)


func _phase() -> float:
	return fposmod(_t, period) / period


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var before := _phase()
	_t += delta
	var p := _phase()
	if before < 0.15 and p >= 0.15:
		AudioManager.sfx(&"steam", -16.0)
	if before < 0.2 and p >= 0.2:
		AudioManager.sfx(&"crusher", -12.0)
	if p < 0.2:
		_out = 0.0
	elif p < 0.4:
		_out = ease((p - 0.2) / 0.2, 0.4)
	elif p < 0.7:
		_out = 1.0
	else:
		_out = 1.0 - smoothstep(0.0, 1.0, (p - 0.7) / 0.3)
	_place()
	queue_redraw()


func _place() -> void:
	if _body:
		var dir := direction.normalized()
		var half := _block_size() * 0.5
		var along := absf(dir.x) * half.x + absf(dir.y) * half.y
		_body.position = dir * (travel * _out + along)


func _draw() -> void:
	var dir := direction.normalized()
	var bs := _block_size()
	var along := absf(dir.x) * bs.x * 0.5 + absf(dir.y) * bs.y * 0.5
	var head := dir * (travel * _out + along)
	var cyl := Rect2(-bs * 0.5 - dir * along * 1.2, bs)
	draw_rect(Rect2(cyl.position - Vector2(2, 2), cyl.size + Vector2(4, 4)), Color8(44, 32, 34))
	draw_rect(cyl, Color8(90, 63, 48))
	var rod_w := 6.0
	var a := Vector2.ZERO
	var b := head - dir * along
	if absf(dir.x) < absf(dir.y):
		draw_rect(Rect2(Vector2(-rod_w * 0.5, minf(a.y, b.y)), Vector2(rod_w, absf(b.y - a.y))), Color8(138, 118, 108))
		draw_rect(Rect2(Vector2(-rod_w * 0.5, minf(a.y, b.y)), Vector2(1, absf(b.y - a.y))), Color8(192, 170, 150))
	else:
		draw_rect(Rect2(Vector2(minf(a.x, b.x), -rod_w * 0.5), Vector2(absf(b.x - a.x), rod_w)), Color8(138, 118, 108))
		draw_rect(Rect2(Vector2(minf(a.x, b.x), -rod_w * 0.5), Vector2(absf(b.x - a.x), 1)), Color8(192, 170, 150))
	var r := Rect2(head - bs * 0.5, bs)
	draw_rect(r, Color8(140, 100, 40))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color8(240, 207, 115))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), Color8(90, 63, 28))
	for c in [Vector2(3, 4), Vector2(r.size.x - 4, 4)]:
		draw_rect(Rect2(r.position + c, Vector2(1, 1)), Color8(30, 20, 22))
	if not Engine.is_editor_hint():
		var p := _phase()
		if p >= 0.15 and p < 0.22:
			draw_circle(-dir * along * 0.4 + Vector2(bs.x * 0.5 + 3, 0), 3.0 + (p - 0.15) * 60.0, Color(0.93, 0.92, 0.88, 0.5))
