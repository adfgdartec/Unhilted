class_name GrapplePoint
extends Area2D

const HOOK := preload("res://art/items/crane_hook.png")
const CHAIN := preload("res://art/items/chain.png")
const ANCHOR := preload("res://art/props/uw_anchor.png")

@export var chain_length := 36.0
@export var swing_only := false

var _t := 0.0


func _ready() -> void:
	add_to_group("grapple_points")
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	if get_child_count() == 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)
	add_child(Fx.make_light(Color(1.0, 0.7, 0.3), 26.0, 0.5 if not swing_only else 0.35))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if swing_only:
		var top := -13.0
		while top > -13.0 - chain_length:
			draw_rect(Rect2(-1, top - 6, 2, 6), Color(0.27, 0.21, 0.21))
			top -= 6.0
		draw_texture(ANCHOR, Vector2(-9, -13))
		var glint := 0.35 + sin(_t * 3.0) * 0.2
		draw_arc(Vector2.ZERO, 9.0, -2.4, -1.2, 6, Color(1.0, 0.92, 0.6, glint), 1.0)
		return
	var y := -10.0
	while y > -10.0 - chain_length:
		draw_texture(CHAIN, Vector2(-2, y - 8))
		y -= 8.0
	draw_texture(HOOK, Vector2(-7, -12))
	var pulse := 0.5 + sin(_t * 4.0) * 0.25
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color(1.0, 0.75, 0.25, pulse * 0.6), 1.0)
