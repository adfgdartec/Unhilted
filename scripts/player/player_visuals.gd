class_name PlayerVisuals
extends Node2D

const LAYER_ORDER := ["cloak_back", "blade_back", "body", "pants", "shoes", "shirt", "arm", "cloak_front", "face", "hood", "mask", "blade"]
const BODY_PATHS := ["res://art/character/frames/body_boy.tres", "res://art/character/frames/body_girl.tres"]
const SHARED := {
	"arm": "res://art/character/frames/arm.tres",
	"face": "res://art/character/frames/face.tres",
	"blade": "res://art/character/frames/blade.tres",
	"blade_back": "res://art/character/frames/blade_back.tres",
}
const FEET_OFFSET := Vector2(0, -40)
const SPRITE_SCALE := 0.5
const SLOT_LAYERS := {
	CosmeticItem.Slot.HOOD: ["hood"],
	CosmeticItem.Slot.MASK: ["mask"],
	CosmeticItem.Slot.CLOAK: ["cloak_back", "cloak_front"],
	CosmeticItem.Slot.SHIRT: ["shirt"],
	CosmeticItem.Slot.PANTS: ["pants"],
	CosmeticItem.Slot.SHOES: ["shoes"],
}
@export var body_frames: Array[SpriteFrames] = [null, null]

@export var preview := false
@export var preview_gender: GameState.Gender = GameState.Gender.BOY

var sway := 0.0
var blade_in_hand := true

var anim := "idle"
var _time := 0.0
var _land_squash := 0.0
var _pop := -1.0
var _gender: int = GameState.Gender.BOY
var _colors: Dictionary = {}
var _layers: Dictionary = {}

const STEEL := Color(0.55, 0.6, 0.66)
const STEEL_DARK := Color(0.32, 0.36, 0.42)
const SCREEN := Color(0.04, 0.05, 0.08)
const GLOW := Color("38f2ff")


func _ready() -> void:
	for i in BODY_PATHS.size():
		if (i >= body_frames.size() or body_frames[i] == null) and ResourceLoader.exists(BODY_PATHS[i]):
			if body_frames.size() <= i:
				body_frames.resize(i + 1)
			body_frames[i] = load(BODY_PATHS[i])
	for layer_name in LAYER_ORDER:
		var sprite := AnimatedSprite2D.new()
		sprite.name = layer_name
		sprite.centered = true
		sprite.offset = FEET_OFFSET
		sprite.scale = Vector2.ONE * SPRITE_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers[layer_name] = sprite
	if not preview:
		EventBus.cosmetics_changed.connect(refresh)
	refresh()


func refresh(outfit_override: Variant = null) -> void:
	_gender = preview_gender if preview else GameState.gender
	var outfit: Dictionary = outfit_override if outfit_override is Dictionary else GameState.outfit
	_colors.clear()
	for layer_name in _layers:
		_layers[layer_name].sprite_frames = null
	_layers["body"].sprite_frames = body_frames[_gender] if _gender < body_frames.size() else null
	if _layers["body"].sprite_frames:
		for layer_name in SHARED:
			if ResourceLoader.exists(SHARED[layer_name]):
				_layers[layer_name].sprite_frames = load(SHARED[layer_name])
	for slot in outfit:
		var item: CosmeticItem = ItemDB.cosmetics.get(outfit[slot])
		if item == null:
			continue
		_colors[int(slot)] = [item.color, item.accent]
		if int(slot) == CosmeticItem.Slot.CLOAK:
			_layers["cloak_front"].sprite_frames = item.sprite_frames
			_layers["cloak_back"].sprite_frames = item.sprite_frames_back
		else:
			for layer_name in SLOT_LAYERS.get(int(slot), []):
				_layers[layer_name].sprite_frames = item.sprite_frames
	_sync_sprites()
	queue_redraw()


func play(anim_name: String) -> void:
	if anim == anim_name:
		return
	anim = anim_name
	_time = 0.0
	_sync_sprites()


