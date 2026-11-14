class_name BrassDoor
extends Node2D
## The sealed brass door in the Hollow. Closed (and readable) until the robot
## carries Shard I; then, the first time you come near, it rolls aside in a
## burst of steam and stays open, leading down to the Underworks Gate.
## The node's position is the bottom-centre of the door.

@export_file("*.tscn") var target_room := ""
@export var target_spawn: StringName = &"from_hollow"

const CLOSED := preload("res://art/props/brass_door.png")
const OPEN := preload("res://art/props/brass_door_open.png")

var _open := false
var _reader: Readable
var _exit: RoomExit


func _ready() -> void:
	z_index = -1
	_open = GameState.has_shard(1) and bool(GameState.flags.get("brass_door_open", false))
	var glow := Fx.make_light(Color(0.22, 0.95, 1.0) if not _open else Color(1.0, 0.75, 0.45), 70.0, 0.7)
	glow.position = Vector2(0, -32)
	glow.name = "Glow"
	add_child(glow)
	_reader = Readable.new()
	_reader.prompt = "Inspect"
	_reader.title = "SEALED DOOR"
	_reader.lore_id = "brass_door"
	_reader.size = Vector2(40, 40)
	_reader.lines = [
		"> A round door of brass, older than anything in the Heap. Warm to the touch.",
		"> Gears behind it turn, very slowly, all by themselves. Somewhere far below, steam hisses.",
		"> The lock is a socket shaped like a blade shard. You only have the one, and it's in your hilt.",
		"> Not yet."]
	add_child(_reader)
	_exit = RoomExit.new()
	_exit.target_room = target_room
	_exit.target_spawn = target_spawn
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 40)
	cs.shape = r
	cs.position = Vector2(0, -20)
	_exit.add_child(cs)
	add_child(_exit)
	_apply()


func _apply() -> void:
	_reader.monitoring = not _open
	_reader.visible = not _open
	_exit.monitoring = _open
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _open or not GameState.has_shard(1):
		return
	var p := WorldManager.player
	if p and p.global_position.distance_to(global_position) < 110.0:
		_open_now()


func _open_now() -> void:
	_open = true
	GameState.flags["brass_door_open"] = true
	AudioManager.sfx(&"steam_door")
	Fx.shake(5.0)
	for k in 3:
		Fx.dust(global_position + Vector2(-24 + k * 24, 0), 1.6)
	Fx.ring(global_position + Vector2(0, -32), Color(1.0, 0.8, 0.5), 50.0, 0.6, 3.0)
	EventBus.toast.emit("The brass door answers your shard.")
	var glow: PointLight2D = get_node("Glow")
	glow.color = Color(1.0, 0.75, 0.45)
	glow.energy = 1.2
	_apply()


func is_open() -> bool:
	return _open


func _draw() -> void:
	var tex := OPEN if _open else CLOSED
	draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
