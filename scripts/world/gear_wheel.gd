@tool
class_name GearWheel
extends Node2D

@export var radius := 72.0
@export var platforms := 4
@export var platform_width := 36.0
@export var speed := 0.5
@export var start_angle := 0.0

var _angle := 0.0
var _bodies: Array[AnimatableBody2D] = []


func _ready() -> void:
	_angle = start_angle
	if Engine.is_editor_hint():
		return
	for i in platforms:
		var b := AnimatableBody2D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(platform_width, 6)
		cs.shape = r
		cs.one_way_collision = true
		b.add_child(cs)
		add_child(b)
		_bodies.append(b)
	_place()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var before := _angle
	_angle += speed * delta
	if int(before / (TAU / 12.0)) != int(_angle / (TAU / 12.0)) and randf() < 0.35:
		AudioManager.sfx(&"gear", -16.0)
	_place()
	queue_redraw()


func platform_position(i: int) -> Vector2:
	var a := _angle + TAU * float(i) / float(maxi(platforms, 1))
	return Vector2(cos(a), sin(a)) * radius


func _place() -> void:
	for i in _bodies.size():
		_bodies[i].position = platform_position(i)


func _draw() -> void:
	var rim := Color8(68, 54, 54)
	var brass := Color8(140, 100, 40)
	var hi := Color8(201, 150, 60)
	var teeth := 24
	for i in teeth:
		var a := _angle + TAU * i / teeth
		var p := Vector2(cos(a), sin(a)) * (radius - 10.0)
		draw_set_transform(p, a, Vector2.ONE)
		draw_rect(Rect2(-3, -3, 6, 6), Color8(44, 32, 34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, radius - 16.0, 0.0, TAU, 48, rim, 8.0)
	draw_arc(Vector2.ZERO, radius - 16.0, PI * 1.1, PI * 1.45, 10, Color8(138, 118, 108), 1.0)
	for i in 6:
		var a := _angle + TAU * i / 6.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (radius - 18.0), rim, 4.0)
	draw_circle(Vector2.ZERO, 9.0, brass)
	draw_circle(Vector2(-2, -2), 3.0, hi)
	draw_circle(Vector2.ZERO, 2.0, Color8(30, 20, 22))
	for i in platforms:
		var p := platform_position(i) if not Engine.is_editor_hint() else \
			Vector2(cos(_angle + TAU * i / platforms), sin(_angle + TAU * i / platforms)) * radius
		draw_line(p * ((radius - 16.0) / radius), p, rim, 2.0)
		var w := platform_width
		draw_rect(Rect2(p + Vector2(-w * 0.5, -3), Vector2(w, 6)), Color8(90, 63, 28))
		draw_rect(Rect2(p + Vector2(-w * 0.5, -3), Vector2(w, 1)), hi)
		draw_rect(Rect2(p + Vector2(-w * 0.5, 2), Vector2(w, 1)), Color8(30, 20, 22))
		draw_circle(p, 2.0, brass)
