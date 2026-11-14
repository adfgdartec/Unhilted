class_name BouncePad
extends Area2D

const WIDTH := 22.0

@export var strength := 470.0

var _squash := 0.0
var _t := 0.0
var _cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(WIDTH - 2.0, 8.0)
	cs.shape = r
	cs.position = Vector2(0, -6)
	add_child(cs)
	z_index = 1
	add_child(Fx.make_light(Color(0.4, 0.95, 1.0), 26.0, 0.25))


func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	if _cooldown <= 0.0:
		for body in get_overlapping_bodies():
			if body is Player and not body.is_dead and body.velocity.y >= 0.0:
				launch(body)
				break
	queue_redraw()


func launch(p: Player) -> void:
	_cooldown = 0.2
	_squash = 1.0
	p.velocity.y = -strength
	p.state_machine.transition("fall")
	p.visuals.play("jump")
	p.visuals.land()
	AudioManager.sfx(&"jump", 2.0, 0.15)
	Fx.ring(global_position + Vector2(0, -6), Color(0.45, 0.95, 1.0), 18.0, 0.25)
	Fx.dust(global_position, 0.8)


func _draw() -> void:
	var sq := _squash
	var bob := sin(_t * 3.0) * 0.5
	draw_rect(Rect2(-WIDTH / 2.0, -5, WIDTH, 5), Color8(30, 26, 30))
	draw_rect(Rect2(-WIDTH / 2.0 + 1, -5, WIDTH - 2, 1), Color8(70, 62, 66))
	for x in range(-9, 10, 4):
		draw_rect(Rect2(x, -3, 2, 1), Color8(48, 42, 46))
	var h := 7.0 - sq * 4.0 + bob * 0.3
	var coils := 3
	for i in coils:
		var y := -5.0 - (i + 0.5) * h / coils
		draw_line(Vector2(-7, y + 1), Vector2(7, y - 1), Color8(150, 150, 156), 1.0)
		draw_line(Vector2(-7, y), Vector2(7, y - 2), Color8(96, 96, 104), 1.0)
	var top := -5.0 - h - 2.0
	draw_rect(Rect2(-9, top, 18, 2), Color8(120, 118, 124))
	draw_rect(Rect2(-9, top, 18, 1), Color8(200, 198, 196))
	var glow := 0.55 + 0.45 * sin(_t * 4.0)
	draw_rect(Rect2(-5, top - 1, 10, 1), Color(0.35, 0.95, 1.0, glow))
