class_name Blade
extends Area2D

enum Mode { FLYING, STUCK, PINNED, HOOKED, RETURNING }

const WALL_STICK_TIME := 0.3
const WALL_STICK_TIME_SWING := 1.0
const PIN_TIME := 0.9

var mode := Mode.FLYING
var player: Player
var velocity := Vector2.ZERO
var power := 1.0
var charged := false
var landed_hit := false

var _range := 150.0
var _stuck_time := 0.0
var _return_speed := 0.0
var _hit: Array[Area2D] = []
var _spin := 0.0
var _trail: Line2D
var _pin_target: Area2D = null
var _pin_offset := Vector2.ZERO
const TRAIL_POINTS := 10
const SPRITE := preload("res://art/character/blade_thrown.png")


func launch(owner_player: Player, direction: Vector2, throw_power := 1.0, is_charged := false, full_range := false) -> void:
	player = owner_player
	power = clampf(throw_power, 0.0, 1.0)
	charged = is_charged
	velocity = direction.normalized() * player.stats.get_stat("throw_speed") * lerpf(0.75, 1.2, power)
	_range = player.stats.get_stat("wire_length") * (1.0 if full_range else lerpf(0.6, 1.0, clampf(power * 2.0, 0.0, 1.0)))
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var tint := Color(1.0, 0.9, 0.55) if charged else Color(0.3, 0.95, 1.0)
	add_child(Fx.make_light(tint, 60.0 if charged else 46.0, 1.1 if charged else 0.9))
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 4.0 if charged else 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	_trail.width_curve = curve
	var g := Gradient.new()
	if charged:
		g.set_color(0, Color(1.0, 0.7, 0.3, 0.0))
		g.set_color(1, Color(1.0, 0.97, 0.85, 0.9))
	else:
		g.set_color(0, Color(0.2, 0.9, 1.0, 0.0))
		g.set_color(1, Color(0.75, 1.0, 1.0, 0.75))
	_trail.gradient = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.material = mat
	add_child(_trail)


func is_hooked() -> bool:
	return mode == Mode.HOOKED

func is_wall_stuck() -> bool:
	return mode == Mode.STUCK and GameState.has_shard(2)

func can_swing() -> bool:
	return mode == Mode.HOOKED and GameState.has_shard(2)

func hold() -> void:
	_stuck_time = maxf(_stuck_time, 1.0)

func is_pinned() -> bool:
	return mode == Mode.PINNED and is_instance_valid(_pin_target)

func pinned_target() -> Area2D:
	return _pin_target if is_pinned() else null


func recall() -> void:
	if mode == Mode.RETURNING:
		return
	var was_pinned := is_pinned()
	var target := _pin_target
	mode = Mode.RETURNING
	_pin_target = null
	AudioManager.sfx(&"recall", -6.0)
	_hit.clear()
	_return_speed = player.stats.get_stat("recall_speed") * 0.4
	if was_pinned:
		_hit.append(target)
		var dmg := player.stats.get_stat("blade_damage") * player.stats.get_stat("recall_damage_mult")
		if target.take_hit(int(round(dmg)), player.global_position, self):
			Fx.spark(global_position, Color("38f2ff"), 6)
			Fx.hit_stop(0.04)


