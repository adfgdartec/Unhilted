class_name Collectible
extends Area2D
## Anything you pick up by touching it.
##   SCRAP          universal currency (respawns, can be farmed)
##   LOCAL_COIN     this region's currency (Bottlecaps in the Heap) - unique, never respawns
##   QUEST_ITEM     key item for a quest (item_id must match the quest objective)
##   CHIP / COSMETIC / CONSUMABLE / PORT_EXPANSION / CORE_CELL
##   SHARD          a sword shard (amount = shard number); plays its attach dialogue
## Everything except scrap is remembered by unique_id once collected.

enum Kind { SCRAP, LOCAL_COIN, QUEST_ITEM, CHIP, COSMETIC, CONSUMABLE, PORT_EXPANSION, CORE_CELL, SHARD }

@export var kind: Kind = Kind.SCRAP
@export var item_id: StringName
@export var amount := 1
@export var display_name := ""
@export var unique_id := "" ## Leave empty to auto-generate from room + node name.

const ICONS := {
	&"scrap": preload("res://art/items/scrap.png"),
	&"scrap_cache": preload("res://art/items/scrap_cache.png"),
	&"bottlecap": preload("res://art/items/bottlecap.png"),
	&"power_cell": preload("res://art/items/power_cell.png"),
	&"chip": preload("res://art/items/chip.png"),
	&"cosmetic": preload("res://art/items/cosmetic.png"),
	&"repair_kit": preload("res://art/items/repair_kit.png"),
	&"port": preload("res://art/items/port.png"),
	&"core_cell": preload("res://art/items/core_cell.png"),
	&"shard": preload("res://art/items/shard.png"),
	&"letter": preload("res://art/items/letter.png"),
}

var is_lost_cache := false ## The scrap you dropped when you died.
var pop_velocity := Vector2.ZERO
var _t := 0.0
var _player: Player


func _ready() -> void:
	collision_layer = 64 # pickups
	collision_mask = 2   # player body
	if get_child_count() == 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 7.0
		shape.shape = circle
		add_child(shape)
	_t = randf() * TAU
	if kind != Kind.SCRAP and not is_lost_cache:
		if unique_id == "":
			unique_id = "%s/%s" % [owner.room_id if owner is Room else "room", name]
		if GameState.is_collected(unique_id):
			queue_free()
			return
	body_entered.connect(_on_body_entered)
	if kind == Kind.SHARD:
		add_child(Fx.make_light(Color(0.4, 1.0, 1.0), 60.0, 1.1))
	elif kind in [Kind.LOCAL_COIN, Kind.CHIP, Kind.COSMETIC, Kind.QUEST_ITEM, Kind.PORT_EXPANSION, Kind.CORE_CELL]:
		add_child(Fx.make_light(_fx_color(), 22.0, 0.45))


func _physics_process(delta: float) -> void:
	_t += delta
	# Dropped scrap pops out, then settles.
	if pop_velocity != Vector2.ZERO:
		position += pop_velocity * delta
		pop_velocity = pop_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	# Scrap magnet (stat can be boosted by the Magnet Coil chip)
	if kind == Kind.SCRAP:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player")
		if _player and not _player.is_dead:
			var target := _player.global_position + Player.BODY_CENTER
			if global_position.distance_to(target) < _player.stats.get_stat("magnet_radius"):
				global_position = global_position.move_toward(target, 220.0 * delta)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body is Player or body.is_dead:
		return
	match kind:
		Kind.SCRAP, Kind.LOCAL_COIN:
			AudioManager.sfx(&"scrap" if kind == Kind.SCRAP else &"coin", -2.0)
		Kind.SHARD:
			AudioManager.sfx(&"shard")
		_:
			AudioManager.sfx(&"item")
	match kind:
		Kind.SCRAP:
			GameState.add_scrap(amount)
			if is_lost_cache:
				GameState.lost_scrap.clear()
				EventBus.toast.emit("Recovered %d scrap" % amount)
		Kind.LOCAL_COIN:
			GameState.add_local(GameState.current_region, amount, true)
			var region := ItemDB.region(GameState.current_region)
			EventBus.toast.emit("+%d %s" % [amount, region.currency_name if region else "coin"])
		Kind.QUEST_ITEM:
			GameState.add_key_item(item_id)
			EventBus.toast.emit("Found: " + (display_name if display_name != "" else String(item_id)))
		Kind.CHIP:
			GameState.add_chip(item_id)
		Kind.COSMETIC:
			GameState.add_cosmetic(item_id)
		Kind.CONSUMABLE:
			GameState.add_consumable(item_id, amount)
			EventBus.toast.emit("Found: " + (display_name if display_name != "" else String(item_id)))
		Kind.PORT_EXPANSION:
			GameState.add_port()
		Kind.CORE_CELL:
			GameState.add_core_cell()
		Kind.SHARD:
			GameState.give_shard(amount)
			var shard: ShardData = ItemDB.shards.get(StringName("shard_%d" % amount))
			if shard:
				DialogueManager.say(["> FOREIGN COMPONENT DETECTED. ATTACHING...", shard.lore, shard.description], "SYSTEM")
	if unique_id != "" and kind != Kind.SCRAP:
		GameState.mark_collected(unique_id)
	EventBus.item_collected.emit(item_id if item_id != &"" else StringName(Kind.keys()[kind].to_lower()))
	var c := _fx_color()
	if kind == Kind.SCRAP and not is_lost_cache:
		Fx.spark(global_position, c, 3)
	else:
		Fx.spark(global_position, c, 10)
		Fx.ring(global_position, c, 16.0 if kind != Kind.SHARD else 60.0, 0.3 if kind != Kind.SHARD else 0.7)
	queue_free()


