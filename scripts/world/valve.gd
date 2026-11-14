class_name Valve
extends Node2D
## A valve wheel. Hit it (sword, thrown blade, zip) to turn it: open <-> shut.
## Steam vents, turrets and doors can watch it (SteamVent.valve_path,
## ValveTurret.valve_path). Quest valves (quest_item set) count toward a quest
## the first time they're opened, and stay open for good (saved in flags).

signal toggled(open: bool)

const SPRITE := preload("res://art/props/uw_valve.png") # 2 frames: shut, open

@export var is_open := false
@export var quest_item: StringName = &""   ## e.g. &"relief_valve" (Pressure Drop)
@export var one_way := false               ## can only be opened (quest valves are)

var _cool := 0.0
var _spin := 0.0
var _hurtbox: Hurtbox


func _ready() -> void:
	if quest_item != &"":
		one_way = true
		if GameState.flags.get(_flag(), false):
			is_open = true
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16 # hit by the sword and the blade like an enemy
	_hurtbox.collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	cs.shape = c
	cs.position = Vector2(0, -16)
	_hurtbox.add_child(cs)
	add_child(_hurtbox)
	_hurtbox.hit.connect(_on_hit)
	# a valve is a switch, not an enemy: no damage numbers, no aim-assist pull
	_hurtbox.remove_from_group("enemy_hurtbox")


func _flag() -> String:
	var room := get_parent() as Room
	return "valve_%s_%s" % [String(room.room_id) if room else "", name]


func _on_hit(_damage: int, _from: Vector2, _source: Node) -> void:
	if _cool > 0.0:
		return
	if one_way and is_open:
		Fx.spark(global_position + Vector2(0, -16), Color(1.0, 0.85, 0.5), 3)
		return
	_cool = 0.35
	is_open = not is_open
	_spin = 1.0
	AudioManager.sfx(&"valve")
	Fx.spark(global_position + Vector2(0, -16), Color(1.0, 0.85, 0.5), 6)
	Fx.shake(1.0)
	if is_open and quest_item != &"" and not GameState.flags.get(_flag(), false):
		GameState.flags[_flag()] = true
		GameState.add_key_item(quest_item) # counts even if the quest isn't taken yet
		EventBus.item_collected.emit(quest_item)
		EventBus.toast.emit("Relief valve opened. The pipes groan, then settle.")
	toggled.emit(is_open)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	_spin = maxf(_spin - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var fw := SPRITE.get_width() / 2.0
	var src := Rect2(fw if is_open else 0.0, 0, fw, SPRITE.get_height())
	draw_set_transform(Vector2(0, -16), _spin * TAU * 0.25, Vector2.ONE)
	draw_texture_rect_region(SPRITE, Rect2(Vector2(-fw / 2.0, -10), Vector2(fw, 20)), Rect2(src.position, Vector2(fw, 20)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect_region(SPRITE, Rect2(Vector2(-fw / 2.0, -6), Vector2(fw, 6)), Rect2(src.position + Vector2(0, 20), Vector2(fw, 6)))
