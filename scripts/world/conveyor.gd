@tool
class_name Conveyor
extends StaticBody2D
## A moving belt: anything standing on it is carried along (the physics
## engine adds the belt's speed to the player's floor velocity).
## The node's position is the TOP-LEFT of the belt.

@export var size := Vector2(128, 12):
	set(v):
		size = v
		queue_redraw()
@export var speed := 50.0 ## px/s, positive = to the right

var _t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if Engine.is_editor_hint():
		return
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = size * 0.5
	add_child(cs)
	# the player adds `speed` itself while standing on a belt (see Player)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(40, 34, 38))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3)), Color8(70, 62, 64))
	var off := fposmod(_t * speed, 8.0)
	var x := -8.0 + off
	while x < size.x:  # belt treads moving with the belt
		if x >= 0.0:
			draw_rect(Rect2(x, 0, 3, 3), Color8(120, 110, 104))
		x += 8.0
	for wx in [6.0, size.x - 6.0]:  # end rollers
		draw_circle(Vector2(wx, size.y * 0.5 + 1), size.y * 0.35, Color8(98, 82, 80))
		draw_circle(Vector2(wx, size.y * 0.5 + 1), 1.5, Color8(30, 20, 22))
	var ax := size.x * 0.5
	var dir := signf(speed)
	draw_line(Vector2(ax - 4 * dir, 7), Vector2(ax + 3 * dir, 7), Color8(212, 132, 74), 1.0) # direction arrow
	draw_line(Vector2(ax + 3 * dir, 7), Vector2(ax, 5), Color8(212, 132, 74), 1.0)
	draw_line(Vector2(ax + 3 * dir, 7), Vector2(ax, 9), Color8(212, 132, 74), 1.0)
