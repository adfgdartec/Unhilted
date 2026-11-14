class_name ShardData
extends Resource

@export var id: StringName
@export_range(1, 5) var number := 1
@export var display_name := ""
@export_multiline var description := ""
@export var ability: StringName
@export_multiline var lore := ""
@export var blade_sprite: Texture2D
