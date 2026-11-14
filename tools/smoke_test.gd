extends Node

const TEST_PIT := "res://tools/fixtures/test_pit.tscn"

var main: Node
var player: Player
var fails := 0
var toasts: Array[String] = []


func _all_gd(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _all_gd(dir + "/" + sub)
	return out


func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		fails += 1
		print("FAIL  ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func press(action: String, hold_frames := 2) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)


func hop_to(target: Vector2) -> bool:
	var jumped := false
	var airborne := 0
	for i in 150:
		var dx := target.x - player.global_position.x
		var dir := signf(dx)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 3.0 and dir != 0.0:
			Input.action_press("move_right" if dir > 0 else "move_left")
		var edge_ahead := dir != 0.0 and not player.test_move(player.global_transform.translated(Vector2(dir * 8.0, 0)), Vector2(0, 6))
		if not jumped and player.is_on_floor() and (absf(dx) <= 50.0 or (edge_ahead and absf(dx) < 90.0)):
			Input.action_press("jump")
			jumped = true
			airborne = 0
		await frames(1)
		airborne += 1
		if OS.has_environment("HOP_DEBUG") and i % 3 == 0:
			print("    hop i=%d pos=%s vel=%s jumped=%s floor=%s ceil=%s state=%s" % [i, player.global_position.round(), player.velocity.round(), jumped, player.is_on_floor(), player.is_on_ceiling(), player.state_machine.current_name()])
		if jumped and airborne > 8 and player.is_on_floor():
			if absf(player.global_position.y - target.y) < 2.0:
				break
			Input.action_release("jump")
			jumped = false
			await frames(2)
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	await frames(6)
	return absf(player.global_position.y - target.y) < 2.0


func enter_building(door_name: String) -> void:
	var door: Door = WorldManager.current_room.get_node(door_name)
	player.global_position = door.global_position
	await frames(3)
	door.interact(player)
	for k in 90:
		await frames(1)
		if WorldManager.interior != null and not WorldManager.is_busy():
			break
	await frames(5)


func leave_building() -> void:
	WorldManager.leave_interior()
	for k in 90:
		await frames(1)
		if WorldManager.interior == null and not WorldManager.is_busy():
			break
	await frames(5)


func skip_dialogue() -> void:
	var guard := 0
	while DialogueManager.active and guard < 40:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await frames(2)
		var up := InputEventAction.new()
		up.action = "interact"
		up.pressed = false
		Input.parse_input_event(up)
		await frames(2)
		guard += 1
	await frames(3)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	SaveManager.delete_save()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	player = main.get_node("World/Player")
	EventBus.toast.connect(func(t): toasts.append(t))

	main._on_new_game(GameState.Gender.GIRL)
	await frames(40)
	check(DialogueManager.active, "intro dialogue plays")
	await skip_dialogue()
	check(not DialogueManager.active, "dialogue closes")
	check(GameState.gender == GameState.Gender.GIRL, "chassis = girl")
	check(DialogueManager.format_text("{They} found {their} blade") == "She found her blade", "pronoun tokens")
	check(WorldManager.current_room != null and WorldManager.current_room.room_id == &"heap_01_pit", "spawned in the Pit")
	check(AudioManager.current_track() == "beginning_underground", "the cave plays the underground theme")
	var missing_sfx := []
	for f in ["res://scripts", "res://autoload"]:
		for path in _all_gd(f):
			var text := FileAccess.get_file_as_string(path)
			var rx := RegEx.create_from_string("sfx\\(&\"(\\w+)\"")
			for m in rx.search_all(text):
				if not ResourceLoader.exists("res://audio/sfx/%s.wav" % m.get_string(1)):
					missing_sfx.append(m.get_string(1))
	check(missing_sfx.is_empty(), "every sound the code plays exists %s" % str(missing_sfx))
	check(GameState.outfit.size() == 4, "starting outfit equipped")
	check(player.visuals._uses_real_art(), "the robot renders with real layered sprites")
	check(player.visuals._layers["hood"].sprite_frames != null and player.visuals._layers["cloak_back"].sprite_frames != null, "outfit pieces have sprite layers (hood, cloak back)")
	await WorldManager.change_room(TEST_PIT, &"wake", false)
	await frames(30)
	check(player.is_on_floor(), "player lands on floor")

	var x0 := player.global_position.x
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(player.global_position.x > x0 + 30, "runs right (%.0f -> %.0f)" % [x0, player.global_position.x])

	await frames(20)
	player.global_position = Vector2(110, 432)
	player.velocity = Vector2.ZERO
	await frames(6)
	var y0 := player.global_position.y
	Input.action_press("jump")
	await frames(12)
	check(player.global_position.y < y0 - 20, "jumps (%.0f -> %.0f)" % [y0, player.global_position.y])
	Input.action_release("jump")
	await frames(60)
	check(player.is_on_floor(), "lands after jump")

	check(player.attack_direction(Vector2(0.1, -0.95)) == "up", "cursor above aims the swing up")
	check(player.attack_direction(Vector2(-0.98, 0.1)) == "forward" and player.facing == -1, "cursor to the left swings left and turns the robot")
	check(player.attack_direction(Vector2(0.0, 1.0)) == "forward", "no pogo swing while standing")
	player.facing = 1

	await press("attack")
	check(player.state_machine.current_name() == "attack", "attack state")
	await frames(30)

	await press("throw")
	await frames(3)
	check(player.blade != null, "blade thrown")
	await frames(1)
	check(not player.visuals._layers["blade"].visible, "the blade sprite leaves the hand when thrown")
	await frames(60)
	check(player.blade == null, "blade returns by itself")

	await frames(30)
	x0 = player.global_position.x
	await press("dash")
	await frames(10)
	check(absf(player.global_position.x - x0) > 25, "dash moves")
	await frames(30)

	await _movement_checks()

	var drone := WorldManager.current_room.get_node_or_null("Drone1")
	check(drone != null, "drone exists")
	if drone:
		var killed := [false]
		EventBus.enemy_killed.connect(func(_id, _p): killed[0] = true, CONNECT_ONE_SHOT)
		for i in 3:
			drone.hurtbox.take_hit(1, drone.global_position + Vector2(-10, 0))
			await frames(2)
		await frames(5)
		check(killed[0], "drone dies and emits enemy_killed")

	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "stretch expands to any window shape (no black bars)")
	player.global_position = Vector2(80, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press("move_right")
	await frames(6)
	check(player.velocity.x >= player.stats.get_stat("max_speed") - 1.0, "reaches full run speed in 0.1 s (%.0f)" % player.velocity.x)
	Input.action_release("move_right")
	await frames(4)
	check(absf(player.velocity.x) < 1.0, "stops almost instantly on release")
	await press("attack")
	Input.action_press("jump")
	await frames(3)
	check(player.state_machine.current_name() == "attack" and player.velocity.y < -100.0, "can jump in the middle of a swing")
	Input.action_release("jump")
	await frames(40)
	var swings := [0]
	var count_swings := func(n): if n == "attack": swings[0] += 1
	player.state_machine.state_changed.connect(count_swings)
	Input.action_press("attack")
	await frames(45)
	Input.action_release("attack")
	player.state_machine.state_changed.disconnect(count_swings)
	check(swings[0] >= 2, "holding attack keeps swinging (%d swings in 0.75 s)" % swings[0])
	await frames(30)
	player.recent_speed = 0.0
	await press("dash")
	await frames(2)
	await press("attack")
	check(player.state_machine.current_name() == "attack" and player.state_machine.current.is_rush(), "attacking mid-dash cancels into a Rush slash")
	await frames(30)
	player.global_position = Vector2(247, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	var top_y := player.global_position.y
	Input.action_press("jump")
	for i in 30:
		await frames(1)
		top_y = minf(top_y, player.global_position.y)
	Input.action_release("jump")
	check(top_y < 385.0 and player.global_position.x > 249.0, "corner correction: head clips the girder edge and slides past (top %.0f)" % top_y)
	await frames(30)
	var saved_bounds: Rect2 = player._room_bounds
	player._room_bounds = Rect2(0, 0, 400, 300)
	player.fit_camera_to_room()
	var view := player.get_viewport_rect().size
	check(is_equal_approx(player.camera.zoom.x, maxf(view.y / 360.0, maxf(view.x / 400.0, view.y / 300.0))), "camera zooms in so a small room fills the screen (zoom %.2f)" % player.camera.zoom.x)
	player._room_bounds = saved_bounds
	player.fit_camera_to_room()
	check(player.camera.zoom.x >= 1.0, "big rooms stay at zoom 1")

	var room := WorldManager.current_room
	player.global_position = Vector2(120, 432)
	player.velocity = Vector2.ZERO
	await frames(20)
	var hp0 := player.health.current
	var sludge := Hazard.new()
	sludge.size = Vector2(40, 12)
	room.add_child(sludge)
	sludge.position = Vector2(200, 420)
	await frames(2)
	player.global_position = Vector2(220, 430)
	await frames(30)
	check(player.health.current == hp0 - 1, "toxic sludge costs 1 health")
	check(player.global_position.distance_to(Vector2(120, 432)) < 6.0, "and puts you back on the last safe ground (%s)" % str(player.global_position))
	sludge.queue_free()
	player.health.refill()
	await frames(60)
	var belt := Conveyor.new()
	belt.size = Vector2(160, 12)
	belt.speed = 60.0
	room.add_child(belt)
	belt.position = Vector2(290, 408)
	await frames(2)
	player.global_position = Vector2(300, 406)
	player.velocity = Vector2.ZERO
	await frames(10)
	var bx := player.global_position.x
	await frames(30)
	check(player.global_position.x > bx + 20.0, "a conveyor carries you along (%.0f -> %.0f)" % [bx, player.global_position.x])
	belt.queue_free()
	await frames(10)
	player.global_position = Vector2(120, 432)
	player.velocity = Vector2.ZERO
	await frames(20)
	player.health.refill()
	var press := Crusher.new()
	press.width = 40
	press.drop = 40
	press.period = 1.0
	room.add_child(press)
	press.position = Vector2(120, 368)
	var hurt_by_press := false
	for i in 90:
		await frames(1)
		if player.health.current < player.health.max_health:
			hurt_by_press = true
			break
	check(hurt_by_press, "a crusher slamming down on you hurts")
	press.queue_free()
	player.health.refill()
	await frames(80)
	player.global_position = Vector2(140, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	var crawler := Rustcrawler.new()
	room.add_child(crawler)
	crawler.global_position = Vector2(300, 300)
	await frames(10)
	check(crawler.state == Rustcrawler.S.CLING, "Rustcrawler clings until you pass under it")
	player.hurtbox.invulnerable = true
	player.global_position = Vector2(300, 432)
	await frames(40)
	check(crawler.state != Rustcrawler.S.CLING, "it drops when you pass beneath")
	player.global_position = Vector2(160, 432)
	var cx := crawler.global_position.x
	await frames(40)
	check(crawler.global_position.x < cx - 15.0, "then scuttles after you")
	crawler.queue_free()
	player.global_position = Vector2(400, 432)
	await frames(10)
	var comp := Compactor.new()
	room.add_child(comp)
	comp.global_position = Vector2(200, 432)
	comp.facing = 1
	comp.set_physics_process(false)
	await frames(5)
	var chp := comp.health.current
	comp.hurtbox.take_hit(2, comp.global_position + Vector2(30, -12))
	check(comp.health.current == chp, "hits on the Compactor's ram plate glance off")
	comp.hurtbox.take_hit(2, comp.global_position + Vector2(-30, -12))
	check(comp.health.current == chp - 2, "hits from behind land")
	comp.hurtbox.take_hit(1, comp.global_position + Vector2(10, -40))
	check(comp.health.current == chp - 3, "hits from above land (pogo)")
	comp.set_physics_process(true)
	player.global_position = Vector2(300, 432)
	var saw_charge := false
	var saw_stun := false
	for i in 200:
		await frames(1)
		if comp.state == Compactor.S.CHARGE:
			saw_charge = true
		if comp.state == Compactor.S.STUNNED:
			saw_stun = true
			break
	check(saw_charge and saw_stun, "it winds up, charges, and is stunned afterwards")
	comp.queue_free()
	player.hurtbox.invulnerable = false
	player.health.refill()
	await frames(10)

	var t0 := 10.0
	var fast := Player.read_flick([{"t": t0 - 0.2, "p": Vector2(100, 100)}, {"t": t0 - 0.08, "p": Vector2(100, 100)}], t0, Vector2(100, 100), Vector2(260, 60))
	check(not fast.is_empty() and fast.charged and fast.dir.x > 0.9, "hard flick right: charged throw to the right")
	var medium := Player.read_flick([{"t": t0 - 0.08, "p": Vector2(100, 100)}], t0, Vector2(100, 100), Vector2(100, 70))
	check(not medium.is_empty() and not medium.charged and medium.dir.y < -0.9 and medium.power > 0.4 and medium.power < 1.0, "medium flick up: normal throw up, partial power (%.2f)" % medium.get("power", -1.0))
	var drag := Player.read_flick([{"t": t0 - 0.08, "p": Vector2(140, 100)}], t0, Vector2(100, 100), Vector2(141, 100))
	check(not drag.is_empty() and drag.power <= 0.5 and drag.dir.x > 0.9, "slow drag then release: weak toss along the drag")
	check(Player.read_flick([{"t": t0 - 0.08, "p": Vector2(100, 100)}], t0, Vector2(100, 100), Vector2(102, 101)).is_empty(), "no movement: no flick (tosses at cursor)")
	var sens := Player.read_flick([{"t": t0 - 0.08, "p": Vector2(100, 100)}], t0, Vector2(100, 100), Vector2(190, 100), 0.7)
	check(sens.get("charged", false), "high flick sensitivity charges a smaller flick")

	var dummy_scene := load("res://scenes/enemies/scrap_drone.tscn")
	var spawn_dummy := func(pos: Vector2) -> ScrapDrone:
		var d: ScrapDrone = dummy_scene.instantiate()
		d.speed = 0.0
		d.scrap_drop = 0
		WorldManager.current_room.add_child(d)
		d.global_position = pos
		d.health.set_max(10, true)
		d.get_node("Hitbox").set_deferred("monitoring", false)
		d.get_node("Hitbox").set_deferred("monitorable", false)
		return d
	player.global_position = Vector2(260, 432)
	player.velocity = Vector2.ZERO
	player.facing = 1
	var dummy: ScrapDrone = spawn_dummy.call(Vector2(330, 424))
	await frames(15)
	player.throw_blade({"dir": Vector2.RIGHT, "power": 1.0, "charged": false})
	var pinned := false
	for i in 30:
		await frames(1)
		if player.blade and player.blade.is_pinned():
			pinned = true
			break
	check(pinned and dummy.health.current == 8, "normal throw pins (2 dmg) into the drone (hp %d)" % dummy.health.current)
	await press("throw")
	await frames(2)
	check(dummy.health.current == 6, "clicking while pinned rips the blade out for one more hit")
	await frames(40)
	check(player.blade == null, "blade back in hand after the rip")
	dummy.health.refill()
	player.global_position = Vector2(250, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	player.throw_blade({"dir": Vector2.RIGHT, "power": 1.0, "charged": false})
	for i in 30:
		await frames(1)
		if player.blade and player.blade.is_pinned():
			break
	var hp_before := dummy.health.current
	await press("dash")
	check(player.state_machine.current_name() == "zip", "dash with a pinned blade starts a zip")
	var zipped := false
	for i in 30:
		await frames(1)
		if player.blade == null:
			zipped = true
			break
	check(zipped and dummy.health.current <= hp_before - 2, "zip arrives, strikes for 2 and catches the blade (hp %d -> %d)" % [hp_before, dummy.health.current])
	check(player.velocity.y < -100.0 and player.can_air_dash, "zip bounces the robot up with the air dash back")
	await frames(40)
	dummy.health.refill()
	player.global_position = Vector2(250, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	player.can_air_dash = false
	player.velocity = Vector2(0, 120)
	player.global_position = Vector2(250, 380)
	player.state_machine.transition("fall")
	player.throw_blade({"dir": Vector2.RIGHT, "power": 1.0, "charged": false})
	player.blade.landed_hit = true
	player.blade.recall()
	await frames(4)
	check(player.blade == null and player.can_air_dash and player.velocity.y < 0.0, "catching a blade that hit, in mid-air: air dash back + hop")
	await frames(40)
	player.global_position = Vector2(250, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	player.recent_speed = 0.0
	await press("attack")
	check(player.melee_hitbox.damage == 1, "standing swing: normal damage")
	check(player.stats.get_stat("blade_damage") > player.stats.get_stat("melee_damage"), "thrown blade does more damage than a swing")
	await frames(25)
	player.recent_speed = 300.0
	await press("attack")
	check(player.state_machine.current_name() == "attack" and player.state_machine.current.is_rush() and player.melee_hitbox.damage == 2, "swing while moving fast is a Rush slash (+1)")
	await frames(25)
	dummy.health.refill()
	var dummy2: ScrapDrone = spawn_dummy.call(Vector2(380, 424))
	dummy.global_position = Vector2(330, 424)
	player.global_position = Vector2(250, 432)
	player.velocity = Vector2.ZERO
	await frames(15)
	player.throw_blade({"dir": Vector2.RIGHT, "power": 1.0, "charged": true})
	await frames(10)
	check(player.blade != null and player.blade.charged and not player.blade.is_pinned(), "charged blade pierces instead of pinning")
	await frames(12)
	check(dummy.health.current == 6 and dummy2.health.current == 6, "charged blade hits both drones for 4 (hp %d, %d)" % [dummy.health.current, dummy2.health.current])
	await frames(60)
	var loose := player.aim_toward(dummy.hurtbox.global_position).rotated(-0.2)
	var bent: Node2D = player.enemy_target(loose)
	check(bent != null, "throw ~11 degrees off still targets the drone")
	dummy.queue_free()
	dummy2.queue_free()
	await frames(5)

	player.global_position = Vector2(250, 432)
	player.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press("throw")
	await frames(30)
	check(player.blade == null, "holding the throw button doesn't throw yet")
	Input.action_release("throw")
	await frames(3)
	check(player.blade != null and player.blade.charged, "releasing after a long hold throws a charged blade")
	await frames(60)

	var spotter = WorldManager.current_room.get_node_or_null("Spotter1")
	check(spotter != null, "spotter exists")
	if spotter:
		player.global_position = Vector2(500, 432)
		player.velocity = Vector2.ZERO
		var saw_warn := false
		var saw_bolt := false
		for i in 200:
			await frames(1)
			if spotter.state == SpotterDrone.S.WARN:
				saw_warn = true
			for c in WorldManager.current_room.get_children():
				if c is Projectile:
					saw_bolt = true
			if saw_bolt:
				break
		check(saw_warn, "spotter shows its warning before firing")
		check(saw_bolt, "spotter fires a bolt")
		var bolt: Projectile = null
		for c in WorldManager.current_room.get_children():
			if c is Projectile:
				bolt = c
		if bolt:
			var hb := bolt.get_children().filter(func(n): return n is Hurtbox)
			hb[0].take_hit(1, player.global_position)
			await frames(2)
			check(not is_instance_valid(bolt), "bolt is destroyed by a hit")
		spotter.hurtbox.take_hit(1, player.global_position)
		await frames(2)
		spotter.hurtbox.take_hit(1, player.global_position)
		await frames(3)
		check(not is_instance_valid(spotter), "spotter dies after 2 hits")
		player.health.refill()

	player.global_position = Vector2(880, 300)
	player.velocity = Vector2.ZERO
	await frames(20)
	check(player.is_on_floor(), "standing on grapple platform")
	player.facing = 1
	Input.action_press("aim_up")
	Input.action_press("aim_right")
	await frames(2)
	await press("throw")
	Input.action_release("aim_up")
	Input.action_release("aim_right")
	await frames(25)
	check(player.blade != null and player.blade.is_hooked(), "blade hooks the crane")
	await press("throw")
	await frames(60)
	check(player.global_position.y < 230 and player.is_on_floor(), "grappled up onto ledge (y=%.0f)" % player.global_position.y)

	player.global_position = Vector2(110, 432)
	player.velocity = Vector2.ZERO
	await frames(15)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(16)
	Input.action_release("jump")
	await frames(10)
	Input.action_release("move_right")
	await frames(30)
	check(player.is_on_floor() and absf(player.global_position.y - 384.0) < 2.0, "can jump from the floor onto the first girder (y=%.0f)" % player.global_position.y)
	player.global_position = Vector2(226, 384)
	player.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(16)
	Input.action_release("jump")
	await frames(14)
	Input.action_release("move_right")
	await frames(30)
	check(player.is_on_floor() and absf(player.global_position.y - 336.0) < 2.0, "girder to container jump works (y=%.0f)" % player.global_position.y)
	player.global_position = Vector2(300, 336)
	player.velocity = Vector2.ZERO
	await frames(10)
	var tut_hook = WorldManager.current_room.get_node("HookTutorial")
	var aim: Vector2 = player.aim_toward(tut_hook.global_position)
	check(player.grapple_target(aim) == tut_hook, "aiming at the tutorial hook targets it")
	player.aim_vector = aim
	player.throw_blade()
	await frames(20)
	check(player.blade != null and player.blade.is_hooked(), "blade catches the tutorial hook")
	await press("throw")
	await frames(60)
	check(player.is_on_floor() and absf(player.global_position.y - 228.0) < 2.0, "reeled up onto the vest ledge (y=%.0f)" % player.global_position.y)

	var gate := WorldManager.current_room.get_node_or_null("ScrapWall")
	if gate:
		gate._hurtbox.take_hit(1, gate.global_position)
		await frames(3)
		check(is_instance_valid(gate) and not gate.is_queued_for_deletion(), "gate holds without Shard I")

	player.global_position = Vector2(1030, 214)
	await frames(10)
	check(GameState.key_item_count(&"power_cell") == 1, "power cell collected")
	player.global_position = Vector2(990, 214)
	await frames(10)
	check(GameState.get_balance(&"heap") >= 1, "bottlecap collected (%d)" % GameState.get_balance(&"heap"))

	await WorldManager.change_room("res://scenes/rooms/heap/heap_02_camp.tscn", &"from_pit")
	await frames(10)
	check(WorldManager.current_room.room_id == &"heap_02_camp", "entered camp")
	check(AudioManager.current_track() == "beginning_aboveground", "the above-ground theme crossfades in at the camp")

	var tinker: NPC = WorldManager.current_room.get_node("Tinker")
	tinker.interact(player)
	await frames(5)
	await skip_dialogue()
	check(QuestManager.get_state(&"lost_power_cell") == GameState.QuestState.COMPLETE, "quest accepted + already complete")
	await frames(10)
	var caps_before := GameState.get_balance(&"heap")
	tinker.interact(player)
	await frames(5)
	await skip_dialogue()
	check(QuestManager.get_state(&"lost_power_cell") == GameState.QuestState.TURNED_IN, "quest turned in")
	check(GameState.get_balance(&"heap") == caps_before + 4, "quest paid 4 bottlecaps")
	check(&"recall_saw" in GameState.owned_chips, "quest gave Recall Saw chip")

	check(WorldManager.current_room.bounds.size.x >= 1900.0, "camp is twice as wide")
	player.global_position = Vector2(1040, 336)
	player.velocity = Vector2.ZERO
	await frames(10)
	var climb := [Vector2(1104, 296), Vector2(1040, 256), Vector2(1104, 216), Vector2(1040, 176), Vector2(1104, 136), Vector2(1040, 96), Vector2(1104, 56), Vector2(1040, 16)]
	var climbed := true
	for target in climb:
		if not await hop_to(target):
			climbed = false
			print("  climb stopped at ", player.global_position, " heading for ", target)
			break
	check(climbed, "scrap tower climbs all the way to the lookout with plain jumps")
	player.global_position = Vector2(1044, 16)
	player.velocity = Vector2.ZERO
	await frames(10)
	var alcove_hook = WorldManager.current_room.get_node("AlcoveHook")
	player.aim_vector = player.aim_toward(alcove_hook.global_position)
	player.throw_blade()
	await frames(20)
	check(player.blade != null and player.blade.is_hooked(), "lookout: blade reaches the alcove hook")
	await press("throw")
	for k in 120:
		await frames(1)
		if player.is_on_floor() and k > 20:
			break
	check(player.is_on_floor() and absf(player.global_position.y + 44.0) < 2.0, "reel in from the hook flings you up and you land in the hidden alcove (y=%.0f)" % player.global_position.y)
	var hatch = WorldManager.current_room.get_node_or_null("OldHatch")
	check(hatch != null, "rusted hatch in the market floor")
	var board = WorldManager.current_room.get_node("Noticeboard")
	board.interact(player)
	await frames(3)
	check(DialogueManager.active, "noticeboard can be read")
	await skip_dialogue()
	for i in 3:
		hatch._hurtbox.take_hit(1, hatch.global_position)
		await frames(2)
	check(not is_instance_valid(hatch), "three hits break the hatch open")
	player.global_position = Vector2(1420, 320)
	player.velocity = Vector2.ZERO
	await frames(60)
	check(WorldManager.current_room.room_id == &"heap_02b_undercamp", "falling through the hole reaches the Hollow under the camp")
	var hollow := WorldManager.current_room
	var path := [Vector2(210, 296), Vector2(330, 256), Vector2(470, 216), Vector2(580, 176)]
	player.global_position = Vector2(160, 336)
	player.velocity = Vector2.ZERO
	await frames(40)
	var reached := true
	for target in path:
		if not await hop_to(target):
			reached = false
			print("  hollow climb stopped at ", player.global_position, " heading for ", target)
			break
	check(reached, "the Hollow's pipe platforms climb to the goggles ledge")
	await frames(10)
	await hop_to(Vector2(640, 176))
	check(&"mask_brass_goggles" in GameState.owned_cosmetics, "picked up the Brass Goggles in the Hollow")
	player.global_position = Vector2(80, 336)
	player.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press("move_left")
	for i in 90:
		await frames(1)
		if WorldManager.current_room.room_id != &"heap_02b_undercamp":
			break
	Input.action_release("move_left")
	await frames(20)
	check(WorldManager.current_room.room_id == &"heap_02_camp", "walking out the Hollow's lit west tunnel returns to the camp")
	check(WorldManager.current_room.get_node_or_null("OldHatch") == null, "the hatch stays broken")
	player.global_position = Vector2(600, 336)
	await frames(10)

	var map_ok := true
	var region_dirs := {&"heap": "heap", &"underworks": "underworks"}
	for region in MapData.REGIONS:
		for rid in MapData.REGIONS[region]["rooms"]:
			var room_path := "res://scenes/rooms/%s/%s.tscn" % [region_dirs[region], rid]
			if not ResourceLoader.exists(room_path):
				map_ok = false
				print("  map lists a room with no scene: ", room_path)
				continue
			var inst: Room = load(room_path).instantiate()
			if inst.bounds != MapData.REGIONS[region]["rooms"][rid]["rect"] or inst.region_id != region:
				map_ok = false
				print("  map rect/region mismatch for ", rid, ": scene ", inst.bounds, " ", inst.region_id)
			inst.free()
	check(map_ok, "map data matches every room's real bounds (both regions)")
	check(GameState.visited_rooms.has("heap_01_pit") and GameState.visited_rooms.has("heap_02_camp"), "visited rooms are tracked for the map")
	check(not GameState.has_map(&"heap"), "no map until you buy one")
	check(WorldManager.current_room.get_node_or_null("DoorRusty") is Door and WorldManager.current_room.get_node_or_null("DoorDot") is Door \
		and WorldManager.current_room.get_node_or_null("DoorMags") is Door, "the camp has walk-in doors for Rusty, Dot and Mags")
	check(WorldManager.current_room.get_node_or_null("Rusty") == null, "the shopkeepers have moved indoors")
	await enter_building("DoorDot")
	var dot: NPC = WorldManager.interior.get_node("Dot")
	GameState.add_scrap(30)
	check(ShopScreen.buy(dot, dot.shop_items[0]) and GameState.has_map(&"heap"), "Dot sells the Map of the Heap (in her map room)")
	await leave_building()
	var gui = main.get_node("GameUI")
	gui.open_journal_map()
	await frames(3)
	var journal: JournalScreen = gui.find_children("*", "JournalScreen", true, false)[0]
	check(journal.current_tab() == 0 and journal.find_children("*", "MapView", true, false).size() == 1, "Tab opens the journal on the map")
	var geo_ok := true
	for id in MapData.REGIONS[&"heap"]["rooms"]:
		if (MapView.room_geometry(&"heap", id)["solids"] as Array).is_empty():
			geo_ok = false
	check(geo_ok, "the map reads every room's real level geometry")
	var mv: MapView = journal.find_children("*", "MapView", true, false)[0]
	await frames(2)
	var inked := 0
	if mv._tex:
		var img := mv._tex.get_image()
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).a > 0.9:
					inked += 1
	check(mv._tex != null and inked > 50, "the map inks the rooms onto the parchment (%d px)" % inked)
	check(mv._room_px.has(&"heap_05_fields") and not mv._room_px.has(&"heap_11_tram"), "Dot's map shows unvisited rooms but not secret ones")
	journal.show_tab(2)
	await frames(2)
	check(GameState.lore.has("camp_noticeboard"), "reading the noticeboard recorded it in the journal")
	journal.show_tab(1)
	await frames(2)
	await gui.close()

	var ui = main.get_node("GameUI")
	var outside_room := WorldManager.current_room
	await enter_building("DoorRusty")
	var inside: InteriorRoom = WorldManager.interior
	check(inside != null and not (player.get_parent() as Node2D).visible and get_viewport().get_camera_2d() == inside.camera,
		"going through Rusty's door hides the camp and shows her shop from above")
	check(WorldManager.current_room == outside_room, "the camp stays loaded (paused) while you're inside")
	var ip: InteriorPlayer = inside.player
	check(ip.visuals.layer_texture("body") != null and ip.visuals.layer_texture("hood") != null and ip.visuals.layer_texture("cloak_front") != null,
		"indoors the robot has top-down sprites for its chassis and outfit")
	check(ip.visuals.facing == OverworldVisuals.Facing.UP, "you come in facing into the room (back to the camera)")
	var p0 := ip.position
	Input.action_press("move_right")
	Input.action_press("aim_up")
	await frames(20)
	Input.action_release("move_right")
	Input.action_release("aim_up")
	check(ip.position.x > p0.x + 8.0 and ip.position.y < p0.y - 8.0, "you walk in 8 directions indoors (%s -> %s)" % [str(p0), str(ip.position)])
	Input.action_press("aim_down")
	await frames(6)
	check(ip.visuals.facing == OverworldVisuals.Facing.DOWN and ip.visuals.walking, "walking toward the camera shows the robot's front")
	Input.action_release("aim_down")
	Input.action_press("move_left")
	await frames(6)
	check(ip.visuals.facing == OverworldVisuals.Facing.SIDE and ip.visuals.flip, "walking left shows its side, mirrored")
	Input.action_release("move_left")
	ip.position = Vector2(30, 90)
	Input.action_press("aim_up")
	await frames(20)
	Input.action_release("aim_up")
	check(ip.position.y > 68.0, "the shelves are solid: you stop at their base (y=%.0f)" % ip.position.y)
	await frames(4)
	check(ip._target != null and ip._target.prompt == "Look", "standing by a shelf offers [E] Look")
	ip.position = Vector2(116, 140)
	await frames(6)
	check(ip._target == inside.get_node("RustyInRoom"), "at the counter, [E] is for Rusty")
	var rusty: NPC = inside.get_node("Rusty")
	press("interact")
	await frames(5)
	await skip_dialogue()
	await frames(5)
	check(ui.is_open(), "talking to Rusty across the counter opens her shop")
	var shop: ShopScreen = ui.find_children("*", "ShopScreen", true, false)[0]
	check(shop._cards.size() == 6, "shop shows a card for every item (port expansion unlocked by the quest)")
	check(shop._cards[&"magnet_coil"].icon_tex == ItemDB.chips[&"magnet_coil"].icon, "chip cards show the chip emblem")
	var kit_card: ShopCard = null
	for it in rusty.shop_items:
		if it.item_type == ShopItem.ItemType.CONSUMABLE:
			kit_card = shop._cards.get(it.item_id)
	check(kit_card != null and kit_card.icon_tex == ShopScreen.ICON_KIT and kit_card.icon_tex.get_width() == 24, "the repair kit has its own 24 px shop icon")
	check(shop._buy.get_theme_stylebox("normal") is StyleBoxTexture and shop._show != null, "Buy is a brass plate and the selected item sits in the display case")
	shop._select(rusty.shop_items[0])
	shop._on_buy()
	check(&"cloak_patchwork" in GameState.owned_cosmetics, "bought Patchwork Cloak with bottlecaps")
	check(shop._cards[&"cloak_patchwork"].stamp != "" and shop._buy.disabled, "bought card is stamped and Buy is disabled")
	var scrap_now := GameState.scrap
	shop._select(rusty.shop_items[5])
	shop._on_buy()
	check(GameState.max_ports == 3 or GameState.scrap == scrap_now, "can't buy the port expansion without enough scrap")
	GameState.add_scrap(200)
	shop.refresh()
	await frames(2)
	shop._select(rusty.shop_items[5])
	shop._on_buy()
	check(GameState.max_ports == 4, "bought port expansion (unlocked by quest)")
	await ui.close()
	await frames(5)
	ip.position = Vector2(inside.exit_x, inside.floor_bottom() - 12.0)
	Input.action_press("aim_down")
	for k in 120:
		await frames(1)
		if WorldManager.interior == null and not WorldManager.is_busy():
			break
	Input.action_release("aim_down")
	await frames(5)
	check(WorldManager.interior == null and (player.get_parent() as Node2D).visible, "walking down over the doormat takes you back outside")
	check(player.global_position.distance_to(WorldManager.current_room.get_node("DoorRusty").global_position) < 4.0, "...standing at Rusty's door")
	await enter_building("DoorMags")
	WorldManager.interior.get_node("MagsInRoom").interact()
	await frames(5)
	check(DialogueManager.active, "Mags talks to you in the garage")
	await skip_dialogue()
	await leave_building()

	var dock = WorldManager.current_room.get_node("ChargingDock")
	player.health.damage(2)
	dock.interact(player)
	await frames(3)
	check(player.health.current == player.health.max_health, "dock heals")
	check(GameState.respawn_room.ends_with("heap_02_camp.tscn"), "dock sets respawn")
	check(SaveManager.has_save(), "dock saves")
	GameState.add_chip(&"long_tether", false)
	var wire_before := player.stats.get_stat("wire_length")
	GameState.toggle_chip(&"long_tether")
	check(player.stats.get_stat("wire_length") > wire_before, "Long Tether raises wire length")
	GameState.toggle_chip(&"recall_saw")
	check(player.stats.get_stat("recall_damage_mult") == 2.0, "Recall Saw doubles recall damage")
	GameState.add_chip(&"steam_vent", false)
	GameState.toggle_chip(&"steam_vent")
	check(GameState.is_overclocked(), "5 of 4 ports = overclocked")
	await frames(2)
	check(player.get_node("Upgrades").get_child_count() == 1, "Steam Vent effect node spawned")
	check(not GameState.can_equip(&"scrap_plating"), "can't go more than 1 port over")
	ui.open_loadout()
	await frames(3)
	var screen: LoadoutScreen = ui.find_children("*", "LoadoutScreen", true, false)[0]
	var lit := 0
	for sl in screen._socket_slots:
		if sl.socket == "lit":
			lit += 1
	check(lit == 4 and screen._socket_slots[4].socket == "over" and screen._socket_slots[4].chip_id == &"steam_vent", "loadout: 4 lit sockets plus the overclock socket in use")
	check(screen._socket_slots[0].chip == ItemDB.chips[&"long_tether"].icon, "loadout: chip emblem shows in its socket")
	check(screen._socket_slots[2].linked, "loadout: 2-port chip fills two sockets with a conduit")
	screen._on_tray(&"steam_vent")
	await frames(20)
	check(not (&"steam_vent" in GameState.equipped_chips) and not GameState.is_overclocked(), "loadout: picking a seated chip ejects it")
	screen._on_tray(&"recall_saw")
	await frames(20)
	check(not (&"recall_saw" in GameState.equipped_chips), "loadout: eject recall saw")
	screen._on_tray(&"steam_vent")
	await frames(25)
	check(&"steam_vent" in GameState.equipped_chips and screen._socket_slots[1].chip_id == &"steam_vent", "loadout: picking a tray chip inserts it into the next free socket")
	screen._on_socket(1)
	await frames(20)
	check(not (&"steam_vent" in GameState.equipped_chips), "loadout: clicking a socket ejects its chip")
	ui.open_wardrobe()
	await frames(3)
	ui._cycle_slot(CosmeticItem.Slot.CLOAK, Control.new())
	await frames(3)
	check(GameState.outfit.has(CosmeticItem.Slot.CLOAK), "wardrobe cycles cloak")
	await ui.close()

	GameState.equipped_chips.clear()
	EventBus.loadout_changed.emit()
	await WorldManager.change_room("res://scenes/rooms/heap/heap_03_intake.tscn", &"from_camp")
	await frames(10)
	var arena = WorldManager.current_room.get_node("BossArena")
	var boss: IntakeCrane = arena.get_node("IntakeCrane")
	check(boss.state == IntakeCrane.S.IDLE, "boss waits until you walk in")
	player.global_position = Vector2(200, 320)
	await frames(5)
	check(DialogueManager.active, "boss intro plays")
	await skip_dialogue()
	await frames(10)
	check(boss.state != IntakeCrane.S.IDLE, "boss fight starts")
	check(AudioManager.current_track() == "boss_final", "the crane fights to its own boss track")
	check(arena._door != null, "arena door shuts")
	check(not boss._hurtbox.take_hit(1, player.global_position), "raised boss is armoured")
	var boss_was = boss.state
	boss.set_physics_process(false)
	player.global_position = Vector2(30, 320)
	player.velocity = Vector2.ZERO
	await frames(10)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(16)
	Input.action_release("jump")
	await frames(6)
	Input.action_release("move_right")
	await frames(30)
	check(player.is_on_floor() and absf(player.global_position.y - 272.0) < 2.0, "Intake side platform reachable by jump (y=%.0f)" % player.global_position.y)
	boss.set_physics_process(true)
	boss._enter(IntakeCrane.S.TRACK)
	boss.head = Vector2(320, IntakeCrane.UP_Y)
	player.global_position = Vector2(300, 236)
	player.velocity = Vector2.ZERO
	await frames(2)
	player.facing = 1
	player.aim_vector = Vector2.UP
	player.throw_blade()
	var glanced := false
	for i in 40:
		await frames(1)
		if player.blade and player.blade.mode == Blade.Mode.RETURNING:
			glanced = true
			break
	check(glanced and boss.hp == IntakeCrane.MAX_HP, "blade glances off armour, no damage")
	await frames(40)
	player.global_position = Vector2(100, 320)
	var reached_stuck := false
	for i in 400:
		await frames(1)
		if boss.state == IntakeCrane.S.STUCK:
			reached_stuck = true
			break
	check(reached_stuck, "boss tracks, warns and slams on its own")
	check(boss.is_vulnerable(), "core open after slam")
	var guard := 0
	while boss.hp > 0 and guard < 60:
		guard += 1
		if boss.state != IntakeCrane.S.STUCK:
			boss._enter(IntakeCrane.S.STUCK)
		boss._hurtbox.take_hit(2, boss.head + Vector2(-20, 0))
		await frames(2)
	check(boss._phase2, "phase 2 triggered at half health")
	await get_tree().create_timer(2.0).timeout
	check(GameState.flags.get("boss_intake_defeated", false), "boss defeated flag saved")
	check(arena._door == null, "door reopens after the fight")
	await frames(5)
	var shard_node = null
	for c in arena.get_children():
		if c is Collectible and c.kind == Collectible.Kind.SHARD:
			shard_node = c
	check(shard_node != null, "Shard I drops")
	if shard_node:
		player.global_position = shard_node.global_position + Vector2(0, 14)
		await frames(10)
	check(GameState.has_shard(1), "Shard I collected")
	await skip_dialogue()
	await WorldManager.change_room("res://scenes/rooms/heap/heap_02_camp.tscn", &"from_intake")
	await WorldManager.change_room("res://scenes/rooms/heap/heap_03_intake.tscn", &"from_camp")
	await frames(5)
	check(WorldManager.current_room.get_node("BossArena/IntakeCrane").state == IntakeCrane.S.WRECKED, "beaten boss stays beaten")
	await WorldManager.change_room(TEST_PIT, &"from_camp")
	await frames(5)
	var wall = WorldManager.current_room.get_node_or_null("ScrapWall")
	check(wall != null, "scrap wall still there before hitting it")
	if wall:
		wall._hurtbox.take_hit(1, wall.global_position)
		await frames(3)
		check(not is_instance_valid(wall) or wall.is_queued_for_deletion(), "Shard I splits the scrap wall")
	player.global_position = Vector2(1124, 214)
	await frames(10)
	check(&"scrap_plating" in GameState.owned_chips, "reward behind the wall collected")
	await WorldManager.change_room("res://scenes/rooms/heap/heap_02_camp.tscn", &"dock")
	await frames(5)

	Fx.shake_enabled = false
	Fx.save_settings()
	Fx.shake_enabled = true
	Fx._ready()
	check(Fx.shake_enabled == false, "screen-shake setting persists")
	Fx.shake_enabled = true
	Fx.save_settings()

	await frames(5)
	GameState.add_scrap(30)
	var scrap_before := GameState.scrap
	player.global_position = Vector2(200, 336)
	await frames(5)
	player.health.damage(99)
	await frames(5)
	check(player.is_dead and GameState.scrap == 0, "death drops scrap")
	await get_tree().create_timer(3.0).timeout
	check(not player.is_dead, "respawned")
	check(player.global_position.distance_to(Vector2(480, 336)) < 20, "respawned at dock")
	check(GameState.lost_scrap.get("amount", 0) == scrap_before, "lost scrap remembered")
	check(toasts.any(func(t): return t.begins_with("Dropped %d scrap" % scrap_before)), "death tells you what you dropped")
	GameState.add_scrap(12)
	player.health.damage(99)
	await frames(5)
	check(toasts.any(func(t): return t.begins_with("Your earlier dropped scrap")), "second death warns the old drop is gone")
	await get_tree().create_timer(3.0).timeout
	check(GameState.lost_scrap.get("amount", 0) == 12, "newest drop is the one remembered")

	var L: Lineage = load("res://data/lineages/heapfolk.tres")
	var a := NPCLook.build(L, NPCLook.roll(L, 1234, "adult", {}))[0].get_image()
	var a2 := NPCLook.build(L, NPCLook.roll(L, 1234, "adult", {}))[0].get_image()
	var b := NPCLook.build(L, NPCLook.roll(L, 5678, "adult", {}))[0].get_image()
	check(a.get_data() == a2.get_data(), "same resident looks the same every time")
	check(a.get_data() != b.get_data(), "two residents of one family are not twins")
	var lens_found := 0
	for img in [a, b]:
		var found := false
		for y in NPCLook.H:
			for x in NPCLook.W:
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0 and absf(c.r - L.lens_color.r) < 0.02 and absf(c.g - L.lens_color.g) < 0.02 and absf(c.b - L.lens_color.b) < 0.02:
					found = true
		if found:
			lens_found += 1
	check(lens_found == 2, "every resident carries the family's amber lens")

	SaveManager.save_game()
	var snapshot := JSON.stringify(GameState.to_dict())
	GameState.reset()
	SaveManager.load_game()
	check(JSON.stringify(GameState.to_dict()) == snapshot, "save/load round trip identical")

	print("\nSMOKE TEST DONE: %d failure(s)" % fails)
	SaveManager.delete_save()
	get_tree().quit(1 if fails > 0 else 0)


func _make_arena() -> StaticBody2D:
	var body := StaticBody2D.new()
	for r in [Rect2(0, 2400, 3000, 40), Rect2(-40, 1600, 40, 840), Rect2(3000, 1600, 40, 840)]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)
	WorldManager.current_room.add_child(body)
	return body


func _put(pos: Vector2, vel := Vector2.ZERO) -> void:
	player.global_position = pos
	player.velocity = vel
	player.state_machine.transition("idle" if vel == Vector2.ZERO else "fall")


func _jump_distance(slide: bool) -> float:
	_put(Vector2(200, 2400))
	await frames(4)
	Input.action_press("move_right")
	await frames(24)
	if slide:
		Input.action_press("slide")
		await frames(10)
	var x_takeoff := player.global_position.x
	Input.action_press("jump")
	await frames(3)
	if slide:
		Input.action_release("slide")
	for k in 120:
		await frames(1)
		if player.is_on_floor() and k > 4:
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	return player.global_position.x - x_takeoff


func _movement_checks() -> void:
	var arena := _make_arena()
	_put(Vector2(200, 2400))
	await frames(4)
	Input.action_press("move_right")
	await frames(24)
	var run_speed := player.velocity.x
	check(run_speed > 170.0 and run_speed < 195.0, "runs at the new top speed (~1.5x: %.0f px/s)" % run_speed)
	Input.action_press("slide")
	await frames(6)
	check(player.state_machine.current_name() == "slide" and player.is_low, "the slide key drops into a slide (low hitbox)")
	await frames(40)
	check(player.state_machine.current_name() == "slide" and absf(player.velocity.x) >= 265.0, "a held slide keeps its speed (%.0f px/s)" % player.velocity.x)
	Input.action_release("slide")
	Input.action_release("move_right")
	await frames(10)
	check(not player.is_low, "letting go of slide stands back up")
	var plain := await _jump_distance(false)
	var slid := await _jump_distance(true)
	check(slid > plain * 1.5, "a slide-jump goes much farther than a running jump (%.0f vs %.0f px)" % [slid, plain])
	_put(Vector2(1500, 2100), Vector2(420, 0))
	await frames(15)
	check(player.velocity.x > 340.0, "speed above a run is kept in the air (420 -> %.0f px/s after 0.25 s)" % player.velocity.x)
	_put(Vector2(2990, 2200), Vector2(0, 60))
	Input.action_press("move_right")
	await frames(12)
	check(player.state_machine.current_name() == "wall_slide" and player.velocity.y <= 111.0, "holding into a wall while falling slides down it slowly")
	Input.action_release("move_right")
	await press("jump")
	await frames(2)
	check(player.velocity.x < -150.0 and player.velocity.y < 0.0 and player.wall_jumps_left == Player.MAX_WALL_JUMPS - 1, "jump kicks off the wall, up and away")
	var kicks := 1
	for k in 4:
		_put(Vector2(2993, 2150), Vector2(0, 20))
		await frames(2)
		if player.try_wall_jump():
			kicks += 1
	check(kicks == Player.MAX_WALL_JUMPS, "wall jumps are limited to %d before you land (got %d)" % [Player.MAX_WALL_JUMPS, kicks])
	_put(Vector2(1000, 2400))
	await frames(6)
	check(player.wall_jumps_left == Player.MAX_WALL_JUMPS, "landing gives the wall jumps back")
	_put(Vector2(400, 2400))
	await frames(10)
	player.dash_cooldown.stop()
	await press("dash")
	await frames(2)
	await press("jump")
	await frames(3)
	check(player.velocity.y < 0.0 and absf(player.velocity.x) > 300.0, "jumping out of a ground dash keeps its speed (%.0f px/s)" % absf(player.velocity.x))
	await frames(60)
	player.health.damage(2)
	var hp := player.health.current
	player.heal_charge = 0
	for k in Player.CLOSE_HITS_TO_HEAL:
		player.register_close_hit()
	check(player.health.current == hp + 1 and player.heal_charge == 0, "every %d hits up close heal a cell (%d -> %d)" % [Player.CLOSE_HITS_TO_HEAL, hp, player.health.current])
	player.health.refill()
	arena.queue_free()
	_put(Vector2(110, 432))
	await frames(10)
