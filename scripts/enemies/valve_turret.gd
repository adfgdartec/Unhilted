class_name ValveTurret
extends EnemyBase

const TEX := preload("res://art/enemies/valve_turret.png")
enum S { IDLE, CHARGE, FIRE, SHUT, DEAD_PRESSURE }

@export var face := 1
@export var reach := 84.0
@export var idle_time := 1.4
@export var offset := 0.0
@export var valve_path: NodePath

var state := S.IDLE
var _st := 0.0
var _jet: Hitbox
var _valve: Node


func _ready() -> void:
	enemy_id = &"valve_turret"
	scrap_drop = 8
	setup(4, Vector2(18, 20), Vector2(24, 24), Vector2(16, 18))
	position.y += 12
	facing = face
	_st = -offset
	_jet = Hitbox.new()
	_jet.collision_layer = 0
	_jet.collision_mask = 8
	_jet.monitorable = false
	_jet.continuous = true
	_jet.start_active = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(reach, 18)
	cs.shape = r
	cs.position = Vector2(face * (14 + reach * 0.5), -12)
	_jet.add_child(cs)
	add_child(_jet)
	if valve_path:
		_valve = get_node_or_null(valve_path)


func _tick(delta: float) -> void:
	_st += delta
	velocity = Vector2.ZERO
	if _valve and _valve.is_open and state != S.DEAD_PRESSURE:
		_set_jet(false)
		state = S.DEAD_PRESSURE
	match state:
		S.IDLE:
			if _st > idle_time:
				_go(S.CHARGE)
				AudioManager.sfx(&"telegraph", -14.0)
		S.CHARGE:
			if _st > 0.5:
				_go(S.FIRE)
				_set_jet(true)
				AudioManager.sfx(&"steam", -4.0)
		S.FIRE:
			if _st > 1.0:
				_set_jet(false)
				_go(S.IDLE)
		S.SHUT:
			if _st > 2.6:
				_go(S.IDLE)
		S.DEAD_PRESSURE:
			pass


func _set_jet(on: bool) -> void:
	_jet.set_deferred("monitoring", on)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _on_hit(damage: int, from_position: Vector2, source: Node) -> void:
	super(damage, from_position, source)
	_knock = 0.0
	if state != S.DEAD_PRESSURE:
		_set_jet(false)
		if state != S.SHUT:
			AudioManager.sfx(&"valve", -6.0)
		_go(S.SHUT)


func _draw() -> void:
	var f := 0
	match state:
		S.CHARGE: f = 1
		S.FIRE: f = 2
		S.SHUT, S.DEAD_PRESSURE: f = 3
	draw_set_transform(Vector2(0, 1), 0.0, Vector2.ONE)
	draw_frame(TEX, f, 4, face < 0)
	if state == S.FIRE:
		var k := _st / 1.0
		for i in 9:
			var t := fmod(_t * 3.0 + i / 9.0, 1.0)
			var x := face * (16 + t * reach)
			var y := -12 + sin(i * 2.3 + _t * 8.0) * (2.0 + t * 6.0)
			draw_circle(Vector2(x, y), 3.0 + t * 6.0, Color(0.95, 0.93, 0.88, 0.45 * (1.0 - t) * (1.0 - k * 0.3)))
	elif state == S.CHARGE and fmod(_t, 0.16) < 0.08:
		draw_circle(Vector2(face * 22, -12), 2.0, Color(0.95, 0.93, 0.88, 0.6))
