class_name Player
extends CharacterBody2D

const BLADE_SCENE := preload("res://scenes/player/blade.tscn")
const BODY_CENTER := Vector2(0, -14)

@onready var stats: PlayerStats = $PlayerStats
@onready var health: HealthComponent = $HealthComponent
@onready var visuals: PlayerVisuals = $Visuals
@onready var state_machine: StateMachine = $StateMachine
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var melee_hitbox: Hitbox = $MeleeHitbox
@onready var blade_anchor: Marker2D = $BladeAnchor
@onready var wire: Line2D = $Wire
@onready var camera: Camera2D = $Camera2D
var _core_light: PointLight2D
const REBOUND_WINDOW := 2.2
const REBOUND_AFTER_RESPAWN := 8.0
var rebound_until := 0.0
var rebounds_landed := 0
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var invuln_timer: Timer = $InvulnTimer

var move_axis := 0.0
var climb_axis := 0.0
var aim_vector := Vector2.RIGHT
var jump_held := false
var attack_pressed := false
var attack_held := false
var recall_pressed := false
var pending_throw := {}
var using_mouse := true
var attack_from_mouse := false
var dash_pressed := false
var slide_held := false
var _slide_just := false

const MAX_WALL_JUMPS := 3
const AIR_DRAG := 170.0
const GROUND_OVERSPEED_DRAG := 900.0
const FULL_HEIGHT := 28.0
const LOW_HEIGHT := 16.0
var wall_jumps_left := MAX_WALL_JUMPS
var _wall_coyote := 0.0
var _wall_coyote_normal := 0.0
var is_low := false
var _hurt_full_h := 28.0

const CLOSE_HITS_TO_HEAL := 3
const CLOSE_RANGE := 56.0
var heal_charge := 0

var jump_velocity := 0.0
var rise_gravity := 0.0

var facing := 1
var blade: Blade = null
var can_air_dash := true
var is_dead := false
var current_interactable: Node = null
var _was_on_floor := false
var _shake := 0.0
var _wire_glow: Line2D
var _afterimage_t := 0.0

const FLICK_WINDOW := 0.09
const FLICK_MIN_SPEED := 220.0
const FLICK_HARD_SPEED := 1300.0
const PAD_CHARGE_TIME := 0.35
const RUSH_SPEED := 230.0
const INPUT_BUFFER := 0.12
const AUTOSWING_DELAY := 0.3
var _attack_buf := 0.0
var _dash_buf := 0.0
var jump_cut_armed := false
var gripping := false
var grip_from_mouse := false
var grip_start := Vector2.ZERO
var grip_time := 0.0
var recent_speed := 0.0
var _mouse_samples: Array = []
var _pending_age := 0.0


func _ready() -> void:
	add_to_group("player")
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	$Hurtbox/CollisionShape2D.shape = $Hurtbox/CollisionShape2D.shape.duplicate()
	_hurt_full_h = ($Hurtbox/CollisionShape2D.shape as RectangleShape2D).size.y
	stats.stats_changed.connect(_on_stats_changed)
	stats.setup($Upgrades)
	health.changed.connect(func(c, m): EventBus.health_changed.emit(c, m))
	health.died.connect(_on_died)
	hurtbox.hit.connect(_on_hurt)
	melee_hitbox.hit_landed.connect(_on_melee_hit)
	invuln_timer.timeout.connect(func(): hurtbox.invulnerable = false)
	EventBus.camera_shake.connect(func(s): _shake = maxf(_shake, s))
	health.changed.connect(func(c, _m): if Fx.post: Fx.post.set_low_health(c == 1))
	_wire_glow = Line2D.new()
	_wire_glow.width = 4.0
	_wire_glow.default_color = Color(0.2, 0.9, 1.0, 0.28)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wire_glow.material = add
	_wire_glow.visible = false
	add_child(_wire_glow)
	move_child(_wire_glow, wire.get_index())
	_core_light = Fx.make_light(Color(0.45, 0.85, 1.0), 56.0, 0.35)
	_core_light.position = BODY_CENTER
	add_child(_core_light)
	get_viewport().size_changed.connect(fit_camera_to_room)
	var guide := preload("res://scripts/player/aim_guide.gd").new()
	guide.name = "AimGuide"
	add_child(guide)
	state_machine.setup(self)


