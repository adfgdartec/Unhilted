extends Node
## Level playthrough test for the Underworks. Run:
##   godot --headless --path . res://tools/underworks_test.tscn
## Checks every exit/spawn link, then has a bot walk the critical path (vent
## lifts, pistons, gear wheels, the stairs of the Falls, the boiling pit),
## exercises each gimmick and enemy, beats the Lamplighter and the Great
## Governor, picks up Shard II, swings across the Swing Galleries, and runs
## the three quests, the shops and the map.

var main: Node
var player: Player
var fails := 0
var dbg := false
var _titles: Array = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func room() -> Room:
	return WorldManager.current_room


func goto(room_id: String, spawn: StringName) -> void:
	var folder := "underworks" if room_id.begins_with("uw_") else "heap"
	for i in 180: # a transition already under way would make change_room ignore this one
		if not WorldManager.is_busy():
			break
		await frames(1)
	await WorldManager.change_room("res://scenes/rooms/%s/%s.tscn" % [folder, room_id], spawn)
	player.hurtbox.invulnerable = true
	player.health.refill()
	await frames(20)
	await _skip_dialogue() # a boss intro started by spawning past its trigger line


func place(pos: Vector2) -> void:
	player.hurtbox.invulnerable = true
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await frames(12)


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "dash", "slide", "throw", "aim_up", "aim_down"]:
		Input.action_release(a)


## Running jump onto a point ~10 px inside a platform's near edge.
func hop_to(target: Vector2) -> bool:
	var jumped := false
	var airborne := 0
	for i in 200:
		var dx := target.x - player.global_position.x
		var dir := signf(dx)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 3.0 and dir != 0.0:
			Input.action_press("move_right" if dir > 0 else "move_left")
		var edge_ahead := dir != 0.0 and not player.test_move(player.global_transform.translated(Vector2(dir * 8.0, 0)), Vector2(0, 6))
		# a short step down: just walk off; a gap (even downward) still needs a jump
		var below := target.y > player.global_position.y + 4.0 and absf(dx) < 70.0
		if not jumped and player.is_on_floor() and not below and (absf(dx) <= 50.0 or (edge_ahead and absf(dx) < 150.0)):
			Input.action_press("jump")
			jumped = true
			airborne = 0
		await frames(1)
		airborne += 1
		if dbg and i % 6 == 0:
			print("    dbg pos=%s vel=%s floor=%s" % [str(player.global_position.round()), str(player.velocity.round()), player.is_on_floor()])
		if player.is_on_floor() and absf(player.global_position.y - target.y) < 2.0 and absf(dx) < 30.0:
			break
		if jumped and airborne > 8 and player.is_on_floor():
			Input.action_release("jump")
			jumped = false
			await frames(2)
	release_all()
	await frames(6)
	return absf(player.global_position.y - target.y) < 2.0 and absf(player.global_position.x - target.x) < 40.0


func walk_to(x: float, max_frames := 500) -> void:
	var dir := signf(x - player.global_position.x)
	Input.action_press("move_right" if dir > 0 else "move_left")
	for i in max_frames:
		await frames(1)
		if signf(x - player.global_position.x) != dir or WorldManager.is_busy():
			break
	release_all()
	await frames(4)


## Walk toward an exit until the room changes.
func walk_out(x: float, max_frames := 600) -> String:
	var start := room().room_id
	var dir := signf(x - player.global_position.x)
	Input.action_press("move_right" if dir > 0 else "move_left")
	for i in max_frames:
		await frames(1)
		if dbg and i % 20 == 0:
			print("    walk_out dbg room=%s pos=%s vel=%s st=%s busy=%s" % [room().room_id, str(player.global_position.round()), str(player.velocity.round()), player.state_machine.current_name(), WorldManager.is_busy()])
		if WorldManager.is_busy() or room().room_id != start:
			break
		# hop small lips on the way
		if player.is_on_floor() and player.is_on_wall():
			Input.action_press("jump")
			await frames(2)
			Input.action_release("jump")
	release_all()
	for i in 90:
		await frames(1)
		if not WorldManager.is_busy() and room().room_id != start:
			break
	await frames(10)
	return String(room().room_id)


## Wait until the robot stands still on the ground (or time runs out).
func settle(max_frames := 240) -> void:
	for i in max_frames:
		await frames(1)
		if player.is_on_floor() and absf(player.velocity.y) < 1.0:
			break
	await frames(4)


func _hit(node: Node, from: Vector2) -> bool:
	var hb: Hurtbox = null
	for c in node.get_children():
		if c is Hurtbox:
			hb = c
	return hb != null and hb.take_hit(1, from, player)


