extends PlayerState
## Falling. Coyote time + jump buffer make jumps feel forgiving.

func enter(_msg := {}) -> void:
	player.visuals.play("fall")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontal(delta)
	if player.wants_jump() and player.can_jump():
		machine.transition("jump")
		return
	if player.wants_jump() and player.try_wall_jump():
		return
	if player.try_actions():
		return
	if player.is_on_floor():
		# land into a slide if you're holding it and moving: no speed lost
		if player.slide_held and absf(player.velocity.x) > 60.0:
			machine.transition("slide")
		else:
			player.settle_state()
		return
	if player.velocity.y > 0.0 and player.is_on_wall() and player.move_axis != 0.0 \
			and signf(player.move_axis) == -signf(player.get_wall_normal().x):
		machine.transition("wall_slide")
