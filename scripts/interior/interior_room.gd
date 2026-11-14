class_name InteriorRoom
extends Node2D

const PLAYER_SCRIPT := preload("res://scripts/interior/interior_player.gd")
const ZOOM := 2.0
const DOOR_GAP := 30.0

@export var interior_id: StringName = &"interior"
@export var display_name := ""
@export var size := Vector2(224, 128)
@export var wall_height := 64.0
@export var floor_texture: Texture2D
@export var wall_texture: Texture2D
@export var music := "camp"
@export var grade: StringName = &"heap"
@export var ambient := Color(1.0, 0.96, 0.92)
@export var exit_x := 112.0

var camera: Camera2D
var player: CharacterBody2D
var _leaving := false


func _ready() -> void:
	y_sort_enabled = true
	var shell := RoomShell.new()
	shell.room = self
	shell.z_index = -10
	add_child(shell)
	var cm := CanvasModulate.new()
	cm.color = ambient
	add_child(cm)
	_build_collision()
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector2(exit_x, floor_bottom() - 14.0)
	player.visuals.facing = OverworldVisuals.Facing.UP
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	camera.make_current()
	_place_camera()


func floor_bottom() -> float:
	return wall_height + size.y


func _process(_delta: float) -> void:
	_place_camera()
	if not _leaving and player.position.y > floor_bottom() + 6.0:
		_leaving = true
		WorldManager.leave_interior()


func _place_camera() -> void:
	var view := get_viewport_rect().size / ZOOM
	var full := Rect2(-8, -8, size.x + 16, floor_bottom() + 24)
	var target := player.position + Vector2(0, -16)
	var c := Vector2.ZERO
	for axis in 2:
		var lo := full.position[axis] + view[axis] * 0.5
		var hi := full.end[axis] - view[axis] * 0.5
		c[axis] = full.get_center()[axis] if lo > hi else clampf(target[axis], lo, hi)
	camera.position = c.round()


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var W := size.x
	var B := floor_bottom()
	var rects := [
		Rect2(-40, -40, W + 80, wall_height + 44),
		Rect2(-40, 0, 40, B + 40),
		Rect2(W, 0, 40, B + 40),
		Rect2(-40, B, exit_x - DOOR_GAP * 0.5 + 40, 40),
		Rect2(exit_x + DOOR_GAP * 0.5, B, W - exit_x - DOOR_GAP * 0.5 + 40, 40),
	]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)


class RoomShell extends Node2D:
	var room: InteriorRoom

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var W := room.size.x
		var H := room.wall_height
		var B := room.floor_bottom()
		draw_rect(Rect2(-400, -400, W + 800, B + 800), Color(0, 0, 0))
		if room.wall_texture:
			draw_texture_rect(room.wall_texture, Rect2(0, 0, W, H), true)
		if room.floor_texture:
			draw_texture_rect(room.floor_texture, Rect2(0, H, W, room.size.y), true)
		draw_rect(Rect2(0, H, W, 4), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, H + 4, W, 3), Color(0, 0, 0, 0.15))
		draw_rect(Rect2(0, H - 1, W, 1), Color(0, 0, 0, 0.6))
		for x in [-6.0, W]:
			draw_rect(Rect2(x, 0, 6, B), Color8(26, 18, 20))
			draw_rect(Rect2(x, 0, 6, 2), Color8(98, 82, 80))
		var gl := room.exit_x - InteriorRoom.DOOR_GAP * 0.5
		var gr := room.exit_x + InteriorRoom.DOOR_GAP * 0.5
		draw_rect(Rect2(-6, B, gl + 6, 6), Color8(26, 18, 20))
		draw_rect(Rect2(gr, B, W - gr + 6, 6), Color8(26, 18, 20))
		draw_rect(Rect2(-6, B, gl + 6, 1), Color8(98, 82, 80))
		draw_rect(Rect2(gr, B, W - gr + 6, 1), Color8(98, 82, 80))
