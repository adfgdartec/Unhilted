class_name Hitbox
extends Area2D
## Deals damage to Hurtboxes it overlaps.
## - Swing mode (player melee): call begin_swing()/end_swing(); each target is hit once per swing.
## - Continuous mode (enemy contact damage): keeps hitting while overlapping;
##   the target's invulnerability frames stop it from hitting every frame.

signal hit_landed(hurtbox: Hurtbox)

@export var damage := 1
@export var continuous := false
@export var start_active := true

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = start_active


func begin_swing() -> void:
	_already_hit.clear()
	set_deferred("monitoring", true)


func end_swing() -> void:
	set_deferred("monitoring", false)


func _physics_process(_delta: float) -> void:
	if continuous and monitoring:
		for area in get_overlapping_areas():
			if area is Hurtbox and area.take_hit(damage, global_position, self):
				hit_landed.emit(area)


func _on_area_entered(area: Area2D) -> void:
	if continuous or not (area is Hurtbox) or area in _already_hit:
		return
	_already_hit.append(area)
	if area.take_hit(damage, global_position, self):
		hit_landed.emit(area)
