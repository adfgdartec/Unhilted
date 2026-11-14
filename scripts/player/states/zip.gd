extends PlayerState
## Zip: dash while the blade is pinned in an enemy and the robot rides the wire
## to it. Arriving strikes the enemy, catches the blade and bounces the robot
## up off it with the air dash restored, ready to flick the next throw.
## Invulnerable while travelling (like a dash).

const SPEED := 560.0
const MAX_TIME := 0.45
const ARRIVE_DIST := 14.0

var _time := 0.0
var _target: Area2D
var _dir := Vector2.RIGHT


func enter(_msg := {}) -> void:
	_time = 0.0
	_target = player.blade.pinned_target() if player.blade else null
	if _target == null:
		player.settle_state()
		return
	player.hurtbox.invulnerable = true
	player.visuals.play("dash")
	AudioManager.sfx(&"zip")
	Fx.afterimage(player, player.visuals)
	Fx.ring(player.global_position + Player.BODY_CENTER, Color(0.4, 1.0, 1.0), 14.0, 0.2, 1.0)
	EventBus.player_dashed.emit(player.global_position + Player.BODY_CENTER, player.facing)


func physics_update(delta: float) -> void:
	_time += delta
	if player.blade == null or not player.blade.is_pinned():
		_end_without_strike() # enemy died or the pin ran out mid-zip
		return
	var to := player.blade.global_position - (player.global_position + Player.BODY_CENTER)
	if to.length() < ARRIVE_DIST:
		_strike()
		return
	_dir = to.normalized()
	if absf(_dir.x) > 0.1:
		player.facing = 1 if _dir.x > 0.0 else -1
	player.velocity = _dir * SPEED
	if _time > MAX_TIME:
		_end_without_strike()
	elif _time > 0.08 and player.get_slide_collision_count() > 0 and player.get_real_velocity().length() < 40.0:
		_end_without_strike() # wedged against level geometry


func _strike() -> void:
	var target := player.blade.pinned_target()
	if target:
		var dmg := player.stats.get_stat("melee_damage") + 1.0
		if target.take_hit(int(round(dmg)), player.global_position + Player.BODY_CENTER, player):
			Fx.hit_stop(0.08)
			AudioManager.sfx(&"hit")
			Fx.shake(3.5)
			Fx.burst(target.global_position, Color(0.5, 1.0, 1.0), 14)
			Fx.slash(target.global_position, _dir.angle(), 30.0)
			player.register_close_hit()
	player.blade.landed_hit = false # the bounce below already restores the air dash
	player.blade.catch()
	player.can_air_dash = true
	player.velocity = Vector2(-_dir.x * 90.0, player.jump_velocity * 0.8)
	machine.transition("fall")


func _end_without_strike() -> void:
	player.velocity *= 0.45
	if player.blade:
		player.blade.recall()
	machine.transition("fall")


func exit() -> void:
	player.hurtbox.invulnerable = not player.invuln_timer.is_stopped()
