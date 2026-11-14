class_name ArenaWaves
extends Node2D
## A sealed combat room. Walk into the trigger and the exits slam shut;
## clear every wave to reopen them and earn the reward. Cleared for good.
## waves: one String per wave, "type@x,type@x" with type = compactor,
## rustcrawler, drone (the Heap), piston_walker, clock_spider, bellows_bat,
## boiler_bloat (the Underworks); spawned on the floor at that x, or at y
## when given as "type@x:y".

@export var trigger := Rect2(0, 0, 100, 100)
@export var seals: Array[Rect2] = []
@export var waves: Array[String] = []
@export var floor_y := 336.0
@export var reward_kind := 3        ## Collectible.Kind (3 = chip)
@export var reward_id: StringName = &""
@export var reward_pos := Vector2.ZERO
@export var arena_id := ""

const COLLECTIBLE := preload("res://scenes/world/collectible.tscn")
const DRONE := preload("res://scenes/enemies/scrap_drone.tscn")

var _active := false
var _wave := -1
var _alive: Array[Node] = []
var _seal_bodies: Array[Node] = []
var _gap := 0.0


func _ready() -> void:
	if arena_id == "":
		arena_id = "%s/%s" % [owner.room_id if owner is Room else "room", name]
	if GameState.is_collected(arena_id):
		set_physics_process(false)
		_spawn_reward()
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = trigger.size
	cs.shape = r
	cs.position = trigger.position + trigger.size * 0.5
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b is Player and not _active and _wave < 0: _start.call_deferred())


func is_active() -> bool:
	return _active


func _start() -> void:
	_active = true
	AudioManager.sfx(&"horn")
	AudioManager.set_override("boss")
	for r in seals:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)
		add_child(body)
		_seal_bodies.append(body)
		Fx.dust(r.position + Vector2(r.size.x * 0.5, r.size.y), 1.2)
	AudioManager.sfx(&"door")
	queue_redraw()
	_next_wave()


func _next_wave() -> void:
	_wave += 1
	if _wave >= waves.size():
		_finish()
		return
	for entry in waves[_wave].split(",", false):
		var parts := entry.strip_edges().split("@")
		var kind := parts[0]
		var where := parts[1].split(":") if parts.size() > 1 else PackedStringArray(["0"])
		var pos := Vector2(float(where[0]), float(where[1]) if where.size() > 1 else floor_y)
		var e: Node2D
		match kind:
			"compactor": e = Compactor.new()
			"rustcrawler":
				e = Rustcrawler.new()
				e.start_on_ceiling = where.size() > 1
			"piston_walker": e = PistonWalker.new()
			"clock_spider": e = ClockSpider.new()
			"bellows_bat": e = BellowsBat.new()
			"boiler_bloat": e = BoilerBloat.new()
			_: e = DRONE.instantiate()
		get_parent().add_child(e)
		e.global_position = to_global(pos)
		Fx.ring(e.global_position + Vector2(0, -10), Color(1.0, 0.5, 0.3), 20.0, 0.3)
		_alive.append(e)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_alive = _alive.filter(func(n): return is_instance_valid(n) and n.is_inside_tree())
	if _alive.is_empty():
		_gap += delta
		if _gap > 0.8:
			_gap = 0.0
			_next_wave()


func _finish() -> void:
	_active = false
	GameState.mark_collected(arena_id)
	AudioManager.set_override("")
	AudioManager.sfx(&"door")
	for b in _seal_bodies:
		b.queue_free()
	_seal_bodies.clear()
	EventBus.toast.emit("Arena cleared!")
	_spawn_reward()
	queue_redraw()


func _spawn_reward() -> void:
	if reward_id == &"" or reward_pos == Vector2.ZERO:
		return
	var c: Collectible = COLLECTIBLE.instantiate()
	c.name = "ArenaReward"
	c.kind = reward_kind
	c.item_id = reward_id
	c.unique_id = arena_id + "/reward"
	c.position = position + reward_pos
	get_parent().add_child.call_deferred(c)


func _draw() -> void:
	if not _active:
		return
	for r in seals:  # shutters
		draw_rect(r, Color8(74, 34, 28))
		var y := r.position.y
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color8(160, 78, 52), 1.0)
			y += 6.0
