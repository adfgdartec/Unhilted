extends PlayerState

const MIN_SPEED := 280.0
const SLIDE_JUMP_SPEED := 360.0
var _speed := 0.0
var _dust := 0.0


func enter(msg := {}) -> void:
	if player.move_axis != 0.0:
		player.facing = 1 if player.move_axis > 0.0 else -1
	_speed = maxf(maxf(absf(player.velocity.x), float(msg.get("speed", 0.0))), MIN_SPEED)
	player.set_low(true)
	player.visuals.play("slide")
	AudioManager.sfx(&"slide", -6.0, 0.05)
	Fx.dust(player.global_position, 0.9)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = player.facing * _speed
	_dust -= delta
	if _dust <= 0.0:
		_dust = 0.06
		Fx.dust(player.global_position + Vector2(-player.facing * 6, 0), 0.35)
	if player.wants_jump() and player.can_jump() and player.can_stand():
		player.velocity.x = player.facing * maxf(_speed, SLIDE_JUMP_SPEED)
		machine.transition("jump")
		return
	if not player.is_on_floor():
		machine.transition("fall")
		return
	if player.try_actions():
		return
	var turned := player.move_axis != 0.0 and signf(player.move_axis) != float(player.facing)
	var bumped := player.is_on_wall() and player.get_real_velocity().length() < 30.0
	if (not player.slide_held or turned or bumped) and player.can_stand():
		if bumped:
			player.velocity.x = 0.0
		player.settle_state()


func exit() -> void:
	player.set_low(false)
