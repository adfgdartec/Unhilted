class_name IntakeCrane
extends Node2D

signal defeated

enum S { IDLE, PARKED, CUTSCENE, INTRO, TRACK, WARN, DROP, STUCK, RISE, BALE_MOVE, BALES, MAGNET_MOVE, MAGNET_WARN, MAGNET_PULL, THROW_GRAB, THROW_AIM, THROW_RECOVER, LASER_STEAM, LASER_AIM, LASER_FIRE, DYING, WRECKED }

const MAX_HP := 16
const RAIL_Y := 40.0
const UP_Y := 112.0
const FLOOR_Y := 320.0
const SLAM_Y := FLOOR_Y - 34.0
const MIN_X := 72.0
const MAX_X := 568.0
const CENTER_X := 320.0
const CEILING_Y := 28.0
const BALE_INTERVAL := 0.5
const THROW_SPEED := 340.0
const THROW_LOCK := 0.3
const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")

var state := S.IDLE
var hp := MAX_HP
var head := Vector2(CENTER_X, UP_Y)
var player: Player

var _t := 0.0
var _anim := 0.0
var _flash := 0.0
var _phase2 := false
var _cycle := 0
var _target_x := CENTER_X
var _bale_targets: Array[float] = []
var _bales_dropped := 0
var _throws_left := 0
var _aim := Vector2.ZERO
var _last_px := 0.0
var _hinted := false
var empowered := false
var _steam := 0.0
var _beams: Array[Vector2] = []
var _beam_hit: Array[Hitbox] = []
const STEAM_TOP := 150.0
const BEAM_GAP := 112.0
var claw_closed := false
const PARK := Vector2(596, 66)
const RETURN_DAMAGE := 3
var _hurtbox: Hurtbox
var _hitbox: Hitbox
var _core_light: PointLight2D


func _ready() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	_hurtbox.invulnerable = true
	_hurtbox.add_child(_rect_shape(Vector2(54, 40), Vector2.ZERO))
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)

	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 8
	_hitbox.continuous = true
	_hitbox.start_active = false
	_hitbox.damage = 1
	_hitbox.add_child(_rect_shape(Vector2(50, 20), Vector2(0, 26)))
	add_child(_hitbox)
	for i in 3:
		var h := Hitbox.new()
		h.collision_layer = 0
		h.collision_mask = 8
		h.continuous = true
		h.start_active = false
		h.damage = 1
		var bcs := CollisionShape2D.new()
		var br := RectangleShape2D.new()
		br.size = Vector2(10, 10)
		bcs.shape = br
		h.add_child(bcs)
		add_child(h)
		_beam_hit.append(h)
	_core_light = Fx.make_light(Color(1.0, 0.6, 0.2), 70.0, 0.0)
	add_child(_core_light)
	_sync_boxes()


