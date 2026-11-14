class_name DemoMode
extends CanvasLayer

const START_ROOM := GameState.START_ROOM
const START_SPAWN := GameState.START_SPAWN
const ROUTE := [&"heap_01_pit", &"heap_02_camp", &"heap_05_fields", &"heap_07_crane", &"heap_08_conveyor", &"heap_03_intake"]
const IDLE_RESET := 45.0

signal run_finished

var running := false
var _idle := 0.0
var _since_shard := 0.0
var _card: Control
var falls := 0
const PADS_PER_ROOM := 3


static func enabled() -> bool:
	return OS.has_feature("demo") or "demo" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.player_died.connect(func(): if running: falls += 1)


func prepare_state() -> void:
	GameState.reset()
	GameState.give_starting_items()
	GameState.respawn_room = START_ROOM
	GameState.respawn_spawn = START_SPAWN


func start_run() -> void:
	falls = 0
	_idle = 0.0
	_since_shard = 0.0
	running = true
	if WorldManager.current_room:
		_on_room_entered(WorldManager.current_room.room_id)


func stop() -> void:
	running = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_idle = 0.0


func _process(delta: float) -> void:
	if not running:
		return
	if not GameState.is_ui_locked():
		_idle += delta
	if _idle > IDLE_RESET and not DialogueManager.active:
		stop()
		run_finished.emit()
	elif GameState.has_shard(1):
		_since_shard += delta
		if _since_shard > 0.5 and not DialogueManager.active:
			_finish()


func _on_room_entered(room_id: StringName) -> void:
	if not running:
		return
	GameState.respawn_room = GameState.current_room
	GameState.respawn_spawn = WorldManager.last_spawn
	_shut_side_exits()
	_close_walls()
	_place_pads.call_deferred()


const DEMO_WALLS := {
	&"heap_01_pit": [Rect2(656, 448, 48, 48)],
}

func _close_walls() -> void:
	var room := WorldManager.current_room
	if room == null or not DEMO_WALLS.has(room.room_id):
		return
	var body := room.get_node_or_null("Solids") as StaticBody2D
	for r: Rect2 in DEMO_WALLS[room.room_id]:
		if r in room.solids:
			continue
		room.solids.append(r)
		var st: PackedStringArray = room.solid_styles
		while st.size() < room.solids.size() - 1:
			st.append("rock")
		st.append("rock")
		room.solid_styles = st
		if body:
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = r.size
			cs.shape = rs
			cs.position = r.get_center()
			body.add_child(cs)
	room.queue_redraw()


func _place_pads() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var room := WorldManager.current_room
	if room == null or room.room_id in [&"heap_01_pit", &"heap_03_intake"]:
		return
	var b: Rect2 = room.bounds
	var space := room.get_world_2d().direct_space_state
	var surfaces := []
	var x := b.position.x + 40.0
	while x < b.end.x - 40.0:
		var y := b.position.y + 2.0
		for guard in 12:
			var q := PhysicsRayQueryParameters2D.create(room.to_global(Vector2(x, y)), room.to_global(Vector2(x, b.end.y)), 1)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var sy: float = room.to_local(hit.position).y
			if sy > b.position.y + 40.0 and _clear(space, room, Vector2(x, sy), 46.0):
				surfaces.append(Vector2(x, sy))
			y = sy + 10.0
		x += 8.0
	var reach := _reachable_air(space, room, b)
	var exits := room.find_children("*", "RoomExit", true, false)
	var picked: Array[Vector2] = []
	surfaces = surfaces.filter(func(sf): return reach.has(Vector2i(int(sf.x) / CELL, int(sf.y - 4.0) / CELL)))
	for s in surfaces:
		if picked.size() >= PADS_PER_ROOM:
			break
		var useful := false
		for t in surfaces:
			var dx: float = absf(t.x - s.x)
			var dy: float = s.y - t.y
			if dx >= 20.0 and dx <= 90.0 and dy >= 62.0 and dy <= 105.0:
				useful = true
				break
		if not useful or not _clear(space, room, s, 120.0):
			continue
		var ok := true
		for p in picked:
			if absf(p.x - s.x) < 160.0:
				ok = false
		for ex in exits:
			if room.to_local((ex as Node2D).global_position).distance_to(s) < 70.0:
				ok = false
		if ok:
			picked.append(s)
	for p in picked:
		var pad := BouncePad.new()
		pad.position = p
		room.add_child(pad)


