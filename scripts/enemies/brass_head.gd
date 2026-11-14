class_name BrassHead
extends Node2D
## Optional mini-boss: the brass giant's head, waking up in Giant's Brow.
## Its weak point is the eye, which is only open (and hittable) during and
## right after a beam. Attacks cycle: BEAM (a ray from the eye sweeps along
## the floor: jump it), DEBRIS (shadows mark where junk will fall), STEAM
## (vents along the floor puff, then blast). Phase 2 at half health: the beam
## sweeps back, more debris. Throws are the safe way to hit the eye.
## The node's position is the bottom-centre of the head sprite.

const TEX := preload("res://art/enemies/brass_head.png")
const MAX_HP := 24
const EYE := Vector2(-35, -58)
enum S { SLEEP, WAKE, IDLE, BEAM_TELL, BEAM, OPEN, DEBRIS, STEAM, DEAD }

@export var floor_y := 432.0
@export var arena_left := 20.0
@export var vents: PackedFloat32Array = PackedFloat32Array([100, 250, 400])
@export var drop_pos := Vector2(300, 400)

var state := S.SLEEP
var hp := MAX_HP
var _st := 0.0
var _cycle := 0
var _hurt: Hurtbox
var _flash := 0.0
var _beam_x := 0.0
var _beam_dir := -1
var _beam_passes := 0
var _shadows: Array = []        ## [x, t] falling-debris telegraphs
var _rocks: Array = []          ## [Vector2 pos, vy]
var _vent_t := -1.0
var _seal: StaticBody2D
var _light: PointLight2D


func _ready() -> void:
	z_index = -1
	_hurt = Hurtbox.new()
	_hurt.collision_layer = 16
	_hurt.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	cs.shape = c
	_hurt.add_child(cs)
	_hurt.position = EYE
	add_child(_hurt)
	_hurt.hit.connect(_on_hit)
	_hurt.invulnerable = true
	_light = Fx.make_light(Color(1.0, 0.7, 0.35), 60.0, 0.0)
	_light.position = EYE
	add_child(_light)
	if GameState.flags.get("giant_defeated", false):
		state = S.DEAD
		hp = 0
		set_physics_process(false)
		_hurt.queue_free()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_st += delta
	_flash = maxf(_flash - delta, 0.0)
	var p := WorldManager.player
	_update_hazards(delta, p)
	match state:
		S.SLEEP:
			if p and p.global_position.x > global_position.x - 380.0:
				_wake()
		S.WAKE:
			if _st > 1.6:
				_go(S.IDLE)
		S.IDLE:
			if _st > (1.1 if hp > MAX_HP / 2 else 0.7):
				_cycle += 1
				match _cycle % 3:
					1: _start_beam()
					2: _start_debris()
					0: _start_steam()
		S.BEAM_TELL:
			if _st > 0.7:
				_go(S.BEAM)
				AudioManager.sfx(&"laser", 2.0)
				_beam_x = global_position.x - 40.0
				_beam_dir = -1
				_beam_passes = 0
		S.BEAM:
			_beam_x += _beam_dir * 520.0 * delta
			if _beam_dir < 0 and _beam_x < arena_left:
				_beam_passes += 1
				if hp <= MAX_HP / 2 and _beam_passes < 2:
					_beam_dir = 1
				else:
					_go(S.OPEN)
			elif _beam_dir > 0 and _beam_x > global_position.x - 40.0:
				_go(S.OPEN)
			if p and state == S.BEAM and _beam_hits(p):
				p.hazard_hit(1, false)
		S.OPEN:
			if _st > 1.5:
				_hurt.invulnerable = true
				_go(S.IDLE)
		S.DEBRIS, S.STEAM:
			if _st > 2.2:
				_go(S.IDLE)
	_light.energy = 1.2 if state in [S.BEAM_TELL, S.BEAM] else (0.6 if state == S.OPEN else 0.0)
	queue_redraw()


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _wake() -> void:
	_go(S.WAKE)
	AudioManager.sfx(&"horn")
	Fx.shake(6.0)
	EventBus.boss_started.emit("THE BRASS BROW", MAX_HP)
	_seal = StaticBody2D.new()
	_seal.collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 80)
	cs.shape = r
	cs.position = Vector2(8, floor_y - 40)
	_seal.add_child(cs)
	get_parent().add_child.call_deferred(_seal)
	AudioManager.sfx(&"door")


func _start_beam() -> void:
	_go(S.BEAM_TELL)
	_hurt.invulnerable = false # the eye is open from the tell until it closes again
	AudioManager.sfx(&"telegraph", -2.0)


func _start_debris() -> void:
	_go(S.DEBRIS)
	AudioManager.sfx(&"slam", -8.0)
	Fx.shake(3.0)
	var n := 3 if hp > MAX_HP / 2 else 5
	var p := WorldManager.player
	for i in n:
		var x := randf_range(arena_left + 20.0, global_position.x - 90.0)
		if i == 0 and p:
			x = clampf(p.global_position.x, arena_left + 20.0, global_position.x - 90.0) # one aimed at you
		_shadows.append([x, 0.0])


func _start_steam() -> void:
	_go(S.STEAM)
	_vent_t = 0.0
	AudioManager.sfx(&"telegraph", -8.0)


## A ray from the eye to a point on the floor; hit if the robot's body is near it.
func _beam_hits(p: Player) -> bool:
	var a := to_global(EYE)
	var b := Vector2(_beam_x, floor_y)
	var c := p.global_position + Player.BODY_CENTER
	var ab := b - a
	var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return c.distance_to(a + ab * t) < 12.0


