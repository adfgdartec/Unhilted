class_name Compactor
extends EnemyBase

const TEX := preload("res://art/enemies/compactor.png")
enum S { PATROL, WINDUP, CHARGE, STUNNED }

@export var patrol_speed := 30.0
@export var charge_speed := 230.0

var state := S.PATROL
var _st := 0.0
var _turn_cd := 0.0


func _ready() -> void:
	enemy_id = &"compactor"
	scrap_drop = 12
	setup(6, Vector2(30, 26), Vector2(32, 28), Vector2(34, 24))
	hurtbox.blocks = _plate_blocks


func _plate_blocks(from: Vector2) -> bool:
	if state == S.STUNNED:
		return false
	var rel := from - (global_position + Vector2(0, -14))
	return signf(rel.x) == float(facing) and rel.y > -16.0


func _tick(delta: float) -> void:
	_st += delta
	_turn_cd = maxf(_turn_cd - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	var d := dist_to_player()
	match state:
		S.PATROL:
			velocity.x = facing * patrol_speed
			if (is_on_wall() or _ledge_ahead()) and _turn_cd <= 0.0:
				facing = -facing
				_turn_cd = 0.4
			if signf(d.x) == float(facing) and absf(d.x) < 150.0 and absf(d.y) < 40.0:
				_go(S.WINDUP)
				AudioManager.sfx(&"telegraph", -8.0)
		S.WINDUP:
			velocity.x = -facing * 10.0
			if _st > 0.55:
				_go(S.CHARGE)
				AudioManager.sfx(&"dash")
		S.CHARGE:
			velocity.x = facing * charge_speed
			if is_on_wall() or _st > 1.6 or _ledge_ahead():
				if is_on_wall():
					AudioManager.sfx(&"crusher", -4.0)
					Fx.shake(4.0)
					Fx.spark(global_position + Vector2(facing * 18, -12), Color(1.0, 0.8, 0.5), 12)
				_go(S.STUNNED)
		S.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _st > 1.4:
				facing = 1 if d.x > 0.0 else -1
				_go(S.PATROL)
	if absf(_knock) > 5.0 and state != S.CHARGE:
		velocity.x += _knock * 0.3
		_knock = move_toward(_knock, 0.0, 900.0 * delta)
	move_and_slide()


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _ledge_ahead() -> bool:
	return is_on_floor() and not test_move(global_transform.translated(Vector2(facing * 18, 0)), Vector2(0, 8))


func _on_hit(damage: int, from_position: Vector2, source: Node) -> void:
	super(damage, from_position, source)
	_knock *= 0.3


func _draw() -> void:
	var f := 0
	match state:
		S.PATROL: f = int(_t * 6.0) % 4
		S.WINDUP: f = 4 + int(_t * 10.0) % 2
		S.CHARGE: f = 6 + int(_t * 14.0) % 2
		S.STUNNED: f = 8 + int(_t * 6.0) % 2
	draw_frame(TEX, f, 10, facing < 0)
