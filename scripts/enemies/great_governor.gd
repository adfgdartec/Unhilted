class_name GreatGovernor
extends Node2D
## BOSS: THE GREAT GOVERNOR. The engine that sets the pressure for the whole
## Underworks: a brass spindle as tall as the hall, with two heavy flyballs on
## arms spinning around it, and a valve-crown on top with one great gauge eye.
## It has been running fast for years.
##
## How the fight reads (the hall is 640 wide, floor at y 320):
##   - SPIN: the flyballs whirl around the spindle. Seen from the side they
##     sweep left and right across the hall. A ball only hurts on its NEAR
##     pass (bright, big); on the far pass it's dim and small and harmless.
##     The LOW ball skims the floor: jump it. The HIGH ball is at chest
##     height: slide under it.
##   - VENTS: steam columns burst from the floor grates. Each grate spits and
##     hisses first (the tell).
##   - OVERPRESSURE: the balls drop, the needle hits red and the crown opens.
##     That's the window: the crown is too high to hit from the floor (hits
##     from down there glance off its rim), so hook one of the two hooks
##     beside it and whip past it, or hit it from the hook height. When the
##     window ends it whistles and blows a ring of steam off the crown: get
##     clear.
##   - Half health: the balls spin faster and the vents fire during the spin.
## The node sits at the room origin, so local and room coordinates match.
##
## Intake mode (the demo's showdown, IntakeShowdown sets intake = true): a
## shorter fight in the crane hall. The crown can be hit from the girder
## ledges beside it. Each quarter of its health it lurches and a flyball
## smashes one of the ledges; at the last quarter it's out of balance
## (wobbling, the crown hittable from anywhere) and at zero it topples over
## and crashes down.

signal defeated

enum S { IDLE, INTRO, SPIN, VENTS, OVERPRESSURE, WHISTLE, DYING, WRECKED }

const MAX_HP := 30
const FLOOR_Y := 320.0
const CENTER_X := 320.0
const HEAD := Vector2(320, 104)
const REACH := 268.0             ## how far the balls swing out from the spindle
const BALL_R := 10.0
const LOW_Y := FLOOR_Y - 10.0    ## low ball centre: jump it
const HIGH_Y := FLOOR_Y - 30.0   ## high ball centre: slide under it (standing robot is 28 tall)
const VENT_XS := [72.0, 168.0, 248.0, 392.0, 472.0, 568.0]
const HEAD_TEX := preload("res://art/enemies/governor_head.png") # calm, angry, cracked

var state := S.IDLE
var max_hp := MAX_HP
var hp := MAX_HP
var intake := false
var platforms: Array = []      ## CrumblePlatforms, knocked out in this order
var off_balance := false
var _knocked := 0
var _tilt := 0.0
var _smashed := false
var _debris: Array = []        ## [offset, size, color, rotation] once smashed
var player: Player

var _t := 0.0
var _anim := 0.0
var _flash := 0.0
var _angle := 0.0
var _spin_speed := 0.0
var _ball_drop := 0.0        ## 0 = arms out, 1 = dropped against the spindle (overpressure)
var _cycle := 0
var _vents: Array = []       ## [x, t] active columns (t counts from the start of the tell)
var _hurtbox: Hurtbox
var _balls: Array[Hitbox] = []
var _vent_hit: Array[Hitbox] = []
var _ring: Hitbox


func _ready() -> void:
	hp = max_hp
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	_hurtbox.invulnerable = true
	_hurtbox.add_child(_shape(CircleShape2D.new(), 22.0))
	_hurtbox.position = HEAD
	_hurtbox.blocks = _crown_blocks
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)
	for i in 2:
		var b := _hitbox(_shape(CircleShape2D.new(), BALL_R - 1.0))
		_balls.append(b)
	for i in VENT_XS.size():
		var r := RectangleShape2D.new()
		r.size = Vector2(20, 180)
		var cs := CollisionShape2D.new()
		cs.shape = r
		var v := _hitbox(cs)
		v.position = Vector2(VENT_XS[i], FLOOR_Y - 90.0)
		_vent_hit.append(v)
	_ring = _hitbox(_shape(CircleShape2D.new(), 58.0))
	_ring.position = HEAD
	var core := Fx.make_light(Color(1.0, 0.7, 0.35), 110.0, 0.7)
	core.position = HEAD
	add_child(core)


