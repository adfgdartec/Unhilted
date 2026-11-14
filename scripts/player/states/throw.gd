extends PlayerState
## Short throw pose; the blade itself flies on its own (see blade.gd).
## The throw's direction and power come from the released gesture.

const DURATION := 0.12
var _time := 0.0


func enter(_msg := {}) -> void:
	_time = 0.0
	player.throw_blade(player.pending_throw)
	player.pending_throw = {}
	player.visuals.play("throw")


func physics_update(delta: float) -> void:
	_time += delta
	player.free_move(delta) # throwing never stops you moving or jumping
	if _time > 0.04 and (player.dash_pressed or player.recall_pressed) and player.try_actions():
		return # don't eat a quick follow-up (dash into the pinned blade, or recall)
	if _time >= DURATION:
		player.settle_state()
