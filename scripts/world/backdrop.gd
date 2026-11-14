class_name Backdrop
extends Node2D
## Parallax background drawn behind a room. Each layer is a 640-wide texture
## that wraps horizontally and scrolls at its own fraction of the camera
## (0 = fixed to the screen, like the sky; higher = closer).
##
## Entries starting with "fx:" are live effects drawn between the layers:
##   fx:sun      a slow-breathing glow round the Heap's smog sun
##   fx:smog     two copies of heap_smog.png drifting at different speeds
##   fx:windows  some of the city's lit windows flicker on and off
##   fx:birds    now and then a few birds cross the far sky
##   fx:embers / fx:dust / fx:motes  drifting particles (warm embers outside,
##               falling grit in the cave, dust hanging in the Intake's light)

const SETS := {
	"heap_outdoor": [
		["res://art/backdrops/heap_sky.png", 0.0],
		["fx:sun", 0.0],
		["fx:smog", 0.03],
		["res://art/backdrops/heap_city.png", 0.06],
		["fx:windows", 0.06],
		["fx:birds", 0.08],
		["res://art/backdrops/heap_far.png", 0.2],
		["res://art/backdrops/heap_near.png", 0.42],
		["fx:embers", 0.6],
	],
	"heap_cave": [
		["res://art/backdrops/cave_far.png", 0.1],
		["res://art/backdrops/cave_mid.png", 0.3],
		["fx:dust", 0.5],
	],
	"intake_interior": [
		["res://art/backdrops/intake_wall.png", 0.12],
		["res://art/backdrops/intake_girders.png", 0.3],
		["fx:motes", 0.45],
	],
	"uw_vault": [
		["res://art/backdrops/uw_far.png", 0.08],
		["res://art/backdrops/uw_mid.png", 0.26],
	],
	"uw_works": [
		["res://art/backdrops/uw_far.png", 0.08],
		["res://art/backdrops/uw_works.png", 0.22],
		["res://art/backdrops/uw_mid.png", 0.36],
	],
}

var _layers: Array = [] ## [Texture2D, factor]
var _anchor_y := 0.0     ## camera centre y at which layers sit exactly as painted
var _t := 0.0
var _smog: Texture2D
var _windows: Array[Vector2i] = []   ## lit window pixels in the city layer
var _city_w := 640.0
var _parts: Array = []               ## [pos (screen), vel, phase] for particle effects
var _part_kind := ""
var _last_center := Vector2.INF
var _bird_next := 6.0                ## seconds until the next flock
var _birds: Array = []               ## [x, y, speed, flap phase]

const SUN_POS := Vector2(470, 196)   ## where heap_sky.png paints the sun
const WINDOW := Color8(255, 196, 106)


func setup(set_name: String, room_bounds: Rect2) -> void:
	_layers.clear()
	for entry in SETS.get(set_name, []):
		var path: String = entry[0]
		if Fx.art_variant != "":
			var alt := path.get_base_dir() + "/" + Fx.art_variant + "/" + path.get_file()
			if ResourceLoader.exists(alt):
				path = alt
		if path.begins_with("fx:"):
			_layers.append([path.substr(3), entry[1]])
			_setup_fx(path.substr(3))
			continue
		_layers.append([load(path), entry[1]])
	_anchor_y = room_bounds.end.y - 180.0
	z_index = -100
	z_as_relative = false
	light_mask = 0 # world lights must not light the distant sky and city


func _setup_fx(name: String) -> void:
	match name:
		"smog":
			if ResourceLoader.exists("res://art/backdrops/heap_smog.png"):
				_smog = load("res://art/backdrops/heap_smog.png")
		"windows":
			# find the city's lit windows once, so a few can flicker
			var city: Texture2D = load("res://art/backdrops/heap_city.png")
			var img := city.get_image()
			_city_w = img.get_width()
			for y in range(150, img.get_height()):
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.5 and absf(c.r - WINDOW.r) < 0.04 and absf(c.g - WINDOW.g) < 0.06:
						_windows.append(Vector2i(x, y))
		"embers", "dust", "motes":
			_part_kind = name
			_parts.clear()
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in (34 if name == "embers" else 26):
				_parts.append([Vector2(rng.randf() * 640.0, rng.randf() * 360.0),
					Vector2(rng.randf_range(4, 12), rng.randf_range(-6, -1)) if name == "embers"
						else Vector2(rng.randf_range(-2, 2), rng.randf_range(3, 9)) if name == "dust"
						else Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2)),
					rng.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	_update_particles(delta)
	_update_birds(delta)
	queue_redraw()


func _update_particles(delta: float) -> void:
	if _parts.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	var shift := Vector2.ZERO if _last_center == Vector2.INF else (center - _last_center)
	_last_center = center
	var view := get_viewport().get_visible_rect().size
	for p in _parts:
		var wob := Vector2(sin(_t * 0.9 + p[2]) * 3.0, cos(_t * 0.7 + p[2]) * 2.0)
		p[0] += (p[1] + wob) * delta - shift * 0.6
		p[0].x = fposmod(p[0].x, view.x)
		p[0].y = fposmod(p[0].y, view.y)


