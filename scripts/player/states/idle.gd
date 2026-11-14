extends PlayerState

func enter(_msg := {}) -> void:
	player.visuals.play("idle")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_horizontal(delta)
	if not player.is_on_floor():
		machine.transition("fall")
	elif player.wants_jump():
		machine.transition("jump")
	elif player.wants_slide():
		machine.transition("slide")
	elif player.try_actions():
		pass
	elif player.move_axis != 0.0:
		machine.transition("run")
