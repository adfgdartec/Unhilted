class_name BreakableFloor
extends StaticBody2D

@export var size := Vector2(40, 12)
@export var hits := 3
@export var break_id := ""

const TEX := preload("res://art/props/hatch.png")

var _hurtbox: Hurtbox
var _hp := 3
var _shake := 0.0


func _ready() -> void:
	if break_id == "":
		break_id = "%s/%s" % [owner.room_id if owner is Room else "room", name]
	if GameState.is_collected(break_id):
		queue_free()
		return
	_hp = hits
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, size.y / 2.0)
	add_child(shape)
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	var hshape := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = size + Vector2(0, 8)
	hshape.shape = hrect
	hshape.position = Vector2(0, size.y / 2.0 - 4.0)
	_hurtbox.add_child(hshape)
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		queue_redraw()


func _on_hit(_damage: int, _from: Vector2, _source: Node) -> void:
	_hp -= 1
	_shake = 1.0
	AudioManager.sfx(&"break" if _hp <= 0 else &"hit", -2.0)
	Fx.spark(global_position + Vector2(0, 2), Color(1.0, 0.8, 0.5), 5)
	Fx.shake(1.5)
	queue_redraw()
	if _hp <= 0:
		GameState.mark_collected(break_id)
		Fx.burst(global_position + Vector2(0, 4), Color(0.7, 0.5, 0.35), 26)
		Fx.dust(global_position, 1.4)
		Fx.shake(4.0)
		EventBus.toast.emit("The old hatch gives way!")
		queue_free()


func _draw() -> void:
	var jitter := Vector2(randf_range(-1, 1) * _shake, 0).round()
	var stage := clampi(hits - _hp, 0, 2)
	var fw := TEX.get_width() / 3
	draw_texture_rect_region(TEX, Rect2(Vector2(-fw / 2.0, 0) + jitter, Vector2(fw, TEX.get_height())), Rect2(stage * fw, 0, fw, TEX.get_height()))
