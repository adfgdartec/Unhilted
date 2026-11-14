class_name OverworldVisuals
extends Node2D
## The robot seen from above for walk-in buildings (Undertale style): front,
## back and side walking sprites for both chassis and every outfit piece, from
## tools/art/build_overworld.py. Each layer is a 4x3 sheet of 48x48 frames:
## rows down / up / side (left is the side row mirrored), columns stand, step,
## stand, step. Feet sit at this node's origin.

const ORDER := ["cloak_back", "body", "pants", "shoes", "shirt", "cloak_front", "face", "hood", "mask"]
const DIR := "res://art/overworld/"
const FEET_Y := 44

enum Facing { DOWN, UP, SIDE }

var facing := Facing.DOWN
var flip := false
var walking := false
var _t := 0.0
var _layers := {}  ## layer name -> Sprite2D


func _ready() -> void:
	for n in ORDER:
		var s := Sprite2D.new()
		s.name = n
		s.hframes = 4
		s.vframes = 3
		s.centered = true
		s.offset = Vector2(0, 24 - FEET_Y)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_layers[n] = s
	EventBus.cosmetics_changed.connect(refresh)
	refresh()


## Re-reads the chassis and outfit from GameState.
func refresh() -> void:
	for s: Sprite2D in _layers.values():
		s.texture = null
	_layers["body"].texture = _tex("body_girl" if GameState.gender == GameState.Gender.GIRL else "body_boy")
	_layers["face"].texture = _tex("face")
	for slot in GameState.outfit:
		var id := String(GameState.outfit[slot])
		if id == "":
			continue
		match int(slot):
			CosmeticItem.Slot.HOOD: _layers["hood"].texture = _tex(id)
			CosmeticItem.Slot.MASK: _layers["mask"].texture = _tex(id)
			CosmeticItem.Slot.SHIRT: _layers["shirt"].texture = _tex(id)
			CosmeticItem.Slot.PANTS: _layers["pants"].texture = _tex(id)
			CosmeticItem.Slot.SHOES: _layers["shoes"].texture = _tex(id)
			CosmeticItem.Slot.CLOAK:
				_layers["cloak_back"].texture = _tex(id + "_back")
				_layers["cloak_front"].texture = _tex(id + "_front")


func _tex(name: String) -> Texture2D:
	var path := DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


func layer_texture(n: String) -> Texture2D:
	return _layers[n].texture if _layers.has(n) else null


func _process(delta: float) -> void:
	_t = _t + delta if walking else 0.0
	var col := int(_t * 7.0) % 4 if walking else 0
	for s: Sprite2D in _layers.values():
		s.frame = int(facing) * 4 + col
		s.flip_h = flip and facing == Facing.SIDE
