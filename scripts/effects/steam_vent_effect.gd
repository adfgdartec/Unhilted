extends Node

const CLOUD := preload("res://scripts/effects/steam_cloud.gd")


func _ready() -> void:
	EventBus.player_dashed.connect(_on_dash)


func _on_dash(at_position: Vector2, _direction: int) -> void:
	var room := WorldManager.current_room
	if room == null:
		return
	var cloud: Area2D = CLOUD.new()
	room.add_child(cloud)
	cloud.global_position = at_position
