class_name GasLamp
extends Node2D

signal relit

const POST := preload("res://art/props/uw_gaslamp.png")
const WALL := preload("res://art/props/uw_wall_lamp.png")

@export var wall_mounted := false
@export var lit := true
@export var radius := 90.0
@export var energy := 0.9

var _light: PointLight2D
var _hurtbox: Hurtbox
var _t := 0.0
var _cool := 0.0


func _ready() -> void:
	add_to_group("gas_lamps")
	_t = randf() * 10.0
	_light = Fx.make_light(Color(1.0, 0.72, 0.36), radius, energy)
	_light.position = _flame()
	add_child(_light)
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 14)
	cs.shape = r
	cs.position = _flame()
	_hurtbox.add_child(cs)
	add_child(_hurtbox)
	_hurtbox.remove_from_group("enemy_hurtbox")
	_hurtbox.hit.connect(func(_d, _f, _s): if not lit and _cool <= 0.0: relight())
	_apply()


func _flame() -> Vector2:
	return Vector2(0, -8) if wall_mounted else Vector2(0, -36)


func snuff() -> void:
	if not lit:
		return
	lit = false
	_cool = 0.3
	AudioManager.sfx(&"steam", -18.0)
	Fx.spark(global_position + _flame(), Color(0.7, 0.7, 0.7), 4)
	_apply()


func relight() -> void:
	if lit:
		return
	lit = true
	AudioManager.sfx(&"catch", -6.0)
	Fx.ring(global_position + _flame(), Color(1.0, 0.8, 0.45), 14.0, 0.3, 1.0)
	_apply()
	relit.emit()


func _apply() -> void:
	_light.enabled = lit
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	if lit:
		_light.energy = energy * (0.92 + sin(_t * 9.0) * 0.04 + sin(_t * 23.0) * 0.03)
	if int(_t * 6.0) != int((_t - delta) * 6.0):
		queue_redraw()


func _draw() -> void:
	var tex := WALL if wall_mounted else POST
	var fw := tex.get_width() / 2
	var frame := (int(_t * 6.0) % 2) if lit else 1
	var origin := Vector2(-fw / 2.0, -tex.get_height() if not wall_mounted else -15.0)
	var tint := Color.WHITE if lit else Color(0.55, 0.55, 0.6)
	draw_texture_rect_region(tex, Rect2(origin, Vector2(fw, tex.get_height())), Rect2(frame * fw, 0, fw, tex.get_height()), tint)
	if not lit:
		var f := _flame()
		draw_rect(Rect2(f + Vector2(-2, -3), Vector2(4, 6)), Color(0.12, 0.12, 0.14))