func _shape(c: CircleShape2D, radius: float) -> CollisionShape2D:
	c.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = c
	return cs


func _hitbox(cs: CollisionShape2D) -> Hitbox:
	var h := Hitbox.new()
	h.collision_layer = 0
	h.collision_mask = 8
	h.monitorable = false
	h.continuous = true
	h.start_active = false
	h.add_child(cs)
	add_child(h)
	return h


func start(p: Player) -> void:
	player = p
	AudioManager.sfx(&"steam_door")
	_enter(S.INTRO)


func set_wrecked() -> void:
	state = S.WRECKED
	_ball_drop = 1.0
	_hurtbox.queue_free()
	for h in _balls + _vent_hit:
		h.queue_free()
	_ring.queue_free()
	_balls.clear()
	_vent_hit.clear()
	queue_redraw()


func _phase2() -> bool:
	return hp <= max_hp / 2


## The crown's brass rim turns hits from below (the floor); reach it from the
## hooks or by whipping past it.
func _crown_blocks(from: Vector2) -> bool:
	if off_balance:
		return false
	return to_local(from).y > HEAD.y + (110.0 if intake else 64.0) # hooks / ledges


func _enter(s: S) -> void:
	state = s
	_t = 0.0
	_hurtbox.invulnerable = s != S.OVERPRESSURE
	_ring.set_deferred("monitoring", false)
	match s:
		S.OVERPRESSURE:
			AudioManager.sfx(&"valve")
			Fx.ring(to_global(HEAD), Color(1.0, 0.5, 0.35), 40.0, 0.4, 2.0)
		S.WHISTLE:
			AudioManager.sfx(&"telegraph", -4.0)
		S.VENTS:
			_plan_vents(3 if not _phase2() else 4)


func _physics_process(delta: float) -> void:
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	if state == S.IDLE or state == S.WRECKED:
		queue_redraw()
		return
	if player == null or not is_instance_valid(player) or player.is_dead:
		_set_balls(false)
		queue_redraw()
		return
	_t += delta
	var fast := _phase2()
	match state:
		S.INTRO:
			_spin_speed = move_toward(_spin_speed, 1.2, 1.0 * delta)
			if _t > 1.2:
				_enter(S.SPIN)
		S.SPIN:
			_ball_drop = move_toward(_ball_drop, 0.0, 2.0 * delta)
			_spin_speed = move_toward(_spin_speed, 2.4 if fast else 1.8, 0.8 * delta)
			if fast and fmod(_t, 2.6) < delta and _t > 1.0:
				_plan_vents(2)
			if _t > (7.0 if fast else 6.0):
				_cycle += 1
				_enter(S.VENTS if _cycle % 2 == 1 else S.OVERPRESSURE)
		S.VENTS:
			_spin_speed = move_toward(_spin_speed, 0.9, 1.5 * delta)
			if _t > 2.4:
				_enter(S.OVERPRESSURE)
		S.OVERPRESSURE:
			_spin_speed = move_toward(_spin_speed, 0.0, 3.0 * delta)
			_ball_drop = move_toward(_ball_drop, 1.0, 2.5 * delta)
			if _t > (3.2 if fast else 3.8):
				_enter(S.WHISTLE)
		S.WHISTLE:
			if _t > 0.5 and _t - delta <= 0.5:
				AudioManager.sfx(&"burst")
				Fx.ring(to_global(HEAD), Color(0.95, 0.93, 0.88), 58.0, 0.35, 3.0)
				Fx.shake(4.0)
				_ring.set_deferred("monitoring", true)
			if _t > 0.75:
				_ring.set_deferred("monitoring", false)
				_enter(S.SPIN)
		S.DYING:
			_spin_speed = move_toward(_spin_speed, 0.0, 0.8 * delta)
			_ball_drop = move_toward(_ball_drop, 1.0, 1.0 * delta)
			if intake:
				# lean further and further, then go over with a crash
				var was := _tilt
				_tilt = minf(_tilt + delta * (0.15 + _t * 0.6), 1.35)
				if was < 1.35 and _tilt >= 1.35:
					AudioManager.sfx(&"slam", 2.0)
					Fx.shake(10.0)
					Fx.dust(to_global(Vector2(CENTER_X + 120, FLOOR_Y)), 2.5)
					Fx.dust(to_global(Vector2(CENTER_X + 40, FLOOR_Y)), 2.0)
					Fx.burst(to_global(Vector2(CENTER_X + 150, FLOOR_Y - 12)), Color(1.0, 0.75, 0.4), 30)
					for p in platforms:
						if is_instance_valid(p):
							p.call("crumble")
			if fmod(_t, 0.16) < delta:
				Fx.spark(to_global(HEAD + Vector2(randf_range(-26, 26), randf_range(-18, 18))), Color(1.0, 0.7, 0.35), 6)
				if randf() < 0.4:
					AudioManager.sfx(&"steam", -10.0)
			if _t > 2.0:
				state = S.WRECKED
				_set_balls(false)
				defeated.emit()
	if off_balance and state != S.DYING:
		_tilt = sin(_anim * 3.2) * 0.06
	_angle += _spin_speed * delta
	_update_balls()
	_update_vents(delta)
	queue_redraw()


