class_name BoilerBloat
extends EnemyBase
## A floating pressure tank that drifts toward you. Close up it swells,
## glows red and bursts (the swell is the tell: get away). Killing it sets
## it off too, a beat later, so pop it from range with the thrown blade, or
## hit it and dash clear. The burst hurts other enemies as well.
##   DRIFT -> SWELL -> BURST

const TEX := preload("res://art/enemies/boiler_bloat.png") # calm, swelling, about to burst
const BURST_RADIUS := 52.0
enum S { DRIFT, SWELL }

var state := S.DRIFT
var _st := 0.0
var _bursting := false


func _ready() -> void:
	enemy_id = &"boiler_bloat"
	scrap_drop = 6
	setup(2, Vector2(16, 16), Vector2(22, 22), Vector2(14, 14))
	collision_mask = 1


func _tick(delta: float) -> void:
	_st += delta
	var d := dist_to_player() + Vector2(0, -14)
	match state:
		S.DRIFT:
			var want := d.normalized() * 34.0 if d.length() < 240.0 else Vector2.ZERO
			want.y += sin(_t * 2.0) * 10.0
			velocity = velocity.move_toward(want, 80.0 * delta)
			if d.length() < 46.0:
				_swell(0.8)
		S.SWELL:
			velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
			if _st > _swell_time:
				_burst()
				return
	if absf(_knock) > 5.0:
		velocity.x += _knock * 0.5
		_knock = move_toward(_knock, 0.0, 900.0 * delta)
	move_and_slide()


var _swell_time := 0.8

func _swell(t: float) -> void:
	if state == S.SWELL:
		_swell_time = minf(_swell_time, _st + t)
		return
	state = S.SWELL
	_st = 0.0
	_swell_time = t
	AudioManager.sfx(&"telegraph", -10.0)


func _on_died() -> void:
	# killed: it goes off a beat later instead of dropping quietly
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	_swell(0.3)


func _burst() -> void:
	if _bursting:
		return
	_bursting = true
	AudioManager.sfx(&"burst")
	Fx.burst(global_position + Vector2(0, -14), Color(1.0, 0.9, 0.8), 26)
	Fx.ring(global_position + Vector2(0, -14), Color(1.0, 0.85, 0.7), BURST_RADIUS, 0.3, 2.0)
	Fx.shake(4.0)
	var c := global_position + Vector2(0, -14)
	if player and is_instance_valid(player) and (player.global_position + Player.BODY_CENTER).distance_to(c) < BURST_RADIUS:
		player.hurtbox.take_hit(1, c, self)
	for hb in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if hb != hurtbox and is_instance_valid(hb) and hb.global_position.distance_to(c) < BURST_RADIUS:
			hb.take_hit(2, c, self)
	super._on_died()


func _draw() -> void:
	var f := 0
	if state == S.SWELL:
		f = 1 if _st < _swell_time * 0.5 else 2
		if f == 2 and fmod(_t, 0.1) < 0.05:
			f = 1
	draw_set_transform(Vector2(0, 0), 0.0, Vector2.ONE)
	draw_frame(TEX, f, 3, false)
