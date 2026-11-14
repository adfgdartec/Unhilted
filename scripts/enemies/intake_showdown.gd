class_name IntakeShowdown
extends Node2D

signal defeated

const MAX_HP := 12
const SHARD_POS := Vector2(334, 292)
const LEDGES := [
	[Vector2(150, 272), 64.0], [Vector2(490, 272), 64.0],
	[Vector2(262, 226), 48.0], [Vector2(378, 226), 48.0],
]
const PADS := [Vector2(212, 320), Vector2(428, 320)]

var governor: GreatGovernor
var crane: IntakeCrane
var phase := "idle"
var player: Player
var _shard_glow := false
var _shard_at := SHARD_POS
var _t := 0.0


func _ready() -> void:
	if not DemoMode.enabled():
		var arena := get_parent()
		arena.boss_path = ^"IntakeCrane"
		arena.boss_name = "INTAKE UNIT 7"
		arena.victory_text = ""
		arena.intro_lines = Array(["> FOREIGN OBJECT ON INTAKE FLOOR.", "> CLASSIFICATION: SCRAP. MODEL: UNKNOWN. AGE: UNKNOWN.", "> RESUMING PROCESSING."], TYPE_STRING, "", null)
		queue_free()
		return
	crane = get_parent().get_node("IntakeCrane")
	crane.park()
	crane.defeated.connect(_on_crane_defeated)
	governor = GreatGovernor.new()
	governor.intake = true
	governor.max_hp = MAX_HP
	governor.hp = MAX_HP
	add_child(governor)
	governor.defeated.connect(_cutscene)
	for l in LEDGES:
		var p := CrumblePlatform.new()
		p.width = l[1]
		p.position = l[0]
		get_parent().add_child.call_deferred(p)
		governor.platforms.append(p)
	for x in PADS:
		var pad := BouncePad.new()
		pad.position = x
		get_parent().add_child.call_deferred(pad)


func start(p: Player) -> void:
	player = p
	phase = "governor"
	governor.start(p)
	AudioManager.set_music_pitch(1.0, 0.5)


func set_wrecked() -> void:
	phase = "done"
	crane.set_wrecked()
	if governor:
		governor.queue_free()
		governor = null
	for c in get_parent().get_children():
		if c is CrumblePlatform:
			c.queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _move_head(to: Vector2, time: float, trans := Tween.TRANS_SINE, carry: Node2D = null) -> void:
	var from := crane.head
	var offset := carry.position - from if carry else Vector2.ZERO
	var tw := create_tween()
	tw.tween_method(func(v: Vector2):
		crane.head = v
		if carry and is_instance_valid(carry):
			carry.position = v + offset
		if _shard_follow:
			_shard_at = v + Vector2(0, 34)
	, from, to, time).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


var _shard_follow := false


func _cutscene() -> void:
	phase = "cutscene"
	GameState.lock_ui()
	AudioManager.keep_music_on_boss_end = true
	EventBus.boss_ended.emit()
	AudioManager.set_music_pitch(0.8, 1.6)
	await _wait(0.9)
	_shard_glow = true
	AudioManager.sfx(&"heal", -2.0)
	Fx.ring(to_global(SHARD_POS), Color(0.45, 0.95, 1.0), 26.0, 0.5)
	await _wait(1.4)
	AudioManager.set_override("silence")
	AudioManager.sfx(&"horn")
	Fx.shake(3.0)
	crane.state = IntakeCrane.S.CUTSCENE
	await _move_head(Vector2(IntakeCrane.CENTER_X, IntakeCrane.UP_Y), 1.0)
	await _wait(0.35)
	crane.claw_closed = true
	await _move_head(Vector2(IntakeCrane.CENTER_X, IntakeCrane.SLAM_Y), 0.16, Tween.TRANS_QUAD)
	governor.smash()
	AudioManager.sfx(&"slam", 4.0)
	Fx.shake(10.0)
	Fx.hit_stop(0.15)
	Fx.burst(to_global(Vector2(IntakeCrane.CENTER_X, IntakeCrane.FLOOR_Y - 10)), Color(1.0, 0.75, 0.4), 40)
	Fx.dust(to_global(Vector2(IntakeCrane.CENTER_X - 40, IntakeCrane.FLOOR_Y)), 2.5)
	Fx.dust(to_global(Vector2(IntakeCrane.CENTER_X + 40, IntakeCrane.FLOOR_Y)), 2.5)
	if Fx.post:
		Fx.post.hit()
	await _wait(0.7)
	await _move_head(Vector2(IntakeCrane.CENTER_X - 30, IntakeCrane.SLAM_Y - 6), 0.3, Tween.TRANS_SINE, governor)
	await _move_head(Vector2(720, IntakeCrane.UP_Y + 30), 1.6, Tween.TRANS_SINE, governor)
	governor.queue_free()
	governor = null
	crane.claw_closed = false
	await _wait(0.4)
	await _move_head(Vector2(SHARD_POS.x, IntakeCrane.UP_Y), 1.1)
	await _move_head(Vector2(SHARD_POS.x, SHARD_POS.y - 34), 0.6)
	crane.claw_closed = true
	_shard_follow = true
	AudioManager.sfx(&"valve", -2.0)
	await _wait(0.3)
	await _move_head(Vector2(IntakeCrane.CENTER_X, IntakeCrane.UP_Y), 0.9)
	_shard_follow = false
	for i in 6:
		_shard_at = _shard_at.lerp(crane.head, 0.45)
		await _wait(0.06)
	_shard_glow = false
	crane.empowered = true
	crane.claw_closed = false
	AudioManager.sfx(&"charged", 4.0)
	Fx.burst(to_global(crane.head), Color(0.45, 0.95, 1.0), 40)
	Fx.ring(to_global(crane.head), Color(0.45, 0.95, 1.0), 90.0, 0.6, 3.0)
	Fx.shake(8.0)
	if Fx.post:
		Fx.post.hit()
	AudioManager.set_music_pitch(1.0, 0.1)
	await DialogueManager.say(["> ITEM OF VALUE RECOVERED.", "> INTEGRATING...  POWER OUTPUT: EXCEEDING SPECIFICATION.",
		"> FOREIGN OBJECT STILL ON INTAKE FLOOR.  RESUMING PROCESSING."], "INTAKE UNIT 7")
	GameState.unlock_ui()
	phase = "crane"
	EventBus.boss_started.emit("INTAKE UNIT 7", IntakeCrane.MAX_HP)
	crane.start(player if player else WorldManager.player)


func _on_crane_defeated() -> void:
	phase = "done"
	AudioManager.set_music_pitch(1.0, 1.5)
	defeated.emit()


func _draw() -> void:
	if not _shard_glow:
		return
	var p := _shard_at + Vector2(0, sin(_t * 3.0) * 2.0)
	var g := 0.6 + 0.4 * sin(_t * 6.0)
	draw_circle(p, 14.0, Color(0.45, 0.95, 1.0, 0.12 * g))
	draw_circle(p, 8.0, Color(0.45, 0.95, 1.0, 0.25 * g))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(0, 7), p + Vector2(-4, 0)]), Color(0.7, 1.0, 1.0))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(0, 0)]), Color(1, 1, 1))
