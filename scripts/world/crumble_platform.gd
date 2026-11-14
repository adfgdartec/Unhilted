class_name CrumblePlatform
extends StaticBody2D
## A rusty girder ledge you can jump up through and stand on. crumble()
## knocks it out: it shakes, splits and drops away. The Intake showdown's
## Governor smashes these one by one as it loses its balance.

@export var width := 52.0

var _shake := 0.0
var _falling := false
var _vel := Vector2.ZERO
var _spin := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 6)
	cs.shape = r
	cs.position = Vector2(0, 3)
	cs.one_way_collision = true
	add_child(cs)


func crumble() -> void:
	if _falling:
		return
	_falling = true
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	_vel = Vector2(randf_range(-30, 30), -60)
	_spin = randf_range(-2.0, 2.0)
	AudioManager.sfx(&"slam", -4.0)
	Fx.burst(global_position + Vector2(0, 3), Color(0.75, 0.45, 0.3), 16)
	Fx.dust(global_position, 1.2)
	Fx.shake(4.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _falling:
		_vel.y += 700.0 * delta
		position += _vel * delta
		rotation += _spin * delta
		modulate.a = maxf(modulate.a - delta * 0.8, 0.0)
		if modulate.a <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var w := width
	var rust := Color8(122, 64, 42)
	var rust_hi := Color8(176, 98, 60)
	var dark := Color8(48, 28, 26)
	draw_rect(Rect2(-w / 2.0, 0, w, 6), rust)
	draw_rect(Rect2(-w / 2.0, 0, w, 1), rust_hi)
	draw_rect(Rect2(-w / 2.0, 5, w, 1), dark)
	var x := -w / 2.0 + 3.0
	while x < w / 2.0 - 3.0:
		draw_line(Vector2(x, 1), Vector2(x + 4, 5), dark, 1.0)
		x += 8.0
	# hanging chains to the ceiling rail
	for side in [-1.0, 1.0]:
		var cx: float = side * (w / 2.0 - 4.0)
		var y := -2.0
		while y > -60.0:
			draw_rect(Rect2(cx - 0.5, y - 2, 1, 2), Color8(90, 80, 76))
			y -= 4.0
