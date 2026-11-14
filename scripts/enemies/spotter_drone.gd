class_name SpotterDrone
extends CharacterBody2D
## Corp surveillance drone. Hovers out of melee reach, keeps its distance and
## fires slow bolts after a clear 0.6 s eye-glow warning. It exists to make the
## thrown blade matter: you either throw at it, or close in with a jump/dash.
## Bolts can be destroyed with a swing or a throw.

enum S { PATROL, WARN, COOLDOWN }

const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")
const SIGHT_RANGE := 210.0
const KEEP_DISTANCE := 110.0
const LEASH := 130.0          ## how far it strays from its home point
const WARN_TIME := 0.6
const COOLDOWN_TIME := 1.8
const BOLT_SPEED := 115.0

@export var enemy_id: StringName = &"spotter_drone"
@export var scrap_drop := 5

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox

var state := S.COOLDOWN
var _home := Vector2.ZERO
var _t := 0.0
var _anim := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _facing := -1
var _player: Player
var _aim := Vector2.ZERO ## where it is aiming (local), for the warning line
var _eye_light: PointLight2D


func _ready() -> void:
	_home = global_position
	_t = COOLDOWN_TIME * 0.5
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	_eye_light = Fx.make_light(Color(1.0, 0.4, 0.3), 30.0, 0.0)
	add_child(_eye_light)


func _physics_process(delta: float) -> void:
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var target := Vector2.ZERO
	var sees := false
	if _player and not _player.is_dead:
		target = _player.global_position + Player.BODY_CENTER
		sees = global_position.distance_to(target) < SIGHT_RANGE and _clear_line(target)

	# Movement: hover near home, sliding to keep a set distance from the player.
	var desired := _home + Vector2(0, sin(_anim * 2.0) * 4.0)
	if sees:
		_facing = 1 if target.x > global_position.x else -1
		_aim = to_local(target)
		desired.x = clampf(target.x - _facing * KEEP_DISTANCE, _home.x - LEASH, _home.x + LEASH)
	var speed := 20.0 if state == S.WARN else 55.0 # it slows down while aiming: a tell
	velocity = (desired - global_position).limit_length(speed) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()

	_eye_light.energy = (1.0 - maxf(_t, 0.0) / WARN_TIME) * 1.2 if state == S.WARN else 0.15
	_t -= delta
	match state:
		S.COOLDOWN:
			if _t <= 0.0 and sees:
				state = S.WARN
				AudioManager.sfx(&"telegraph", -10.0)
				_t = WARN_TIME
		S.WARN:
			if _t <= 0.0:
				if sees:
					_fire(target)
				state = S.COOLDOWN
				_t = COOLDOWN_TIME
	queue_redraw()


func _clear_line(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire(target: Vector2) -> void:
	AudioManager.sfx(&"laser", -4.0)
	var bolt := Projectile.new()
	bolt.velocity = (target - global_position).normalized() * BOLT_SPEED
	bolt.damage = 1
	bolt.lifetime = 3.0
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector2(_facing * 6.0, 2.0)


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	health.damage(damage)
	_knock = (global_position - from_position).normalized() * 160.0
	_flash = 0.12
	if state == S.WARN: # getting hit cancels the shot
		state = S.COOLDOWN
		_t = COOLDOWN_TIME


func _on_died() -> void:
	EventBus.enemy_killed.emit(enemy_id, global_position)
	for i in 2:
		var scrap: Collectible = COLLECTIBLE_SCENE.instantiate()
		scrap.kind = Collectible.Kind.SCRAP
		scrap.amount = maxi(scrap_drop / 2, 1)
		scrap.position = position
		scrap.pop_velocity = Vector2(randf_range(-70, 70), randf_range(-60, 20))
		get_parent().add_child.call_deferred(scrap)
	Fx.burst(global_position, Color(1.0, 0.6, 0.35), 16)
	queue_free()


func _draw() -> void:
	var body := Color.WHITE if _flash > 0.0 else Color(0.32, 0.36, 0.44)
	# rotor
	var blade_w := 10.0 * absf(sin(_anim * 30.0)) + 2.0
	draw_line(Vector2(-blade_w, -9), Vector2(blade_w, -9), Color(0.7, 0.75, 0.8), 1.0)
	draw_line(Vector2(0, -9), Vector2(0, -6), Color(0.5, 0.55, 0.6), 1.0)
	# hull
	draw_circle(Vector2.ZERO, 6.0, body)
	draw_rect(Rect2(-7, -1, 14, 3), body.darkened(0.25))
	# eye: dim normally, swells and brightens while aiming
	var eye_pos := Vector2(_facing * 2.5, 0)
	if state == S.WARN:
		var k := 1.0 - _t / WARN_TIME
		# aim line that firms up as the shot approaches
		draw_dashed_line(eye_pos, eye_pos + _aim.limit_length(SIGHT_RANGE), Color(1.0, 0.35, 0.25, 0.2 + 0.5 * k), 1.0, 4.0)
		draw_circle(eye_pos, 3.0 + 4.0 * k, Color(1.0, 0.45, 0.3, 0.35))
		draw_circle(eye_pos, 2.5, Color(1.0, 0.75, 0.5))
	else:
		draw_circle(eye_pos, 1.8, Color(0.75, 0.3, 0.25))
