extends PlayerState

func enter(_msg := {}) -> void:
	player.visuals.play("run")


var _step := 0.0

func physics_update(delta: float) -> void:
	_step -= delta
	if _step <= 0.0 and player.is_on_floor() and absf(player.velocity.x) > 40.0:
		_step = 0.27
		AudioManager.sfx(&"step", -14.0, 0.15)
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
	elif player.move_axis == 0.0 and absf(player.velocity.x) < 5.0:
		machine.transition("idle")