func _update_birds(delta: float) -> void:
	_bird_next -= delta
	if _bird_next <= 0.0 and _birds.is_empty() and _has("birds"):
		_bird_next = randf_range(18.0, 34.0)
		var y := randf_range(70.0, 150.0)
		var speed := randf_range(16.0, 24.0) * (1 if randf() < 0.5 else -1)
		var x0 := -20.0 if speed > 0 else 660.0
		for i in randi_range(3, 5):
			_birds.append([x0 - signf(speed) * i * randf_range(8, 14), y + randf_range(-6, 6) + i * 2.0, speed, randf() * TAU])
	for b in _birds:
		b[0] += b[2] * delta
	_birds = _birds.filter(func(b): return b[0] > -60.0 and b[0] < 720.0)


func _has(fx_name: String) -> bool:
	for layer in _layers:
		if layer[0] is String and layer[0] == fx_name:
			return true
	return false


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or _layers.is_empty():
		return
	var view := get_viewport().get_visible_rect().size
	var center := cam.get_screen_center_position()
	var top_left := center - view * 0.5
	for layer in _layers:
		if layer[0] is String:
			_draw_fx(layer[0], layer[1], center, top_left, view)
			continue
		var tex: Texture2D = layer[0]
		var f: float = layer[1]
		var w := float(tex.get_width())
		var ox := fposmod(-center.x * f, w)
		var oy := -(center.y - _anchor_y) * f * 0.35
		var x := top_left.x + ox - w
		var y := top_left.y - 20.0 + oy
		while x < top_left.x + view.x:
			draw_texture(tex, Vector2(round(x), round(y)))
			x += w



func _draw_fx(name: String, f: float, center: Vector2, top_left: Vector2, view: Vector2) -> void:
	var base := Vector2(top_left.x, top_left.y - 20.0)
	match name:
		"sun":
			# the sky layer is screen-fixed, so the sun is too; its glow breathes
			var pulse := 0.5 + 0.5 * sin(_t * 0.6)
			var c := base + SUN_POS
			for i in 4:
				draw_circle(c, 34.0 + i * 16.0 + pulse * 4.0, Color(1.0, 0.72, 0.42, 0.045 - i * 0.008))
		"smog":
			if _smog == null:
				return
			var w := float(_smog.get_width())
			for k in 2:
				var speed := 3.0 if k == 0 else 7.0
				var ox := fposmod(-center.x * (f + k * 0.03) + _t * speed, w)
				var oy := -(center.y - _anchor_y) * (f + k * 0.03) * 0.35 + (k * 18.0)
				var x := top_left.x + ox - w
				while x < top_left.x + view.x:
					draw_texture(_smog, Vector2(round(x), round(base.y + oy)), Color(1, 1, 1, 0.55 if k == 0 else 0.35))
					x += w
		"windows":
			# a scatter of the lit windows blink off and on, each on its own clock
			var ox := fposmod(-center.x * f, _city_w)
			var oy := -(center.y - _anchor_y) * f * 0.35
			for i in _windows.size():
				var phase := fposmod(_t * (0.13 + (i % 7) * 0.03) + i * 0.618, 1.0)
				if i % 3 != 0 or phase > 0.12:
					continue
				var wp := _windows[i]
				var x := top_left.x + ox - _city_w + wp.x
				while x < top_left.x + view.x:
					draw_rect(Rect2(round(x), round(base.y + oy + wp.y), 1, 1), Color8(70, 40, 60))
					x += _city_w
		"birds":
			for b in _birds:
				var p := Vector2(top_left.x + b[0], base.y + b[1])
				var up := sin(_t * 9.0 + b[3]) > 0.0
				var col := Color8(40, 26, 44)
				if up:
					draw_rect(Rect2(p + Vector2(-2, -1), Vector2(1, 1)), col)
					draw_rect(Rect2(p + Vector2(2, -1), Vector2(1, 1)), col)
				else:
					draw_rect(Rect2(p + Vector2(-2, 1), Vector2(1, 1)), col)
					draw_rect(Rect2(p + Vector2(2, 1), Vector2(1, 1)), col)
				draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
		"embers", "dust", "motes":
			for p in _parts:
				var flick := 0.5 + 0.5 * sin(_t * 3.0 + p[2] * 5.0)
				var col: Color
				match name:
					"embers": col = Color(1.0, 0.62 + flick * 0.2, 0.32, 0.35 + flick * 0.5)
					"dust": col = Color(0.75, 0.7, 0.66, 0.25 + flick * 0.25)
					_: col = Color(1.0, 0.85, 0.6, 0.18 + flick * 0.3)
				draw_rect(Rect2((top_left + p[0]).round(), Vector2(1, 1)), col)
