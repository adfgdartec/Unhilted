extends Node

var main: Node
var player: Player
var fails := 0
var dbg := false


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func goto(room: String, spawn: StringName) -> void:
	await WorldManager.change_room("res://scenes/rooms/heap/%s.tscn" % room, spawn)
	player.hurtbox.invulnerable = true
	player.health.refill()
	await frames(20)


func place(pos: Vector2) -> void:
	player.hurtbox.invulnerable = true
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await frames(12)


func hop_to(target: Vector2, dash := false) -> bool:
	var jumped := false
	var airborne := 0
	var dashed := false
	for i in 180:
		var dx := target.x - player.global_position.x
		var dir := signf(dx)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 3.0 and dir != 0.0:
			Input.action_press("move_right" if dir > 0 else "move_left")
		var edge_ahead := dir != 0.0 and not player.test_move(player.global_transform.translated(Vector2(dir * 8.0, 0)), Vector2(0, 6))
		if not jumped and player.is_on_floor() and (absf(dx) <= 50.0 or (edge_ahead and absf(dx) < (160.0 if dash else 130.0))):
			Input.action_press("jump")
			jumped = true
			airborne = 0
		await frames(1)
		if dbg and i % 4 == 0:
			print("    dbg f%d pos=%s vel=%s floor=%s jumped=%s" % [i, str(player.global_position.round()), str(player.velocity.round()), player.is_on_floor(), jumped])
		airborne += 1
		if dash and jumped and not dashed and airborne == 12:
			Input.action_press("dash")
			await frames(2)
			Input.action_release("dash")
			dashed = true
		if jumped and airborne > 8 and player.is_on_floor():
			if absf(player.global_position.y - target.y) < 2.0 and absf(dx) < 40.0:
				break
			Input.action_release("jump")
			jumped = false
			dashed = false
			await frames(2)
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	await frames(6)
	return absf(player.global_position.y - target.y) < 2.0 and absf(player.global_position.x - target.x) < 48.0


func leap(land_x: float, land_y: float, mode: String, dir := 1) -> bool:
	var key := "move_right" if dir > 0 else "move_left"
	Input.action_press(key)
	var took_off := false
	for i in 240:
		await frames(1)
		var edge_ahead := player.is_on_floor() and not player.test_move(player.global_transform.translated(Vector2(10 * dir, 0)), Vector2(0, 6))
		if not took_off and mode == "slide" and player.is_on_floor() and player.state_machine.current_name() != "slide":
			if not player.test_move(player.global_transform.translated(Vector2(70 * dir, 0)), Vector2(0, 6)):
				Input.action_press("slide")
		if not took_off and edge_ahead:
			took_off = true
			if mode == "dash":
				player.dash_cooldown.stop()
				Input.action_press("dash")
				await frames(3)
				Input.action_release("dash")
			Input.action_press("jump")
			await frames(4)
			Input.action_release("slide")
		if took_off and player.is_on_floor():
			break
		if player.global_position.y > land_y + 40.0:
			break
	Input.action_release("jump")
	Input.action_release(key)
	Input.action_release("slide")
	await frames(30)
	var past := player.global_position.x >= land_x if dir > 0 else player.global_position.x <= land_x
	return absf(player.global_position.y - land_y) < 2.0 and past


func walk_to(x: float, max_frames := 400) -> void:
	var dir := signf(x - player.global_position.x)
	Input.action_press("move_right" if dir > 0 else "move_left")
	for i in max_frames:
		await frames(1)
		if signf(x - player.global_position.x) != dir or WorldManager.is_busy():
			break
	Input.action_release("move_right")
	Input.action_release("move_left")
	await frames(4)


func reel(hook_name: String) -> bool:
	var hook = WorldManager.current_room.get_node(hook_name)
	player.aim_vector = player.aim_toward(hook.global_position)
	player.throw_blade()
	for i in 30:
		await frames(1)

		if player.blade and player.blade.is_hooked():
			break
	if not (player.blade and player.blade.is_hooked()):
		if dbg:
			print("    reel: not hooked; blade=", player.blade, " mode=", player.blade.mode if player.blade else -1, " pos=", player.blade.global_position if player.blade else Vector2.ZERO)
		return false
	Input.action_press("throw")
	await frames(2)
	Input.action_release("throw")
	await frames(70)
	return player.is_on_floor()