const CELL := 8

func _reachable_air(space: PhysicsDirectSpaceState2D, room: Node2D, b: Rect2) -> Dictionary:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var x0 := int(b.position.x) / CELL
	var y0 := int(b.position.y) / CELL
	var x1 := int(b.end.x) / CELL
	var y1 := int(b.end.y) / CELL
	var solid := {}
	var is_air := func(c: Vector2i) -> bool:
		if c.x < x0 or c.x >= x1 or c.y < y0 or c.y >= y1:
			return false
		if not solid.has(c):
			q.position = room.to_global(Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5))
			solid[c] = not space.intersect_point(q, 1).is_empty()
		return not solid[c]
	var seen := {}
	var todo: Array[Vector2i] = []
	for m in room.find_children("*", "Marker2D", true, false):
		var mp := room.to_local((m as Node2D).global_position)
		var c := Vector2i(int(mp.x) / CELL, int(mp.y - 12.0) / CELL)
		if is_air.call(c) and not seen.has(c):
			seen[c] = true
			todo.append(c)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and is_air.call(n):
				seen[n] = true
				todo.append(n)
	return seen


func _clear(space: PhysicsDirectSpaceState2D, room: Node2D, at: Vector2, height: float) -> bool:
	for k in range(1, 5):
		var q := PhysicsPointQueryParameters2D.new()
		q.position = room.to_global(at + Vector2(0, -height * k / 4.0))
		q.collision_mask = 1
		for side in [-8.0, 8.0]:
			q.position = room.to_global(at + Vector2(side, -height * k / 4.0))
			if not space.intersect_point(q, 1).is_empty():
				return false
	return true


func _shut_side_exits() -> void:
	var room := WorldManager.current_room
	for ex in room.find_children("*", "RoomExit", true, false):
		var target := StringName((ex as RoomExit).target_room.get_file().get_basename())
		if target in ROUTE:
			continue
		ex.set_deferred("monitoring", false)
		var wall := StaticBody2D.new()
		wall.name = "DemoBlock_" + ex.name
		wall.collision_layer = 1
		wall.collision_mask = 0
		for c in ex.get_children():
			if c is CollisionShape2D:
				var cs := CollisionShape2D.new()
				cs.shape = c.shape
				cs.position = c.position
				wall.add_child(cs)
		wall.position = ex.position
		room.add_child.call_deferred(wall)


func _finish() -> void:
	stop()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = true
	await _end_card()
	get_tree().paused = false
	run_finished.emit()


func _fall_line() -> String:
	if falls == 0:
		return "Nothing knocked you down for good. You never fell."
	return "Knocked down %d time%s. Got back up %d time%s." % [falls, "" if falls == 1 else "s", falls, "" if falls == 1 else "s"]


func _rebounds() -> int:
	return WorldManager.player.rebounds_landed if WorldManager.player else 0


func _end_card() -> void:
	_card = ColorRect.new()
	(_card as ColorRect).color = Color(0.02, 0.02, 0.03, 0.0)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_card)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_card.add_child(box)
	var lines := [
		["END OF DEMO", 8, UIKit.QUIET],
		["UNHILTED", 32, UIKit.CYAN],
		["BOUNCING BACK", 16, UIKit.AMBER],
		[_fall_line(), 8, UIKit.TEXT],
		["Rebound Strikes: %d" % _rebounds(), 8, UIKit.QUIET],
		["Thrown away. Knocked down. Back up again.  Thanks for playing.", 8, UIKit.QUIET],
	]
	for l in lines:
		var lab := UIKit.label(l[0], mini(l[1], 16), l[2])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if l[1] > 16:
			lab.add_theme_font_size_override("font_size", l[1])
		box.add_child(lab)
	var tw := create_tween()
	tw.tween_property(_card, "color:a", 0.92, 0.8)
	await get_tree().create_timer(6.0, true).timeout
	_card.queue_free()
