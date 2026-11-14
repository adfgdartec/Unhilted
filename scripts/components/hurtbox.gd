class_name Hurtbox
extends Area2D

signal hit(damage: int, from_position: Vector2, source: Node)

var invulnerable := false
var blocks: Callable = Callable()


func _ready() -> void:
	monitoring = false
	if collision_layer & 16:
		add_to_group("enemy_hurtbox")


func take_hit(damage: int, from_position: Vector2, source: Node = null) -> bool:
	if invulnerable:
		return false
	if blocks.is_valid() and blocks.call(from_position):
		return false
	hit.emit(damage, from_position, source)
	if is_in_group("enemy_hurtbox"):
		Fx.damage_number(global_position, damage)
		AudioManager.sfx(&"enemy_hit", -4.0)
	return true
