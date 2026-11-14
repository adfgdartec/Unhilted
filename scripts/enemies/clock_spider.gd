class_name ClockSpider
extends EnemyBase

const TEX := preload("res://art/enemies/clock_spider.png")
enum S { SKITTER, CROUCH, LEAP, REWIND }

var state := S.SKITTER
var _st := 0.0
var _leaps := 0


func _ready() -> void:
	enemy_id = &"clock_spider"
	scrap_drop = 5
	setup(2, Vector2(16, 10), Vector2(22, 14), Vector2(18, 10))


func _tick(delta: float) -> void:
	_st += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	var d := dist_to_player()
	match state:
		S.SKITTER:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, signf(d.x) * 40.0 if absf(d.x) < 220.0 else 0.0, 500.0 * delta)
			if absf(d.x) < 180.0 and absf(d.y) < 80.0 and _st > 0.6 and is_on_floor():
				facing = 1 if d.x > 0.0 else -1
				_go(S.CROUCH)
				AudioManager.sfx(&"gear", -10.0)
		S.CROUCH:
			velocity.x = 0.0
			if _st > 0.35:
				var dist := clampf(absf(d.x), 40.0, 170.0)
				velocity = Vector2(facing * dist * 1.25, -300.0)
				_go(S.LEAP)
		S.LEAP:
			if is_on_floor() and _st > 0.1:
				velocity.x = 0.0
				_leaps += 1
				Fx.dust(global_position, 0.5)
				_go(S.REWIND if _leaps >= 3 else S.SKITTER)
		S.REWIND:
			velocity.x = 0.0
			if _st > 1.6:
				_leaps = 0
				_go(S.SKITTER)
	if absf(_knock) > 5.0:
		velocity.x += _knock
		_knock = move_toward(_knock, 0.0, 900.0 * delta)
	move_and_slide()


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _draw() -> void:
	var f := 0
	match state:
		S.CROUCH: f = 1
		S.LEAP: f = 2
		S.REWIND: f = 1 if int(_t * 4.0) % 2 == 0 else 0
		_: f = 0 if int(_t * 8.0) % 2 == 0 else 1
	draw_frame(TEX, f, 3, facing < 0)
