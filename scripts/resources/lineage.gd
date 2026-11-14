class_name Lineage
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var shared_traits := ""

@export_group("Palette")
@export var coat_colors: Array[Color] = []
@export var patch_colors: Array[Color] = []
@export var skin_tones: Array[Color] = []
@export var hair_colors: Array[Color] = []
@export var accent_colors: Array[Color] = []
@export var trouser_color := Color8(58, 46, 44)
@export var boot_color := Color8(46, 32, 28)
@export var outline_color := Color8(30, 20, 22)
@export var lens_color := Color8(255, 178, 78)

@export_group("Inheritable traits")
@export_enum("patchwork", "tailored") var coat_style := "patchwork"
@export var headwear: PackedStringArray = ["hood", "cap", "bandana", "beanie", "none"]
@export var goggle_styles: PackedStringArray = ["single", "double", "raised"]
@export var accessories: PackedStringArray = ["none", "pack", "belt"]
@export var height_range := Vector2i(15, 19)
@export var width_range := Vector2i(8, 11)
@export var hunch_max := 2
