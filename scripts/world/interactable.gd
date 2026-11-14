class_name Interactable
extends Area2D

@export var prompt := "Interact"


func _ready() -> void:
	collision_layer = 128
	collision_mask = 2
	body_entered.connect(func(b): if b is Player: b.set_interactable(self))
	body_exited.connect(func(b): if b is Player: b.clear_interactable(self))


func interact(_player: Player) -> void:
	pass