func _update_hazards(delta: float, p: Player) -> void:
	for sh in _shadows:
		sh[1] += delta
		if sh[1] > 0.75 and sh[1] - delta <= 0.75:
			_rocks.append([Vector2(sh[0], floor_y - 300.0), 0.0])
	_shadows = _shadows.filter(func(sh): return sh[1] <= 0.75)
	for r in _rocks:
		r[1] += 900.0 * delta
		r[0].y += r[1] * delta
		if p and not p.is_dead and (r[0] - (p.global_position + Player.BODY_CENTER)).length() < 16.0:
			p.hazard_hit(1, false)
			r[0].y = floor_y + 99.0
		if r[0].y >= floor_y - 6.0 and r[0].y < floor_y + 50.0:
			Fx.dust(Vector2(r[0].x, floor_y), 1.0)
			AudioManager.sfx(&"crusher", -10.0)
			r[0].y = floor_y + 99.0
	_rocks = _rocks.filter(func(r): return r[0].y < floor_y + 60.0)
	if _vent_t >= 0.0:
		_vent_t += delta
		if _vent_t > 0.6 and _vent_t < 1.5 and p and not p.is_dead:
			for vx in vents:
				if absf(p.global_position.x - vx) < 14.0 and p.global_position.y > floor_y - 150.0:
					p.hazard_hit(1, false)
		if _vent_t > 0.6 and _vent_t - delta <= 0.6:
			AudioManager.sfx(&"steam_door", -10.0)
		if _vent_t > 1.6:
			_vent_t = -1.0


func _on_hit(damage: int, _from: Vector2, _source: Node) -> void:
	if state == S.DEAD:
		return
	hp = maxi(hp - damage, 0)
	_flash = 0.12
	EventBus.boss_health_changed.emit(hp, MAX_HP)
	Fx.spark(to_global(EYE), Color(1.0, 0.8, 0.4), 10)
	if hp <= 0:
		_die()


func _die() -> void:
	_go(S.DEAD)
	_hurt.set_deferred("monitorable", false)
	GameState.flags["giant_defeated"] = true
	EventBus.boss_ended.emit()
	AudioManager.sfx(&"slam")
	Fx.shake(8.0)
	Fx.burst(to_global(EYE), Color(1.0, 0.75, 0.4), 30)
	_shadows.clear()
	_rocks.clear()
	_vent_t = -1.0
	if _seal:
		_seal.queue_free()
	var c: Collectible = preload("res://scenes/world/collectible.tscn").instantiate()
	c.kind = Collectible.Kind.PORT_EXPANSION
	c.unique_id = "heap_09_giant/port"
	c.position = drop_pos
	get_parent().add_child.call_deferred(c)
	EventBus.toast.emit("The giant's eye goes dark.")
	set_physics_process(false)


func _frame() -> int:
	match state:
		S.SLEEP, S.IDLE, S.DEBRIS, S.STEAM, S.WAKE:
			return 1 if state == S.WAKE and fmod(_st, 0.3) < 0.15 else 0
		S.BEAM_TELL:
			return 2 if _st < 0.35 else 3
		S.BEAM:
			return 3
		S.OPEN:
			return 2
		S.DEAD:
			return 4
	return 0


func _draw() -> void:
	var fw := TEX.get_width() / 5
	var h := TEX.get_height()
	var tint := Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	draw_texture_rect_region(TEX, Rect2(-fw / 2, -h, fw, h), Rect2(_frame() * fw, 0, fw, h), tint)
	var eye := EYE
	# beam telegraph: a thin flickering line toward the floor ahead
	if state == S.BEAM_TELL and fmod(_st, 0.1) < 0.06:
		draw_line(eye, to_local(Vector2(global_position.x - 60.0, floor_y)), Color(0.5, 1.0, 1.0, 0.5), 1.0)
	if state == S.BEAM:
		var b := to_local(Vector2(_beam_x, floor_y))
		draw_line(eye, b, Color(0.4, 1.0, 1.0, 0.35), 9.0)
		draw_line(eye, b, Color(0.7, 1.0, 1.0, 0.8), 4.0)
		draw_line(eye, b, Color.WHITE, 1.5)
		draw_circle(b, 5.0, Color(1.0, 1.0, 1.0, 0.8))
	for sh in _shadows:  # where debris will land
		var k: float = sh[1] / 0.75
		draw_rect(Rect2(to_local(Vector2(sh[0] - 10 * k - 4, floor_y - 2)), Vector2(20 * k + 8, 2)), Color(0, 0, 0, 0.5))
	for r in _rocks:
		var rp := to_local(r[0])
		draw_rect(Rect2(rp - Vector2(7, 6), Vector2(14, 12)), Color8(68, 54, 54))
		draw_rect(Rect2(rp - Vector2(7, 6), Vector2(14, 2)), Color8(138, 118, 108))
		draw_rect(Rect2(rp + Vector2(1, -2), Vector2(4, 3)), Color8(146, 78, 50))
	if _vent_t >= 0.0:
		for vx in vents:
			var base := to_local(Vector2(vx, floor_y))
			if _vent_t < 0.6:   # puffs: the tell
				var a := 0.4 + 0.4 * sin(_vent_t * 30.0)
				draw_circle(base + Vector2(0, -4), 5.0, Color(1, 1, 1, a))
			elif _vent_t < 1.5: # the blast
				for k in 6:
					var y := -k * 24.0 - fmod(_vent_t * 200.0, 24.0)
					draw_circle(base + Vector2(sin(k + _vent_t * 9.0) * 3.0, y), 9.0 - k * 0.6, Color(0.95, 0.95, 0.92, 0.55))
		for vx in vents:   # the grates
			var g := to_local(Vector2(vx, floor_y))
			draw_rect(Rect2(g + Vector2(-8, -2), Vector2(16, 2)), Color8(98, 82, 80))
