extends PlayerState

const MIN_LENGTH := 28.0
const CLIMB_SPEED := 110.0
const PUMP_ACCEL := 420.0
const MAX_SPEED := 520.0
const RELEASE_BOOST := 1.08

var _anchor := Vector2.ZERO
var _length := 60.0
var _time := 0.0


func enter(_msg := {}) -> void:
	if player.blade == null or not player.blade.is_hooked():
		player.settle_state()
		return
	_anchor = player.blade.global_position
	_time = 0.0
	var bob := player.global_position + Player.BODY_CENTER
	_length = clampf(bob.distance_to(_anchor), MIN_LENGTH, player.stats.get_stat("wire_length"))
	player.can_air_dash = true
	player.wall_jumps_left = Player.MAX_WALL_JUMPS
	player.visuals.play("grapple")
	AudioManager.sfx(&"creak", -4.0)


func physics_update(delta: float) -> void:
	_time += delta
	if player.blade == null or not player.blade.is_hooked():
		machine.transition("fall")
		return
	if player.wants_jump():
		_release(true)
		return
	if player.recall_pressed:
		player.recall_pressed = false
		_release(false)
		return
	if player.dash_pressed:
		player.consume_dash()
		machine.transition("grapple")
		return
	if player.is_on_floor() and _time > 0.1 and player.velocity.y >= 0.0:
		_release(false)
		return

	var bob := player.global_position + Player.BODY_CENTER
	var radial := bob - _anchor
	var n := radial.normalized() if radial.length() > 0.01 else Vector2.DOWN
	var tangent := Vector2(-n.y, n.x)
	if tangent.x < 0.0:
		tangent = -tangent
	var v := player.velocity + Vector2(0.0, player.rise_gravity) * delta
	v += tangent * player.move_axis * PUMP_ACCEL * delta * clampf(n.y, 0.25, 1.0)
	_length = clampf(_length + player.climb_axis * CLIMB_SPEED * delta, MIN_LENGTH, player.stats.get_stat("wire_length"))
	var next := bob + v * delta
	var off := next - _anchor
	if off.length() > _length:
		next = _anchor + off.normalized() * _length
		var n2 := off.normalized()
		var outward := v.dot(n2)
		if outward > 0.0:
			v -= n2 * outward
	v = v.limit_length(MAX_SPEED)
	var to_next := (next - bob) / delta
	player.velocity = to_next if to_next.length() <= MAX_SPEED * 1.2 else v
	if absf(player.velocity.x) > 10.0:
		player.facing = 1 if player.velocity.x > 0.0 else -1
	if _time > 0.2 and player.get_slide_collision_count() > 0 and player.get_real_velocity().length() < 15.0 and player.move_axis == 0.0:
		_release(false)


func _release(jump: bool) -> void:
	if player.blade:
		player.blade.recall()
	if jump:
		player.consume_jump()
		player.velocity = player.velocity * RELEASE_BOOST + Vector2(0.0, player.jump_velocity * 0.45)
		player.velocity.y = minf(player.velocity.y, player.jump_velocity * 0.45)
		player.jump_cut_armed = false
		AudioManager.sfx(&"jump", -4.0)
		machine.transition("jump", {"launched": true})
	else:
		machine.transition("fall")
