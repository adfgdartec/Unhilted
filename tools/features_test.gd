extends Node

var fails := 0
var main: Node
var player: Player


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func skip_dialogue() -> void:
	for i in 120:
		if not DialogueManager.active:
			return
		DialogueManager._close()
		await frames(2)


func has_key(action: String, code: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == code:
			return true
	return false


func has_mouse(action: String, b: MouseButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and e.button_index == b:
			return true
	return false


func has_pad(action: String) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var saved_preset := Fx.control_preset
	var saved_custom := Fx.custom_binds.duplicate()
	Fx.control_preset = "standard"
	Fx.custom_binds = {}
	Fx.apply_controls()
	check(has_key("jump", KEY_SPACE) and has_mouse("attack", MOUSE_BUTTON_RIGHT) and has_key("move_left", KEY_A), "Standard scheme: Space jumps, right click attacks, WASD moves")
	Fx.control_preset = "arrows"
	Fx.apply_controls()
	check(has_key("jump", KEY_Z) and has_key("attack", KEY_X) and has_key("throw", KEY_C) and not has_key("jump", KEY_SPACE), "Arrows + Z X C scheme rebinds jump / attack / throw")
	check(has_key("aim_left", KEY_LEFT) and has_key("aim_up", KEY_UP), "...and aiming follows the arrow keys")
	check(has_pad("jump") and has_pad("attack") and has_pad("move_left"), "...and the gamepad still works")
	Fx.control_preset = "jkl"
	Fx.apply_controls()
	check(has_key("attack", KEY_J) and has_key("jump", KEY_K) and has_key("throw", KEY_L), "WASD + J K L scheme")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	Fx.custom_binds = {"jump": [Keybinds.describe_event(ev)]}
	Fx.apply_controls()
	check(has_key("jump", KEY_F) and not has_key("jump", KEY_K), "a custom key replaces the scheme's key for that action")
	check("F" in Keybinds.summary(Fx.control_preset, Fx.custom_binds), "...and shows up in the controls line")
	Fx.control_preset = saved_preset
	Fx.custom_binds = saved_custom
	Fx.apply_controls()

	SaveManager.delete_save()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(10)
	player = main.get_node("World/Player")
	main.get_node("TitleScreen").demo_run_requested.emit()
	await frames(60)
	await skip_dialogue()

	var pads_total := 0
	var pad_rooms := 0
	for rid in ["heap_01_pit", "heap_02_camp", "heap_05_fields", "heap_07_crane", "heap_08_conveyor"]:
		var spawn: StringName = &"start" if rid == "heap_01_pit" else &""
		await WorldManager.change_room("res://scenes/rooms/heap/%s.tscn" % rid, WorldManager.current_room.find_children("*", "Marker2D", true, false)[0].name if false else &"")
		for i in 40:
			await frames(1)
			if not WorldManager.is_busy():
				break
		await frames(6)
		await skip_dialogue()
		var n := WorldManager.current_room.find_children("*", "BouncePad", true, false).size()
		print("      %s: %d pad(s)" % [rid, n])
		pads_total += n
		if n > 0:
			pad_rooms += 1
	check(pad_rooms >= 3, "scrap spring pads are placed through the route (%d pads in %d rooms)" % [pads_total, pad_rooms])
	var pad: BouncePad = null
	for c in WorldManager.current_room.find_children("*", "BouncePad", true, false):
		pad = c
	if pad == null:
		var bp := BouncePad.new()
		bp.position = player.position + Vector2(0, 0)
		WorldManager.current_room.add_child(bp)
		pad = bp
	player.velocity = Vector2.ZERO
	pad.launch(player)
	check(player.velocity.y <= -400.0, "a pad bounces you higher than a jump")
	await frames(30)

	player.hurtbox.invulnerable = false
	player.rebound_until = 0.0
	check(not player.rebound_ready(), "no Rebound charge to start with")
	player._on_hurt(1, player.global_position + Vector2(20, 0), null)
	check(player.rebound_ready(), "getting hit charges a Rebound Strike")
	player.health.refill()
	await frames(30)
	player.state_machine.transition("attack")
	await frames(2)
	var base := int(player.stats.get_stat("melee_damage"))
	check(player.melee_hitbox.damage >= base * 2, "...and the next attack hits for double (%d vs %d)" % [player.melee_hitbox.damage, base])
	check(not player.rebound_ready(), "...spending the charge")
	await frames(30)
	player.hurtbox.invulnerable = false

	var room_before := WorldManager.current_room.room_id
	var ok_all := true
	var bounced := true
	for i in 4:
		player.health.damage(99)
		await frames(5)
		if i == 0:
			check(Engine.time_scale < 0.9, "dying slows the world for a beat")
		for k in 500:
			await frames(1)
			if k > 30 and not player.is_dead and not WorldManager.is_busy():
				break
		await skip_dialogue()
		if player.is_dead or WorldManager.current_room.room_id != room_before:
			ok_all = false
		await frames(2)
		if not (player.visuals._pop >= 0.0 or player.velocity.y < 0.0):
			bounced = false
		await frames(50)
	check(ok_all, "four deaths in a row: each one respawns (no limit)")
	check(bounced, "respawning bounces back up (squash, hop, settle)")
	check(is_equal_approx(Engine.time_scale, 1.0), "time runs normally again after respawning")

	await WorldManager.change_room("res://scenes/rooms/heap/heap_03_intake.tscn", &"from_camp")
	await frames(20)
	await skip_dialogue()
	player.hurtbox.invulnerable = true
	var boss: IntakeCrane = WorldManager.current_room.get_node("BossArena/IntakeCrane")
	if boss.state in [IntakeCrane.S.IDLE, IntakeCrane.S.PARKED]:
		boss.start(player)
	await frames(5)
	player.global_position = Vector2(120, 318)
	boss._cycle = 1
	boss.head.y = IntakeCrane.UP_Y
	boss._next_attack()
	check(boss.state == IntakeCrane.S.THROW_GRAB, "INTAKE UNIT 7 can grab a block to throw")
	var thrown: Projectile = null
	for i in 240:
		await frames(1)
		for c in WorldManager.current_room.find_children("*", "Area2D", true, false):
			if c is Projectile and c.shatter > 0:
				thrown = c
		if thrown:
			break
	check(thrown != null, "...aims, then throws it")
	if thrown:
		var to_player := (player.global_position + Vector2(0, -12)) - thrown.global_position
		check(thrown.velocity.normalized().dot(to_player.normalized()) > 0.8, "...straight at the robot")
		check(not thrown.deflectable, "...it can't be swatted to bits: dodge it, or bounce it back")
	var frags := 0
	for i in 200:
		await frames(1)
		frags = 0
		for c in WorldManager.current_room.find_children("*", "Area2D", true, false):
			if c is Projectile and c.size < 1.0:
				frags += 1
		if frags >= 3:
			break
	check(frags >= 3, "the block shatters into skidding fragments: a second dodge")
	await frames(90)
	boss._cycle = 1
	boss._throws_left = 0
	boss.state = IntakeCrane.S.RISE
	boss.head.y = IntakeCrane.UP_Y
	boss._next_attack()
	thrown = null
	for i in 240:
		await frames(1)
		for c in WorldManager.current_room.find_children("*", "Area2D", true, false):
			if c is Projectile and c.shatter > 0 and not c.returned:
				thrown = c
		if thrown:
			break
	var hp_before := boss.hp
	if thrown:
		await frames(4)
		check(thrown.bounce_back, "the thrown block can be bounced back")
		thrown._bounce_back()
		for i in 120:
			await frames(1)
			if not is_instance_valid(thrown):
				break
	check(boss.hp <= hp_before - IntakeCrane.RETURN_DAMAGE, "bounced back, it hits the crane through its armour (%d -> %d)" % [hp_before, boss.hp])
	check(boss.state == IntakeCrane.S.STUCK or boss.state == IntakeCrane.S.DYING, "...and knocks its core open")

	if boss.state != IntakeCrane.S.DYING and boss.hp > 0:
		boss._phase2 = true
		boss._cycle = 0
		boss.state = IntakeCrane.S.RISE
		boss.head.y = IntakeCrane.UP_Y
		boss._next_attack()
		check(boss.state == IntakeCrane.S.LASER_STEAM, "in its pink phase the crane can vent steam for a laser attack")
		var fired := false
		var steam_full := false
		for i in 300:
			await frames(1)
			if boss.state == IntakeCrane.S.LASER_AIM and boss._steam >= 0.99:
				steam_full = true
			if boss.state == IntakeCrane.S.LASER_FIRE:
				await frames(2)
				fired = boss._beam_hit[1].monitoring
				break
		check(steam_full, "...the steam fills the bottom half before the lasers aim")
		check(fired and boss._beams.size() == 3, "...then three lasers fire along the aim lines")
		if boss._beams.size() == 3:
			check(absf(boss._beams[2].x - boss._beams[1].x) >= 100.0, "...with gaps between them to stand in")

	print("\nFEATURES TEST DONE: %d failure(s)" % fails)
	get_tree().quit(1 if fails else 0)
