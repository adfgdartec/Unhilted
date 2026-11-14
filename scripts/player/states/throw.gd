extends PlayerState

const DURATION := 0.12
var _time := 0.0


func enter(_msg := {}) -> void:
	_time = 0.0
	player.throw_blade(player.pending_throw)
	player.pending_throw = {}
	player.visuals.play("throw")


func physics_update(delta: float) -> void:
	_time += delta
	player.free_move(delta)
	if _time > 0.04 and (player.dash_pressed or player.recall_pressed) and player.try_actions():
		return
	if _time >= DURATION:
		player.settle_state()
