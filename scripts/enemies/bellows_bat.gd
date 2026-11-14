class_name BellowsBat
extends EnemyBase

const TEX := preload("res://art/enemies/bellows_bat.png")
enum S { HOVER, INHALE, SWOOP, CLIMB }

@export var sense := 150.0

var state := S.HOVER
var _st := 0.0
var _home := Vector2.ZERO
var _dir := Vector2.ZERO
var _cd := 0.0


func _ready() -> void:
	enemy_id = &"bellows_bat"
	scrap_drop = 5
	setup(2, Vector2(14, 12), Vector2(22, 16), Vector2(16, 12))
	_home = global_position
	collision_mask = 1


func _tick(delta: float) -> void:
	_st += delta
	_cd = maxf(_cd - delta, 0.0)
	var d := dist_to_player() + Vector2(0, -12)
	match state:
		S.HOVER:
			var target := _home + Vector2(sin(_t * 1.3) * 16.0, sin(_t * 2.6) * 5.0)
			velocity = (target - global_position) * 3.0
			if _cd <= 0.0 and d.length() < sense:
				facing = 1 if d.x > 0.0 else -1
				_go(S.INHALE)
				AudioManager.sfx(&"bat", -6.0)
		S.INHALE:
			velocity = velocity.move_toward(Vector2(0, -20), 400.0 * delta)
			if _st > 0.4:
				_dir = (d + Vector2(0, 6)).normalized()
				_go(S.SWOOP)
		S.SWOOP:
			var spd := lerpf(260.0, 120.0, clampf(_st / 0.6, 0.0, 1.0))
			_dir = _dir.rotated(-signf(_dir.x) * 1.4 * delta).normalized()
			velocity = _dir * spd
			if _st > 0.7 or is_on_floor() or is_on_wall():
				_go(S.CLIMB)
		S.CLIMB:
			velocity = (_home - global_position).normalized() * 90.0
			if global_position.distance_to(_home) < 8.0 or _st > 2.5:
				_cd = 1.0
				_go(S.HOVER)
	if absf(_knock) > 5.0:
		velocity.x += _knock
		_knock = move_toward(_knock, 0.0, 900.0 * delta)
	move_and_slide()


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _draw() -> void:
	var f := int(_t * 10.0) % 3
	match state:
		S.INHALE: f = 0
		S.SWOOP: f = 3
	draw_set_transform(Vector2(0, 6), 0.0, Vector2.ONE)
	draw_frame(TEX, f, 4, facing < 0)
