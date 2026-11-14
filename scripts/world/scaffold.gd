@tool
class_name Scaffold
extends Node2D
## Rusted steel structure drawn BEHIND a room's solids (no collision), so
## platforms read as floors of a building instead of floating slabs.
##   columns: each Rect2 is one tower bay (x, top, width, bottom). Draws two
##            legs, horizontal ties at `ties` heights and X-bracing between.
##   stilts:  platforms to hold up with a pair of legs down to `ground_y`.
## Light comes from the low sun on the right: right edges are lit warm.

@export var columns: Array[Rect2] = []:
	set(v):
		columns = v
		queue_redraw()
@export var ties: PackedFloat32Array = PackedFloat32Array():
	set(v):
		ties = v
		queue_redraw()
@export var stilts: Array[Rect2] = []:
	set(v):
		stilts = v
		queue_redraw()
@export var ground_y := 336.0
## platforms hung from above by two chains (drawn up to `hang_top`)
@export var hangers: Array[Rect2] = []
@export var hang_top := -200.0
@export var mast := Vector2.ZERO        ## top of a beacon mast (ZERO = none)
@export var mast_base_y := 16.0

const DARK := Color8(58, 30, 26)
const MID := Color8(102, 52, 38)
const LIT := Color8(170, 92, 56)
const HOT := Color8(222, 146, 92)
const RIVET := Color8(196, 120, 78)
const STREAK := Color8(84, 40, 30)

var _t := 0.0


func _ready() -> void:
	show_behind_parent = true
	self_modulate = Color(0.8, 0.76, 0.82) # a shade behind the floors, so floors read as standable
	if not Engine.is_editor_hint() and mast != Vector2.ZERO:
		var beacon := Fx.make_light(Color(1.0, 0.3, 0.2), 40.0, 0.8)
		beacon.position = mast
		add_child(beacon)


func _process(delta: float) -> void:
	if mast != Vector2.ZERO:
		_t += delta
		queue_redraw()


func _h(a: float, b: float) -> int:
	return absi((int(a) * 73856093) ^ (int(b) * 19349663)) % 997


func _leg(x: float, top: float, bottom: float, w := 4.0) -> void:
	draw_rect(Rect2(x - w * 0.5, top, w, bottom - top), MID)
	draw_rect(Rect2(x - w * 0.5, top, 1, bottom - top), DARK)
	draw_rect(Rect2(x + w * 0.5 - 1.0, top, 1, bottom - top), LIT)
	# rust streaks running down from the joints
	var y := top + 6.0
	while y < bottom - 8.0:
		var h := _h(x, y)
		if h % 3 == 0:
			draw_rect(Rect2(x - 1.0, y, 1, 4 + h % 6), STREAK)
		y += 11.0
	draw_rect(Rect2(x - w * 0.5 - 1.0, bottom - 2.0, w + 2.0, 2.0), DARK) # foot plate


func _tie(x0: float, x1: float, y: float) -> void:
	draw_rect(Rect2(x0, y - 1.5, x1 - x0, 3), MID)
	draw_line(Vector2(x0, y - 1.5), Vector2(x1, y - 1.5), LIT, 1.0)
	draw_line(Vector2(x0, y + 1.5), Vector2(x1, y + 1.5), DARK, 1.0)
	for x in [x0 + 1.0, x1 - 2.0]:
		draw_rect(Rect2(x, y - 0.5, 1, 1), RIVET)


func _brace(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, DARK, 2.0)
	draw_line(a + Vector2(0, -1), b + Vector2(0, -1), MID, 1.0)


func _draw() -> void:
	for c in columns:
		var x0 := c.position.x
		var x1 := c.end.x
		var levels: Array[float] = [c.position.y]
		for y in ties:
			if y > c.position.y and y < c.end.y:
				levels.append(y)
		levels.append(c.end.y - 2.0)
		levels.sort()
		# X-bracing in every bay, then ties, then legs on top
		for i in levels.size() - 1:
			var ya := levels[i] + 2.0
			var yb := levels[i + 1] - 2.0
			if yb - ya < 6.0:
				continue
			_brace(Vector2(x0 + 2, ya), Vector2(x1 - 2, yb))
			_brace(Vector2(x1 - 2, ya), Vector2(x0 + 2, yb))
		for y in levels:
			_tie(x0, x1, y)
		_leg(x0, c.position.y, c.end.y)
		_leg(x1, c.position.y, c.end.y)
	for r in stilts:
		var top := r.end.y
		var bottom := ground_y
		var lx := r.position.x + 8.0
		var rx := r.end.x - 8.0
		if bottom - top > 24.0:
			var mid := top + (bottom - top) * 0.5
			_brace(Vector2(lx, top + 3), Vector2(rx, mid))
			_brace(Vector2(rx, top + 3), Vector2(lx, mid))
			_brace(Vector2(lx, mid), Vector2(rx, bottom - 3))
			_brace(Vector2(rx, mid), Vector2(lx, bottom - 3))
			_tie(lx, rx, mid)
		_leg(lx, top, bottom, 3.0)
		_leg(rx, top, bottom, 3.0)
	for r in hangers:
		for x in [r.position.x + 6.0, r.end.x - 6.0]:
			var y := r.position.y
			while y > hang_top:
				draw_rect(Rect2(x - 1.0, y - 4.0, 2, 3), MID)
				draw_rect(Rect2(x - 1.0, y - 4.0, 1, 3), LIT)
				y -= 4.0
	if mast != Vector2.ZERO:
		# antenna mast with a rag flag and a blinking beacon
		_leg(mast.x, mast.y, mast_base_y, 2.0)
		var wave := sin(_t * 4.0)
		var flag := PackedVector2Array([mast + Vector2(1, 3), mast + Vector2(13, 5 + wave), mast + Vector2(11, 9 + wave * 0.5), mast + Vector2(1, 10)])
		draw_colored_polygon(flag, Color8(120, 46, 40))
		draw_line(mast + Vector2(1, 3), mast + Vector2(13, 5 + wave), Color8(176, 74, 58), 1.0)
		var on := fmod(_t, 1.4) < 0.7
		draw_circle(mast + Vector2(0, -1), 1.5, Color8(255, 80, 60) if on else Color8(90, 30, 26))
		for k in get_children():
			if k is PointLight2D:
				k.enabled = on
