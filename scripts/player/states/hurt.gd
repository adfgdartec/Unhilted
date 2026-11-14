extends PlayerState

const DURATION := 0.25
var _time := 0.0


func enter(msg := {}) -> void:
	_time = 0.0
	player.velocity = Vector2(float(msg.get("dir", -1.0)) * 170.0, -150.0)
	player.visuals.play("hurt")


func physics_update(delta: float) -> void:
	_time += delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 400.0 * delta)
	if _time >= DURATION:
		player.settle_state()
