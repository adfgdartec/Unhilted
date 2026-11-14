class_name ShardData
extends Resource
## One of the five shards of the ancient sword. Each unlocks a blade ability
## and opens new paths (metroidvania gates).

@export var id: StringName
@export_range(1, 5) var number := 1
@export var display_name := ""
@export_multiline var description := ""
@export var ability: StringName ## e.g. &"pierce", &"swing", &"ricochet", &"live_wire", &"complete"
@export_multiline var lore := ""
@export var blade_sprite: Texture2D