func _fx_color() -> Color:
	match kind:
		Kind.LOCAL_COIN: return Color(1.0, 0.65, 0.25)
		Kind.SHARD, Kind.CHIP: return Color(0.4, 1.0, 1.0)
		Kind.CORE_CELL: return Color(1.0, 0.4, 0.4)
		Kind.QUEST_ITEM: return Color(1.0, 0.85, 0.3)
	return Color(0.85, 0.85, 0.9)


func _draw() -> void:
	var bob := Vector2(0, round(sin(_t * 3.0) * 1.5))
	match kind:
		Kind.SCRAP:
			if is_lost_cache:
				_icon(&"scrap_cache", Vector2.ZERO)
				draw_arc(Vector2.ZERO, 9.0 + sin(_t * 4.0), 0.0, TAU, 16, Color(0.22, 0.95, 1.0, 0.7), 1.0)
			else:
				_icon(&"scrap", Vector2.ZERO)
		Kind.LOCAL_COIN:
			var region := ItemDB.region(owner.region_id if owner is Room else &"heap")
			if region and region.coin_icon:
				draw_texture(region.coin_icon, (bob - region.coin_icon.get_size() * 0.5).round())
				_twinkle(bob)
			else:
				_icon(&"bottlecap", bob)
		Kind.QUEST_ITEM:
			_icon(item_id if ICONS.has(item_id) else &"power_cell", bob)
		Kind.CHIP:
			var chip: UpgradeChip = ItemDB.chips.get(item_id)
			_icon(&"chip", bob)
			draw_rect(Rect2(bob + Vector2(-2, -2), Vector2(4, 4)), chip.icon_color if chip else Color.CYAN)
		Kind.COSMETIC:
			var item: CosmeticItem = ItemDB.cosmetics.get(item_id)
			_icon(&"cosmetic", bob, item.color.lightened(0.15) if item else Color.WHITE)
		Kind.CONSUMABLE:
			_icon(&"repair_kit", bob)
		Kind.PORT_EXPANSION:
			_icon(&"port", bob)
		Kind.CORE_CELL:
			_icon(&"core_cell", bob)
		Kind.SHARD:
			var glow := 0.6 + sin(_t * 4.0) * 0.3
			draw_circle(bob, 12.0, Color(0.22, 0.95, 1.0, 0.12 * glow))
			_icon(&"shard", bob)


## A small four-point glint every couple of seconds, so pickups catch the eye.
func _twinkle(offset: Vector2) -> void:
	var t := fmod(_t, 2.4)
	if t > 0.3:
		return
	var a := sin(t / 0.3 * PI)
	var p := offset + Vector2(4, -4)
	var c := Color(1, 1, 1, a)
	draw_line(p + Vector2(-3 * a, 0), p + Vector2(3 * a, 0), c, 1.0)
	draw_line(p + Vector2(0, -3 * a), p + Vector2(0, 3 * a), c, 1.0)


func _icon(icon_name: StringName, offset: Vector2, tint := Color.WHITE) -> void:
	var tex: Texture2D = ICONS[icon_name]
	var size := tex.get_size()
	draw_texture(tex, (offset - size * 0.5).round(), tint)
	if icon_name != &"scrap":
		_twinkle(offset)
