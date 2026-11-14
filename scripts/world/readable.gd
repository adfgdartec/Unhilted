class_name Readable
extends Interactable

@export var title := ""
@export_multiline var lines: Array[String] = ["..."]
@export var size := Vector2(24, 32)
@export var lore_id := ""


func _ready() -> void:
	super()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)


func interact(_player: Player) -> void:
	if DialogueManager.active:
		return
	if lore_id != "" and not GameState.lore.has(lore_id):
		GameState.lore[lore_id] = {"title": title, "lines": lines.duplicate()}
		EventBus.toast.emit("Journal: " + title.capitalize())
	DialogueManager.say(lines, title)
