class_name Lineage
extends Resource
## A town's "family": what every resident inherits, and the ranges their
## individual traits are rolled from. Residents of one town share a silhouette,
## palette and signature feature, but no two come out the same.
## To give a new town its own people, make a new Lineage .tres.

@export var id: StringName
@export var display_name := ""
@export_multiline var shared_traits := "" ## design note: what the family has in common

@export_group("Palette")
@export var coat_colors: Array[Color] = []
@export var patch_colors: Array[Color] = []
@export var skin_tones: Array[Color] = []
@export var hair_colors: Array[Color] = []
@export var accent_colors: Array[Color] = [] ## scarves, bandanas, beanies
@export var trouser_color := Color8(58, 46, 44)
@export var boot_color := Color8(46, 32, 28)
@export var outline_color := Color8(30, 20, 22)
## The family signature: every resident's goggle lenses glow this colour.
@export var lens_color := Color8(255, 178, 78)

@export_group("Inheritable traits")
## "patchwork" (Heapfolk: stitched centre seam, ragged hem, patches) or
## "tailored" (Bellows Kin: long fitted coat, a row of brass buttons, clean hem)
@export_enum("patchwork", "tailored") var coat_style := "patchwork"
@export var headwear: PackedStringArray = ["hood", "cap", "bandana", "beanie", "none"] ## also: stovepipe, bowler
@export var goggle_styles: PackedStringArray = ["single", "double", "raised"] ## also: monocle
@export var accessories: PackedStringArray = ["none", "pack", "belt"] ## also: apron, lantern, cane, brass_arm
@export var height_range := Vector2i(15, 19) ## coat height in pixels (adults)
@export var width_range := Vector2i(8, 11)
@export var hunch_max := 2
