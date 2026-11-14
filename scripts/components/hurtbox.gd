class_name Hurtbox
extends Area2D
## Receives hits. Put it on anything that can be damaged.
## Player hurtbox -> layer "player_hurtbox". Enemy hurtbox -> layer "enemy_hurtbox".

signal hit(damage: int, from_position: Vector2, source: Node)

var invulnerable := false
## Optional armour: called with the attacker's position; return true to block
## the hit (the attack glances off, take_hit returns false).
var blocks: Callable = Callable()


func _ready() -> void:
	monitoring = false # Hurtboxes are only detected, they never scan.
	if collision_layer & 16:
		add_to_group("enemy_hurtbox") # used by throw aim-assist


## Returns true if the hit landed (false while invulnerable).
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
