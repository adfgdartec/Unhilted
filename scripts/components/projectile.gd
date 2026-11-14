class_name Projectile
extends Area2D

const BALE := preload("res://art/items/bale.png")
const BOLT := preload("res://art/items/bolt.png")

var velocity := Vector2.ZERO
var gravity_force := 0.0
var damage := 1
var lifetime := 3.0
var radius := 3.5
var color := Color(1.0, 0.45, 0.3)
var deflectable := true
var style := "bolt"
var shatter := 0
var spin := 0.0
var size := 1.0
var bounce_back := false
var return_target: Node2D
var returned := false
var _rot := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 | 1
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	if deflectable or bounce_back:
		var hb := Hurtbox.new()
		hb.collision_layer = 16
		hb.collision_mask = 0
		var hshape := CollisionShape2D.new()
		var hc := CircleShape2D.new()
		hc.radius = radius + 3.0
		hshape.shape = hc
		hb.add_child(hshape)
		add_child(hb)
		hb.hit.connect(func(_d, _f, _s): _bounce_back() if bounce_back else _pop())
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(_b): _pop())
	if style == "bolt":
		add_child(Fx.make_light(color, 26.0, 0.9))


func _physics_process(delta: float) -> void:
	velocity.y += gravity_force * delta
	position += velocity * delta
	_rot += spin * delta
	if returned and is_instance_valid(return_target):
		var to := return_target.call("returned_block_point") as Vector2
		velocity = velocity.lerp((to - global_position).normalized() * velocity.length(), 0.25)
		if global_position.distance_to(to) < 30.0:
			return_target.call("hit_by_returned_block", self)
			shatter = 0
			Fx.burst(global_position, Color(0.45, 0.95, 1.0), 20)
			queue_free()
	lifetime -= delta
	if lifetime <= 0.0:
		_pop()
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if returned:
		return
	if area is Hurtbox and area.collision_layer & 8:
		area.take_hit(damage, global_position, self)
		_pop()


func _pop() -> void:
	if is_queued_for_deletion():
		return
	Fx.spark(global_position, color, 5)
	if shatter > 0:
		_shatter()
	queue_free()


func _bounce_back() -> void:
	if returned or not is_instance_valid(return_target):
		return
	returned = true
	shatter = 0
	gravity_force = 0.0
	lifetime = 2.5
	spin *= -2.0
	set_deferred("collision_mask", 0)
	var to := return_target.call("returned_block_point") as Vector2
	velocity = (to - global_position).normalized() * maxf(velocity.length() * 1.5, 420.0)
	Fx.float_text(global_position + Vector2(0, -16), "BOUNCED BACK!")
	Fx.ring(global_position, Color(0.45, 0.95, 1.0), 22.0, 0.25)
	Fx.hit_stop(0.08)
	Fx.shake(4.0)
	AudioManager.sfx(&"hit", 2.0)
	color = Color(0.45, 0.95, 1.0)


func _shatter() -> void:
	Fx.shake(4.0)
	Fx.dust(global_position, 1.4)
	AudioManager.sfx(&"slam", -4.0)
	var dir := signf(velocity.x) if absf(velocity.x) > 1.0 else 1.0
	for i in shatter:
		var f := Projectile.new()
		f.style = "bale"
		f.size = 0.55
		f.radius = 4.5
		f.deflectable = false
		f.gravity_force = 650.0
		f.lifetime = 1.4
		f.spin = randf_range(-14.0, 14.0)
		f.color = color
		var spread := (float(i) / maxf(shatter - 1, 1) - 0.5) * 2.0
		f.velocity = Vector2(dir * 150.0 + spread * 120.0, -170.0 - absf(spread) * 40.0)
		get_parent().add_child.call_deferred(f)
		f.global_position = global_position + Vector2(0, -6)


func _draw() -> void:
	if style == "bale":
		draw_set_transform(Vector2.ZERO, _rot, Vector2(size, size))
		draw_texture(BALE, Vector2(-8, -8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, radius + 3.0, Color(color, 0.18))
		draw_texture(BOLT, Vector2(-4, -4))
