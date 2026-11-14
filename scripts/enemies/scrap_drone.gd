class_name ScrapDrone
extends CharacterBody2D
## The Heap's first enemy: a corporate garbage-collection drone that patrols
## back and forth and turns at walls and ledges. Built from the same
## Health / Hitbox / Hurtbox components as the player.

const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")
const GRAVITY := 900.0

@export var enemy_id: StringName = &"scrap_drone"
@export var speed := 38.0
@export var scrap_drop := 6

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var floor_ray: RayCast2D = $FloorRay

var dir := -1
var _knock := 0.0
var _flash := 0.0
var _turn_cooldown := 0.0
var _t := 0.0


func _ready() -> void:
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	if absf(_knock) > 5.0:
		velocity.x = _knock
		_knock = move_toward(_knock, 0.0, 700.0 * delta)
	else:
		velocity.x = dir * speed
	move_and_slide()

	_turn_cooldown -= delta
	floor_ray.position.x = 8.0 * dir
	if _turn_cooldown <= 0.0 and (is_on_wall() or (is_on_floor() and not floor_ray.is_colliding())):
		dir *= -1
		_turn_cooldown = 0.3
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _on_hit(damage: int, from_position: Vector2, _source: Node) -> void:
	health.damage(damage)
	Fx.spark(global_position + Vector2(0, -8), Color(1.0, 0.85, 0.6), 6)
	_knock = signf(global_position.x - from_position.x) * 180.0
	_flash = 0.12


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


func _draw() -> void:
	var col := Color.WHITE if _flash > 0.0 else Color(0.85, 0.3, 0.35)
	var hover := sin(_t * 6.0)
	draw_rect(Rect2(-9, -14 + hover, 18, 10), col)                      # body
	draw_rect(Rect2(-9, -14 + hover, 18, 2), Color(0.95, 0.85, 0.2))   # hazard stripe
	draw_circle(Vector2(5 * dir, -9 + hover), 2.0, Color(1, 0.9, 0.3)) # sensor eye
	draw_rect(Rect2(-7, -4, 4, 4), Color(0.2, 0.2, 0.25))              # treads
	draw_rect(Rect2(3, -4, 4, 4), Color(0.2, 0.2, 0.25))
