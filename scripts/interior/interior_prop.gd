class_name InteriorProp
extends Node2D

@export var texture: Texture2D
@export_enum("stand", "wall", "floor") var mode := "stand"
@export var footprint := Vector2.ZERO
@export var look_lines: Array[String] = []
@export var prompt := "Look"
@export var reach := 30.0
@export var flip := false


func _ready() -> void:
	if texture:
		var s := Sprite2D.new()
		s.texture = texture
		s.flip_h = flip
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		match mode:
			"stand":
				s.offset = Vector2(0, -texture.get_height() * 0.5)
			"wall":
				z_index = -5
			"floor":
				z_index = -6
		add_child(s)
	if footprint != Vector2.ZERO:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = footprint
		cs.shape = r
		cs.position = Vector2(0, -footprint.y * 0.5)
		body.add_child(cs)
		add_child(body)
	if not look_lines.is_empty():
		add_to_group("interior_interactable")


func interact() -> void:
	DialogueManager.say(look_lines)