## Swing across a gap: jump off the edge, throw at the ring at the top of the
## jump, hang (throw again), pump toward the target, and jump off when moving
## up and past the ring. True if it lands on the target platform.
func swing_across(ring_name: String, land: Vector2, dir := 1, release_past := 40.0, jump_x := NAN) -> bool:
	var ring = room().get_node(ring_name)
	var key := "move_right" if dir > 0 else "move_left"
	Input.action_press(key)
	# run to the edge and jump
	for i in 180:
		await frames(1)
		var edge := player.is_on_floor() and not player.test_move(player.global_transform.translated(Vector2(10 * dir, 0)), Vector2(0, 6))
		if not is_nan(jump_x):
			edge = (player.global_position.x - jump_x) * dir >= 0.0
		if edge:
			break
	Input.action_press("jump")
	var rising := false
	for i in 50:
		await frames(1)
		rising = rising or player.velocity.y < -50.0
		if rising and player.velocity.y >= -20.0:
			break
	Input.action_release("jump")
	if dbg:
		print("    swing throw from ", player.global_position.round(), " vel ", player.velocity.round(), " st ", player.state_machine.current_name(), " dist ", int(player.blade_anchor.global_position.distance_to(ring.global_position)))
	player.aim_vector = player.aim_toward(ring.global_position)
	player.throw_blade()
	var hooked := false
	for i in 30:
		await frames(1)
		if player.blade and player.blade.is_hooked():
			hooked = true
			break
	if not hooked:
		if dbg:
			print("    swing: ring not hooked from ", player.global_position)
		release_all()
		return false
	Input.action_press("throw")
	await frames(2)
	Input.action_release("throw")
	await frames(1)
	var swung := player.state_machine.current_name() == "swing"
	var released := false
	for i in 240:
		await frames(1)
		var st := player.state_machine.current_name()
		if dbg and i % 5 == 0:
			print("    swing dbg st=%s pos=%s vel=%s" % [st, str(player.global_position.round()), str(player.velocity.round())])
		if st == "swing":
			var past: bool = (player.global_position.x - ring.global_position.x) * dir > release_past
			if past and player.velocity.y < -40.0:
				Input.action_press("jump")
				await frames(3)
				Input.action_release("jump")
				released = true
		elif released:
			# in the air after letting go: steer for the landing like a player would
			Input.action_release("move_left")
			Input.action_release("move_right")
			var to := land.x - player.global_position.x
			if absf(to) > 6.0:
				Input.action_press("move_right" if to > 0.0 else "move_left")
			if player.is_on_floor():
				break
	release_all()
	await frames(20)
	if dbg:
		print("    swing end: swung=%s released=%s pos=%s" % [swung, released, str(player.global_position.round())])
	return swung and absf(player.global_position.y - land.y) < 2.0 and (player.global_position.x - land.x) * dir > -30.0


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
		await _advance_dialogue()
	EventBus.region_title.connect(func(t, s): _titles.append([t, s]))
	player.hurtbox.invulnerable = true
	GameState.give_shard(1) # the Underworks comes after the Heap

	# run one section alone:  -- only=galleries  (add  dbg  for bot traces)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
		if arg == "dbg":
			dbg = true
	if only != "":
		GameState.give_shard(2)
		match only:
			"gate": await _descent_and_market()
			"row": await goto("uw_03_row", &"from_market"); await _row_and_works()
			"gear": await goto("uw_05_gearworks", &"from_works"); await _gearworks_and_falls()
			"enemies": await _enemies()
			"gauge": await goto("uw_08_gauge", &"from_falls"); await _gauge_and_approach()
			"governor": await _governor()
			"lamp": await _lamplighter()
			"galleries": await goto("uw_11_galleries", &"from_governor"); await _galleries()
			"side": await _side_rooms()
		print("\nUNDERWORKS TEST DONE: %d failure(s)" % fails)
		get_tree().quit(1 if fails else 0)
		return

	await _links()
	if dbg:
		print("    after links: room=", room().room_id, " busy=", WorldManager.is_busy(), " locked=", GameState.is_ui_locked(), " dialogue=", DialogueManager.active)
	await _descent_and_market()
	await _row_and_works()
	await _gearworks_and_falls()
	await _gauge_and_approach()
	await _enemies()
	await _lamplighter()
	await _governor()
	await _galleries()
	await _side_rooms()
	await _town()

	print("\nUNDERWORKS TEST DONE: %d failure(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _advance_dialogue() -> void:
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true; Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new(); up.action = "interact"; up.pressed = false; Input.parse_input_event(up)
	await frames(2)


func _skip_dialogue() -> void:
	var guard := 0
	while DialogueManager.active and guard < 80:
		guard += 1
		await _advance_dialogue()


# ------------------------------------------------------------------ 1. links
func _links() -> void:
	var dir := DirAccess.open("res://scenes/rooms/underworks")
	var rooms := []
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			rooms.append(f)
	check(rooms.size() == 15, "15 Underworks rooms exist (%d)" % rooms.size())
	var bad := []
	for f in rooms + ["../heap/heap_13_gate.tscn"]:
		var inst: Room = load("res://scenes/rooms/underworks/" + f).instantiate()
		for n in inst.find_children("*", "", true, false):
			if n is RoomExit:
				if not ResourceLoader.exists(n.target_room):
					bad.append("%s -> missing %s" % [f, n.target_room])
					continue
				var dest: Node = load(n.target_room).instantiate()
				if dest.get_node_or_null("Spawns/" + String(n.target_spawn)) == null:
					bad.append("%s -> %s has no spawn %s" % [f, n.target_room.get_file(), n.target_spawn])
				dest.free()
			elif n is Door:
				if not ResourceLoader.exists(n.interior):
					bad.append("%s/%s -> missing interior %s" % [f, n.name, n.interior])
				if inst.get_node_or_null("Spawns/" + String(n.return_spawn)) == null:
					bad.append("%s/%s returns to missing spawn %s" % [f, n.name, n.return_spawn])
		inst.free()
	check(bad.is_empty(), "every Underworks exit and door leads somewhere real %s" % str(bad))
	var floating := []
	for f in rooms:
		var room_id: String = f.get_basename()
		var inst: Room = load("res://scenes/rooms/underworks/" + f).instantiate()
		var names := []
		for m in inst.get_node("Spawns").get_children():
			names.append(m.name)
		var region := inst.region_id
		inst.free()
		if region != &"underworks":
			floating.append("%s has region %s" % [room_id, region])
		for sname in names:
			await goto(room_id, StringName(sname))
			await frames(40)
			if not player.is_on_floor():
				floating.append("%s/%s %s" % [room_id, sname, str(player.global_position.round())])
	check(floating.is_empty(), "every Underworks spawn stands on solid ground %s" % str(floating))


# ------------------------------------------------------------------ 2. Descent and Market
func _descent_and_market() -> void:
	GameState.flags.erase("entered_region_underworks")
	_titles.clear()
	await goto("heap_13_gate", &"from_hollow")
	await place(Vector2(400, 336))
	check(await walk_out(540) == "uw_01_descent", "the Gate's stairs lead down into the Descent")
	await frames(10)
	check(_titles.size() == 1 and _titles[0][0] == "THE UNDERWORKS", "a title card announces the Underworks the first time %s" % str(_titles))
	check(GameState.current_region == &"underworks", "the HUD switches to the Underworks' currency (Brass Cogs)")
	# down the iron stair to the market
	var ok := true
	for i in range(6):
		if not await hop_to(Vector2(152 + 64 * i, 200 + 40 * i)):
			ok = false
			print("  stair stopped at ", player.global_position)
			break
	check(ok, "Descent: down the iron stair a step at a time")
	await hop_to(Vector2(560, 440))
	# the vent lift up to the alcove cog
	var cogs := GameState.get_balance(&"underworks")
	Input.action_press("move_right")
	var top := 999.0
	for i in 120:
		await frames(1)
		top = minf(top, player.global_position.y)
		if player.global_position.y < 260.0:
			# steer over the ledge, then stop pushing
			Input.action_release("move_right")
			if player.global_position.x > 512.0:
				Input.action_press("move_left")
			else:
				Input.action_release("move_left")
	release_all()
	await settle()
	check(top < 120.0, "Descent: the steam vent throws the robot up the shaft (top y %d)" % int(top))
	if dbg:
		print("    alcove end pos ", player.global_position, " cogs ", GameState.get_balance(&"underworks") - cogs)
	check(GameState.get_balance(&"underworks") > cogs and absf(player.global_position.y - 170.0) < 2.0, "...onto the alcove ledge, and the cog there is a Brass Cog")
	await place(Vector2(560, 440))
	check(await walk_out(650) == "uw_02_market", "Descent -> Pipe Market")
	# swing-only ring: without Shard II the blade skates off
	await place(Vector2(1290, 352))
	var ring = room().get_node("SwingRing")
	Input.action_press("jump")
	await frames(10)
	Input.action_release("jump")
	var reach_ok := player.blade_anchor.global_position.distance_to(ring.global_position) < player.stats.get_stat("wire_length")
	player.aim_vector = player.aim_toward(ring.global_position) # aim is re-read every frame: set it right before the throw
	player.throw_blade()
	var hooked := false
	for i in 30:
		await frames(1)
		if dbg and player.blade and i % 3 == 0:
			print("    ring dbg blade ", player.blade.global_position.round(), " mode ", player.blade.mode, " ring ", ring.global_position, " player ", player.global_position.round())
		if player.blade and player.blade.is_hooked():
			hooked = true
	if GameState.has_shard(2):
		check(hooked, "(with Shard II the same throw hooks the ring)")
	else:
		check(reach_ok and not hooked, "Pipe Market: the brass swing ring (in reach) won't take the blade without Shard II")
	await frames(60)
	await settle()
	await place(Vector2(1450, 352))
	check(await walk_out(1620) == "uw_03_row", "Pipe Market -> Bellows Row")


# ------------------------------------------------------------------ 3. Bellows Row and Boiler Works
func _row_and_works() -> void:
	# the roofs: crate, three roofs, the relief valve
	var path := [Vector2(360, 312), Vector2(440, 270), Vector2(580, 230)]
	var ok := true
	for t in path:
		if not await hop_to(t):
			ok = false
			print("  roof climb stopped at ", player.global_position, " for ", t)
			break
	check(ok, "Bellows Row: up a crate and over the roofs, clear of the scalding vents")
	var valve: Valve = room().get_node("ReliefValve")
	_hit(valve, player.global_position)
	await frames(5)
	check(valve.is_open and GameState.key_item_count(&"relief_valve") == 1, "hitting a relief valve turns it (1 of 3, even before the quest)")
	var vent: SteamVent = room().get_node("ScaldVent0")
	var seen_on := false
	var seen_off := false
	for i in 200:
		await frames(1)
		seen_on = seen_on or vent.is_on()
		seen_off = seen_off or not vent.is_on()
	check(seen_on and seen_off, "the street's scalding vents run on a rhythm")
	await place(Vector2(1150, 352))
	check(await walk_out(1300) == "uw_04_works", "Bellows Row -> Boiler Works")
	# the turret valve shuts the turret off for good
	var turret: ValveTurret = room().get_node("Turret")
	_hit(room().get_node("TurretValve"), player.global_position)
	await frames(5)
	check(turret.state == ValveTurret.S.DEAD_PRESSURE, "opening the floor valve bleeds the turret's pressure")
	# piston lifts
	var lift: Piston = room().get_node("LiftA")
	while lift._phase() > 0.1:
		await frames(1)
	await place(Vector2(420, 420))
	var low := player.global_position.y
	var high := low
	for i in 100:
		await frames(1)
		high = minf(high, player.global_position.y)
	check(low - high > 100.0, "the first piston lifts the robot %d px" % int(low - high))
	ok = await hop_to(Vector2(500, 280))
	check(ok, "...up to the catwalk")
	_hit(room().get_node("ReliefValve"), player.global_position)
	await frames(5)
	check(GameState.key_item_count(&"relief_valve") == 2, "relief valve 2 of 3 (Boiler Works)")
	var lift_b: Piston = room().get_node("LiftB")
	while lift_b._phase() > 0.1:
		await frames(1)
	await place(Vector2(650, 262))
	for i in 70:
		await frames(1)
	ok = await hop_to(Vector2(780, 200))
	check(ok, "the second piston lifts it to the high ledge")
	check(await walk_out(980) == "uw_05_gearworks", "Boiler Works -> Gearworks (high exit)")


# ------------------------------------------------------------------ 4. Gearworks and Condensate Falls
func _gearworks_and_falls() -> void:
	var gear: GearWheel = room().get_node("GearA")
	# stand on a platform and ride it
	var p0: Vector2 = gear.global_position + gear.platform_position(0)
	await place(p0 + Vector2(0, -4))
	await frames(10)
	var on_start := player.is_on_floor()
	var start := player.global_position
	for i in 45:
		await frames(1)
	var p1: Vector2 = gear.global_position + gear.platform_position(0)
	check(on_start and player.is_on_floor() and player.global_position.distance_to(p1 + Vector2(0, -3)) < 8.0 and player.global_position.distance_to(start) > 10.0,
		"a gear wheel's platform carries the robot round with it")
	await place(Vector2(740, 300))
	Input.action_press("move_right")
	var top := 999.0
	for i in 100:
		await frames(1)
		top = minf(top, player.global_position.y)
		if player.global_position.y < 100.0:
			Input.action_press("move_right")
	release_all()
	await settle()
	check(absf(player.global_position.y - 120.0) < 2.0, "Gearworks: the vent lifts the robot up to the Gallery ledge")
	await place(Vector2(880, 300))
	check(await walk_out(980) == "uw_07_falls", "Gearworks -> Condensate Falls")
	# down the stair of grates, past the falls, to the valve and on to the hall
	await place(Vector2(50, 120))
	var ok := true
	for i in range(5):
		if not await hop_to(Vector2(160 + 80 * i, 160 + 40 * i)):
			ok = false
			print("  falls stair stopped at ", player.global_position)
			break
	ok = ok and await hop_to(Vector2(570, 360))
	check(ok, "Condensate Falls: down the stair of grates")
	var valves := GameState.key_item_count(&"relief_valve")
	_hit(room().get_node("ReliefValve"), player.global_position)
	await frames(5)
	check(GameState.key_item_count(&"relief_valve") == valves + 1, "relief valve 3 of 3 (the Falls)")
	# the Cistern side isn't a dead end: a ladder of grates back up to the entry
	await place(Vector2(100, 400))
	ok = true
	for t in [Vector2(40, 360), Vector2(110, 320), Vector2(40, 280), Vector2(110, 240), Vector2(40, 200), Vector2(110, 168), Vector2(170, 160), Vector2(60, 120)]:
		if not await hop_to(t):
			ok = false
			print("  falls ladder stopped at ", player.global_position, " for ", t)
			break
	check(ok, "Falls: from the Cistern side, up the ladder of grates to the entry")
	await place(Vector2(580, 360))
	check(await walk_out(660) == "uw_08_gauge", "Condensate Falls -> Pressure Gauge Hall")


# ------------------------------------------------------------------ 5. Gauge Hall and the Approach
func _gauge_and_approach() -> void:
	var turret: ValveTurret = room().get_node("TurretA")
	var fired := false
	for i in 200:
		await frames(1)
		fired = fired or turret.state == ValveTurret.S.FIRE
	check(fired, "the Gauge Hall turret builds pressure and fires")
	_hit(turret, Vector2(300, 330))
	await frames(2)
	check(turret.state == ValveTurret.S.SHUT, "any hit spins the turret's valve shut (it stalls)")
	await hop_to(Vector2(416, 312))
	ok_print(await hop_to(Vector2(540, 312)) and await hop_to(Vector2(610, 260)), "Gauge Hall: over the block and up onto the catwalk")
	await place(Vector2(1060, 352))
	var ok := await hop_to(Vector2(1130, 300))
	check(ok and GameState.key_item_count(&"letter") >= 1, "a lost letter on the ledge")
	# the lift vent to the Steam Trials
	await place(Vector2(940, 352))
	for i in 150:
		await frames(1)
		if room().room_id == &"uw_15_trials":
			break
	await frames(30)
	check(room().room_id == &"uw_15_trials", "the hall's lift vent rises into the Steam Trials")
	await goto("uw_08_gauge", &"from_trials")
	await place(Vector2(1180, 352))
	check(await walk_out(1300) == "uw_09_approach", "Pressure Gauge Hall -> Governor's Approach")
	ok = await hop_to(Vector2(510, 312)) and await hop_to(Vector2(650, 352))
	check(ok, "Approach: across the boiling pit by the island")
	await place(Vector2(880, 352))
	check(await walk_out(980) == "uw_10_governor", "Approach -> The Pendulum")


func ok_print(cond: bool, what: String) -> void:
	check(cond, what)


# ------------------------------------------------------------------ 6. the enemies
func _enemies() -> void:
	await goto("uw_15_trials", &"from_gauge")
	await place(Vector2(320, 300))
	await frames(10)
	var arena: ArenaWaves = room().get_node("Arena")
	check(arena.is_active(), "Steam Trials: the arena seals when you walk in")
	var kinds := {}
	var stomped := false
	var bloat_deaths := [0]
	EventBus.enemy_killed.connect(func(id, _p): if id == &"boiler_bloat": bloat_deaths[0] += 1)
	for k in 2400:
		await frames(1)
		for n in room().get_children():
			if n is EnemyBase:
				kinds[n.enemy_id] = true
				if n is PistonWalker and n.state == PistonWalker.S.STOMP:
					stomped = true
				if k % 20 == 0 and not (n is BoilerBloat and n.state == BoilerBloat.S.SWELL):
					n.hurtbox.take_hit(1, n.global_position + Vector2(-20, 0), player)
		if not arena.is_active() and k > 60:
			break
	check(not arena.is_active() and GameState.is_collected(arena.arena_id), "all three waves cleared")
	check(kinds.has(&"clock_spider") and kinds.has(&"bellows_bat") and kinds.has(&"piston_walker") and kinds.has(&"boiler_bloat"),
		"the waves bring every Underworks enemy %s" % str(kinds.keys()))
	check(bloat_deaths[0] >= 2, "killed Boiler Bloats still burst (they only die by bursting)")
	await frames(20)
	var reward := room().get_node_or_null("ArenaReward")
	check(reward != null and reward.kind == Collectible.Kind.CORE_CELL, "the Steam Trials reward is a core cell")
	# piston walker: the stomp sends shockwaves along the floor
	var w := PistonWalker.new()
	room().add_child(w)
	w.global_position = Vector2(200, 320)
	await place(Vector2(280, 320))
	var waves := 0
	for k in 120:
		await frames(1)
		for n in room().get_children():
			if n is Shockwave:
				waves = maxi(waves, room().get_children().filter(func(c): return c is Shockwave).size())
		if waves >= 2:
			break
	check(waves >= 2, "a Piston Walker stomps when you're close: two shockwaves run out along the floor")
	if is_instance_valid(w):
		w.queue_free()


# ------------------------------------------------------------------ 7. the Lamplighter
func _lamplighter() -> void:
	await goto("uw_06_gallery", &"from_gearworks")
	var lamp: GasLamp = room().get_node("Lamp1")
	lamp.snuff()
	await frames(30)
	check(not lamp.lit and not lamp._light.enabled, "a gas lamp can be snuffed (its light goes out)")
	_hit(lamp, player.global_position)
	await frames(2)
	check(lamp.lit, "hitting a dark lamp lights it again")
	await place(Vector2(200, 320))
	await frames(10)
	await _skip_dialogue()
	var boss: Lamplighter = room().get_node("BossArena/Lamplighter")
	for i in 60:
		await frames(1)
	check(boss.state != Lamplighter.S.IDLE, "walking into the Gallery starts the Lamplighter")
	var swept := false
	for k in 900:
		await frames(1)
		swept = swept or boss.state == Lamplighter.S.SWEEP
		if swept:
			break
	check(swept, "it closes in and sweeps its pole")
	# check the sweep height in real numbers: a standing robot is in it, a sliding one is under it
	var pole_shape: RectangleShape2D = (boss._pole.get_child(0) as CollisionShape2D).shape
	var pole_y: float = boss.global_position.y + (boss._pole.get_child(0) as CollisionShape2D).position.y
	var pole_bottom := pole_y + pole_shape.size.y * 0.5
	var floor_y := 320.0
	check(pole_bottom > floor_y - 27.0 and pole_bottom < floor_y - 15.0,
		"the sweep passes through a standing robot (27 px) but over a sliding one (15 px) (bottom at %d above the floor)" % int(floor_y - pole_bottom))
	for k in 400:
		await frames(1)
		if boss.state == Lamplighter.S.DYING or boss.state == Lamplighter.S.WRECKED:
			break
		if k % 6 == 0:
			boss._hurtbox.take_hit(1, boss.global_position + Vector2(-20, -30), player)
	for k in 120:
		await frames(1)
		if boss.state == Lamplighter.S.WRECKED:
			break
	await frames(10)
	check(boss.state == Lamplighter.S.WRECKED and GameState.flags.get("boss_lamplighter_defeated", false), "the Lamplighter goes down and stays down")
	check(GameState.key_item_count(&"lamplighters_lantern") == 1, "it leaves its lantern (for Wick)")
	var cell := false
	for n in room().get_node("BossArena").get_children():
		if n is Collectible and n.kind == Collectible.Kind.CORE_CELL:
			cell = true
	check(cell, "...and a core cell")
	var all_lit := true
	for l in get_tree().get_nodes_in_group("gas_lamps"):
		all_lit = all_lit and l.lit
	check(all_lit, "every lamp in the Gallery lights again")


# ------------------------------------------------------------------ 8. The Pendulum
func _governor() -> void:
	await goto("uw_10_governor", &"from_approach")
	check(GameState.has_shard(2) == false, "no Shard II yet")
	var gov: GreatGovernor = room().get_node("BossArena/GreatGovernor")
	# the high ball is at chest height: standing robots are hit, sliding ones pass under
	var b: Dictionary = gov.ball(1)
	var r := GreatGovernor.BALL_R - 1.0
	var standing_top := 320.0 - 27.0
	var sliding_top := 320.0 - 15.0
	var ball_bottom: float = b.pos.y + r
	check(ball_bottom > standing_top and ball_bottom < sliding_top, "the high flyball clears a sliding robot but not a standing one (bottom %d px up)" % int(320.0 - ball_bottom))
	var low_top: float = gov.ball(0).pos.y - r
	check(320.0 - low_top < 58.0, "the low flyball is under jump height (%d px tall)" % int(320.0 - low_top))
	# the hooks by the crown must be reachable for real: jump under one and throw
	await place(Vector2(200, 320))
	await frames(5)
	await _skip_dialogue() # standing past the trigger line starts the fight and its intro
	await place(Vector2(200, 320))
	var hook_l = room().get_node("HookL")
	Input.action_press("jump")
	var up := false
	for i in 50:
		await frames(1)
		up = up or player.velocity.y < -50.0
		if up and player.velocity.y >= -20.0:
			break
	Input.action_release("jump")
	player.aim_vector = player.aim_toward(hook_l.global_position)
	player.throw_blade()
	var hooked_l := false
	for i in 40:
		await frames(1)
		if player.blade and player.blade.is_hooked():
			hooked_l = true
			break
	check(hooked_l, "the crown's hooks can be reached with a jump and a throw from the floor")
	if player.blade:
		player.blade.recall()
	await frames(60)
	check(not gov._crown_blocks(Vector2(300, hook_l.global_position.y + 14.0)), "a hit from hanging at hook height counts")
	await place(Vector2(200, 320))
	await frames(5)
	await _skip_dialogue()
	for i in 90:
		await frames(1)
	check(gov.state != GreatGovernor.S.IDLE, "walking in starts The Pendulum")
	var saw_near := false
	var saw_vents := false
	var blocked_floor := false
	for k in 3000:
		await frames(1)
		saw_near = saw_near or gov._balls.any(func(h): return h.monitoring)
		saw_vents = saw_vents or not gov._vents.is_empty()
		if gov.is_vulnerable():
			if not blocked_floor:
				blocked_floor = not gov._hurtbox.take_hit(1, Vector2(320, 300), player) # from the floor: glances off
			if k % 5 == 0:
				gov._hurtbox.take_hit(2, Vector2(256, 100), player) # from the hook height
		if gov.state == GreatGovernor.S.WRECKED:
			break
	check(saw_near, "its flyballs are dangerous on the near pass")
	check(saw_vents, "floor vents burst during the fight")
	check(blocked_floor, "hits from the floor glance off the crown's rim")
	check(gov.state == GreatGovernor.S.WRECKED and GameState.flags.get("boss_governor_defeated", false), "hitting the open crown from the hooks brings The Pendulum down")
	await frames(20)
	var shard: Collectible = null
	for n in room().get_node("BossArena").get_children():
		if n is Collectible and n.kind == Collectible.Kind.SHARD:
			shard = n
	check(shard != null and shard.amount == 2, "it drops Shard II")
	if shard:
		await place(shard.global_position + Vector2(0, 20))
		await frames(30)
		await _skip_dialogue()
	check(GameState.has_shard(2), "Shard II (Swing) picked up")
	var gate = room().get_node_or_null("ShutGate")
	if gate:
		gate._hurtbox.take_hit(1, gate.global_position)
	await frames(10)
	await place(Vector2(560, 320))
	check(await walk_out(660) == "uw_11_galleries", "with Shard II the way on opens: the Swing Galleries")


# ------------------------------------------------------------------ 9. the Swing Galleries
func _galleries() -> void:
	await place(Vector2(150, 352))
	var ok := await swing_across("RingA", Vector2(464, 320))
	check(ok, "swing from ring A over the boiling pit onto the first pillar")
	if not ok:
		await place(Vector2(464, 320))
	ok = await swing_across("RingB", Vector2(744, 320))
	check(ok, "...ring B onto the second pillar")
	if not ok:
		await place(Vector2(744, 320))
	ok = await swing_across("RingC", Vector2(1000, 352))
	check(ok, "...ring C to the far side")
	# climbing the wire: up shortens it, down lets it out
	await place(Vector2(1100, 352))
	var ring = room().get_node("RingLoft")
	if dbg:
		print("    climb start st=", player.state_machine.current_name(), " floor=", player.is_on_floor(), " blade=", player.blade, " jumpheld=", Input.is_action_pressed("jump"), " ui_locked=", GameState.is_ui_locked())
	Input.action_press("jump")
	var rising := false
	for i in 50:
		await frames(1)
		rising = rising or player.velocity.y < -50.0
		if rising and player.velocity.y >= -20.0:
			break
	Input.action_release("jump")
	player.aim_vector = player.aim_toward(ring.global_position)
	player.throw_blade()
	for i in 30:
		await frames(1)
		if player.blade and player.blade.is_hooked():
			break
	if dbg:
		print("    climb: hooked=", player.blade != null and player.blade.is_hooked(), " pos ", player.global_position.round())
	Input.action_press("throw")
	await frames(2)
	Input.action_release("throw")
	await frames(10)
	var st: String = player.state_machine.current_name()
	var len0 := (player.global_position + Player.BODY_CENTER).distance_to(ring.global_position)
	Input.action_press("aim_up")
	await frames(30)
	Input.action_release("aim_up")
	var len1 := (player.global_position + Player.BODY_CENTER).distance_to(ring.global_position)
	check(st == "swing" and len1 < len0 - 20.0, "holding up climbs the wire while swinging (%d -> %d)" % [int(len0), int(len1)])
	Input.action_press("throw")
	await frames(2)
	Input.action_release("throw")
	await settle()
	# the Loft: swing from its ring up onto the high ledge, then through the door
	await place(Vector2(1020, 352))
	var ok_loft := await swing_across("RingLoft", Vector2(1190, 200), 1, 30.0, 1040.0)
	check(ok_loft, "swinging from the loft ring lands on the high ledge")
	if not ok_loft:
		await place(Vector2(1200, 200))
	check(await walk_out(1300) == "uw_14_loft", "...and the ledge leads into the Clockmaker's Loft")
	await place(Vector2(400, 320))
	await frames(10)
	await _skip_dialogue()
	check(GameState.is_collected("uw_14_loft/Port"), "the Loft's port expansion")
	await goto("uw_11_galleries", &"from_governor")
	await place(Vector2(1200, 352))
	check(await walk_out(1300) == "uw_02_market", "the Galleries come out on the Pipe Market's high walkway")
	check(absf(player.global_position.y - 232.0) < 4.0, "...up on the walkway (y %d)" % int(player.global_position.y))
	# with Shard II the market's ring works: swing up from the stairwell to the walkway
	await place(Vector2(1240, 352))
	ok = await swing_across("SwingRing", Vector2(1480, 232), 1, 15.0)
	check(ok, "Pipe Market: with Swing, the ring by the stairwell takes you up to the walkway")


# ------------------------------------------------------------------ 10. side rooms
func _side_rooms() -> void:
	await goto("uw_12_tunnel", &"from_market")
	var letters := GameState.key_item_count(&"letter")
	var ok := await hop_to(Vector2(500, 280)) and await hop_to(Vector2(620, 262))
	check(ok, "Old Tram Tunnel: up onto the tram's roof")
	await walk_to(645)
	check(GameState.key_item_count(&"letter") == letters + 1, "a letter on the tram")
	await place(Vector2(56, 320))
	for i in 150:
		await frames(1)
		if room().room_id == &"uw_02_market":
			break
	check(room().room_id == &"uw_02_market", "the tunnel's lift vent carries the robot up the stairwell to the market")
	await goto("uw_13_cistern", &"from_falls")
	letters = GameState.key_item_count(&"letter")
	ok = true
	for t in [Vector2(600, 330), Vector2(490, 310), Vector2(380, 330), Vector2(270, 310), Vector2(120, 352)]:
		if not await hop_to(t):
			ok = false
			print("  cistern stopped at ", player.global_position, " for ", t)
			break
	check(ok, "The Cistern: across the stepping stones")
	await walk_to(55)
	check(GameState.key_item_count(&"letter") == letters + 1, "a letter at the far end of the Cistern")


# ------------------------------------------------------------------ 11. town: quests, shops, map
func _town() -> void:
	await goto("uw_02_market", &"from_descent")
	GameState.add_local(&"underworks", 30, false)
	GameState.add_scrap(400)
	for qid in [&"pressure_drop", &"last_lamplighter", &"letters_home"]:
		QuestManager.accept(qid)
		check(QuestManager.get_state(qid) == GameState.QuestState.COMPLETE, "quest %s: everything found earlier counts" % qid)
		QuestManager.turn_in(qid)
		check(QuestManager.get_state(qid) == GameState.QuestState.TURNED_IN, "quest %s turned in" % qid)
	check(&"piston_legs" in GameState.owned_chips and &"ball_bearings" in GameState.owned_chips, "rewards: Piston Legs and Ball Bearings chips")
	check(&"cloak_bellows" in GameState.owned_cosmetics, "reward: the Bellows Frock Coat")
	# Gauge & Gear
	await place(Vector2(320, 352))
	WorldManager.enter_interior("res://scenes/interiors/gauge_gear.tscn", &"from_gauge")
	await frames(60)
	var gilda: NPC = null
	for n in get_tree().root.find_children("Gilda", "", true, false):
		if n is NPC:
			gilda = n
	check(gilda != null and gilda.shop_items.size() == 4, "Gauge & Gear: Gilda keeps a shop of four things")
	if gilda:
		var before := GameState.get_balance(&"underworks")
		check(ShopScreen.buy(gilda, gilda.shop_items[0]) and GameState.get_balance(&"underworks") == before - 8, "the Verdigris Monocle costs 8 Brass Cogs")
		check(&"mask_monocle" in GameState.owned_cosmetics, "...and it's yours")
	WorldManager.leave_interior()
	await frames(60)
	WorldManager.enter_interior("res://scenes/interiors/tram_depot.tscn", &"from_depot")
	await frames(60)
	var quill: NPC = null
	for n in get_tree().root.find_children("Quill", "", true, false):
		if n is NPC:
			quill = n
	check(quill != null and ShopScreen.buy(quill, quill.shop_items[0]) and GameState.has_map(&"underworks"), "Quill sells the Map of the Underworks")
	WorldManager.leave_interior()
	await frames(60)
	# the Bellows Kin look like their own family
	var kin: Lineage = load("res://data/lineages/bellows_kin.tres")
	var t := NPCLook.roll(kin, 99, "adult", {"headwear": "stovepipe", "goggles": "monocle", "accessory": "brass_arm"})
	var img := NPCLook.build(kin, t)[0].get_image()
	var top := NPCLook.H
	for y in NPCLook.H:
		for x in NPCLook.W:
			if img.get_pixel(x, y).a > 0.0:
				top = mini(top, y)
	check(top >= 0 and top < 12, "a Bellows Kin in a stovepipe hat fits the taller canvas (top row %d)" % top)
