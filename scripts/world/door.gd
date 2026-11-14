class_name Door
extends Interactable
## A doorway into a walk-in building (a 2.5D interior). Stand in it and press
## [E] to go inside; walking out over the doormat brings you back here, to the
## camp marker named return_spawn.

@export_file("*.tscn") var interior := ""
@export var return_spawn: StringName = &""
@export var size := Vector2(24, 40)


func _ready() -> void:
	super()
	if prompt == "Interact":
		prompt = "Enter"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)


func interact(_player: Player) -> void:
	if interior != "" and not WorldManager.is_busy():
		AudioManager.sfx(&"door", -4.0)
		WorldManager.enter_interior(interior, return_spawn)