func land() -> void:
	_land_squash = 1.0


func respawn_pop() -> void:
	_pop = 0.0


func _sync_sprites() -> void:
	for sprite: AnimatedSprite2D in _layers.values():
		sprite.visible = sprite.sprite_frames != null
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			sprite.frame = 0


func freeze_frame(anim_name: String, frame_index: int) -> void:
	anim = anim_name
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.animation = anim_name
			sprite.frame = mini(frame_index, sprite.sprite_frames.get_frame_count(anim_name) - 1)
			sprite.pause()


func current_frame() -> int:
	return _layers["body"].frame if _layers.has("body") else 0


func _uses_real_art() -> bool:
	return _layers.has("body") and _layers["body"].sprite_frames != null


func _process(delta: float) -> void:
	_time += delta
	_land_squash = move_toward(_land_squash, 0.0, delta * 6.0)
	if not _uses_real_art():
		queue_redraw()
		return
	var sq := Vector2(1.0 + _land_squash * 0.12, 1.0 - _land_squash * 0.14)
	if _pop >= 0.0:
		_pop += delta
		var t := _pop / 0.7
		var s := 1.0 - cos(t * PI * 2.5) * exp(-t * 3.5) * 0.45
		sq *= Vector2(clampf(2.0 - s, 0.7, 1.4), s)
		if t >= 1.0:
			_pop = -1.0
	for sprite: AnimatedSprite2D in _layers.values():
		sprite.scale = sq * SPRITE_SCALE
	_layers["blade"].visible = blade_in_hand and _layers["blade"].sprite_frames != null
	if not preview:
		var want := clampf(sway, -1.0, 1.0) * (0.07 if anim == "run" else 0.03)
		if anim in ["dead", "hurt", "wall", "slide"]:
			want = 0.0
		rotation = lerpf(rotation, want, 1.0 - exp(-delta * 10.0))
		if anim == "jump":
			for sprite: AnimatedSprite2D in _layers.values():
				sprite.scale *= Vector2(0.96, 1.05)


