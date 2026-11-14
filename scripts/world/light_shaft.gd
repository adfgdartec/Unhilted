@tool
class_name LightShaft
extends Node2D
## Daylight leaking through a crack in the heap: a bright jagged slit at the
## node's position, a soft tapered beam slanting down, dust drifting through
## it, and a real light where it lands. Purely visual (no collision).

@export var length := 300.0:
	set(v):
		length = v
		queue_redraw()
@export var top_width := 10.0
@export var bottom_width := 46.0
@export var slant := 40.0             ## horizontal drift of the beam over its length
@export var color := Color(1.0, 0.82, 0.58, 0.16)
@export var land_light := 0.8         ## energy of the light where the beam lands (0 = none)

var _t := 0.0
var _dust: Array = []


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if Engine.is_editor_hint():
		return
	_t = randf() * 10.0
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(name)
	for i in 14:
		_dust.append([rnd.randf(), rnd.randf_range(-0.5, 0.5), rnd.randf_range(0.02, 0.06), rnd.randf() * TAU])
	if land_light > 0.0:
		var l := Fx.make_light(Color(color, 1.0), bottom_width * 1.6, land_light)
		l.position = Vector2(slant, length)
		add_child(l)
		var top := Fx.make_light(Color(color, 1.0), 26.0, 0.6)
		add_child(top)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var shimmer := 0.85 + 0.15 * sin(_t * 0.9) * sin(_t * 2.3)
	# beam in a few nested layers: brighter core, soft edges
	for k in 4:
		var f := 1.0 - k * 0.22
		var tw := top_width * f * 0.5
		var bw := bottom_width * f * 0.5
		var c := Color(color, color.a * shimmer * (0.45 + k * 0.25))
		var pts := PackedVector2Array([Vector2(-tw, 0), Vector2(tw, 0), Vector2(slant + bw, length), Vector2(slant - bw, length)])
		var cols := PackedColorArray([c, c, Color(c, 0.0), Color(c, 0.0)])
		draw_polygon(pts, cols)
	# the crack itself
	var crack := Color(1.0, 0.93, 0.78, 0.9)
	draw_line(Vector2(-top_width * 0.5, 0), Vector2(-1, -1), crack, 1.0)
	draw_line(Vector2(-1, -1), Vector2(2, 1), crack, 1.0)
	draw_line(Vector2(2, 1), Vector2(top_width * 0.5, 0), crack, 1.0)
	# dust motes drifting down through the light
	for d in _dust:
		var p: float = fmod(d[0] + _t * d[2], 1.0)
		var w: float = lerpf(top_width, bottom_width, p) * 0.5
		var x: float = slant * p + d[1] * w * 2.0 + sin(_t + d[3]) * 2.0
		var a := sin(p * PI) * 0.8
		draw_rect(Rect2(Vector2(x, p * length).round(), Vector2.ONE), Color(1.0, 0.9, 0.75, a))