## Ball i's position and whether it's on its near (dangerous) pass.
func ball(i: int) -> Dictionary:
	var a := _angle + PI * i
	var reach := REACH * (1.0 - _ball_drop * 0.85)
	var y_base := LOW_Y if i == 0 else HIGH_Y
	var y := lerpf(y_base, HEAD.y + 70.0, _ball_drop)
	var near := cos(a) > 0.15 and _ball_drop < 0.2
	return {"pos": Vector2(CENTER_X + sin(a) * reach, y), "near": near, "depth": cos(a)}


func _update_balls() -> void:
	for i in _balls.size():
		var b := ball(i)
		_balls[i].position = b.pos
		var on: bool = b.near and state in [S.SPIN, S.VENTS, S.INTRO]
		if _balls[i].monitoring != on:
			_balls[i].set_deferred("monitoring", on)


func _set_balls(on: bool) -> void:
	for h in _balls:
		h.set_deferred("monitoring", on)


func _plan_vents(count: int) -> void:
	# always one under the robot, the rest spread out (never all of them)
	var px := to_local(player.global_position).x
	var order := range(VENT_XS.size())
	order.sort_custom(func(a, b): return absf(VENT_XS[a] - px) < absf(VENT_XS[b] - px))
	var picked := [order[0]]
	var rest := order.slice(1)
	rest.shuffle()
	for k in rest:
		if picked.size() >= count:
			break
		picked.append(k)
	for k in picked:
		if not _vents.any(func(v): return v[0] == k):
			_vents.append([k, 0.0])


const VENT_TELL := 0.8
const VENT_BURN := 0.7

func _update_vents(delta: float) -> void:
	for v in _vents:
		var before: float = v[1]
		v[1] += delta
		if before < VENT_TELL and v[1] >= VENT_TELL:
			AudioManager.sfx(&"steam", -6.0)
			_vent_hit[v[0]].set_deferred("monitoring", true)
		if v[1] >= VENT_TELL + VENT_BURN:
			_vent_hit[v[0]].set_deferred("monitoring", false)
	_vents = _vents.filter(func(v): return v[1] < VENT_TELL + VENT_BURN)


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	if state != S.OVERPRESSURE:
		return
	hp = maxi(hp - damage, 0)
	_flash = 0.1
	EventBus.boss_health_changed.emit(hp, max_hp)
	Fx.spark(to_global(HEAD.lerp(to_local(from_position), 0.4)), Color(1.0, 0.75, 0.35), 10)
	if intake:
		_check_balance()
	if hp <= 0:
		_hurtbox.invulnerable = true
		for v in _vent_hit:
			v.set_deferred("monitoring", false)
		_vents.clear()
		Fx.burst(to_global(HEAD), Color(1.0, 0.8, 0.45), 40)
		Fx.ring(to_global(HEAD), Color(1.0, 0.95, 0.8), 100.0, 0.6, 3.0)
		if Fx.post:
			Fx.post.hit()
		Fx.hit_stop(0.25)
		Fx.shake(9.0)
		_enter(S.DYING)


