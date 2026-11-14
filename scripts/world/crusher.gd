@tool
class_name Crusher
extends Node2D
## A hydraulic press that slams down on a rhythm. It shakes and its lamp
## flashes before it drops (the tell). Getting caught under it hurts and
## sends you back to safe ground. The block is solid: you can ride it up.
## The node's position is the top-centre of the rail (the block hangs below).

@export var width := 48.0
@export var drop := 96.0          ## how far the block travels
@export var period := 2.6         ## seconds per cycle
@export var offset := 0.0         ## phase offset (seconds) to stagger several
const BLOCK_H := 24.0

var _t := 0.0
var _y := 0.0
var _body: AnimatableBody2D
var _hit: Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_t = offset
	_body = AnimatableBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, BLOCK_H)
	cs.shape = r
	_body.add_child(cs)
	add_child(_body)
	_hit = Area2D.new()
	_hit.collision_layer = 0
	_hit.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(width - 6, 6)
	hs.shape = hr
	hs.position = Vector2(0, BLOCK_H * 0.5 + 2)
	_hit.add_child(hs)
	_body.add_child(_hit)
	_hit.body_entered.connect(func(b): if b is Player and _falling(): b.hazard_hit(1))
	_place()


## 0..0.45 up and waiting, 0.45..0.6 shaking (tell), 0.6..0.66 slam, 0.66..0.8 down, 0.8..1 rising
func _phase() -> float:
	return fposmod(_t, period) / period


func _falling() -> bool:
	var p := _phase()
	return p >= 0.6 and p < 0.7


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var before := _phase()
	_t += delta
	var p := _phase()
	if before < 0.45 and p >= 0.45:
		AudioManager.sfx(&"telegraph", -14.0)
	if before < 0.66 and p >= 0.66:
		AudioManager.sfx(&"crusher", -4.0)
		Fx.shake(2.0)
		Fx.dust(global_position + Vector2(0, drop + BLOCK_H), 1.2)
	_place()
	queue_redraw()


func _place() -> void:
	var p := _phase()
	if p < 0.6:
		_y = 0.0
	elif p < 0.66:
		_y = drop * (p - 0.6) / 0.06
	elif p < 0.8:
		_y = drop
	else:
		_y = drop * (1.0 - (p - 0.8) / 0.2)
	var shake := (randf_range(-1, 1) if p > 0.45 and p < 0.6 else 0.0)
	if _body:
		_body.position = Vector2(shake, _y + BLOCK_H * 0.5)


func _draw() -> void:
	var p := _phase() if not Engine.is_editor_hint() else 0.0
	# piston rod and rail
	draw_rect(Rect2(-width * 0.5 - 4, -4, width + 8, 4), Color8(58, 30, 26))
	draw_rect(Rect2(-3, 0, 6, _y), Color8(138, 118, 108))
	draw_rect(Rect2(-3, 0, 1, _y), Color8(192, 170, 150))
	var top := _y + (_body.position.x if _body else 0.0) * 0.0
	var r := Rect2(-width * 0.5 + (_body.position.x if _body else 0.0), top, width, BLOCK_H)
	draw_rect(r, Color8(74, 34, 28))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color8(160, 78, 52))
	draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), Color8(38, 20, 18))
	var x := r.position.x + 2
	while x < r.end.x - 4:  # hazard teeth on the bottom
		draw_rect(Rect2(x, r.end.y - 4, 3, 4), Color8(240, 207, 115) if int((x - r.position.x) / 4) % 2 == 0 else Color8(30, 20, 22))
		x += 4
	var warn := p > 0.45 and p < 0.66 and fmod(_t, 0.12) < 0.06
	draw_circle(r.position + Vector2(r.size.x * 0.5, 9), 2.0, Color8(255, 90, 58) if warn else Color8(90, 30, 26))
