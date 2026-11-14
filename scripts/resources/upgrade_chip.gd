class_name UpgradeChip
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export_range(1, 3) var port_cost := 1
@export var icon: Texture2D
@export var icon_color := Color("38f2ff")
@export var add_modifiers: Dictionary = {}
@export var mult_modifiers: Dictionary = {}
@export var effect_scene: PackedScene
