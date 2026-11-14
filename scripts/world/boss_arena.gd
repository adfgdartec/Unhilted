class_name BossArena
extends Node2D

@export var boss_flag := "boss_intake_defeated"
@export var boss_name := "INTAKE UNIT 7"
@export var trigger_x := 120.0
@export var door_rect := Rect2(0, 272, 16, 48)
@export var boss_path: NodePath = ^"IntakeCrane"
@export_enum("shard", "core_cell", "none") var reward := "shard"
@export var shard_number := 1
@export var shard_position := Vector2(320, 304)
@export var reward_id := ""
@export var victory_text := ""
@export var intro_lines: Array[String] = []

const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")

@onready var boss: Node2D = get_node(boss_path)

var _door: StaticBody2D
var _active := false


func _ready() -> void:
	if GameState.flags.get(boss_flag, false):
		boss.set_wrecked()
		_spawn_shard()
		return
	boss.defeated.connect(_on_defeated)


func _physics_process(_delta: float) -> void:
	if _active or GameState.flags.get(boss_flag, false) or WorldManager.is_busy():
		return
	var p := WorldManager.player
	if p and not p.is_dead and to_local(p.global_position).x > trigger_x:
		_start()


func _start() -> void:
	_active = true
	_close_door()
	EventBus.boss_started.emit(boss_name, int(boss.MAX_HP))
	if not intro_lines.is_empty():
		await DialogueManager.say(intro_lines, boss_name)
	if is_inside_tree():
		boss.start(WorldManager.player)


func _on_defeated() -> void:
	GameState.flags[boss_flag] = true
	_active = false
	if _door:
		_door.queue_free()
		_door = null
	EventBus.boss_ended.emit()
	EventBus.toast.emit(victory_text if victory_text != "" else "%s shuts down." % boss_name)
	_spawn_shard()
	SaveManager.save_game()


func _exit_tree() -> void:
	if _active:
		EventBus.boss_ended.emit()


func _close_door() -> void:
	AudioManager.sfx(&"door")
	_door = StaticBody2D.new()
	_door.collision_layer = 1
	_door.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = door_rect.size
	cs.shape = r
	cs.position = door_rect.get_center()
	_door.add_child(cs)
	var look := Sprite2D.new()
	look.texture = preload("res://art/items/shutter_door.png")
	look.centered = false
	look.position = door_rect.position
	_door.add_child(look)
	add_child.call_deferred(_door)
	Fx.shake(3.0)


func _spawn_shard() -> void:
	if reward == "none":
		return
	if reward == "core_cell":
		if GameState.is_collected(reward_id):
			return
		var cell: Collectible = COLLECTIBLE_SCENE.instantiate()
		cell.kind = Collectible.Kind.CORE_CELL
		cell.amount = 1
		cell.unique_id = reward_id
		cell.position = shard_position
		add_child.call_deferred(cell)
		return
	if GameState.has_shard(shard_number):
		return
	var shard: Collectible = COLLECTIBLE_SCENE.instantiate()
	shard.kind = Collectible.Kind.SHARD
	shard.amount = shard_number
	shard.unique_id = "shard_%d" % shard_number
	shard.position = shard_position
	add_child.call_deferred(shard)
