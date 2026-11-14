class_name AbilityGate
extends StaticBody2D
## A barrier that only breaks once you have the right shard.
## Example: a scrap wall that Shard I (Edge) cuts through. Stays broken forever.

@export_range(1, 5) var required_shard := 1
@export var size := Vector2(16, 48)
@export var gate_id := "" ## Leave empty to auto-generate from room + node name.

const WALL := preload("res://art/items/scrap_wall.png")

var _hurtbox: Hurtbox
var _msg_cooldown := 0.0


func _ready() -> void:
	if gate_id == "":
		gate_id = "%s/%s" % [owner.room_id if owner is Room else "room", name]
	if GameState.is_collected(gate_id):
		queue_free()
		return
	collision_layer = 1
	collision_mask = 0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16 # enemy_hurtbox, so player attacks find it
	_hurtbox.collision_mask = 0
	var hshape := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = size + Vector2(4, 4)
	hshape.shape = hrect
	hshape.position = shape.position
	_hurtbox.add_child(hshape)
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)


func _process(delta: float) -> void:
	_msg_cooldown = maxf(_msg_cooldown - delta, 0.0)


func _on_hit(_damage: int, _from: Vector2, _source: Node) -> void:
	if GameState.has_shard(required_shard):
		GameState.mark_collected(gate_id)
		Fx.shake(5.0)
		AudioManager.sfx(&"break")
		EventBus.toast.emit("The barrier splits apart!")
		queue_free()
	elif _msg_cooldown <= 0.0:
		_msg_cooldown = 2.0
		var names := ["I: Edge", "II: Swing", "III: Ricochet", "IV: Live Wire", "V"]
		EventBus.toast.emit("The blade sparks off the scrap. (Needs Shard %s)" % names[required_shard - 1])
		Fx.shake(1.5)
		AudioManager.sfx(&"glance")


func _draw() -> void:
	var r := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	draw_texture_rect(WALL, r, true)
	draw_rect(r, Color(0.08, 0.07, 0.09), false, 1.0)
