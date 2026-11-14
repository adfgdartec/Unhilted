class_name Interactable
extends Area2D
## Base for anything you press [E] on. Override interact().

@export var prompt := "Interact"


func _ready() -> void:
	collision_layer = 128 # "interact"
	collision_mask = 2    # player body
	body_entered.connect(func(b): if b is Player: b.set_interactable(self))
	body_exited.connect(func(b): if b is Player: b.clear_interactable(self))


func interact(_player: Player) -> void:
	pass