func catch() -> void:
	player.on_blade_returned(landed_hit)
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	var anchor := player.blade_anchor.global_position
	match mode:
		Mode.FLYING:
			global_position += velocity * delta
			_spin += delta * (44.0 if charged else 30.0)
			if global_position.distance_to(anchor) > _range:
				recall()
		Mode.STUCK:
			_stuck_time -= delta
			if _stuck_time <= 0.0:
				recall()
		Mode.PINNED:
			if not is_instance_valid(_pin_target) or not _pin_target.is_visible_in_tree():
				_pin_target = null
				recall()
			else:
				global_position = _pin_target.global_position + _pin_offset
				_stuck_time -= delta
				if _stuck_time <= 0.0:
					recall()
				elif global_position.distance_to(anchor) > player.stats.get_stat("wire_length") * 1.3:
					recall()
		Mode.HOOKED:
			pass
		Mode.RETURNING:
			var max_speed := player.stats.get_stat("recall_speed")
			_return_speed = minf(_return_speed + max_speed * 4.0 * delta, max_speed * 1.6)
			var to_hand := anchor - global_position
			if to_hand.length() < 10.0:
				player.on_blade_returned(landed_hit)
				queue_free()
				return
			global_position += to_hand.normalized() * minf(_return_speed * delta, to_hand.length())
			rotation = to_hand.angle() + PI
			_spin += delta * 30.0
	if _trail:
		_trail.add_point(global_position)
		var still := mode == Mode.HOOKED or mode == Mode.STUCK or mode == Mode.PINNED
		while _trail.get_point_count() > (0 if still else TRAIL_POINTS):
			_trail.remove_point(0)
	queue_redraw()


func _on_body_entered(_body: Node) -> void:
	if mode != Mode.FLYING:
		return
	mode = Mode.STUCK
	_stuck_time = WALL_STICK_TIME_SWING if GameState.has_shard(2) else WALL_STICK_TIME
	AudioManager.sfx(&"pin", -4.0)
	velocity = Vector2.ZERO
	Fx.shake(1.0)


func _on_area_entered(area: Area2D) -> void:
	if area is GrapplePoint and mode == Mode.FLYING:
		if area.swing_only and not GameState.has_shard(2):
			Fx.spark(global_position, Color(1.0, 0.85, 0.5), 5)
			AudioManager.sfx(&"glance")
			recall()
			return
		mode = Mode.HOOKED
		global_position = area.global_position
		AudioManager.sfx(&"hook")
		EventBus.blade_hooked.emit(area)
		return
	if area is Hurtbox and (mode == Mode.FLYING or mode == Mode.RETURNING) and not (area in _hit):
		_hit.append(area)
		var dmg := player.stats.get_stat("blade_damage")
		if mode == Mode.RETURNING:
			dmg *= player.stats.get_stat("recall_damage_mult")
		if charged and mode == Mode.FLYING:
			dmg *= 2.0
		if area.take_hit(int(round(dmg)), global_position, self):
			landed_hit = true
			Fx.hit_stop(0.07 if charged else 0.05)
			Fx.shake(3.0 if charged else 2.0)
			Fx.spark(global_position, Color(1.0, 0.9, 0.55) if charged else Color("38f2ff"), 12 if charged else 8)
			if mode == Mode.FLYING and not (charged or GameState.has_shard(1)) and area.is_inside_tree():
				_pin(area)
		elif mode == Mode.FLYING:
			Fx.spark(global_position, Color(1.0, 0.85, 0.5), 4)
			AudioManager.sfx(&"glance")
			recall()


func _pin(area: Area2D) -> void:
	AudioManager.sfx(&"pin")
	mode = Mode.PINNED
	_pin_target = area
	_pin_offset = (global_position - area.global_position).limit_length(6.0)
	_stuck_time = PIN_TIME
	velocity = Vector2.ZERO


func _draw() -> void:
	var glow := Color(1.0, 0.85, 0.45) if charged else Color("38f2ff")
	var still := mode == Mode.HOOKED or mode == Mode.STUCK or mode == Mode.PINNED
	var spin := 0.0 if still else _spin
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	draw_circle(Vector2.ZERO, 7.0 if charged else 5.5, Color(glow, 0.22))
	var sz := Vector2(SPRITE.get_width(), SPRITE.get_height()) * 0.5
	draw_texture_rect(SPRITE, Rect2(Vector2(-6, -sz.y / 2.0), sz), false, Color(1.0, 0.95, 0.8) if charged else Color.WHITE)
	if mode == Mode.PINNED:
		var t := fmod(Time.get_ticks_msec() / 1000.0, 0.5) / 0.5
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 6.0 + t * 6.0, 0.0, TAU, 16, Color(glow, 0.7 * (1.0 - t)), 1.0)
