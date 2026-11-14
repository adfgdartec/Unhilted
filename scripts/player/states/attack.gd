extends PlayerState

const DURATION := 0.24
const ACTIVE_START := 0.03
const ACTIVE_END := 0.14
const CANCEL_AFTER := 0.14

var _time := 0.0
var _combo := 1
var _direction := "forward"
var _swinging := false
var _rush := false


func enter(msg := {}) -> void:
	_time = 0.0
	_swinging = false
	_combo = int(msg.get("combo", 1))
	var aim := player.aim_vector
	if player.attack_from_mouse:
		aim = (player.get_global_mouse_position() - (player.global_position + Player.BODY_CENTER)).normalized()
	_direction = player.attack_direction(aim)
	var hb := player.melee_hitbox
	_rush = player.recent_speed >= Player.RUSH_SPEED
	hb.damage = int(player.stats.get_stat("melee_damage")) + (1 if _rush else 0)
	if player.take_rebound():
		hb.damage *= 2
	match _direction:
		"up": hb.rotation = -PI / 2.0
		"down": hb.rotation = PI / 2.0
		_: hb.rotation = 0.0 if player.facing > 0 else PI
	player.visuals.play("attack_" + _direction if _direction != "forward" else "attack")


func physics_update(delta: float) -> void:
	_time += delta
	var keep_facing := player.facing
	player.free_move(delta)
	if _swinging:
		player.facing = keep_facing

	if _time >= ACTIVE_START and not _swinging and _time < ACTIVE_END:
		_swinging = true
		player.melee_hitbox.begin_swing()
		AudioManager.sfx(&"swing_rush" if _rush else &"swing", -3.0, 0.1)
		var hb := player.melee_hitbox
		var arc := (36.0 if _rush else 26.0)
		Fx.slash(hb.global_position + Vector2.from_angle(hb.rotation) * 4.0, hb.rotation, arc, _combo % 2 == 0)
		if _rush:
			Fx.ring(hb.global_position, Color(0.5, 1.0, 1.0), 16.0, 0.18, 1.0)
	if _time >= ACTIVE_END and _swinging:
		_swinging = false
		player.melee_hitbox.end_swing()

	if _time >= CANCEL_AFTER:
		if (player.dash_pressed or player.recall_pressed or not player.pending_throw.is_empty()) and player.try_actions():
			return

	var next_at := Player.AUTOSWING_DELAY if player.attack_held and not player.attack_pressed else DURATION
	if player.attack_pressed and _time >= CANCEL_AFTER:
		next_at = _time
	if _time >= next_at and (player.attack_held or player.attack_pressed) and player.blade == null:
		player.consume_attack()
		machine.transition("attack", {"combo": _combo + 1})
		return
	if _time >= DURATION and not (player.attack_held and player.blade == null):
		player.settle_state()


func exit() -> void:
	player.melee_hitbox.end_swing()


func is_rush() -> bool:
	return _rush


func on_hit_landed() -> void:
	if _rush:
		Fx.hit_stop(0.04)
		Fx.shake(2.0)
	if _direction == "down":
		player.velocity.y = player.jump_velocity * 0.85
		player.jump_cut_armed = false
		player.can_air_dash = true
	elif _direction == "forward":
		player.velocity.x -= player.facing * 90.0
