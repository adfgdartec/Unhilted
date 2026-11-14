extends PlayerState
## Quick horizontal burst with brief invulnerability. One air dash per jump.

var _time := 0.0
var _duration := 0.16


func enter(_msg := {}) -> void:
	_time = 0.0
	_duration = player.stats.get_stat("dash_duration")
	if not player.is_on_floor():
		player.can_air_dash = false
	if player.move_axis != 0.0:
		player.facing = 1 if player.move_axis > 0.0 else -1
	player.dash_cooldown.start(player.stats.get_stat("dash_cooldown"))
	player.hurtbox.invulnerable = true
	player.velocity = Vector2(player.facing * player.stats.get_stat("dash_speed"), 0.0)
	player.visuals.play("dash")
	AudioManager.sfx(&"dash", -2.0)
	EventBus.player_dashed.emit(player.global_position + Player.BODY_CENTER, player.facing)
	Fx.afterimage(player, player.visuals)
	if player.is_on_floor():
		Fx.dust(player.global_position, 0.8)


func physics_update(delta: float) -> void:
	_time += delta
	player.velocity.y = 0.0
	# Dash-slash: attacking mid-dash cancels into a Rush slash at full speed.
	if player.attack_pressed and player.blade == null and _time > 0.03:
		machine.transition("attack")
		return
	if player.dash_pressed and player.blade and player.blade.is_pinned():
		machine.transition("zip")
		return
	# dash-jump: jump out of a ground dash and keep most of its speed
	if player.wants_jump() and player.can_jump():
		player.velocity.x = player.facing * player.stats.get_stat("dash_speed") * 0.75
		machine.transition("jump")
		return
	if _time >= _duration:
		# carry momentum out of the dash instead of stopping
		player.velocity.x = player.facing * maxf(player.stats.get_stat("max_speed") * 1.3, absf(player.velocity.x) * 0.6)
		if player.is_on_floor() and player.slide_held:
			machine.transition("slide", {"speed": player.stats.get_stat("dash_speed") * 0.7})
		else:
			player.settle_state()


func exit() -> void:
	player.hurtbox.invulnerable = not player.invuln_timer.is_stopped()
