extends PlayerState

const SLIDE_SPEED := 110.0
var _normal := 0.0
var _release_t := 0.0


func enter(_msg := {}) -> void:
	_normal = player.get_wall_normal().x
	player.facing = 1 if _normal > 0.0 else -1
	player.visuals.play("wall")
	_release_t = 0.0
	if player.velocity.y > SLIDE_SPEED:
		player.velocity.y = SLIDE_SPEED


func physics_update(delta: float) -> void:
	player.velocity.y = minf(player.velocity.y + player.rise_gravity * 0.35 * delta, SLIDE_SPEED)
	player.velocity.x = -_normal * 30.0
	player.facing = 1 if _normal > 0.0 else -1
	if randf() < 0.25:
		Fx.dust(player.global_position + Vector2(-_normal * 5.0, -10.0), 0.2)
	if player.wants_jump() and player.try_wall_jump(_normal):
		return
	if player.try_actions():
		return
	if player.is_on_floor():
		player.settle_state()
		return
	var holding := player.move_axis != 0.0 and signf(player.move_axis) == -signf(_normal)
	if not player.is_on_wall() or not holding:
		_release_t += delta
		if _release_t > 0.08 or not player.is_on_wall():
			player.wall_coyote(_normal)
			machine.transition("fall")
	else:
		_release_t = 0.0