func is_vulnerable() -> bool:
	return state == S.OVERPRESSURE


## Each lost quarter: a lurch, and a flyball smashes the next ledge.
func _check_balance() -> void:
	var marks := [0.75, 0.5, 0.25]
	while _knocked < marks.size() and hp <= max_hp * marks[_knocked] and hp > 0:
		_knock_platform(_knocked)
		_knocked += 1
		if _knocked == marks.size():
			off_balance = true
			EventBus.toast.emit("The Governor is losing its balance!")
			AudioManager.set_music_pitch(1.08, 2.0)


func _knock_platform(i: int) -> void:
	Fx.shake(6.0)
	AudioManager.sfx(&"burst", -2.0)
	if i < platforms.size() and is_instance_valid(platforms[i]):
		var p: Node2D = platforms[i]
		Fx.ring(p.global_position, Color(1.0, 0.7, 0.35), 30.0, 0.3, 2.0)
		p.call("crumble")


## The crane's slam: what's left of the Governor breaks into pieces.
func smash() -> void:
	_smashed = true
	_tilt = 0.0
	_debris.clear()
	for i in 14:
		_debris.append([Vector2(randf_range(-60, 60), randf_range(-26, 0)), Vector2(randf_range(6, 16), randf_range(4, 10)),
			[Color8(201, 150, 60), Color8(140, 100, 40), Color8(44, 32, 34), Color8(98, 82, 80)][i % 4], randf_range(-0.8, 0.8)])
	queue_redraw()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if _smashed:
		for d in _debris:
			draw_set_transform(Vector2(CENTER_X, FLOOR_Y - 4) + d[0], d[3], Vector2.ONE)
			var sz: Vector2 = d[1]
			draw_rect(Rect2(-sz / 2.0, sz), d[2])
			draw_rect(Rect2(-sz / 2.0, Vector2(sz.x, 1)), Color(d[2]).lightened(0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if _tilt != 0.0:
		var pivot := Vector2(CENTER_X, FLOOR_Y)
		draw_set_transform(pivot - pivot.rotated(_tilt), _tilt, Vector2.ONE)
	var brass := Color8(201, 150, 60)
	var brass_dk := Color8(140, 100, 40)
	var iron := Color8(44, 32, 34)
	var iron_hi := Color8(98, 82, 80)
	# far-side balls first (behind the spindle)
	var order := [0, 1]
	order.sort_custom(func(a, b): return ball(a).depth < ball(b).depth)
	for i in order:
		if ball(i).depth <= 0.0:
			_draw_ball(i, brass, brass_dk)
	# spindle: a fluted column from the floor up to the crown
	draw_rect(Rect2(CENTER_X - 10, HEAD.y + 18, 20, FLOOR_Y - HEAD.y - 18), iron)
	draw_rect(Rect2(CENTER_X - 10, HEAD.y + 18, 3, FLOOR_Y - HEAD.y - 18), iron_hi)
	var y := HEAD.y + 30.0
	var spin_off := fmod(_angle * 12.0, 12.0)
	while y < FLOOR_Y - 6.0:  # rotating collar bands show the spin
		draw_rect(Rect2(CENTER_X - 12, y + spin_off * 0.0, 24, 3), brass_dk)
		y += 24.0
	draw_rect(Rect2(CENTER_X - 30, FLOOR_Y - 14, 60, 14), iron)
	draw_rect(Rect2(CENTER_X - 30, FLOOR_Y - 14, 60, 2), brass)
	# the sliding sleeve the arms hang from (rises as the balls fly out)
	var sleeve_y := lerpf(HEAD.y + 44.0, HEAD.y + 80.0, _ball_drop)
	draw_rect(Rect2(CENTER_X - 14, sleeve_y, 28, 10), brass_dk)
	draw_rect(Rect2(CENTER_X - 14, sleeve_y, 28, 2), brass)
	# arms
	for i in [0, 1]:
		var b := ball(i)
		draw_line(Vector2(CENTER_X, HEAD.y + 26), b.pos, Color(iron_hi, 0.9 if b.depth > 0 else 0.5), 3.0)
		draw_line(Vector2(CENTER_X, sleeve_y + 5), b.pos.lerp(Vector2(CENTER_X, HEAD.y + 26), 0.5), Color(iron, 0.9 if b.depth > 0 else 0.5), 2.0)
	# near-side balls in front
	for i in order:
		if ball(i).depth > 0.0:
			_draw_ball(i, brass, brass_dk)
	# the crown and its gauge eye
	var frame := 0
	if state == S.OVERPRESSURE or state == S.WHISTLE or (_phase2() and state == S.SPIN and fmod(_anim, 0.5) < 0.1):
		frame = 1
	if state == S.DYING or state == S.WRECKED:
		frame = 2
	var fw := HEAD_TEX.get_width() / 3
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) if state == S.WHISTLE else Vector2.ZERO
	var crown_lift := 6.0 if state == S.OVERPRESSURE else 0.0
	draw_texture_rect_region(HEAD_TEX, Rect2(HEAD + shake + Vector2(-fw / 2.0, -26 - crown_lift), Vector2(fw, HEAD_TEX.get_height())),
		Rect2(frame * fw, 0, fw, HEAD_TEX.get_height()), tint)
	if state == S.OVERPRESSURE:
		# the open valve: red glow pulsing under the lifted cap
		var pulse := 0.5 + sin(_anim * 10.0) * 0.3
		draw_circle(HEAD + Vector2(0, -22), 7.0, Color(1.0, 0.4, 0.25, pulse))
	if state == S.WHISTLE:
		for k in 5:
			var a := _anim * 3.0 + k * TAU / 5.0
			draw_circle(HEAD + Vector2(cos(a), sin(a)) * (20.0 + _t * 40.0), 4.0, Color(0.95, 0.93, 0.88, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # the floor doesn't tilt
	# floor vents: grates, tell puffs, columns
	for i in VENT_XS.size():
		var vx: float = VENT_XS[i]
		draw_rect(Rect2(vx - 12, FLOOR_Y - 2, 24, 3), Color8(68, 54, 54))
		draw_rect(Rect2(vx - 12, FLOOR_Y - 2, 24, 1), brass)
	for v in _vents:
		var vx: float = VENT_XS[v[0]]
		var t: float = v[1]
		if t < VENT_TELL:
			if fmod(t, 0.16) < 0.08:
				draw_circle(Vector2(vx + randf_range(-6, 6), FLOOR_Y - 6 - t * 10.0), 3.0, Color(1.0, 0.85, 0.75, 0.6))
		else:
			var k := (t - VENT_TELL) / VENT_BURN
			for j in 7:
				var yy := FLOOR_Y - fmod(j * 26.0 + t * 260.0, 180.0)
				draw_circle(Vector2(vx + sin(j * 1.7 + t * 9.0) * 4.0, yy), 7.0 + j * 0.6, Color(1.0, 0.86, 0.76, 0.5 * (1.0 - k * 0.6)))


func _draw_ball(i: int, brass: Color, brass_dk: Color) -> void:
	var b := ball(i)
	var near: bool = b.depth > 0.0
	var r := BALL_R * (1.0 if near else 0.72)
	var a := 1.0 if near else 0.45
	draw_circle(b.pos, r + 1.0, Color(0.12, 0.08, 0.09, a))
	draw_circle(b.pos, r, Color(brass_dk, a))
	draw_circle(b.pos + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(brass, a))
	if near and b.near and state in [S.SPIN, S.VENTS]:
		# hot rim on the dangerous pass
		draw_arc(b.pos, r + 2.0, 0.0, TAU, 16, Color(1.0, 0.6, 0.3, 0.6), 1.0)
