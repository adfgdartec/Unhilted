extends Node
## Loads/unloads handmade room scenes, places the player at a spawn marker
## and plays the fade between rooms. Also handles respawning after death.

var room_container: Node2D
var player: Player
var current_room: Room
var ambient: CanvasModulate ## registered by Main
## The walk-in building the robot is inside (null when outdoors). The outdoor
## room stays loaded but hidden and paused while you're in here.
var interior: InteriorRoom
var _interior_return: StringName = &""

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func register(container: Node2D, p: Player) -> void:
	room_container = container
	player = p


func is_busy() -> bool:
	return _busy


## room_path is a scene file like "res://scenes/rooms/heap/heap_02_camp.tscn".
## spawn is the name of a Marker2D inside that room's "Spawns" node.
var last_spawn: StringName = &"" ## the spawn marker the player arrived at in the current room

func change_room(room_path: String, spawn: StringName, fade := true) -> void:
	if _busy:
		return
	_busy = true
	GameState.lock_ui()
	if fade:
		await _fade_to(1.0, 0.2)

	if current_room:
		room_container.remove_child(current_room)
		current_room.queue_free()
		current_room = null
	player.reset_for_room()

	last_spawn = spawn
	var scene: PackedScene = load(room_path)
	current_room = scene.instantiate()
	room_container.add_child(current_room)
	GameState.current_room = room_path
	GameState.current_region = current_room.region_id
	if ambient:
		ambient.color = current_room.ambient
	if Fx.post:
		Fx.post.set_grade(current_room.grade)
	AudioManager.music(current_room.music)

	player.global_position = current_room.get_spawn(spawn)
	player.last_safe = player.global_position
	player.velocity = Vector2.ZERO
	player.apply_camera_limits(current_room.bounds)
	GameState.visited_rooms[String(current_room.room_id)] = true
	EventBus.room_entered.emit(current_room.room_id)
	var region_flag := "entered_region_" + String(current_room.region_id)
	if not GameState.flags.get(region_flag, false):
		GameState.flags[region_flag] = true
		var region := ItemDB.region(current_room.region_id)
		if region and current_room.region_id != &"heap": # the Heap opens with its own wake-up scene
			EventBus.region_title.emit(region.display_name.to_upper(), current_room.display_name)
	EventBus.currency_changed.emit() # HUD swaps to this region's local currency
	SaveManager.save_game()

	if fade:
		await _fade_to(0.0, 0.25)
	GameState.unlock_ui()
	_busy = false


## Go into a walk-in building. The current room and the 2D robot are hidden and
## paused (not freed), so coming back out is instant and nothing outside resets.
func enter_interior(path: String, return_spawn: StringName) -> void:
	if _busy or interior:
		return
	_busy = true
	GameState.lock_ui()
	EventBus.interact_prompt.emit("")
	await _fade_to(1.0, 0.2)
	var world := room_container.get_parent() as Node2D
	world.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_interior_return = return_spawn
	interior = (load(path) as PackedScene).instantiate()
	world.get_parent().add_child(interior)
	AudioManager.music(interior.music)
	if Fx.post:
		Fx.post.set_grade(interior.grade)
	EventBus.interior_entered.emit(interior.interior_id)
	await _fade_to(0.0, 0.25)
	GameState.unlock_ui()
	_busy = false


## Walk back out to the door you came in by.
func leave_interior() -> void:
	if _busy or interior == null:
		return
	_busy = true
	GameState.lock_ui()
	EventBus.interact_prompt.emit("")
	AudioManager.sfx(&"door", -6.0)
	await _fade_to(1.0, 0.2)
	clear_interior()
	if current_room:
		player.global_position = current_room.get_spawn(_interior_return)
		player.velocity = Vector2.ZERO
		player.last_safe = player.global_position
		player.camera.reset_smoothing()
		AudioManager.music(current_room.music)
		if Fx.post:
			Fx.post.set_grade(current_room.grade)
	await _fade_to(0.0, 0.25)
	GameState.unlock_ui()
	_busy = false


## Remove the interior (if any) and bring the outdoor world back.
func clear_interior() -> void:
	if interior:
		interior.queue_free()
		interior = null
	var world := room_container.get_parent() as Node2D
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	if player and player.camera:
		player.camera.make_current()


func in_interior() -> bool:
	return interior != null


func respawn() -> void:
	await change_room(GameState.respawn_room, GameState.respawn_spawn)
	player.revive()


func fade_out() -> void:
	await _fade_to(1.0, 0.3)

func fade_in() -> void:
	await _fade_to(0.0, 0.3)


func _fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, time)
	tween.set_trans(Tween.TRANS_SINE)
	await tween.finished
