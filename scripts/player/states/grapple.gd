extends PlayerState
## The blade is hooked on a grapple point: the wire yanks the robot toward it
## (Ultrakill whiplash style). Hold a direction and you keep the speed when it
## lets go, flying on past the hook; jump during the pull to launch out of it.
## With Shard II the same pull works on a blade stuck in a wall ("wall zip"):
## you arrive against the wall, ready to wall-jump off it.

const MAX_TIME := 1.2
var _time := 0.0
var _target := Vector2.ZERO
var _wall := false ## Shard II wall zip: pulled to the blade stuck in a wall


func enter(_msg := {}) -> void:
	_time = 0.0
	if player.blade == null or not (player.blade.is_hooked() or player.blade.is_wall_stuck()):
		player.settle_state()
		return
	_wall = player.blade.is_wall_stuck()
	if _wall:
		player.blade.hold()
	_target = player.blade.global_position
	player.can_air_dash = true
	player.visuals.play("grapple")
	AudioManager.sfx(&"zip", -6.0)
	Fx.shake(1.5)


func physics_update(delta: float) -> void:
	_time += delta
	var to_target := _target - (player.global_position + Player.BODY_CENTER)
	if to_target.length() < 14.0 or _time > MAX_TIME or player.wants_jump():
		_release()
		return
	player.velocity = to_target.normalized() * player.stats.get_stat("grapple_speed")
	if player.get_slide_collision_count() > 0 and _time > 0.15 and player.get_real_velocity().length() < 20.0:
		_release() # got stuck on geometry


func _release() -> void:
	if player.blade:
		player.blade.recall()
	if player.wants_jump():
		# whiplash jump: all the pull's speed plus a jump on top
		player.consume_jump()
		player.velocity = Vector2(player.velocity.x * 1.05, minf(player.velocity.y, 0.0) + player.jump_velocity * 0.8)
		player.jump_cut_armed = true
		AudioManager.sfx(&"jump", -4.0)
		machine.transition("jump", {"launched": true})
	else:
		# Hold a direction to fling on past the hook with the pull's speed;
		# let go and you settle at the hook (so hooks over ledges set you down).
		var steering := player.move_axis != 0.0 and signf(player.move_axis) == signf(player.velocity.x)
		player.velocity *= 0.9 if steering else 0.3
		if _wall:
			player.velocity = Vector2(player.velocity.x * 0.2, minf(player.velocity.y, 0.0) * 0.3)
			player.wall_jumps_left = maxi(player.wall_jumps_left, 1) # a wall zip always leaves a kick
		machine.transition("fall")
