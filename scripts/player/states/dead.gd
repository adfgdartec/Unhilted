extends PlayerState

func enter(_msg := {}) -> void:
	player.visuals.play("dead")
	player.velocity.x *= 0.3
	if player.blade:
		player.blade.recall()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 300.0 * delta)
