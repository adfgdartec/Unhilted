extends Node

@onready var room_container: Node2D = $World/RoomContainer
@onready var player: Player = $World/Player
@onready var hud: CanvasLayer = $HUD
@onready var game_ui: CanvasLayer = $GameUI
@onready var title: CanvasLayer = $TitleScreen
var demo: DemoMode = null

const DEMO_INTRO_LINES := [
	"> ...",
	"> CORE TEMPERATURE: NOMINAL.  DORMANCY: 2,000 YEARS, 4 MONTHS.",
	"> LOCATION: THE HEAP.  STATUS: DISCARDED.",
	"> Something is still gripped in your hand. A hilt. A wire hums inside it, glowing.",
	"> DIRECTIVE RECOVERED: GET BACK UP.",
	"> (Every hit you take charges a REBOUND STRIKE. Scrap springs bounce you higher.)",
]
const ELDER_LINES := [
	"Easy. Easy now. Don't try to stand all at once.",
	"You're under the Heap. Whatever the world up there throws away ends up down here. So did you.",
	"Two thousand years. That's how long since anything stirred in that casing. I kept count, scratch by scratch, on these old glasses.",
	"...We've been waiting for one like you for a long time.",
	"Go on. Up and to the right, there's a camp. And if you hear the crane's horn, keep moving.",
]
const INTRO_LINES := [
	"> ...",
	"> CORE TEMPERATURE: NOMINAL.  DORMANCY: 2,000 YEARS, 4 MONTHS.",
	"> LOCATION: UNKNOWN.  SURROUNDINGS: ...GARBAGE?",
	"> Something is still gripped in your hand. A hilt. A wire hums inside it, glowing.",
	"> PRIMARY OBJECTIVE: [DATA CORRUPTED]",
]


func _ready() -> void:
	get_tree().root.theme = UIKit.theme()
	Input.set_custom_mouse_cursor(load("res://art/ui/cursor.png"), Input.CURSOR_ARROW, Vector2(9, 9))
	WorldManager.register(room_container, player)
	var modulate_node := CanvasModulate.new()
	modulate_node.name = "Ambient"
	modulate_node.color = Color(0.62, 0.6, 0.74)
	$World.add_child(modulate_node)
	WorldManager.ambient = modulate_node
	var post := PostFX.new()
	post.name = "PostFX"
	add_child(post)
	Fx.post = post
	title.new_game_requested.connect(_on_new_game)
	title.continue_requested.connect(_on_continue)
	if DemoMode.enabled():
		demo = DemoMode.new()
		demo.name = "Demo"
		add_child(demo)
		demo.run_finished.connect(_on_quit_to_title)
		title.demo_run_requested.connect(_on_demo_run)
	game_ui.quit_to_title.connect(_on_quit_to_title)
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		Fx.toggle_fullscreen()


func _show_title() -> void:
	WorldManager.ambient.color = Color.WHITE
	player.hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	hud.hide()
	if demo:
		title.show_demo_title()
	else:
		title.show_title(SaveManager.has_save())
	AudioManager.music("title")


func _on_new_game(gender: int) -> void:
	SaveManager.delete_save()
	GameState.reset()
	GameState.gender = gender as GameState.Gender
	GameState.give_starting_items()
	await _begin(GameState.START_ROOM, GameState.START_SPAWN)
	await DialogueManager.say(INTRO_LINES, "SYSTEM")
	await DialogueManager.say(ELDER_LINES, "TRASH COLLECTOR")
	EventBus.toast.emit("Move: WASD   Jump: Space   Attack: Right click   Throw: hold Left click + flick   Dash: Shift")


func _on_demo_run() -> void:
	demo.prepare_state()
	await _begin(DemoMode.START_ROOM, DemoMode.START_SPAWN)
	demo.start_run()
	await DialogueManager.say(DEMO_INTRO_LINES, "SYSTEM")
	await DialogueManager.say(ELDER_LINES, "TRASH COLLECTOR")
	EventBus.toast.emit(Keybinds.summary(Fx.control_preset, Fx.custom_binds).replace("\n", "   "))


func _on_continue() -> void:
	if not SaveManager.load_game():
		_show_title()
		return
	await _begin(GameState.respawn_room, GameState.respawn_spawn)


func _begin(room_path: String, spawn: StringName) -> void:
	title.hide()
	player.show()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.on_game_started()
	hud.show()
	hud.refresh_all()
	await WorldManager.change_room(room_path, spawn)
	hud.refresh_all()


func _on_quit_to_title() -> void:
	if demo:
		demo.stop()
		get_tree().paused = false
		if game_ui.is_open():
			game_ui.close()
		if DialogueManager.active:
			DialogueManager._close()
	else:
		SaveManager.save_game()
	await WorldManager.fade_out()
	WorldManager.clear_interior()
	if WorldManager.current_room:
		WorldManager.current_room.queue_free()
		WorldManager.current_room = null
	player.reset_for_room()
	_show_title()
	await WorldManager.fade_in()