func _rect_shape(size: Vector2, offset: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	return cs


func park() -> void:
	state = S.PARKED
	head = PARK
	_hurtbox.invulnerable = true
	_hitbox.set_deferred("monitoring", false)
	_sync_boxes()
	queue_redraw()


func start(p: Player) -> void:
	player = p
	_enter(S.INTRO)
	AudioManager.sfx(&"horn")


func set_wrecked() -> void:
	state = S.WRECKED
	head = Vector2(410, SLAM_Y + 10)
	_hurtbox.queue_free()
	_hitbox.queue_free()
	queue_redraw()


func _enter(s: S) -> void:
	state = s
	_t = 0.0
	if not is_instance_valid(_hurtbox):
		return
	_hurtbox.invulnerable = s != S.STUCK
	_hitbox.set_deferred("monitoring", s == S.DROP)
	if s == S.WARN or s == S.MAGNET_WARN or s == S.THROW_AIM or s == S.LASER_AIM:
		AudioManager.sfx(&"telegraph", -6.0)
	if s == S.LASER_STEAM:
		AudioManager.sfx(&"steam", 0.0)
	if s == S.LASER_FIRE:
		AudioManager.sfx(&"burst", 2.0)
		Fx.shake(5.0)
		_set_beams(true)
		for b in _beams:
			Fx.spark(to_global(b), Color(1.0, 0.4, 0.8), 10)
	elif is_instance_valid(_hurtbox) and not _beam_hit.is_empty():
		_set_beams(false)
	if s == S.STUCK:
		AudioManager.sfx(&"slam")
		Fx.shake(5.0)
		var floor_point := to_global(Vector2(head.x, FLOOR_Y))
		Fx.ring(floor_point, Color(1.0, 0.7, 0.4), 60.0, 0.4, 3.0)
		Fx.dust(floor_point + Vector2(-26, 0), 1.6)
		Fx.dust(floor_point + Vector2(26, 0), 1.6)
		Fx.spark(floor_point, Color(1.0, 0.8, 0.5), 14)


func _physics_process(delta: float) -> void:
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	if state in [S.IDLE, S.WRECKED, S.PARKED, S.CUTSCENE]:
		if state == S.PARKED:
			head = PARK + Vector2(0, sin(_anim * 1.3) * 1.5)
		_sync_boxes()
		queue_redraw()
		return
	if player == null or not is_instance_valid(player) or player.is_dead:
		queue_redraw()
		return
	_t += delta
	var px := to_local(player.global_position).x

	match state:
		S.INTRO:
			head.y = UP_Y + sin(_anim * 3.0) * 2.0
			if _t > 0.8:
				_enter(S.TRACK)
		S.TRACK:
			head.x = move_toward(head.x, clampf(px, MIN_X, MAX_X), (135.0 if _phase2 else 105.0) * (1.2 if empowered else 1.0) * delta)
			head.y = move_toward(head.y, UP_Y, 200.0 * delta)
			if _t > (1.1 if _phase2 else 1.5):
				_enter(S.WARN)
		S.WARN:
			if _t > 0.55:
				_enter(S.DROP)
		S.DROP:
			head.y = move_toward(head.y, SLAM_Y, 650.0 * delta)
			if head.y >= SLAM_Y:
				_enter(S.STUCK)
		S.STUCK:
			if _t > (1.1 if _phase2 else 1.35) * (0.9 if empowered else 1.0):
				_enter(S.RISE)
		S.RISE:
			head.y = move_toward(head.y, UP_Y, 260.0 * delta)
			if head.y <= UP_Y:
				_next_attack()
		S.BALE_MOVE:
			head.x = move_toward(head.x, _target_x, 220.0 * delta)
			if absf(head.x - _target_x) < 1.0:
				_plan_bales(px)
				_enter(S.BALES)
		S.BALES:
			if _bales_dropped < _bale_targets.size() and _t >= BALE_INTERVAL * (_bales_dropped + 1):
				_drop_bale(_bale_targets[_bales_dropped])
				_bales_dropped += 1
			if _bales_dropped >= _bale_targets.size() and _t > BALE_INTERVAL * _bale_targets.size() + 0.9:
				_enter(S.TRACK)
		S.MAGNET_MOVE:
			head.x = move_toward(head.x, CENTER_X, 220.0 * delta)
			if absf(head.x - CENTER_X) < 1.0:
				_enter(S.MAGNET_WARN)
		S.MAGNET_WARN:
			if _t > 0.7:
				_enter(S.MAGNET_PULL)
		S.MAGNET_PULL:
			var resisting := player.state_machine.current_name() in ["grapple", "dash"]
			if not resisting:
				player.global_position.x = move_toward(player.global_position.x, to_global(Vector2(CENTER_X, 0)).x, 72.0 * delta)
			if _t > 1.6:
				_enter(S.WARN)
		S.LASER_STEAM:
			head.x = move_toward(head.x, CENTER_X, 200.0 * delta)
			head.y = move_toward(head.y, UP_Y - 20.0, 120.0 * delta)
			_steam = move_toward(_steam, 1.0, delta * 1.1)
			if _t > 1.1:
				_plan_beams(px)
				_enter(S.LASER_AIM)
		S.LASER_AIM:
			_steam = 1.0
			if _t < 0.75:
				_plan_beams(px, 0.06)
			if _t > 1.3:
				_enter(S.LASER_FIRE)
		S.LASER_FIRE:
			if _t > 0.45:
				_enter(S.TRACK)
		S.THROW_GRAB:
			head.y = move_toward(head.y, UP_Y - 14.0, 120.0 * delta)
			if _t > 0.5:
				_enter(S.THROW_AIM)
		S.THROW_AIM:
			var aim_time := 0.75 if _phase2 else 0.95
			if _t < aim_time - THROW_LOCK:
				var target := to_local(player.global_position + Vector2(0, -12))
				if _phase2 and _throws_left == 1:
					var vx := (px - _last_px) / maxf(delta, 0.001)
					target.x += clampf(vx, -160.0, 160.0) * 0.45
				_aim = _aim.lerp(target, 0.35) if _aim != Vector2.ZERO else target
			if _t > aim_time:
				_throw_block()
				_throws_left -= 1
				_enter(S.THROW_RECOVER)
		S.THROW_RECOVER:
			if _t > 0.55:
				if _throws_left > 0:
					_aim = Vector2.ZERO
					_enter(S.THROW_AIM)
				else:
					_enter(S.TRACK)
		S.DYING:
			head.y = move_toward(head.y, SLAM_Y + 10.0, 120.0 * delta)
			if fmod(_t, 0.18) < delta:
				Fx.spark(to_global(head + Vector2(randf_range(-24, 24), randf_range(-16, 16))), Color(1.0, 0.6, 0.3), 6)
			if _t > 1.4:
				state = S.WRECKED
				defeated.emit()
	if not state in [S.LASER_STEAM, S.LASER_AIM, S.LASER_FIRE]:
		_steam = move_toward(_steam, 0.0, delta * 0.6)
	_last_px = px
	_sync_boxes()
	queue_redraw()


func _next_attack() -> void:
	_cycle += 1
	if _phase2 and _cycle % 3 == 0:
		_enter(S.MAGNET_MOVE)
	elif _phase2 and _cycle % 3 == 1:
		_enter(S.LASER_STEAM)
	elif _cycle % 4 == 2:
		_throws_left = 2 if _phase2 else 1
		_aim = Vector2.ZERO
		_enter(S.THROW_GRAB)
	elif _cycle % 2 == 0:
		_target_x = 120.0 if head.x > CENTER_X else 520.0
		_enter(S.BALE_MOVE)
	else:
		_enter(S.TRACK)


func _plan_bales(px: float) -> void:
	_bale_targets.clear()
	_bales_dropped = 0
	for offset in [0.0, -64.0, 64.0]:
		_bale_targets.append(clampf(px + offset, 40.0, 600.0))


func _drop_bale(x: float) -> void:
	var bale := Projectile.new()
	bale.style = "bale"
	bale.radius = 8.0
	bale.gravity_force = 700.0
	bale.deflectable = false
	bale.lifetime = 2.0
	bale.color = Color(0.7, 0.6, 0.45)
	get_parent().add_child(bale)
	bale.global_position = to_global(Vector2(x, CEILING_Y))


func _plan_beams(px: float, ease := 1.0) -> void:
	var want: Array[Vector2] = []
	for off in [-BEAM_GAP, 0.0, BEAM_GAP]:
		want.append(Vector2(clampf(px + off, 30.0, 610.0), FLOOR_Y))
	if _beams.size() != 3:
		_beams = want
		return
	for i in 3:
		_beams[i] = _beams[i].lerp(want[i], ease)


func _beam_origin() -> Vector2:
	return head + Vector2(0, 24)


func _set_beams(on: bool) -> void:
	for i in _beam_hit.size():
		var h := _beam_hit[i]
		if on and i < _beams.size():
			var a := _beam_origin()
			var b := _beams[i]
			h.position = (a + b) * 0.5
			h.rotation = (b - a).angle()
			((h.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size = Vector2(a.distance_to(b), 8)
		h.set_deferred("monitoring", on)


func _throw_block() -> void:
	var from := head + Vector2(0, 30)
	var dir := (_aim - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var block := Projectile.new()
	block.style = "bale"
	block.size = 1.5
	block.radius = 11.0
	block.deflectable = false
	block.gravity_force = 120.0
	block.lifetime = 2.5
	block.spin = 7.0 * signf(dir.x if dir.x != 0.0 else 1.0)
	block.shatter = 4 if _phase2 else 3
	block.damage = 1
	block.color = Color(0.75, 0.62, 0.45)
	block.velocity = dir * (THROW_SPEED + (60.0 if _phase2 else 0.0))
	block.bounce_back = true
	block.return_target = self
	if not _hinted:
		_hinted = true
		EventBus.toast.emit("Hit the block to bounce it back!")
	get_parent().add_child(block)
	block.global_position = to_global(from)
	AudioManager.sfx(&"throw", -2.0)
	Fx.shake(3.0)


func _sync_boxes() -> void:
	if _core_light:
		_core_light.position = head
		var want := 1.3 if state == S.STUCK else (0.35 if state in [S.MAGNET_WARN, S.MAGNET_PULL] else 0.0)
		_core_light.color = Color(0.95, 0.35, 0.75) if state in [S.MAGNET_WARN, S.MAGNET_PULL] or (_phase2 and state != S.STUCK) else Color(1.0, 0.6, 0.2)
		_core_light.energy = lerpf(_core_light.energy, want, 0.2)
	if is_instance_valid(_hurtbox):
		_hurtbox.position = head
	if is_instance_valid(_hitbox):
		_hitbox.position = head


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	if state != S.STUCK:
		return
	hp = maxi(hp - damage, 0)
	_flash = 0.1
	EventBus.boss_health_changed.emit(hp, MAX_HP)
	Fx.spark(to_global(head.lerp(to_local(from_position), 0.4)), Color(1.0, 0.7, 0.3), 10)
	if hp <= 0:
		_die()
	elif not _phase2 and hp <= MAX_HP / 2:
		_phase2 = true
		if empowered:
			AudioManager.set_music_pitch(1.08, 1.5)
		Fx.shake(6.0)
		Fx.ring(to_global(head), Color(0.95, 0.35, 0.75), 70.0, 0.5, 3.0)


func _die() -> void:
	_enter(S.DYING)
	_hurtbox.invulnerable = true
	Fx.burst(to_global(head), Color(1.0, 0.65, 0.3), 36)
	Fx.ring(to_global(head), Color(1.0, 0.9, 0.7), 90.0, 0.6, 3.0)
	if Fx.post:
		Fx.post.hit()
	Fx.hit_stop(0.25)
	Fx.shake(9.0)
	for i in 6:
		var scrap: Collectible = COLLECTIBLE_SCENE.instantiate()
		scrap.kind = Collectible.Kind.SCRAP
		scrap.amount = 5
		scrap.position = head
		scrap.pop_velocity = Vector2(randf_range(-160, 160), randf_range(-140, -40))
		get_parent().add_child.call_deferred(scrap)


func returned_block_point() -> Vector2:
	return to_global(head)


func hit_by_returned_block(_block: Node) -> void:
	if state in [S.DYING, S.WRECKED, S.IDLE]:
		return
	hp = maxi(hp - RETURN_DAMAGE, 0)
	_flash = 0.15
	EventBus.boss_health_changed.emit(hp, MAX_HP)
	Fx.hit_stop(0.12)
	Fx.shake(7.0)
	Fx.burst(to_global(head), Color(0.45, 0.95, 1.0), 24)
	Fx.float_text(to_global(head + Vector2(0, -30)), "-%d" % RETURN_DAMAGE, Color(1.0, 0.85, 0.4))
	if hp <= 0:
		_die()
		return
	if not _phase2 and hp <= MAX_HP / 2:
		_phase2 = true
		Fx.ring(to_global(head), Color(0.95, 0.35, 0.75), 70.0, 0.5, 3.0)
	_throws_left = 0
	head.y = minf(head.y + 30.0, SLAM_Y)
	_enter(S.STUCK)


func is_vulnerable() -> bool:
	return state == S.STUCK


func _draw() -> void:
	var steel := Color(0.34, 0.33, 0.37)
	var dark := Color(0.18, 0.17, 0.2)
	var trim := Color(0.95, 0.35, 0.75) if _phase2 else (Color(0.4, 0.95, 1.0) if empowered else Color(1.0, 0.6, 0.15))

	draw_rect(Rect2(16, RAIL_Y - 4, 608, 8), dark)
	for x in range(24, 624, 32):
		draw_line(Vector2(x, RAIL_Y - 4), Vector2(x + 8, RAIL_Y + 4), Color(0.3, 0.28, 0.25), 1.0)
	var trolley_x := head.x
	draw_rect(Rect2(trolley_x - 18, RAIL_Y - 9, 36, 14), steel)

	if state == S.WRECKED:
		_draw_wreck(steel, dark)
		return

	draw_line(Vector2(trolley_x - 10, RAIL_Y + 5), head + Vector2(-16, -20), Color(0.55, 0.52, 0.5), 1.5)
	draw_line(Vector2(trolley_x + 10, RAIL_Y + 5), head + Vector2(16, -20), Color(0.55, 0.52, 0.5), 1.5)

	if state == S.WARN:
		var blink := 1.0 if fmod(_t, 0.12) < 0.07 else 0.35
		draw_dashed_line(Vector2(head.x, head.y + 34), Vector2(head.x, FLOOR_Y), Color(1.0, 0.25, 0.2, blink), 2.0, 6.0)
		draw_rect(Rect2(head.x - 26, FLOOR_Y - 3, 52, 3), Color(1.0, 0.25, 0.2, blink))
	if state == S.BALES:
		for i in _bale_targets.size():
			if i >= _bales_dropped:
				var tx: float = _bale_targets[i]
				var a := 0.55 + 0.35 * sin(_anim * 14.0)
				draw_rect(Rect2(tx - 8, CEILING_Y, 16, FLOOR_Y - CEILING_Y), Color(1.0, 0.3, 0.2, 0.07))
				draw_rect(Rect2(tx - 11, FLOOR_Y - 3, 22, 3), Color(1.0, 0.3, 0.2, a))
				draw_line(Vector2(tx - 11, FLOOR_Y - 3), Vector2(tx - 11, FLOOR_Y - 9), Color(1.0, 0.3, 0.2, a), 2.0)
				draw_line(Vector2(tx + 11, FLOOR_Y - 3), Vector2(tx + 11, FLOOR_Y - 9), Color(1.0, 0.3, 0.2, a), 2.0)
				draw_rect(Rect2(tx - 8, CEILING_Y - 2, 16, 8), Color(0.45, 0.4, 0.33))
	if _steam > 0.01:
		_draw_steam()
	if state == S.LASER_AIM:
		_draw_prefire()
	if state == S.LASER_FIRE:
		for b in _beams:
			var a := _beam_origin()
			var fade := 1.0 - _t / 0.45
			draw_line(a, b, Color(1.0, 0.3, 0.75, 0.35 * fade), 10.0)
			draw_line(a, b, Color(1.0, 0.45, 0.85, 0.9 * fade), 4.0)
			draw_line(a, b, Color(1.0, 0.95, 1.0, fade), 1.5)
			draw_circle(b, 7.0, Color(1.0, 0.6, 0.9, 0.6 * fade))
	if state in [S.THROW_GRAB, S.THROW_AIM]:
		var hold := head + Vector2(0, 32)
		draw_set_transform(hold, sin(_anim * 6.0) * 0.08, Vector2(1.5, 1.5))
		draw_texture(Projectile.BALE, Vector2(-8, -8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == S.THROW_AIM and _aim != Vector2.ZERO:
		var aim_time := 0.75 if _phase2 else 0.95
		var locked := _t >= aim_time - THROW_LOCK
		var a := (1.0 if fmod(_t, 0.1) < 0.06 else 0.4) if locked else 0.45
		var from := head + Vector2(0, 32)
		var to := from + (_aim - from).normalized() * 700.0
		draw_dashed_line(from, to, Color(1.0, 0.25, 0.2, a), 2.0 if locked else 1.0, 7.0)
		draw_arc(_aim, 9.0, 0.0, TAU, 20, Color(1.0, 0.3, 0.2, a), 1.5)
	if state == S.MAGNET_WARN or state == S.MAGNET_PULL:
		for i in 3:
			var r := 34.0 + fmod(120.0 - _anim * 70.0 + i * 40.0, 120.0)
			draw_arc(head, r, 0.0, TAU, 32, Color(0.95, 0.35, 0.75, 0.55 - r / 300.0), 1.5)

	var closed := state in [S.DROP, S.STUCK, S.DYING, S.THROW_GRAB, S.THROW_AIM] or claw_closed
	var spread := 4.0 if closed else 12.0
	for side in [-1.0, 1.0]:
		var base := head + Vector2(side * 14.0, 18.0)
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(side * 4.0, 0), base + Vector2(side * spread, 16), base + Vector2(side * (spread - 4.0), 18)]), dark)
	draw_rect(Rect2(head.x - 2, head.y + 18, 4, 16), dark)

	var body := Rect2(head.x - 28, head.y - 20, 56, 40)
	draw_rect(body, Color.WHITE if _flash > 0.0 else steel)
	draw_rect(Rect2(body.position, Vector2(56, 5)), trim)
	for i in 4:
		draw_line(Vector2(body.position.x + 6 + i * 14, body.position.y), Vector2(body.position.x + 12 + i * 14, body.position.y + 5), dark, 2.0)
	draw_rect(body, dark, false, 1.0)

	var core := head + Vector2(0, 2)
	if state == S.STUCK:
		var pulse := 0.7 + 0.3 * sin(_anim * 12.0)
		draw_circle(core, 11.0, Color(trim, 0.25 * pulse))
		draw_circle(core, 7.0, trim)
		draw_circle(core, 3.0, Color(1, 0.95, 0.85))
	else:
		draw_circle(core, 7.0, dark)
		draw_line(core + Vector2(-7, 0), core + Vector2(7, 0), steel.lightened(0.2), 1.0)
		draw_circle(core, 2.0, trim.darkened(0.4))
		if empowered:
			var g := 0.6 + 0.4 * sin(_anim * 5.0)
			draw_circle(core, 10.0, Color(0.4, 0.95, 1.0, 0.18 * g))
			draw_colored_polygon(PackedVector2Array([core + Vector2(0, -4), core + Vector2(2.5, 0), core + Vector2(0, 4), core + Vector2(-2.5, 0)]), Color(0.75, 1.0, 1.0, g))


func _draw_steam() -> void:
	var top := lerpf(FLOOR_Y, STEAM_TOP, _steam)
	var rows := 9
	for r in rows:
		var y := lerpf(FLOOR_Y - 4.0, top + 10.0, float(r) / (rows - 1))
		var x := 8.0 + fmod(_anim * (14.0 + r * 3.0) * (1 if r % 2 == 0 else -1), 48.0)
		while x < 640.0:
			var wob := sin(_anim * 1.7 + x * 0.05 + r) * 4.0
			var a := 0.10 + 0.06 * sin(_anim * 2.3 + x * 0.11 + r * 1.3)
			draw_circle(Vector2(x, y + wob), 18.0 + (r % 3) * 4.0, Color(0.92, 0.86, 0.9, a * _steam))
			x += 34.0
	var x2 := 0.0
	while x2 < 640.0:
		draw_circle(Vector2(x2, top + sin(_anim * 2.0 + x2 * 0.04) * 5.0), 12.0, Color(0.95, 0.9, 0.95, 0.16 * _steam))
		x2 += 20.0


func _draw_prefire() -> void:
	var top := lerpf(FLOOR_Y, STEAM_TOP, _steam)
	var locked := _t >= 0.75
	var flick := (1.0 if fmod(_t, 0.08) < 0.05 else 0.5) if locked else (0.55 + 0.25 * sin(_anim * 30.0))
	var a := _beam_origin()
	draw_circle(a, 4.0 + (2.0 if locked else 0.0), Color(1.0, 0.4, 0.85, 0.8))
	for b in _beams:
		var d := (b - a)
		if absf(d.y) < 1.0:
			continue
		var t0 := clampf((top - a.y) / d.y, 0.0, 1.0)
		var p0 := a + d * t0
		var seg := p0
		var steps := int(p0.distance_to(b) / 6.0)
		for k in steps:
			var p1 := p0.lerp(b, float(k + 1) / steps)
			if k % 2 == 0:
				draw_line(seg, p1, Color(1.0, 0.35, 0.8, 0.85 * flick), 2.0 if locked else 1.0)
			seg = p1
		draw_arc(b, 6.0, 0.0, TAU, 12, Color(1.0, 0.35, 0.8, 0.7 * flick), 1.0)


func _draw_wreck(steel: Color, dark: Color) -> void:
	draw_line(Vector2(head.x - 10, RAIL_Y + 5), Vector2(head.x - 18, RAIL_Y + 60), Color(0.55, 0.52, 0.5), 1.5)
	draw_line(Vector2(head.x + 10, RAIL_Y + 5), Vector2(head.x + 4, RAIL_Y + 44), Color(0.55, 0.52, 0.5), 1.5)
	draw_set_transform(head, 0.35, Vector2.ONE)
	draw_rect(Rect2(-28, -20, 56, 40), steel.darkened(0.2))
	draw_rect(Rect2(-28, -20, 56, 5), Color(0.5, 0.35, 0.2))
	draw_circle(Vector2(0, 2), 7.0, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
