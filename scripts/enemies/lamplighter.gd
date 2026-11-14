class_name Lamplighter
extends CharacterBody2D

signal defeated

const MAX_HP := 14
const TEX := preload("res://art/enemies/lamplighter.png")
const GRAVITY := 900.0
enum S { IDLE, STALK, WINDUP, SWEEP, RECOVER, LEAP, SNUFF, DAZZLED, DYING, WRECKED }

var state := S.IDLE
var hp := MAX_HP
var player: Player
var facing := -1
var _st := 0.0
var _t := 0.0
var _flash := 0.0
var _attacks := 0
var _lamp: GasLamp = null
var _hurtbox: Hurtbox
var _contact: Hitbox
var _pole: Hitbox
var _head_light: PointLight2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_child(_box(CollisionShape2D.new(), Vector2(16, 56), Vector2(0, -28)))
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(_box(CollisionShape2D.new(), Vector2(22, 60), Vector2(0, -30)))
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)
	_contact = _make_hitbox(Vector2(14, 40), Vector2(0, -22))
	_contact.start_active = false
	_pole = _make_hitbox(Vector2(70, 10), Vector2(40, -26))
	_pole.start_active = false
	_head_light = Fx.make_light(Color(1.0, 0.78, 0.4), 70.0, 0.8)
	_head_light.position = Vector2(0, -56)
	add_child(_head_light)
	_connect_lamps.call_deferred()


func _connect_lamps() -> void:
	for lamp in get_tree().get_nodes_in_group("gas_lamps"):
		lamp.relit.connect(_on_lamp_relit.bind(lamp))


func _box(cs: CollisionShape2D, size: Vector2, at: Vector2) -> CollisionShape2D:
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = at
	return cs


func _make_hitbox(size: Vector2, at: Vector2) -> Hitbox:
	var h := Hitbox.new()
	h.collision_layer = 0
	h.collision_mask = 8
	h.monitorable = false
	h.continuous = true
	h.add_child(_box(CollisionShape2D.new(), size, at))
	add_child(h)
	return h


func start(p: Player) -> void:
	player = p
	_contact.set_deferred("monitoring", true)
	AudioManager.sfx(&"telegraph", -6.0)
	_go(S.STALK)


func set_wrecked() -> void:
	state = S.WRECKED
	_hurtbox.queue_free()
	_contact.queue_free()
	_pole.queue_free()
	_head_light.energy = 0.2
	queue_redraw()


func _phase2() -> bool:
	return hp <= MAX_HP / 2


func _go(s: S) -> void:
	state = s
	_st = 0.0
	_pole.set_deferred("monitoring", s == S.SWEEP)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	if state == S.IDLE or state == S.WRECKED:
		queue_redraw()
		return
	_st += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 480.0)
	var dx := 0.0
	if player and is_instance_valid(player) and not player.is_dead:
		dx = player.global_position.x - global_position.x
	var fast := _phase2()
	_pole.scale.x = facing
	match state:
		S.STALK:
			facing = 1 if dx > 0.0 else -1
			velocity.x = facing * (78.0 if fast else 58.0) if absf(dx) > 46.0 else 0.0
			if absf(dx) < 72.0 and _st > 0.4:
				_go(S.WINDUP)
				AudioManager.sfx(&"telegraph", -10.0)
			elif _st > 2.4 and _should_snuff():
				_start_leap()
		S.WINDUP:
			velocity.x = 0.0
			if _st > (0.42 if fast else 0.55):
				_go(S.SWEEP)
				AudioManager.sfx(&"swing_rush", -2.0)
		S.SWEEP:
			velocity.x = facing * 40.0
			if _st > 0.28:
				_attacks += 1
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = 0.0
			if _st > (0.6 if fast else 0.8):
				if _should_snuff():
					_start_leap()
				else:
					_go(S.STALK)
		S.LEAP:
			if is_on_floor() and _st > 0.15:
				velocity.x = 0.0
				Fx.dust(global_position, 0.8)
				_go(S.SNUFF)
		S.SNUFF:
			velocity.x = 0.0
			if _st > 0.35 and _lamp and is_instance_valid(_lamp):
				_lamp.snuff()
				_lamp = null
			if _st > 0.7:
				_go(S.STALK)
		S.DAZZLED:
			velocity.x = 0.0
			if _st > 1.4:
				_go(S.STALK)
		S.DYING:
			velocity.x = 0.0
			if fmod(_st, 0.2) < delta:
				Fx.spark(global_position + Vector2(randf_range(-10, 10), randf_range(-56, -10)), Color(1.0, 0.75, 0.4), 6)
			_head_light.energy = lerpf(0.8, 0.15, clampf(_st / 1.3, 0.0, 1.0))
			if _st > 1.3:
				state = S.WRECKED
				_relight_all()
				EventBus.enemy_killed.emit(&"lamplighter", global_position)
				GameState.add_key_item(&"lamplighters_lantern")
				EventBus.item_collected.emit(&"lamplighters_lantern")
				defeated.emit()
	move_and_slide()
	queue_redraw()


