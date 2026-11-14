extends PlayerState
## Rising part of a jump. Releasing jump early cuts the jump short.

func enter(msg := {}) -> void:
	if msg.get("launched", false):
		player.visuals.play("jump")
		return # a wall jump / launch already set the velocity
	player.start_jump(float(msg.get("power", 1.0)))


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontal(delta)
	if player.wants_jump() and player.try_wall_jump():
		return
	if player.try_actions():
		return
	if player.velocity.y >= 0.0 or player.is_on_ceiling():
		machine.transition("fall")
