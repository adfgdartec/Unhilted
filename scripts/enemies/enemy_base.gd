class_name EnemyBase
extends CharacterBody2D

const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")
const GRAVITY := 900.0

@export var enemy_id: StringName = &"enemy"
@export var scrap_drop := 6

var health: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox
var player: Player
var facing := -1
var _flash := 0.0
var _knock := 0.0
var _t := 0.0


func setup(hp: int, body: Vector2, hurt: Vector2, contact: Vector2) -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body
	cs.shape = r
	cs.position = Vector2(0, -body.y * 0.5)
	add_child(cs)
	health = HealthComponent.new()
	health.max_health = hp
	add_child(health)
	health.set_max(hp, true)
	hurtbox = Hurtbox.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = hurt
	hs.shape = hr
	hs.position = Vector2(0, -hurt.y * 0.5)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 8
	hitbox.monitorable = false
	hitbox.continuous = true
	var ks := CollisionShape2D.new()
	var kr := RectangleShape2D.new()
	kr.size = contact
	ks.shape = kr
	ks.position = Vector2(0, -contact.y * 0.5)
	hitbox.add_child(ks)
	add_child(hitbox)
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = WorldManager.player
	_tick(delta)
	queue_redraw()


func _tick(_delta: float) -> void:
	pass


func dist_to_player() -> Vector2:
	if player == null or player.is_dead:
		return Vector2(99999, 99999)
	return player.global_position - global_position


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	health.damage(damage)
	_flash = 0.12
	_knock = signf(global_position.x - from_position.x) * 160.0
	Fx.spark(global_position + Vector2(0, -8), Color(1.0, 0.85, 0.6), 6)


func _on_died() -> void:
	EventBus.enemy_killed.emit(enemy_id, global_position)
	Fx.burst(global_position + Vector2(0, -8), Color(1.0, 0.55, 0.3))
	Fx.shake(3.0)
	var pieces := 3
	for i in pieces:
		var scrap: Collectible = COLLECTIBLE_SCENE.instantiate()
		scrap.kind = Collectible.Kind.SCRAP
		scrap.amount = maxi(scrap_drop / pieces, 1)
		scrap.position = position + Vector2(0, -8)
		scrap.pop_velocity = Vector2(randf_range(-90, 90), randf_range(-120, -60))
		get_parent().add_child.call_deferred(scrap)
	queue_free()


func draw_frame(tex: Texture2D, frame: int, frames: int, flip_h: bool, flip_v := false) -> void:
	var fw := tex.get_width() / frames
	var h := tex.get_height()
	var tint := Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if flip_h else 1, -1 if flip_v else 1))
	var y := -h if not flip_v else 0
	draw_texture_rect_region(tex, Rect2(-fw / 2, y, fw, h), Rect2(frame * fw, 0, fw, h), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
