@tool
class_name Hazard
extends Area2D
## Toxic sludge, rebar spikes, or boiling water (the Underworks). Touching it
## costs 1 health and puts you back on the last safe ground. The node's
## position is the TOP-LEFT of the rect.

@export var size := Vector2(64, 16):
	set(v):
		size = v
		queue_redraw()
@export_enum("sludge", "spikes", "boiling") var kind := "sludge":
	set(v):
		kind = v
		queue_redraw()
@export var damage := 1

var _t := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2 # player body
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	var liquid := kind != "spikes"
	r.size = size - Vector2(4, 4 if liquid else 6)
	cs.shape = r
	cs.position = size * 0.5 + Vector2(0, 2 if liquid else 3)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(func(b): if b is Player: b.hazard_contacts = maxi(b.hazard_contacts - 1, 0))
	if kind == "boiling":
		var lb := Fx.make_light(Color(1.0, 0.6, 0.35), maxf(size.x * 0.5, 40.0), 0.45)
		lb.position = Vector2(size.x * 0.5, 0)
		add_child(lb)
	if kind == "sludge":
		var l := Fx.make_light(Color(0.5, 1.0, 0.3), maxf(size.x * 0.6, 40.0), 0.6)
		l.position = Vector2(size.x * 0.5, 0)
		add_child(l)


func _on_enter(b: Node) -> void:
	if b is Player:
		b.hazard_contacts += 1
		if kind == "sludge":
			AudioManager.sfx(&"sludge")
			Fx.spark(b.global_position, Color(0.5, 1.0, 0.3), 8)
		elif kind == "boiling":
			AudioManager.sfx(&"steam", -4.0)
			Fx.spark(b.global_position, Color(1.0, 0.95, 0.9), 10)
		b.hazard_hit(damage)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if kind == "boiling":
		# scalding condensate: dark copper-teal water, a pale rolling surface, bubbles
		draw_rect(Rect2(Vector2.ZERO, size), Color8(34, 52, 50))
		draw_rect(Rect2(Vector2(0, 4), Vector2(size.x, size.y - 4)), Color8(26, 38, 38))
		var bx := 0.0
		while bx < size.x:
			var by := 1.0 + sin(_t * 3.0 + bx * 0.3) * 1.0
			draw_rect(Rect2(bx, by, 2, 1), Color8(214, 226, 214))
			bx += 2.0
		for i in int(size.x / 18.0):
			var ph := fmod(_t * 0.9 + i * 0.37, 1.0)
			var px := fmod(i * 23.0 + 7.0, size.x)
			draw_circle(Vector2(px, size.y - 2.0 - ph * (size.y - 2.0)), 1.0 + ph, Color(0.9, 0.95, 0.92, 0.6 * (1.0 - ph)))
			if ph > 0.85:
				draw_circle(Vector2(px, -2.0 - (ph - 0.85) * 40.0), 2.5, Color(0.95, 0.95, 0.92, 0.25))
		return
	if kind == "sludge":
		draw_rect(Rect2(Vector2.ZERO, size), Color8(40, 72, 30))
		draw_rect(Rect2(Vector2(0, 3), Vector2(size.x, size.y - 3)), Color8(30, 54, 26))
		var x := 0.0
		while x < size.x:  # wavy glowing surface
			var y := 1.0 + sin(_t * 2.0 + x * 0.25) * 1.0
			draw_rect(Rect2(x, y, 2, 1), Color8(143, 224, 90))
			draw_rect(Rect2(x, y + 1, 2, 1), Color8(63, 143, 46))
			x += 2.0
		for i in int(size.x / 24.0):  # bubbles
			var bx := fmod(i * 37.0, size.x - 4.0) + 2.0
			var ph := fmod(_t * 0.7 + i * 0.37, 1.0)
			if ph < 0.3:
				draw_circle(Vector2(bx, 4.0 - ph * 6.0), 1.0 + ph * 2.0, Color(0.6, 1.0, 0.4, 0.8 - ph * 2.0))
	else:
		var x := 0.0
		while x < size.x:  # rebar spikes
			var h := 6.0 + fmod(x * 7.0, 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + 2, size.y - h), Vector2(x + 4, size.y)]), Color8(98, 82, 80))
			draw_line(Vector2(x + 2, size.y - h), Vector2(x + 3, size.y - 1), Color8(168, 90, 48), 1.0)
			x += 4.0
		draw_rect(Rect2(0, size.y - 2, size.x, 2), Color8(44, 32, 34))
