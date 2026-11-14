class_name PistonWalker
extends EnemyBase
## A boiler on two piston legs. It stomps along a patrol; when you're close
## and level with it, it hisses (steam from the stack, legs bunch up: the
## tell) and stomps, sending a shockwave along the floor both ways. Jump the
## wave, then hit it while it resets.
##   PATROL -> WINDUP -> STOMP -> RECOVER -> PATROL

const TEX := preload("res://art/enemies/piston_walker.png") # 6 frames
enum S { PATROL, WINDUP, STOMP, RECOVER }

@export var speed := 26.0

var state := S.PATROL
var _st := 0.0
var _turn_cd := 0.0
var _cd := 0.0


func _ready() -> void:
	enemy_id = &"piston_walker"
	scrap_drop = 10
	setup(5, Vector2(24, 32), Vector2(28, 34), Vector2(26, 30))


func _tick(delta: float) -> void:
	_st += delta
	_turn_cd = maxf(_turn_cd - delta, 0.0)
	_cd = maxf(_cd - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	var d := dist_to_player()
	match state:
		S.PATROL:
			velocity.x = facing * speed
			if (is_on_wall() or _ledge_ahead()) and _turn_cd <= 0.0:
				facing = -facing
				_turn_cd = 0.5
			if _cd <= 0.0 and absf(d.x) < 110.0 and absf(d.y) < 36.0 and is_on_floor():
				facing = 1 if d.x > 0.0 else -1
				_go(S.WINDUP)
				AudioManager.sfx(&"steam", -10.0)
		S.WINDUP:
			velocity.x = 0.0
			if _st > 0.55:
				_go(S.STOMP)
				AudioManager.sfx(&"crusher", -2.0)
				Fx.shake(3.0)
				Fx.dust(global_position, 1.4)
				Shockwave.spawn(get_parent(), global_position + Vector2(14, 0), 1.0)
				Shockwave.spawn(get_parent(), global_position + Vector2(-14, 0), -1.0)
		S.STOMP:
			velocity.x = 0.0
			if _st > 0.25:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = 0.0
			if _st > 0.7:
				_cd = 1.2
				_go(S.PATROL)
	if absf(_knock) > 5.0:
		velocity.x += _knock * 0.4
		_knock = move_toward(_knock, 0.0, 900.0 * delta)
	move_and_slide()


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _ledge_ahead() -> bool:
	return is_on_floor() and not test_move(global_transform.translated(Vector2(facing * 16, 0)), Vector2(0, 8))


func _draw() -> void:
	var f := int(_t * 6.0) % 4
	match state:
		S.WINDUP: f = 4
		S.STOMP: f = 5
		S.RECOVER: f = 5 if _st < 0.3 else 4
	draw_frame(TEX, f, 6, facing < 0)
