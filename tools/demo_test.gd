extends Node
## Tests the showcase demo (scripts/demo/demo_mode.gd). Run:
##   godot --headless --path . res://tools/demo_test.tscn -- demo
## Plays the route start to finish: Under the Heap -> Camp -> Scrap Fields ->
## Crane Yard -> Conveyor Hall -> the Intake -> Shard I -> the end card, then
## checks the return to the title, side exits being shut, the per-room
## respawn, the idle reset, and that nothing was saved.
## Rooms are crossed by stepping onto each exit (the Heap bot test covers the
## platforming itself); the boss is fought through its real states.

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


func room() -> Room:
	return WorldManager.current_room


func skip_dialogue() -> void:
	for i in 120:
		if not DialogueManager.active:
			return
		DialogueManager._close()
		await frames(2)


## Step onto the exit that leads to target_room and wait for the new room.
func go_through(target: String) -> bool:
	var ex: RoomExit = null
	for n in room().find_children("*", "RoomExit", true, false):
		if n.target_room.get_file().get_basename() == target:
			ex = n
	if ex == null:
		return false
	player.global_position = ex.global_position
	player.velocity = Vector2.ZERO
	for i in 180:
		await frames(1)
		if not WorldManager.is_busy() and room().room_id == StringName(target):
			break
	await frames(15)
	await skip_dialogue()
	return room().room_id == StringName(target)


func shut(exit_name: String) -> bool:
	var ex: RoomExit = room().get_node_or_null(exit_name)
	return ex != null and not ex.monitoring and room().has_node("DemoBlock_" + exit_name)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	check(DemoMode.enabled(), "demo mode is on (launched with -- demo)")
	SaveManager.delete_save()
	main = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(10)
	player = main.get_node("World/Player")
	var title = main.get_node("TitleScreen")
	var names: Array = title.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(names == ["Play"], "the demo title has one Play button %s" % str(names))
	title.demo_run_requested.emit()
	await frames(60)
	check(DialogueManager.active, "Play opens with the wake-up scene")
	await skip_dialogue()
	check(room().room_id == &"heap_01_pit" and main.demo.running, "...under the Heap, with the demo running")
	check(not GameState.has_shard(1), "no shards yet: Shard I is the prize")
	player.hurtbox.invulnerable = true

	check(await go_through("heap_02_camp"), "Under the Heap -> Scavenger Camp")
	check(shut("ExitToUnder"), "the hatch down to the Hollow is shut for the demo")
	var doors_open: bool = room().get_node("DoorRusty").monitoring and room().get_node("DoorDot").monitoring and room().get_node("DoorMags").monitoring
	check(doors_open, "...but the walk-in buildings stay open")
	check(await go_through("heap_05_fields"), "Camp -> Scrap Fields")
	check(shut("ExitToSinkhole") and shut("ExitToGiant"), "the Sinkhole drop and the Giant's Brow path are shut")
	# dying here puts you back at this room's entrance, not the wake-up chamber
	player.hurtbox.invulnerable = false
	player.health.damage(99)
	for i in 400:
		await frames(1)
		if i > 60 and not player.is_dead and not WorldManager.is_busy():
			break
	await skip_dialogue()
	check(room().room_id == &"heap_05_fields" and not player.is_dead, "dying in the Scrap Fields respawns you in the Scrap Fields")
	player.hurtbox.invulnerable = true
	player.health.refill()
	check(await go_through("heap_07_crane"), "Scrap Fields -> Crane Yard")
	check(await go_through("heap_08_conveyor"), "Crane Yard -> Conveyor Hall")
	check(shut("ExitToPit"), "the side door to the Compactor Pit is shut")
	check(await go_through("heap_03_intake"), "Conveyor Hall -> the Intake")

	# the boss: the Governor, the crane's takeover, then the crane
	var arena = room().get_node("BossArena")
	var show: IntakeShowdown = arena.get_node("IntakeShowdown")
	var boss: IntakeCrane = arena.get_node("IntakeCrane")
	var gov: GreatGovernor = show.governor
	check(boss.state == IntakeCrane.S.PARKED, "INTAKE UNIT 7 waits up on its rail")
	check(room().find_children("*", "CrumblePlatform", true, false).size() == 4, "four girder ledges hang beside the Governor's crown")
	player.global_position = Vector2(200, 320)
	await frames(5)
	await skip_dialogue()
	await frames(10)
	check(gov.state != GreatGovernor.S.IDLE, "THE GREAT GOVERNOR spins up")
	check(main.demo.running, "...and the demo keeps going through the fight")
	player.global_position = Vector2(100, 320)
	var guard := 0
	while gov.hp > 0 and guard < 1500:
		guard += 1
		if gov.state == GreatGovernor.S.OVERPRESSURE:
			gov._hurtbox.take_hit(2, gov.to_global(GreatGovernor.HEAD))
		await frames(3)
	check(gov.hp <= 0, "the Governor goes down in its overpressure windows")
	check(gov.off_balance and gov._knocked == 3, "...knocking out its ledges as it loses balance")
	for i in 1200:
		await frames(1)
		if show.phase == "crane":
			break
		if DialogueManager.active:
			DialogueManager._close()
	check(show.phase == "crane" and boss.empowered, "the crane smashes the wreck, takes the shard and absorbs it")
	check(not is_instance_valid(show.governor) or show.governor == null, "...after hauling the wreckage away")
	await skip_dialogue()
	await frames(10)
	check(boss.state != IntakeCrane.S.PARKED and boss.state != IntakeCrane.S.CUTSCENE, "then INTAKE UNIT 7 attacks")
	guard = 0
	while boss.hp > 0 and guard < 900:
		guard += 1
		if boss.state == IntakeCrane.S.STUCK:
			boss._hurtbox.take_hit(2, boss.head + Vector2(-20, 0))
		await frames(3)
	check(boss.hp <= 0, "the empowered crane goes down between its slams")
	await get_tree().create_timer(2.5).timeout
	var shard_node = null
	for c in arena.get_children():
		if c is Collectible and c.kind == Collectible.Kind.SHARD:
			shard_node = c
	check(shard_node != null, "Shard I drops")
	if shard_node:
		player.global_position = shard_node.global_position + Vector2(0, 14)
	await frames(20)
	check(GameState.has_shard(1) and DialogueManager.active, "picking it up plays the attach scene")
	check(main.demo._card == null, "...and the demo waits for it to finish")
	await skip_dialogue()
	await get_tree().create_timer(2.5, true).timeout
	check(get_tree().paused and main.demo._card != null, "then the demo ends on its card")
	await get_tree().create_timer(7.0, true).timeout
	await frames(40)
	check(title.visible and not main.demo.running and not get_tree().paused, "...and goes back to the title")

	# idle reset
	title.demo_run_requested.emit()
	await frames(60)
	await skip_dialogue()
	main.demo._idle = DemoMode.IDLE_RESET + 1.0
	await frames(80)
	check(title.visible and not main.demo.running, "leaving it alone resets to the title")
	check(not SaveManager.has_save(), "nothing was saved")
	print("\nDEMO TEST DONE: %d failure(s)" % fails)
	get_tree().quit(1 if fails else 0)