func _lit_lamps() -> Array:
	return get_tree().get_nodes_in_group("gas_lamps").filter(func(l): return l.lit)


func _should_snuff() -> bool:
	if _lit_lamps().is_empty():
		return false
	return _attacks >= (2 if _phase2() else 3)


func _start_leap() -> void:
	var best: GasLamp = null
	for l in _lit_lamps():
		if best == null or absf(l.global_position.x - global_position.x) < absf(best.global_position.x - global_position.x):
			best = l
	if best == null:
		_go(S.STALK)
		return
	_attacks = 0
	_lamp = best
	var to := best.global_position.x + (14.0 if best.global_position.x < global_position.x else -14.0) - global_position.x
	facing = 1 if to > 0.0 else -1
	velocity = Vector2(clampf(to * 1.6, -320.0, 320.0), -340.0)
	AudioManager.sfx(&"jump", -2.0)
	_go(S.LEAP)


func _on_lamp_relit(lamp: GasLamp) -> void:
	if state in [S.STALK, S.WINDUP, S.RECOVER, S.SNUFF] and lamp.global_position.distance_to(global_position) < 64.0:
		_go(S.DAZZLED)
		AudioManager.sfx(&"glance")
		Fx.ring(global_position + Vector2(0, -56), Color(1.0, 0.9, 0.6), 24.0, 0.3, 2.0)


func _relight_all() -> void:
	for l in get_tree().get_nodes_in_group("gas_lamps"):
		l.relight()


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	if state in [S.IDLE, S.DYING, S.WRECKED]:
		return
	hp = maxi(hp - damage, 0)
	_flash = 0.1
	EventBus.boss_health_changed.emit(hp, MAX_HP)
	Fx.spark(global_position + Vector2(0, -30), Color(1.0, 0.8, 0.5), 8)
	if state == S.STALK:
		velocity.x = signf(global_position.x - from_position.x) * 60.0
	if hp <= 0:
		_go(S.DYING)
		_hurtbox.invulnerable = true
		_contact.set_deferred("monitoring", false)
		Fx.hit_stop(0.2)
		Fx.shake(6.0)
		AudioManager.sfx(&"enemy_die")


func _draw() -> void:
	var dark := _lit_lamps().is_empty() and state != S.WRECKED and state != S.DYING
	var frame := int(_t * 4.0) % 2
	match state:
		S.WINDUP, S.SNUFF: frame = 2
		S.SWEEP: frame = 3
		S.LEAP: frame = 4
		S.RECOVER, S.DAZZLED: frame = 0
	var fw := TEX.get_width() / 5
	var h := TEX.get_height()
	var tint := Color(3, 3, 3) if _flash > 0.0 else (Color(1, 1, 1, 0.18) if dark else Color.WHITE)
	if state == S.WRECKED:
		draw_set_transform(Vector2(0, -6), -PI * 0.5 * facing, Vector2(facing, 1))
		draw_texture_rect_region(TEX, Rect2(-fw / 2.0, -h / 2.0, fw, h), Rect2(0, 0, fw, h), Color(0.6, 0.55, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	draw_texture_rect_region(TEX, Rect2(-fw / 2.0, -h, fw, h), Rect2(frame * fw, 0, fw, h), tint)
	if dark:
		draw_texture_rect_region(TEX, Rect2(-fw / 2.0 + 22, -h + 6, 12, 14), Rect2(frame * fw + 22, 6, 12, 14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == S.WINDUP and fmod(_t, 0.14) < 0.07:
		draw_circle(Vector2(0, -h + 14), 9.0, Color(1.0, 0.9, 0.6, 0.35))
	if state == S.DAZZLED:
		for i in 3:
			var a := _t * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 10.0, -h - 2 + sin(a) * 3.0), 1.5, Color(1.0, 0.9, 0.5))
