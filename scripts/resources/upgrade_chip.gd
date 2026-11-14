class_name UpgradeChip
extends Resource
## A port upgrade. Each chip costs 1-3 ports. It can change stats (add/mult
## modifiers) and/or spawn an effect scene that adds new behaviour.
## Stat names are the keys in PlayerStats.base (e.g. "wire_length", "max_health").

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export_range(1, 3) var port_cost := 1
@export var icon: Texture2D
@export var icon_color := Color("38f2ff") ## Placeholder until real icons exist.
## Added to the base stat. Example: {"max_health": 1}
@export var add_modifiers: Dictionary = {}
## Multiplies the stat. Example: {"wire_length": 1.4}
@export var mult_modifiers: Dictionary = {}
## Optional behaviour node spawned under Player/Upgrades while equipped.
@export var effect_scene: PackedScene