func on_game_started() -> void:
	is_dead = false
	stats.recalculate()
	health.set_max(int(stats.get_stat("max_health")), true)
	visuals.refresh()
	state_machine.transition("idle")
	EventBus.player_spawned.emit(self)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		using_mouse = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4 or event is InputEventJoypadButton:
		using_mouse = false


func _physics_process(delta: float) -> void:
	_sample_mouse()
	_read_input()
	state_machine.physics_update(delta)
	_corner_correct(delta)
	var belt := _floor_conveyor()
	var carry := belt.speed if belt and is_on_floor() else 0.0
	velocity.x += carry
	move_and_slide()
	velocity.x -= carry
	_post_move()
	_update_wire()
	visuals.sway = velocity.x / maxf(stats.get_stat("max_speed"), 1.0)
	visuals.blade_in_hand = blade == null
	visuals.scale.x = facing


func _process(delta: float) -> void:
	_update_camera(delta)
	if _core_light and not is_dead:
		_core_light.energy = lerpf(_core_light.energy, 1.1 if rebound_ready() else 0.35, 0.15)
	var st := state_machine.current_name()
	if st == "dash" or st == "zip" or (recent_speed >= RUSH_SPEED and blade == null and not is_dead):
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.035 if (st == "dash" or st == "zip") else 0.07
			Fx.afterimage(self, visuals)
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = move_toward(_shake, 0.0, 20.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	visuals.modulate.a = 0.4 if (hurtbox.invulnerable and int(Time.get_ticks_msec() / 70) % 2 == 0) else 1.0


var _cam_y := 0.0
var _lead := 0.0

func _update_camera(delta: float) -> void:
	_lead = move_toward(_lead, facing * 18.0 + clampf(velocity.x * 0.08, -10.0, 10.0), 40.0 * delta)
	var y := global_position.y
	if is_on_floor() or state_machine.current_name() in ["grapple", "swing"]:
		_cam_y = lerpf(_cam_y, y, 1.0 - exp(-delta * 6.0))
	elif y < _cam_y - 56.0:
		_cam_y = y + 56.0
	elif y > _cam_y + 24.0:
		_cam_y = lerpf(_cam_y, y + (40.0 if velocity.y > 300.0 else 0.0), 1.0 - exp(-delta * 8.0))
	camera.position = Vector2(_lead, _cam_y - y - 24.0)


func _read_input() -> void:
	if GameState.is_ui_locked() or is_dead:
		move_axis = 0.0
		climb_axis = 0.0
		jump_held = false
		slide_held = false
		_slide_just = false
		attack_pressed = false
		attack_held = false
		_attack_buf = 0.0
		_dash_buf = 0.0
		recall_pressed = false
		pending_throw = {}
		gripping = false
		dash_pressed = false
		return

	move_axis = Input.get_axis("move_left", "move_right")
	climb_axis = Input.get_axis("aim_up", "aim_down")

	var raw := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if raw.length() < 0.3:
		aim_vector = Vector2(facing, 0)
	else:
		aim_vector = Vector2.from_angle(snappedf(raw.angle(), PI / 4.0))

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer.start(stats.get_stat("jump_buffer"))
	jump_held = Input.is_action_pressed("jump")
	var dt := get_physics_process_delta_time()
	if Input.is_action_just_pressed("attack"):
		_attack_buf = INPUT_BUFFER
		attack_from_mouse = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	else:
		_attack_buf = maxf(_attack_buf - dt, 0.0)
	attack_held = Input.is_action_pressed("attack")
	attack_pressed = _attack_buf > 0.0
	var down_slide := Input.is_action_pressed("aim_down") and move_axis != 0.0 and absf(velocity.x) > 140.0
	slide_held = Input.is_action_pressed("slide") or down_slide
	_slide_just = Input.is_action_just_pressed("slide") or (down_slide and Input.is_action_just_pressed("aim_down"))
	if Input.is_action_just_pressed("dash"):
		_dash_buf = INPUT_BUFFER
	else:
		_dash_buf = maxf(_dash_buf - dt, 0.0)
	dash_pressed = _dash_buf > 0.0
	_read_throw_input()

	if Input.is_action_just_pressed("interact") and current_interactable and is_on_floor():
		current_interactable.interact(self)
	if Input.is_action_just_pressed("use_item"):
		_use_repair_kit()
	if Input.is_action_just_pressed("pause"):
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui:
			ui.toggle_pause()
	elif Input.is_action_just_pressed("map"):
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui:
			ui.open_journal_map()


func _read_throw_input() -> void:
	recall_pressed = false
	if not pending_throw.is_empty():
		_pending_age += get_physics_process_delta_time()
		if _pending_age > 0.3:
			pending_throw = {}
	else:
		_pending_age = 0.0
	if Input.is_action_just_pressed("throw"):
		if blade == null:
			gripping = true
			grip_from_mouse = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			grip_start = get_viewport().get_mouse_position()
			grip_time = 0.0
			if grip_from_mouse and Fx.click_throw:
				gripping = false
				pending_throw = {"dir": aim_toward(get_global_mouse_position()), "power": 1.0, "charged": false}
		else:
			recall_pressed = true
	if gripping:
		grip_time += get_physics_process_delta_time()
		if blade != null:
			gripping = false
		elif Input.is_action_just_released("throw") or not Input.is_action_pressed("throw"):
			gripping = false
			pending_throw = release_grip()


func release_grip() -> Dictionary:
	if not grip_from_mouse:
		var charged := grip_time >= PAD_CHARGE_TIME
		return {"dir": aim_vector, "power": 1.0 if charged else 0.75, "charged": charged}
	var now := Time.get_ticks_msec() / 1000.0
	var flick := read_flick(_mouse_samples, now, grip_start, get_viewport().get_mouse_position(), Fx.flick_scale())
	if flick.is_empty() or not flick.has("flick"):
		return {"dir": aim_toward(get_global_mouse_position()), "power": 0.8, "charged": false}
	return flick


static func read_flick(samples: Array, now: float, start: Vector2, release: Vector2, speed_scale := 1.0) -> Dictionary:
	var ref := release
	var t_ref := now
	for s in samples:
		if now - float(s.t) <= FLICK_WINDOW:
			ref = s.p
			t_ref = float(s.t)
			break
	var dt := maxf(now - t_ref, 1.0 / 120.0)
	var v := (release - ref) / dt
	var speed := v.length()
	var lo := FLICK_MIN_SPEED * speed_scale
	var hi := FLICK_HARD_SPEED * speed_scale
	if speed >= lo and (release - ref).length() >= 3.0:
		return {
			"flick": true,
			"dir": v.normalized(),
			"power": clampf(inverse_lerp(lo, hi, speed) * 0.6 + 0.4, 0.4, 1.0),
			"charged": speed >= hi,
		}
	var drag := release - start
	if drag.length() >= 10.0:
		return {"dir": drag.normalized(), "power": clampf(drag.length() / 160.0, 0.2, 0.5), "charged": false}
	return {}


func grip_preview() -> Vector2:
	var d := get_viewport().get_mouse_position() - grip_start
	return d.normalized() if d.length() >= 6.0 else Vector2.ZERO


func _sample_mouse() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_mouse_samples.append({"t": now, "p": get_viewport().get_mouse_position()})
	while _mouse_samples.size() > 2 and now - float(_mouse_samples[0].t) > 0.25:
		_mouse_samples.pop_front()


var _fall_speed := 0.0
var last_safe := Vector2.ZERO
var _safe_candidates: Array = []
var hazard_contacts := 0

const CORNER_NUDGE := 5

func _corner_correct(delta: float) -> void:
	var step := velocity * delta
	if velocity.y < 0.0 and test_move(global_transform, Vector2(0, step.y)):
		for i in range(1, CORNER_NUDGE + 1):
			for side in [-1, 1]:
				var off := Vector2(side * i, 0)
				if not test_move(global_transform.translated(off), Vector2(0, step.y)) and not test_move(global_transform, off):
					global_position += off
					return
	if not is_on_floor() and absf(velocity.x) > 1.0 and velocity.y > -60.0 and test_move(global_transform, Vector2(step.x + signf(velocity.x), 0)):
		for i in range(1, 7):
			var up := Vector2(0, -i)
			if not test_move(global_transform, up) and not test_move(global_transform.translated(up), Vector2(step.x + signf(velocity.x), 0)):
				global_position += up
				return


func _post_move() -> void:
	recent_speed = maxf(get_real_velocity().length(), recent_speed - 900.0 * get_physics_process_delta_time())
	var on_floor := is_on_floor()
	if not on_floor:
		_fall_speed = maxf(get_real_velocity().y, 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	var solid_both_sides := test_move(global_transform.translated(Vector2(-8, 0)), Vector2(0, 4)) and test_move(global_transform.translated(Vector2(8, 0)), Vector2(0, 4))
	if on_floor and hazard_contacts == 0 and _floor_conveyor() == null and solid_both_sides:
		_safe_candidates.append([now, global_position])
	else:
		_safe_candidates.clear()
	while not _safe_candidates.is_empty() and now - float(_safe_candidates[0][0]) > 0.25:
		last_safe = _safe_candidates.pop_front()[1]
	_wall_coyote = maxf(_wall_coyote - get_physics_process_delta_time(), 0.0)
	if on_floor:
		can_air_dash = true
		wall_jumps_left = MAX_WALL_JUMPS
		coyote_timer.stop()
		if not _was_on_floor:
			visuals.land()
			Fx.dust(global_position, clampf(_fall_speed / 300.0, 0.6, 1.6))
			AudioManager.sfx(&"land", linear_to_db(clampf(_fall_speed / 380.0, 0.25, 1.0)))
	elif _was_on_floor and velocity.y >= 0.0:
		coyote_timer.start(stats.get_stat("coyote_time"))
	_was_on_floor = on_floor
	blade_anchor.position.x = 6.0 * facing


func apply_gravity(delta: float, multiplier := 1.0) -> void:
	if jump_cut_armed:
		if velocity.y >= 0.0:
			jump_cut_armed = false
		elif not jump_held:
			velocity.y *= stats.get_stat("jump_cut")
			jump_cut_armed = false
	var g := rise_gravity
	if velocity.y > 0.0:
		g *= stats.get_stat("fall_gravity_mult")
	if jump_held and absf(velocity.y) < 45.0 and not is_on_floor():
		g *= stats.get_stat("apex_gravity_mult")
	velocity.y = minf(velocity.y + g * multiplier * delta, stats.get_stat("terminal_velocity"))


func move_horizontal(delta: float) -> void:
	var top := stats.get_stat("max_speed")
	var target := move_axis * top
	var rate: float
	var over := absf(velocity.x) > top and (move_axis == 0.0 or signf(move_axis) == signf(velocity.x))
	if over:
		var drag := GROUND_OVERSPEED_DRAG if is_on_floor() else AIR_DRAG
		velocity.x = move_toward(velocity.x, signf(velocity.x) * top, drag * delta)
	else:
		if is_on_floor():
			rate = stats.get_stat("ground_accel") if move_axis != 0.0 else stats.get_stat("ground_friction")
			if move_axis != 0.0 and signf(move_axis) != signf(velocity.x):
				rate += stats.get_stat("ground_friction")
		else:
			rate = stats.get_stat("air_accel")
		velocity.x = move_toward(velocity.x, target, rate * delta)
	if move_axis != 0.0:
		facing = 1 if move_axis > 0.0 else -1


func start_jump(power := 1.0) -> void:
	consume_jump()
	coyote_timer.stop()
	velocity.y = jump_velocity * power
	jump_cut_armed = true
	AudioManager.sfx(&"jump", -4.0)
	visuals.play("jump")


func free_move(delta: float) -> void:
	if wants_jump() and can_jump():
		start_jump()
	apply_gravity(delta)
	move_horizontal(delta)


func wants_slide() -> bool:
	return is_on_floor() and (_slide_just or (slide_held and absf(velocity.x) > 40.0))


func set_low(low: bool) -> void:
	if low == is_low:
		return
	is_low = low
	var cs := $CollisionShape2D as CollisionShape2D
	var cap := cs.shape as CapsuleShape2D
	var h := LOW_HEIGHT if low else FULL_HEIGHT
	cap.height = h
	cs.position.y = -h * 0.5
	var hs := $Hurtbox/CollisionShape2D as CollisionShape2D
	var box := hs.shape as RectangleShape2D
	box.size.y = _hurt_full_h * (h / FULL_HEIGHT)
	hs.position.y = -box.size.y * 0.5


func can_stand() -> bool:
	return not is_low or not test_move(global_transform, Vector2(0, -(FULL_HEIGHT - LOW_HEIGHT)))


func try_wall_jump(normal_x := 0.0) -> bool:
	if is_on_floor() or wall_jumps_left <= 0:
		return false
	var n := normal_x
	if n == 0.0:
		if is_on_wall():
			n = get_wall_normal().x
		elif test_move(global_transform, Vector2(-3, 0)):
			n = 1.0
		elif test_move(global_transform, Vector2(3, 0)):
			n = -1.0
		elif _wall_coyote > 0.0:
			n = _wall_coyote_normal
	if n == 0.0:
		return false
	consume_jump()
	wall_jumps_left -= 1
	_wall_coyote = 0.0
	velocity = Vector2(signf(n) * 230.0, jump_velocity * 0.95)
	facing = 1 if n > 0.0 else -1
	jump_cut_armed = true
	AudioManager.sfx(&"jump", -3.0, 0.08)
	Fx.dust(global_position + Vector2(-signf(n) * 5.0, -12.0), 0.7)
	state_machine.transition("jump", {"launched": true})
	return true


func wall_coyote(normal_x: float) -> void:
	_wall_coyote = 0.1
	_wall_coyote_normal = normal_x


func register_close_hit(weight := 1) -> void:
	if is_dead:
		return
	heal_charge += weight
	if heal_charge >= CLOSE_HITS_TO_HEAL:
		if health.current < health.max_health:
			heal_charge = 0
			health.heal(1)
			AudioManager.sfx(&"heal", -6.0)
			Fx.ring(global_position + BODY_CENTER, Color(0.5, 1.0, 0.7), 16.0, 0.25)
		else:
			heal_charge = CLOSE_HITS_TO_HEAL
	EventBus.heal_charge_changed.emit(heal_charge, CLOSE_HITS_TO_HEAL)


func consume_attack() -> void:
	_attack_buf = 0.0
	attack_pressed = false


func consume_dash() -> void:
	_dash_buf = 0.0
	dash_pressed = false


func wants_jump() -> bool:
	return not jump_buffer_timer.is_stopped()

func consume_jump() -> void:
	jump_buffer_timer.stop()

func can_jump() -> bool:
	return is_on_floor() or not coyote_timer.is_stopped()

func can_dash() -> bool:
	return dash_cooldown.is_stopped() and (is_on_floor() or can_air_dash)


func try_actions() -> bool:
	if not pending_throw.is_empty():
		if blade == null:
			state_machine.transition("throw")
			return true
		pending_throw = {}
	if recall_pressed and blade:
		recall_pressed = false
		if blade.is_hooked():
			state_machine.transition("swing" if blade.can_swing() else "grapple")
			return true
		blade.recall()
	if dash_pressed and blade and blade.is_pinned():
		consume_dash()
		state_machine.transition("zip")
		return true
	if dash_pressed and blade and (blade.is_hooked() or blade.is_wall_stuck()):
		consume_dash()
		state_machine.transition("grapple")
		return true
	if dash_pressed and can_dash():
		consume_dash()
		state_machine.transition("dash")
		return true
	if attack_pressed and blade == null:
		consume_attack()
		state_machine.transition("attack")
		return true
	return false


func settle_state() -> void:
	if not is_on_floor():
		state_machine.transition("fall")
	elif move_axis != 0.0:
		state_machine.transition("run")
	else:
		state_machine.transition("idle")


func throw_blade(throw := {}) -> void:
	var dir: Vector2 = throw.get("dir", aim_vector)
	var power: float = throw.get("power", 1.0)
	var charged: bool = throw.get("charged", false)
	if absf(dir.x) > 0.05:
		facing = 1 if dir.x > 0.0 else -1
	blade = BLADE_SCENE.instantiate()
	get_parent().add_child(blade)
	blade.global_position = blade_anchor.global_position
	var assisted := _assisted_aim(dir)
	var to_hook := grapple_target(dir) != null
	blade.launch(self, assisted, power, charged, to_hook)
	AudioManager.sfx(&"charged" if charged else &"throw", 0.0 if charged else -3.0)
	if charged:
		Fx.ring(blade_anchor.global_position, Color(1.0, 0.92, 0.6), 18.0, 0.25)
		Fx.hit_stop(0.03)
		Fx.shake(1.5)
	EventBus.blade_thrown.emit()


func aim_toward(world_point: Vector2) -> Vector2:
	var d := world_point - blade_anchor.global_position
	if d.length() < 2.0:
		return Vector2(facing, 0)
	return d.normalized()


func attack_direction(aim: Vector2) -> String:
	if aim.y < -0.6:
		return "up"
	if aim.y > 0.6 and not is_on_floor():
		return "down"
	if absf(aim.x) > 0.05:
		facing = 1 if aim.x > 0.0 else -1
	return "forward"


const AIM_ASSIST_ANGLE := 0.5

func _assisted_aim(direction: Vector2) -> Vector2:
	var target := grapple_target(direction)
	if target == null:
		target = enemy_target(direction)
	if target:
		return (target.global_position - blade_anchor.global_position).normalized()
	return direction


const ENEMY_ASSIST_ANGLE := 0.3

func enemy_target(direction: Vector2) -> Node2D:
	var from := blade_anchor.global_position
	var best: Node2D = null
	var best_diff := ENEMY_ASSIST_ANGLE
	var space := get_world_2d().direct_space_state
	for hb in get_tree().get_nodes_in_group("enemy_hurtbox"):
		if not hb.is_visible_in_tree() or hb.invulnerable:
			continue
		var to: Vector2 = hb.global_position - from
		if to.length() > stats.get_stat("wire_length") or to.length() < 4.0:
			continue
		var diff := absf(direction.angle_to(to))
		if diff >= best_diff:
			continue
		var query := PhysicsRayQueryParameters2D.create(from, hb.global_position, 1)
		if not space.intersect_ray(query).is_empty():
			continue
		best_diff = diff
		best = hb
	return best


func grapple_target(direction: Vector2) -> Node2D:
	var from := blade_anchor.global_position
	var best: Node2D = null
	var best_diff := AIM_ASSIST_ANGLE
	var space := get_world_2d().direct_space_state
	for point in get_tree().get_nodes_in_group("grapple_points"):
		var to: Vector2 = point.global_position - from
		if to.length() > stats.get_stat("wire_length"):
			continue
		var diff := absf(direction.angle_to(to))
		if diff >= best_diff:
			continue
		var query := PhysicsRayQueryParameters2D.create(from, point.global_position, 1)
		if not space.intersect_ray(query).is_empty():
			continue
		best_diff = diff
		best = point
	return best


func on_blade_returned(landed_hit := false) -> void:
	blade = null
	EventBus.blade_returned.emit()
	if landed_hit and not is_on_floor() and not is_dead:
		can_air_dash = true
		velocity.y = minf(velocity.y, jump_velocity * 0.4)
		AudioManager.sfx(&"catch")
		Fx.ring(blade_anchor.global_position, Color(0.4, 1.0, 1.0), 12.0, 0.2, 1.0)


func _update_wire() -> void:
	if blade and is_instance_valid(blade):
		wire.visible = true
		wire.points = PackedVector2Array([to_local(blade_anchor.global_position), to_local(blade.global_position)])
		_wire_glow.visible = true
		_wire_glow.points = wire.points
	else:
		wire.visible = false
		_wire_glow.visible = false


func _on_hurt(damage: int, from_position: Vector2, _source: Node) -> void:
	if is_dead:
		return
	if GameState.is_overclocked():
		damage *= 2
	hurtbox.invulnerable = true
	invuln_timer.start(stats.get_stat("invuln_time"))
	health.damage(damage)
	if heal_charge >= CLOSE_HITS_TO_HEAL and not health.is_dead():
		register_close_hit(0)
	AudioManager.sfx(&"hurt")
	Fx.hit_stop(0.08)
	Fx.shake(4.0)
	Fx.spark(global_position + BODY_CENTER, Color(1.0, 0.45, 0.35), 10)
	if Fx.post:
		Fx.post.hit()
	if not is_dead:
		var dir := signf(global_position.x - from_position.x)
		state_machine.transition("hurt", {"dir": dir if dir != 0.0 else -float(facing)})
		_charge_rebound(REBOUND_WINDOW)


func _on_melee_hit(target: Hurtbox) -> void:
	AudioManager.sfx(&"hit")
	Fx.hit_stop(0.05)
	Fx.shake(2.0)
	Fx.spark(target.global_position.lerp(melee_hitbox.global_position, 0.5), Color.WHITE)
	var attack := state_machine.current
	if attack.has_method("on_hit_landed"):
		attack.on_hit_landed()
	register_close_hit()


func _on_died() -> void:
	is_dead = true
	AudioManager.sfx(&"die")
	if GameState.scrap > 0:
		if not GameState.lost_scrap.is_empty():
			EventBus.toast.emit("Your earlier dropped scrap (%d) is gone." % int(GameState.lost_scrap.get("amount", 0)))
		EventBus.toast.emit("Dropped %d scrap. It's waiting where you fell." % GameState.scrap)
		GameState.lost_scrap = {
			"room": GameState.current_room,
			"x": global_position.x, "y": global_position.y - 12.0,
			"amount": GameState.scrap,
		}
		GameState.scrap = 0
		EventBus.currency_changed.emit()
	state_machine.transition("dead")
	EventBus.player_died.emit()
	_death_beat()
	await get_tree().create_timer(2.6, true, false, true).timeout
	WorldManager.respawn()


func _death_beat() -> void:
	if Fx.hitstop_enabled:
		Engine.time_scale = 0.35
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(camera, "zoom", camera.zoom * 1.22, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _core_light:
		tw.parallel().tween_property(_core_light, "energy", 0.0, 1.6)
	if Fx.post:
		Fx.post.hit()
	Fx.ring(global_position + BODY_CENTER, Color(0.5, 0.75, 0.85), 26.0, 0.6)
	for i in 5:
		await get_tree().create_timer(0.16 + i * 0.05, true, false, true).timeout
		if not is_dead:
			break
		Fx.spark(global_position + BODY_CENTER + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Color(0.45, 0.9, 1.0).darkened(i * 0.15), 4 - i / 2)
	Engine.time_scale = 1.0


func hazard_hit(damage := 1, respawn := true) -> void:
	if is_dead or hurtbox.invulnerable and not respawn:
		return
	AudioManager.sfx(&"hurt")
	health.damage(damage)
	Fx.hit_stop(0.08)
	Fx.shake(4.0)
	if Fx.post:
		Fx.post.hit()
	if is_dead or not respawn:
		if not is_dead:
			hurtbox.invulnerable = true
			invuln_timer.start(stats.get_stat("invuln_time"))
		return
	velocity = Vector2.ZERO
	if blade and is_instance_valid(blade):
		blade.queue_free()
		blade = null
	_safe_candidates.clear()
	await get_tree().create_timer(0.12).timeout
	if is_dead or last_safe == Vector2.ZERO:
		return
	global_position = last_safe
	velocity = Vector2.ZERO
	hurtbox.invulnerable = true
	invuln_timer.start(stats.get_stat("invuln_time"))
	Fx.ring(global_position + BODY_CENTER, Color(0.4, 1.0, 0.8), 24.0, 0.3)
	state_machine.transition("idle")


func _floor_conveyor() -> Conveyor:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7 and c.get_collider() is Conveyor:
			return c.get_collider()
	return null


func revive() -> void:
	is_dead = false
	Engine.time_scale = 1.0
	fit_camera_to_room()
	if _core_light:
		_core_light.energy = 0.35
	Fx.ring(global_position + BODY_CENTER, Color(0.3, 0.95, 1.0), 30.0, 0.4)
	Fx.burst(global_position + BODY_CENTER, Color(0.4, 0.95, 1.0), 14)
	AudioManager.sfx(&"heal", -4.0)
	health.refill()
	hurtbox.invulnerable = false
	state_machine.transition("idle")
	velocity = Vector2(0, -190)
	visuals.respawn_pop()
	Fx.float_text(global_position + Vector2(0, -40), "BOUNCED BACK")
	_charge_rebound(REBOUND_AFTER_RESPAWN)


func _charge_rebound(seconds: float) -> void:
	rebound_until = Time.get_ticks_msec() / 1000.0 + seconds
	Fx.ring(global_position + BODY_CENTER, Color(0.45, 0.95, 1.0), 20.0, 0.3)


func rebound_ready() -> bool:
	return Time.get_ticks_msec() / 1000.0 < rebound_until


func take_rebound() -> bool:
	if not rebound_ready():
		return false
	rebound_until = 0.0
	rebounds_landed += 1
	Fx.float_text(global_position + Vector2(0, -40), "REBOUND!")
	Fx.burst(global_position + BODY_CENTER, Color(0.45, 0.95, 1.0), 12)
	AudioManager.sfx(&"charged", 0.0)
	return true


func _use_repair_kit() -> void:
	if health.current >= health.max_health or health.is_dead():
		return
	if GameState.use_consumable(&"repair_kit"):
		health.heal(2)
		AudioManager.sfx(&"heal")
		EventBus.toast.emit("Repair kit used: +2 health")


func reset_for_room() -> void:
	set_low(false)
	last_safe = Vector2.ZERO
	hazard_contacts = 0
	_safe_candidates.clear()
	if blade and is_instance_valid(blade):
		blade.queue_free()
	blade = null
	current_interactable = null
	EventBus.interact_prompt.emit("")
	velocity = Vector2.ZERO
	if not is_dead:
		state_machine.transition("idle")


var _room_bounds := Rect2()

func apply_camera_limits(bounds: Rect2) -> void:
	_room_bounds = bounds
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	fit_camera_to_room()
	_cam_y = global_position.y
	camera.reset_smoothing.call_deferred()


const WORLD_HEIGHT := 360.0

func fit_camera_to_room() -> void:
	var view := get_viewport_rect().size
	var z := maxf(1.0, view.y / WORLD_HEIGHT)
	if _room_bounds.size != Vector2.ZERO:
		z = maxf(z, maxf(view.x / _room_bounds.size.x, view.y / _room_bounds.size.y))
	camera.zoom = Vector2(z, z)


func set_interactable(node: Node) -> void:
	current_interactable = node
	EventBus.interact_prompt.emit("[E] " + node.prompt)


func clear_interactable(node: Node) -> void:
	if current_interactable == node:
		current_interactable = null
		EventBus.interact_prompt.emit("")


func _on_stats_changed() -> void:
	var h := stats.get_stat("jump_height")
	var t := stats.get_stat("jump_time_to_apex")
	jump_velocity = -2.0 * h / t
	rise_gravity = 2.0 * h / (t * t)
	health.set_max(int(stats.get_stat("max_health")))
