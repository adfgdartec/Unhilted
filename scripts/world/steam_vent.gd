@tool
class_name SteamVent
extends Node2D
## A grate in the floor that blows steam. Two kinds:
##   lift  - the column throws you upward (a launch pad that also gives the air
##           dash and wall kicks back). Steam fills the column while it's on.
##   scald - the column burns: it hurts and sends you to safe ground.
## It runs on a rhythm (period / on_time), or, with a valve, only while that
## valve is open (or shut, with inverted). Before turning on it hisses and
## spits a few puffs: the tell.
## The node's position is the centre of the grate, on the floor surface.

@export var width := 24.0
@export var reach := 96.0           ## how tall the steam column is
@export_enum("lift", "scald") var kind := "lift"
@export var launch_speed := 520.0
@export var period := 0.0           ## 0 = always on (unless a valve controls it)
@export var on_time := 1.2
@export var offset := 0.0
@export var valve_path: NodePath    ## optional Valve that switches it
@export var inverted := false       ## on while the valve is SHUT

const TELL := 0.45

var _t := 0.0
var _on := true
var _area: Area2D
var _valve: Node = null
var _inside: Player = null
var _puffs: Array = []   ## [pos, age, life, size]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_t = offset
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width - 4, reach)
	cs.shape = r
	cs.position = Vector2(0, -reach * 0.5)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(func(b): if b is Player: _inside = b)
	_area.body_exited.connect(func(b): if b == _inside: _inside = null)
	if valve_path:
		_valve = get_node_or_null(valve_path)
	var l := Fx.make_light(Color(1.0, 0.75, 0.45) if kind == "lift" else Color(1.0, 0.45, 0.3), 30.0, 0.4)
	l.position = Vector2(0, -6)
	add_child(l)
	_on = _should_be_on()


func is_on() -> bool:
	return _on


func _should_be_on() -> bool:
	if _valve and is_instance_valid(_valve):
		return _valve.is_open != inverted
	if period <= 0.0:
		return true
	return fposmod(_t, period) < on_time


## True in the moment before it turns on (the hiss).
func _telling() -> bool:
	if _valve or period <= 0.0 or _on:
		return false
	var p := fposmod(_t, period)
	return p > period - TELL


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var was := _on
	_on = _should_be_on()
	if _on and not was:
		AudioManager.sfx(&"steam", -8.0)
	if _on and _inside and is_instance_valid(_inside):
		if kind == "lift":
			if _inside.velocity.y > -launch_speed * 0.9:
				_inside.velocity.y = -launch_speed
				_inside.jump_cut_armed = false
				_inside.can_air_dash = true
				_inside.wall_jumps_left = Player.MAX_WALL_JUMPS
				var st := _inside.state_machine.current_name()
				if st in ["idle", "run", "slide", "fall", "wall_slide"]:
					_inside.state_machine.transition("jump", {"launched": true})
		elif not _inside.hurtbox.invulnerable:
			_inside.hazard_hit(1)
	# puffs: a steady stream while on, a few spits during the tell
	var rate := 0.0
	if _on:
		rate = 0.03
	elif _telling():
		rate = 0.12
	if rate > 0.0 and randf() < delta / rate:
		var life := (reach / 140.0) if _on else 0.35
		_puffs.append([Vector2(randf_range(-width * 0.35, width * 0.35), -2.0), 0.0, life, randf_range(4.0, 7.0)])
	for p in _puffs:
		p[1] += delta
	_puffs = _puffs.filter(func(p): return p[1] < p[2])
	queue_redraw()


func _draw() -> void:
	# the grate, set into the floor
	var hw := width * 0.5
	draw_rect(Rect2(-hw - 2, -3, width + 4, 4), Color8(68, 54, 54))
	draw_rect(Rect2(-hw - 2, -3, width + 4, 1), Color8(201, 150, 60))
	var x := -hw + 2
	while x < hw - 1:
		draw_rect(Rect2(x, -2, 2, 3), Color8(20, 16, 18))
		x += 4
	if Engine.is_editor_hint():
		draw_rect(Rect2(-hw, -reach, width, reach), Color(1, 1, 1, 0.08))
		return
	var col := Color(0.93, 0.92, 0.88) if kind == "lift" else Color(1.0, 0.82, 0.72)
	for p in _puffs:
		var k: float = p[1] / p[2]
		var rise: float = reach * k if _on else 18.0 * k
		var pos: Vector2 = p[0] + Vector2(sin(p[1] * 6.0 + p[0].x) * 2.0, -rise)
		var sz: float = p[3] * (1.0 + k * 1.4)
		draw_circle(pos, sz, Color(col, 0.35 * (1.0 - k)))
	if _on:
		# a faint column so the reach is readable at a glance
		draw_rect(Rect2(-hw + 2, -reach, width - 4, reach), Color(col, 0.07))