func _run() -> void:
	await get_tree().process_frame
	SaveManager.delete_save()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	player = main.get_node("World/Player")
	main._on_new_game(GameState.Gender.BOY)
	await frames(40)
	var guard := 0
	while DialogueManager.active and guard < 60:
		guard += 1
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true; Input.parse_input_event(ev)
		await frames(2)
		var up := InputEventAction.new(); up.action = "interact"; up.pressed = false; Input.parse_input_event(up)
		await frames(2)
	player.hurtbox.invulnerable = true

	var pit_only := "pit_only" in OS.get_cmdline_user_args()
	if pit_only:
		await _pit_section()
		print("HEAP TEST DONE: %d failure(s)" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return

	var dir := DirAccess.open("res://scenes/rooms/heap")
	var bad_links := []
	var rooms := []
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			rooms.append(f)
	for f in rooms:
		var inst: Room = load("res://scenes/rooms/heap/" + f).instantiate()
		var targets := []
		for n in inst.find_children("*", "", true, false):
			if n is RoomExit or n is BrassDoor:
				targets.append([n.target_room, n.target_spawn])
			elif n is Door:
				if not ResourceLoader.exists(n.interior):
					bad_links.append("%s/%s -> missing interior %s" % [f, n.name, n.interior])
				if inst.get_node_or_null("Spawns/" + String(n.return_spawn)) == null:
					bad_links.append("%s/%s returns to missing spawn %s" % [f, n.name, n.return_spawn])
		for t in targets:
			if not ResourceLoader.exists(t[0]):
				bad_links.append("%s -> missing %s" % [f, t[0]])
				continue
			var dest: Node = load(t[0]).instantiate()
			if dest.get_node_or_null("Spawns/" + String(t[1])) == null:
				bad_links.append("%s -> %s has no spawn %s" % [f, t[0].get_file(), t[1]])
			dest.free()
		inst.free()
	check(bad_links.is_empty(), "every exit leads to a real room and spawn %s" % str(bad_links))
	var floating := []
	for f in rooms:
		var room_id: String = f.get_basename()
		if room_id in ["heap_01_pit", "heap_02_camp", "heap_03_intake"]:
			continue
		var inst: Room = load("res://scenes/rooms/heap/" + f).instantiate()
		var names := []
		for m in inst.get_node("Spawns").get_children():
			names.append(m.name)
		inst.free()
		for sname in names:
			await goto(room_id, StringName(sname))
			var start := player.global_position
			await frames(50)
			var ok := player.is_on_floor()
			if not ok:
				floating.append("%s/%s %s" % [room_id, sname, str(start)])
	check(floating.is_empty(), "every spawn point lands on solid ground %s" % str(floating))

	await _pit_section()

	await goto("heap_05_fields", &"from_camp")
	await place(Vector2(1150, 432))
	var path := [Vector2(1210, 392), Vector2(1270, 352), Vector2(1330, 312), Vector2(1390, 272),
		Vector2(1326, 232), Vector2(1390, 192), Vector2(1326, 152), Vector2(1390, 112), Vector2(1326, 72), Vector2(1390, 32)]
	var ok := true
	for t in path:
		if not await hop_to(t):
			ok = false
			print("  fields climb stopped at ", player.global_position, " heading for ", t)
			break
	check(ok, "Scrap Fields: the hill and crane mast climb with plain jumps")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	await frames(30)
	check(WorldManager.current_room.room_id == &"heap_07_crane", "jumping off the top of the mast reaches the Crane Yard")

	await goto("heap_07_crane", &"from_fields")
	await place(Vector2(210, 568))
	var hooks_ok: bool = await reel("Hook1")
	hooks_ok = hooks_ok and absf(player.global_position.y - 512.0) < 2.0
	if hooks_ok:
		await place(Vector2(350, 512))
		hooks_ok = await reel("Hook2") and absf(player.global_position.y - 442.0) < 2.0
	if hooks_ok:
		await place(Vector2(468, 442))
		hooks_ok = await reel("Hook3") and absf(player.global_position.y - 372.0) < 2.0
	if not hooks_ok:
		print("  crane hooks stopped at ", player.global_position)
	check(hooks_ok, "Crane Yard: hook to hook to hook over the spikes")
	check(await hop_to(Vector2(610, 336)), "Crane Yard: jump from the last girder to the landing")
	await walk_to(760)
	await frames(30)
	check(WorldManager.current_room.room_id == &"heap_08_conveyor", "the landing leads into Conveyor Hall")

	await goto("heap_08_conveyor", &"from_crane")
	await place(Vector2(560, 336))
	await walk_to(1100, 600)
	check(player.global_position.x > 1080.0, "Conveyor Hall: you can push up the belt under the crushers (x=%.0f)" % player.global_position.x)
	await place(Vector2(330, 336))
	ok = true
	for t in [Vector2(370, 296), Vector2(494, 256), Vector2(430, 216), Vector2(494, 176), Vector2(430, 136), Vector2(494, 96)]:
		if not await hop_to(t):
			ok = false
			print("  ladder stopped at ", player.global_position, " heading for ", t)
			break
	check(ok, "Conveyor Hall: the service ladder climbs to the top")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	await frames(30)
	check(WorldManager.current_room.room_id == &"heap_12_compactor", "the ladder leads up into the Compactor Pit")

	await goto("heap_12_compactor", &"from_conveyor")
	var arena: ArenaWaves = WorldManager.current_room.get_node("Arena")
	await walk_to(450)
	await frames(10)
	check(arena.is_active(), "walking in starts the arena and seals the hatch")
	var waves_seen := 0
	for i in 900:
		await frames(1)
		var enemies := []
		for n in WorldManager.current_room.get_children():
			if n is EnemyBase or n is ScrapDrone:
				enemies.append(n)
		for e in enemies:
			e.health.damage(99) if e.has_method("_tick") else e.health.damage(99)
		if arena._wave > waves_seen:
			waves_seen = arena._wave
		if not arena.is_active():
			break
	check(not arena.is_active() and waves_seen >= 2, "clearing all three waves ends the arena")
	await frames(10)
	var reward := WorldManager.current_room.get_node_or_null("ArenaReward")
	check(reward != null, "the arena reward appears")
	if reward:
		await place(reward.global_position + Vector2(0, 10))
		await frames(20)
	check(&"piston_heart" in GameState.owned_chips, "picked up the Piston Heart chip")

	await goto("heap_10_sinkhole", &"from_seep")
	ok = true
	var y := 656
	var i := 0
	while y >= 56:
		var t := Vector2(194 if i % 2 == 0 else 130, y)
		if WorldManager.current_room.room_id != &"heap_10_sinkhole":
			break
		if not await hop_to(t):
			ok = false
			print("  sinkhole stopped at ", player.global_position, " heading for ", t)
			break
		y -= 40
		i += 1
	ok = ok or WorldManager.current_room.room_id == &"heap_05_fields"
	check(ok, "Sinkhole: the ledges climb all the way up")
	Input.action_press("jump")
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(30)
	check(WorldManager.current_room.room_id == &"heap_05_fields", "the top of the sinkhole comes out in the fields")

	await goto("heap_04_seep", &"from_sinkhole")
	var comp_node := WorldManager.current_room.get_node_or_null("Compactor")
	if comp_node:
		comp_node.queue_free()
	GameState.shards[0] = false
	var hp_before := player.health.current
	ok = true
	for leg in [[2420.0, Vector2(2085, 276), true], [1505.0, Vector2(1395, 276), false], [1120.0, Vector2(785, 276), true], [515.0, Vector2(405, 276), false]]:
		var t: Vector2 = leg[1]
		var need_dash: bool = leg[2]
		await walk_to(leg[0])
		var crossed: bool = (await leap(t.x, t.y, "dash", -1)) if need_dash else (await hop_to(t))
		if not crossed:
			ok = false
			print("  seep stopped at ", player.global_position, " heading for ", t)
			break
	if player.health.current != hp_before:
		print("  seep: health %d -> %d" % [hp_before, player.health.current])
	check(ok and player.health.current == hp_before, "Seep Tunnels: every sludge pit can be cleared (two with a dash-jump)")

	await goto("heap_02b_undercamp", &"from_camp")
	var door: BrassDoor = WorldManager.current_room.get_node("BrassDoor")
	await place(Vector2(690, 176))
	await frames(10)
	check(not door.is_open(), "without Shard I the brass door stays shut")
	GameState.give_shard(1)
	await frames(10)
	check(door.is_open(), "with Shard I it rolls aside when you come near")
	await walk_to(760)
	await frames(40)
	check(WorldManager.current_room.room_id == &"heap_13_gate", "through the brass door: the Underworks Gate")
	await place(Vector2(400, 336))
	await walk_to(530)
	await frames(40)
	check(WorldManager.current_room.room_id == &"uw_01_descent", "the stairs at the bottom of the Gate lead down into the Underworks")
	await goto("heap_02b_undercamp", &"from_gate")

	await place(Vector2(150, 320))
	var hatch = WorldManager.current_room.get_node_or_null("SeepHatch")
	if hatch:
		hatch._hurtbox.take_hit(1, hatch.global_position)
	await frames(60)
	check(WorldManager.current_room.room_id == &"heap_04_seep", "Shard I breaks the Hollow floor hatch and drops you into the Seep")
	await frames(30)
	check(WorldManager.current_room.get_node_or_null("ShaftGate") == null, "the same shaft is open from below too")

	await goto("heap_01_pit", &"from_camp")
	await place(Vector2(520, 456))
	var pit_wall = WorldManager.current_room.get_node_or_null("ScrapWall")
	if pit_wall:
		pit_wall._hurtbox.take_hit(1, pit_wall.global_position)
	await frames(5)
	await walk_to(455, 120)
	check(&"scrap_plating" in GameState.owned_chips, "Shard I opens the chimney alcove: Scrap Plating chip")

	await goto("heap_09_giant", &"from_fields")
	var head: BrassHead = WorldManager.current_room.get_node("BrassHead")
	await place(Vector2(250, 432))
	await frames(10)
	check(head.state != BrassHead.S.SLEEP, "the brass head wakes when you walk in")
	var closed_hit := head._hurt.take_hit(2, player.global_position)
	check(not closed_hit, "its eye can't be hurt while shut")
	var saw_open := false
	for k in 900:
		await frames(1)
		if not head._hurt.invulnerable and head.state != BrassHead.S.DEAD:
			saw_open = true
			head._hurt.take_hit(2, player.global_position)
		if head.state == BrassHead.S.DEAD:
			break
	check(saw_open and head.state == BrassHead.S.DEAD, "hitting the open eye brings it down")
	await frames(10)
	var port := false
	for n in WorldManager.current_room.get_children():
		if n is Collectible and n.kind == Collectible.Kind.PORT_EXPANSION:
			port = true
	check(port and GameState.flags.get("giant_defeated", false), "it drops a port expansion and stays defeated")

	print("\nHEAP TEST DONE: %d failure(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _pit_section() -> void:
	await goto("heap_01_pit", &"wake")
	await place(Vector2(80, 656))
	var near_drones := 0
	for e in WorldManager.current_room.get_children():
		if e is Node2D and (String(e.name).begins_with("Drone") or String(e.name).begins_with("Spotter")):
			if (e as Node2D).global_position.distance_to(Vector2(80, 656)) < 300.0:
				near_drones += 1
	check(near_drones == 0, "no enemy can reach the robot while it wakes up (%d nearby)" % near_drones)
	var tunnel_ok: bool = await hop_to(Vector2(330, 624))
	tunnel_ok = tunnel_ok and await hop_to(Vector2(452, 624))
	check(tunnel_ok, "Under the Heap: up the step and over the spike pit with plain jumps")
	check(&"long_tether" in GameState.owned_chips, "the Long Tether chip lies on the way")
	var climb := [Vector2(520, 616), Vector2(630, 576), Vector2(520, 536), Vector2(630, 496), Vector2(520, 456),
		Vector2(630, 416), Vector2(520, 376), Vector2(630, 336)]
	var climb_ok := true
	for t in climb:
		if not await hop_to(t):
			climb_ok = false
			print("  chimney climb stopped at ", player.global_position, " heading for ", t)
			break
	check(climb_ok, "Under the Heap: the chimney girders climb with plain jumps")
	var on_hump: bool = await hop_to(Vector2(744, 320))
	check(on_hump and GameState.key_item_count(&"power_cell") == 1, "the upper tunnel's hump has Tinker's power cell")
	check(await hop_to(Vector2(880, 336)), "on to the edge of the dash gap")
	var spotter_node := WorldManager.current_room.get_node_or_null("Spotter1")
	if spotter_node:
		spotter_node.queue_free()
	await place(Vector2(800, 336))
	var plain_ok: bool = await leap(1072.0, 336.0, "jump")
	check(not plain_ok, "the 176 px spike gap can't be cleared with a running jump")
	await place(Vector2(800, 336))
	check(await leap(1072.0, 336.0, "slide"), "...a slide-jump clears it")
	await place(Vector2(800, 336))
	check(await leap(1072.0, 336.0, "dash"), "...and so does a dash-jump")
	await place(Vector2(1130, 336))
	check(not await hop_to(Vector2(1190, 256)), "the wall is too tall to jump")
	await place(Vector2(1130, 336))
	var hooked: bool = await reel("HookTutorial")
	check(hooked and absf(player.global_position.y - 256.0) < 2.0, "throwing at the hook and reeling in lands on the wall top (y=%.0f)" % player.global_position.y)
	await walk_to(1300)
	await frames(30)
	check(WorldManager.current_room.room_id == &"heap_02_camp", "the tunnel comes out in the camp")
	await goto("heap_01_pit", &"from_camp")
	await place(Vector2(630, 496))
	await walk_to(690)
	check(&"shirt_hazard_vest" in GameState.owned_cosmetics, "the vest nook opens off a chimney girder")
	await place(Vector2(520, 456))
	await walk_to(450, 60)
	check(player.global_position.x > 500.0, "the scrap wall blocks the alcove without Shard I")
