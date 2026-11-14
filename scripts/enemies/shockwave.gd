class_name Shockwave
extends Hitbox

var dir := 1.0
var speed := 220.0
var life := 0.7
var _age := 0.0


static func spawn(parent: Node, at: Vector2, direction: float, travel_speed := 220.0, lifetime := 0.7) -> Shockwave:
	var w := Shockwave.new()
	w.dir = direction
	w.speed = travel_speed
	w.life = lifetime
	w.collision_layer = 0
	w.collision_mask = 8
	w.monitorable = false
	w.continuous = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 10)
	cs.shape = r
	cs.position = Vector2(0, -5)
	w.add_child(cs)
	w.position = at
	parent.add_child(w)
	return w


func _physics_process(delta: float) -> void:
	super(delta)
	_age += delta
	position.x += dir * speed * delta
	if _age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _age / life
	var a := 1.0 - k
	draw_arc(Vector2(-dir * 2, 0), 8.0, PI, TAU, 10, Color(0.93, 0.9, 0.82, 0.7 * a), 2.0)
	draw_circle(Vector2(-dir * 6, -3), 3.0, Color(0.93, 0.9, 0.82, 0.4 * a))
	draw_circle(Vector2(-dir * 11, -2), 2.0, Color(0.93, 0.9, 0.82, 0.25 * a))
