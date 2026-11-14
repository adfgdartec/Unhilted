class_name Rustcrawler
extends EnemyBase

const TEX := preload("res://art/enemies/rustcrawler.png")
enum S { CLING, DROP, CHASE }

@export var start_on_ceiling := true
@export var speed := 70.0

var state := S.CLING
var _hop_cd := 0.0


func _ready() -> void:
	enemy_id = &"rustcrawler"
	scrap_drop = 4
	setup(2, Vector2(14, 10), Vector2(18, 14), Vector2(14, 10))
	state = S.CLING if start_on_ceiling else S.CHASE
	if state == S.CLING:
		position.y += 14


func _tick(delta: float) -> void:
	var d := dist_to_player()
	match state:
		S.CLING:
			velocity = Vector2.ZERO
			if absf(d.x) < 26.0 and d.y > 0.0 and d.y < 200.0:
				state = S.DROP
				AudioManager.sfx(&"telegraph", -16.0)
		S.DROP:
			velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
			velocity.x = 0.0
			move_and_slide()
			if is_on_floor():
				state = S.CHASE
				Fx.dust(global_position, 0.6)
		S.CHASE:
			_hop_cd = maxf(_hop_cd - delta, 0.0)
			velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
			if absf(_knock) > 5.0:
				velocity.x = _knock
				_knock = move_toward(_knock, 0.0, 800.0 * delta)
			elif is_on_floor():
				facing = 1 if d.x > 0.0 else -1
				velocity.x = facing * speed if absf(d.x) < 260.0 else 0.0
				if _hop_cd <= 0.0 and absf(d.x) < 60.0 and absf(d.y) < 60.0:
					velocity.y = -230.0
					velocity.x = facing * 140.0
					_hop_cd = 1.1
				elif is_on_wall():
					velocity.y = -200.0
			move_and_slide()


func _draw() -> void:
	match state:
		S.CLING:
			draw_frame(TEX, 4 + int(_t * 3.0) % 2, 7, facing < 0, true)
		S.DROP:
			draw_frame(TEX, 6, 7, facing < 0)
		_:
			var f := 6 if not is_on_floor() else int(_t * 12.0) % 4
			draw_frame(TEX, f, 7, facing < 0)
