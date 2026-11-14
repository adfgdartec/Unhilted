extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DUST := preload("res://scripts/effects/dust_fx.gd")
const RING := preload("res://scripts/effects/ring_fx.gd")
const SLASH := preload("res://scripts/effects/slash_fx.gd")
const AFTERIMAGE := preload("res://scripts/effects/afterimage_fx.gd")
const NUMBER := preload("res://scripts/effects/damage_number_fx.gd")

var art_variant := ""
var shake_enabled := true
var hitstop_enabled := true
var post_enabled := true
var flashes_enabled := true
var click_throw := false
var fullscreen := false
var master_volume := 0.9
var music_volume := 0.7
var sfx_volume := 0.9
var damage_numbers := true
var flick_sensitivity := 1
var control_preset := "standard"
var custom_binds := {}
var post: PostFX

var _light_tex: GradientTexture2D


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		shake_enabled = cfg.get_value("accessibility", "screen_shake", true)
		hitstop_enabled = cfg.get_value("accessibility", "hit_stop", true)
		post_enabled = cfg.get_value("accessibility", "post_effects", true)
		flashes_enabled = cfg.get_value("accessibility", "flashes", true)
		click_throw = cfg.get_value("controls", "click_throw", false)
		fullscreen = cfg.get_value("display", "fullscreen", false)
		master_volume = cfg.get_value("audio", "master", 0.9)
		music_volume = cfg.get_value("audio", "music", 0.7)
		sfx_volume = cfg.get_value("audio", "sfx", 0.9)
		damage_numbers = cfg.get_value("display", "damage_numbers", true)
		flick_sensitivity = clampi(cfg.get_value("controls", "flick_sensitivity", 1), 0, 2)
		control_preset = cfg.get_value("controls", "preset", "standard")
		if not control_preset in Keybinds.PRESET_ORDER:
			control_preset = "standard"
		custom_binds = cfg.get_value("controls", "custom", {})
	apply_controls()
	apply_display.call_deferred()


func apply_controls() -> void:
	Keybinds.apply(control_preset, custom_binds)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("accessibility", "screen_shake", shake_enabled)
	cfg.set_value("accessibility", "hit_stop", hitstop_enabled)
	cfg.set_value("accessibility", "post_effects", post_enabled)
	cfg.set_value("accessibility", "flashes", flashes_enabled)
	cfg.set_value("controls", "click_throw", click_throw)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "damage_numbers", damage_numbers)
	cfg.set_value("controls", "flick_sensitivity", flick_sensitivity)
	cfg.set_value("controls", "preset", control_preset)
	cfg.set_value("controls", "custom", custom_binds)
	cfg.save(SETTINGS_PATH)
	if post:
		post.apply_settings()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").apply_volumes()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_display()
	save_settings()


func flick_scale() -> float:
	return [1.35, 1.0, 0.7][flick_sensitivity]


func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 128
		_light_tex.height = 128
	return _light_tex


func make_light(color: Color, radius: float, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 64.0
	return l


func hit_stop(duration := 0.06, time_scale := 0.05) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func shake(strength := 3.0) -> void:
	if shake_enabled:
		EventBus.camera_shake.emit(strength)


func _spawn(node: Node2D, at_position: Vector2) -> Node2D:
	var room := WorldManager.current_room
	if room == null:
		node.free()
		return null
	room.add_child(node)
	node.global_position = at_position
	return node


func _spawn_particles(p: CPUParticles2D, at_position: Vector2) -> void:
	if _spawn(p, at_position):
		p.emitting = true
		p.finished.connect(p.queue_free)


func damage_number(at_position: Vector2, amount: int) -> void:
	if not damage_numbers or amount <= 0:
		return
	var n: Node2D = NUMBER.new()
	n.amount = amount
	_spawn(n, at_position)


func float_text(at_position: Vector2, text: String, color := Color(0.45, 0.95, 1.0)) -> void:
	var n: Node2D = NUMBER.new()
	n.word = text
	n.word_color = color
	_spawn(n, at_position)


func spark(at_position: Vector2, color := Color.WHITE, count := 8) -> void:
	_spawn_particles(FxParticles.burst(color, count, 140.0), at_position)
	ring(at_position, color, 8.0, 0.12, 2.0)


func burst(at_position: Vector2, color := Color(1.0, 0.7, 0.35), count := 22) -> void:
	_spawn_particles(FxParticles.burst(color, count, 190.0), at_position)
	_spawn_particles(FxParticles.burst(Color(0.6, 0.58, 0.62), count / 2, 110.0, 300.0), at_position)
	ring(at_position, color, 26.0, 0.3, 2.0)


func ring(at_position: Vector2, color := Color.WHITE, radius := 24.0, duration := 0.35, width := 2.0) -> void:
	var r: Node2D = RING.new()
	r.color = color
	r.radius = radius
	r.duration = duration
	r.width = width
	_spawn(r, at_position)


func dust(at_position: Vector2, strength := 1.0) -> void:
	var d: Node2D = DUST.new()
	_spawn(d, at_position)
	_spawn_particles(FxParticles.puff(Color(0.75, 0.7, 0.72, 0.6), int(6 * strength), 50.0 * strength), at_position)


func slash(at_position: Vector2, direction_angle: float, reach := 24.0, flip := false) -> void:
	var s: Node2D = SLASH.new()
	s.reach = reach
	s.flip = flip
	s.rotation = direction_angle
	_spawn(s, at_position)


func afterimage(player: Node2D, visuals: PlayerVisuals) -> void:
	var holder: Node2D = AFTERIMAGE.new()
	var ghost := PlayerVisuals.new()
	ghost.preview = true
	ghost.preview_gender = GameState.gender
	ghost.scale = visuals.scale
	ghost.use_parent_material = true
	holder.add_child(ghost)
	holder.modulate = Color(0.35, 0.95, 1.0, 0.55)
	if _spawn(holder, player.global_position):
		ghost.refresh(GameState.outfit)
		ghost.blade_in_hand = visuals.blade_in_hand
		ghost.freeze_frame(visuals.anim, visuals.current_frame())
