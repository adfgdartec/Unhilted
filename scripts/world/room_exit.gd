class_name RoomExit
extends Area2D
## Walk into this to go to another room. target_spawn must be the name of a
## Marker2D in the target room's Spawns node (place it a little away from that
## room's own exit so you don't bounce straight back).

@export_file("*.tscn") var target_room := ""
@export var target_spawn: StringName = &"left"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player body
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player and not body.is_dead and target_room != "":
		WorldManager.change_room(target_room, target_spawn)
