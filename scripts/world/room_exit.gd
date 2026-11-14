class_name RoomExit
extends Area2D

@export_file("*.tscn") var target_room := ""
@export var target_spawn: StringName = &"left"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player and not body.is_dead and target_room != "":
		WorldManager.change_room(target_room, target_spawn)
