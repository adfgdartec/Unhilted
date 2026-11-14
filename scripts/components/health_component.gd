class_name HealthComponent
extends Node

signal changed(current: int, maximum: int)
signal died

@export var max_health := 3
var current := 0


func _ready() -> void:
	current = max_health


func set_max(value: int, refill := false) -> void:
	max_health = maxi(value, 1)
	current = max_health if refill else mini(current, max_health)
	changed.emit(current, max_health)


func damage(amount: int) -> void:
	if current <= 0:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()


func heal(amount: int) -> void:
	if current <= 0:
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func refill() -> void:
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0