func _draw() -> void:
	if _uses_real_art():
		return
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var bob := 0.0
	var leg := 0.0
	match anim:
		"idle":
			bob = sin(_time * 3.0) * 0.6
		"run":
			leg = sin(_time * 16.0) * 3.0
			bob = -absf(sin(_time * 16.0)) * 1.2
		"jump":
			sy = 1.12; sx = 0.9
		"fall":
			sy = 1.05; leg = 2.0
		"dash":
			sx = 1.25; sy = 0.82
		"attack", "attack_up", "attack_down":
			rot = 0.12 if anim == "attack" else 0.0
		"hurt":
			rot = -0.25
		"dead":
			rot = -PI / 2.0; bob = 4.0
	sy -= _land_squash * 0.18
	sx += _land_squash * 0.15
	draw_set_transform(Vector2(0, bob), rot, Vector2(sx, sy))

	var cloak: Array = _colors.get(CosmeticItem.Slot.CLOAK, [])
	var trail := clampf(-absf(sway) * 6.0, -6.0, 0.0) - (4.0 if anim == "dash" else 0.0)

	if not cloak.is_empty():
		var flutter := sin(_time * 7.0) * 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, -27), Vector2(6, -27), Vector2(5 + trail * 0.3, -6),
			Vector2(-9 + trail + flutter, -4), Vector2(-10 + trail, -14)]), cloak[1])

	var narrow := 1.0 if _gender == GameState.Gender.GIRL else 0.0
	draw_rect(Rect2(-4 + leg * 0.5, -8, 3, 8), STEEL_DARK)
	draw_rect(Rect2(1 - leg * 0.5, -8, 3, 8), STEEL_DARK)
	draw_rect(Rect2(-5 + narrow, -22, 10 - narrow * 2.0, 14), STEEL)
	draw_rect(Rect2(-3 + narrow, -19, 6 - narrow * 2.0, 3), STEEL_DARK)
	draw_circle(Vector2(0, -16), 1.5, GLOW * Color(1, 1, 1, 0.8))

	var pants: Array = _colors.get(CosmeticItem.Slot.PANTS, [])
	if not pants.is_empty():
		draw_rect(Rect2(-5, -10, 10, 4), pants[0])
		draw_rect(Rect2(-5 + leg * 0.5, -7, 4, 5), pants[0])
		draw_rect(Rect2(1 - leg * 0.5, -7, 4, 5), pants[0])
		draw_rect(Rect2(-5, -10, 10, 1), pants[1])

	var shoes: Array = _colors.get(CosmeticItem.Slot.SHOES, [])
	var shoe_col: Color = shoes[0] if not shoes.is_empty() else STEEL_DARK.darkened(0.3)
	draw_rect(Rect2(-5 + leg * 0.5, -2, 5, 2), shoe_col)
	draw_rect(Rect2(1 - leg * 0.5, -2, 5, 2), shoe_col)

	var shirt: Array = _colors.get(CosmeticItem.Slot.SHIRT, [])
	if not shirt.is_empty():
		draw_rect(Rect2(-5 + narrow, -22, 10 - narrow * 2.0, 11), shirt[0])
		draw_rect(Rect2(-5 + narrow, -18, 10 - narrow * 2.0, 1), shirt[1])

	if not cloak.is_empty():
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7, -27), Vector2(7, -27), Vector2(6, -19), Vector2(-7, -18)]), cloak[0])

	if blade_in_hand and anim != "dead":
		var hand := Vector2(6, -14)
		var tip := hand + (Vector2(4, -12) if anim == "attack_up" else Vector2(10, 4) if anim == "attack_down" else Vector2(9, -6))
		draw_line(hand, tip, GLOW, 2.0)
		draw_line(hand, tip, Color.WHITE, 1.0)

	if _gender == GameState.Gender.GIRL:
		draw_line(Vector2(-5, -30), Vector2(-9, -22 + sin(_time * 4.0)), STEEL_DARK, 2.0)
		draw_circle(Vector2(-9, -22 + sin(_time * 4.0)), 1.5, GLOW)

	var hood: Array = _colors.get(CosmeticItem.Slot.HOOD, [])
	if not hood.is_empty():
		var tip_sway := trail * 0.6 + sin(_time * 5.0) * 0.8
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8, -24), Vector2(-8, -32), Vector2(-3, -37), Vector2(4, -37),
			Vector2(8, -32), Vector2(8, -25), Vector2(4, -23), Vector2(-4, -23)]), hood[0])
		draw_colored_polygon(PackedVector2Array([
			Vector2(-3, -37), Vector2(-15 + tip_sway, -33), Vector2(-7, -30)]), hood[0])
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8, -27), Vector2(-8, -24), Vector2(-4, -23), Vector2(-6, -27)]), hood[1])

	var face_center := Vector2(1, -29)
	draw_circle(face_center, 5.5, SCREEN)
	var blink := fmod(_time + 0.3, 3.2) < 0.12
	var eye_h := 1.0 if blink else 3.0
	var eye_col := Color(1, 0.3, 0.3) if anim == "hurt" else GLOW
	if anim != "dead":
		draw_rect(Rect2(face_center.x - 2.5, face_center.y - eye_h * 0.5, 1.5, eye_h), eye_col)
		draw_rect(Rect2(face_center.x + 1.5, face_center.y - eye_h * 0.5, 1.5, eye_h), eye_col)

	var mask: Array = _colors.get(CosmeticItem.Slot.MASK, [])
	if not mask.is_empty():
		draw_circle(face_center, 5.0, mask[0])
		draw_rect(Rect2(face_center.x - 3, face_center.y - 1, 6, 1.5), mask[1])
		draw_rect(Rect2(face_center.x - 2.5, face_center.y - 1, 1.5, 1.5), eye_col)
		draw_rect(Rect2(face_center.x + 1.0, face_center.y - 1, 1.5, 1.5), eye_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
