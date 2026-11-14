extends Node

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const POOL := 14

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track := ""
var _last_played := {}
var _override := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = &"Music"
		m.volume_db = -80.0
		add_child(m)
	apply_volumes()
	EventBus.enemy_killed.connect(func(_id, _p): sfx(&"enemy_die"))
	EventBus.boss_started.connect(func(n, _h): set_override(BOSS_TRACKS.get(n, "boss")))
	EventBus.boss_ended.connect(_on_boss_ended)


func _stream(name: StringName) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := SFX_DIR + String(name) + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s


func sfx(name: StringName, volume_db := 0.0, pitch_var := 0.06) -> void:
	var s := _stream(name)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 25:
		return
	_last_played[name] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


var keep_music_on_boss_end := false


func _on_boss_ended() -> void:
	if keep_music_on_boss_end:
		keep_music_on_boss_end = false
		return
	set_override("")
	set_music_pitch(1.0, 1.5)


const BOSS_TRACKS := {
	"THE PENDULUM": "boss_og",
	"INTAKE UNIT 7": "boss_final",
}


func music(track: String, fade := 1.2) -> void:
	_room_track = track
	_play_track(_override if _override != "" else track, fade)


var _room_track := ""

func set_override(track: String) -> void:
	_override = track
	_play_track(track if track != "" else _room_track, 0.8)


func current_track() -> String:
	return _current_track


func _play_track(track: String, fade: float) -> void:
	if track == _current_track:
		return
	_current_track = track
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -60.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if outgoing.playing:
		var tw := create_tween()
		tw.tween_property(outgoing, "volume_db", -80.0, fade)
		tw.tween_callback(outgoing.stop)
	if track == "":
		return
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tw2 := create_tween()
	tw2.tween_property(incoming, "volume_db", 0.0, fade)


var _pitch_tw: Tween
func set_music_pitch(pitch: float, time := 1.0) -> void:
	if _pitch_tw:
		_pitch_tw.kill()
	_pitch_tw = create_tween().set_parallel().set_ignore_time_scale(true)
	_pitch_tw.tween_property(_music_a, "pitch_scale", pitch, time)
	_pitch_tw.tween_property(_music_b, "pitch_scale", pitch, time)


func apply_volumes() -> void:
	_set_bus("Master", Fx.master_volume)
	_set_bus("Music", Fx.music_volume)
	_set_bus("SFX", Fx.sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
