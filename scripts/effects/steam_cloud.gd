extends Hitbox

const LIFETIME := 0.6
var _age := 0.0


func _init() -> void:
	damage = 1
	collision_layer = 0
	collision_mask = 16
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var a := (1.0 - t) * 0.5
	for i in 4:
		var off := Vector2(cos(i * 1.7) * 8.0, sin(i * 2.3) * 5.0 - t * 10.0)
		draw_circle(off, 7.0 + t * 6.0, Color(0.9, 0.92, 0.95, a))
