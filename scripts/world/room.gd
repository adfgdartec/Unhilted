@tool
class_name Room
extends Node2D

@export var room_id: StringName = &"room"
@export var region_id: StringName = &"heap"
@export var display_name := ""
@export var bounds := Rect2(0, 0, 640, 360):
	set(v):
		bounds = v
		queue_redraw()
@export var solids: Array[Rect2] = []:
	set(v):
		solids = v
		queue_redraw()
@export var solid_styles: PackedStringArray = []:
	set(v):
		solid_styles = v
		queue_redraw()
@export_enum("heap_scrap", "heap_industrial") var tileset := "heap_scrap":
	set(v):
		tileset = v
		queue_redraw()
@export_enum("heap_outdoor", "heap_cave", "intake_interior", "uw_vault", "uw_works", "none") var backdrop := "heap_outdoor"
@export_group("Atmosphere")
@export var music := ""
@export var ambient := Color(0.62, 0.6, 0.74)
@export var grade: StringName = &"heap"
@export_enum("none", "rain") var weather := "none"
@export var motes_color := Color(0.85, 0.75, 0.8, 0.35)
@export var motes_amount := 40
@export_group("")
@export var bg_top := Color("191b29")
@export var bg_bottom := Color("2a2233")

const COLLECTIBLE_SCENE := preload("res://scenes/world/collectible.tscn")
const TILESETS := {
	"heap_scrap": preload("res://art/tiles/heap_scrap.png"),
	"heap_industrial": preload("res://art/tiles/heap_industrial.png"),
}
const T := 16
const DECALS := preload("res://art/tiles/ground_decals.png")

const GROUND := Color8(44, 32, 34)
const RIM_HOT := Color8(222, 146, 92)
const RIM := Color8(140, 90, 70)
const SHADE := Color8(26, 18, 20)
const MOSS := Color8(96, 124, 90)
const GIRDER := Color8(160, 78, 52)
const GIRDER_MID := Color8(120, 56, 40)
const GIRDER_DARK := Color8(74, 34, 28)
const GIRDER_HOLE := Color8(38, 20, 18)
const CONT := Color8(68, 102, 86)
const CONT_RIDGE := Color8(52, 80, 68)
const CONT_LIGHT := Color8(108, 146, 122)
const CONT_FRAME := Color8(42, 62, 54)
const RUST := Color8(146, 78, 50)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var body := StaticBody2D.new()
	body.name = "Solids"
	body.collision_layer = 1
	body.collision_mask = 0
	for rect in solids:
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		shape.position = rect.get_center()
		body.add_child(shape)
	add_child(body)
	_apply_painted_art()
	if backdrop != "none":
		var bd := Backdrop.new()
		bd.name = "Backdrop"
		add_child(bd)
		bd.setup(backdrop, bounds)
	_add_atmosphere()
	_spawn_lost_scrap()


var _painted := false

func _apply_painted_art() -> void:
	if Fx.art_variant == "":
		return
	var base := "res://art/rooms/%s/%s" % [Fx.art_variant, room_id]
	if not ResourceLoader.exists(base + "_terrain.png"):
		return
	_painted = true
	var terrain := Sprite2D.new()
	terrain.name = "PaintedTerrain"
	terrain.texture = load(base + "_terrain.png")
	terrain.centered = false
	terrain.position = Vector2(-8, -8)
	add_child(terrain)
	if ResourceLoader.exists(base + "_front.png"):
		var front := Sprite2D.new()
		front.name = "PaintedFront"
		front.texture = load(base + "_front.png")
		front.centered = false
		front.z_index = 40
		add_child(front)
	var cfg := ConfigFile.new()
	if cfg.load("res://art/rooms/%s/style.cfg" % Fx.art_variant) == OK:
		ambient = cfg.get_value("style", "ambient", ambient)
	queue_redraw()


func _add_atmosphere() -> void:
	if motes_amount > 0:
		var m := FxParticles.motes(bounds, motes_color, motes_amount)
		m.z_index = -5
		add_child(m)
		m.emitting = true
	if weather == "rain":
		var r := FxParticles.rain(bounds)
		r.z_index = -4
		add_child(r)
		r.emitting = true


func get_spawn(spawn_name: StringName) -> Vector2:
	var marker := get_node_or_null("Spawns/" + String(spawn_name)) as Node2D
	if marker == null:
		push_warning("Room %s has no spawn '%s'" % [room_id, spawn_name])
		return bounds.get_center()
	return marker.global_position


func _spawn_lost_scrap() -> void:
	var lost := GameState.lost_scrap
	if lost.is_empty() or lost.get("room", "") != scene_file_path:
		return
	var cache: Collectible = COLLECTIBLE_SCENE.instantiate()
	cache.kind = Collectible.Kind.SCRAP
	cache.amount = int(lost["amount"])
	cache.is_lost_cache = true
	cache.position = Vector2(float(lost["x"]), float(lost["y"]))
	add_child.call_deferred(cache)


func _draw() -> void:
	if Engine.is_editor_hint() or backdrop == "none":
		var bands := 12
		for b in bands:
			var t := float(b) / float(bands - 1)
			var y := bounds.position.y + bounds.size.y * float(b) / bands
			draw_rect(Rect2(bounds.position.x, y, bounds.size.x, bounds.size.y / bands + 1.0), bg_top.lerp(bg_bottom, t))
	if _painted:
		return
	var tex: Texture2D = TILESETS.get(tileset)
	for i in solids.size():
		match _style(i):
			"ground": _draw_ground(solids[i])
			"girder": _draw_girder(solids[i])
			"container": _draw_container(solids[i])
			"ceiling": _draw_ceiling(solids[i])
			"rock": _draw_rock(solids[i])
			"brick": _draw_brick(solids[i])
			"pipe": _draw_pipe(solids[i])
			"grate": _draw_grate(solids[i])
			"plate": _draw_plate(solids[i])
			_: _draw_tiles(solids[i], tex)


func _style(i: int) -> String:
	if i < solid_styles.size() and solid_styles[i] != "":
		return solid_styles[i]
	return "tiles" if tileset == "heap_industrial" else "ground"


func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663)) % 1009


func _draw_ground(r: Rect2) -> void:
	draw_rect(r, GROUND)
	var gy := r.position.y + 7.0
	while gy + 16.0 <= r.end.y - 2.0:
		var gx := r.position.x + 4.0 + float(_hash(int(gy), 3) % 30)
		while gx + 14.0 <= r.end.x - 2.0:
			var h := _hash(int(gx), int(gy))
			var jitter := float(h % 7)
			if h % 4 == 0 and gy + jitter + 10.0 <= r.end.y - 2.0:
				draw_texture_rect_region(DECALS, Rect2(gx, gy + jitter, 14, 10), Rect2((h / 4 % 6) * 14, 0, 14, 10))
			gx += 26.0 + float(h % 31)
		gy += 15.0
	if not _solid_at(Vector2(r.position.x - 1.0, r.position.y + 4.0)):
		var y := r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.position.x, y, 1.0 + float(_hash(int(y), 7) % 2), minf(4.0, r.end.y - y)), SHADE)
			y += 4.0
	if not _solid_at(Vector2(r.end.x + 1.0, r.position.y + 4.0)):
		var y := r.position.y
		while y < r.end.y:
			draw_rect(Rect2(r.end.x - 1.0, y, 1.0, minf(4.0, r.end.y - y)), RIM if _hash(int(y), 9) % 3 else RIM_HOT)
			y += 4.0
	if not _solid_at(Vector2(r.position.x + r.size.x * 0.5, r.end.y + 1.0)):
		draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), SHADE)
	if _solid_at(Vector2(r.position.x + r.size.x * 0.5, r.position.y - 1.0)):
		return
	var pts := PackedVector2Array()
	var x := r.position.x
	while x <= r.end.x:
		var off := float(_hash(int(x), int(r.position.y)) % 4) - 2.0
		if x == r.position.x or x >= r.end.x:
			off = 0.0
		pts.append(Vector2(x, r.position.y + off))
		x = minf(x + 4.0, r.end.x) if x < r.end.x else r.end.x + 1.0
	var body := PackedVector2Array(pts)
	body.append(Vector2(r.end.x, r.position.y + 5.0))
	body.append(Vector2(r.position.x, r.position.y + 5.0))
	draw_colored_polygon(body, GROUND)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		draw_line(a, b, RIM_HOT if b.y >= a.y else RIM, 1.0)
		draw_line(a + Vector2(0, 1), b + Vector2(0, 1), RIM.darkened(0.35), 1.0)
		var h := _hash(int(a.x), 17)
		if h % 5 == 0:
			draw_line(a, a + Vector2(-1, -3), MOSS, 1.0)
			draw_line(a + Vector2(1, 0), a + Vector2(2, -2), MOSS, 1.0)
		elif h % 13 == 0:
			draw_line(a + Vector2(0, 1), a + Vector2(3, -6), Color8(84, 62, 58), 1.0)


func _draw_rock(r: Rect2) -> void:
	var body := GROUND.darkened(0.18)
	draw_rect(r, body)
	var gy := r.position.y + 5.0
	while gy + 12.0 <= r.end.y - 3.0:
		var gx := r.position.x + 2.0 + float(_hash(int(gy), 11) % 26)
		while gx + 14.0 <= r.end.x - 2.0:
			var h := _hash(int(gx), int(gy))
			if h % 3 == 0:
				draw_texture_rect_region(DECALS, Rect2(gx, gy + float(h % 4), 14, 10), Rect2((h / 3 % 6) * 14, 0, 14, 10), Color(0.8, 0.74, 0.78))
			gx += 20.0 + float(h % 29)
		gy += 14.0
	var top_lit := Color8(156, 120, 104)
	var top_hot := Color8(196, 150, 112)
	var band := body.lightened(0.07)
	var by := r.position.y
	while by < r.end.y:
		var bh := minf(4.0, r.end.y - by)
		if not _solid_at(Vector2(r.position.x - 1.0, by + bh * 0.5)):
			draw_rect(Rect2(r.position.x, by, minf(6.0, r.size.x), bh), band)
		if not _solid_at(Vector2(r.end.x + 1.0, by + bh * 0.5)):
			draw_rect(Rect2(r.end.x - minf(6.0, r.size.x), by, minf(6.0, r.size.x), bh), band.darkened(0.12))
		by += 4.0
	var bx := r.position.x
	while bx < r.end.x:
		var bw := minf(4.0, r.end.x - bx)
		if not _solid_at(Vector2(bx + bw * 0.5, r.position.y - 1.0)):
			draw_rect(Rect2(bx, r.position.y, bw, minf(7.0, r.size.y)), band)
		if not _solid_at(Vector2(bx + bw * 0.5, r.end.y + 1.0)):
			draw_rect(Rect2(bx, r.end.y - minf(6.0, r.size.y), bw, minf(6.0, r.size.y)), band.darkened(0.15))
		bx += 4.0
	var y := r.position.y
	while y < r.end.y:
		var hh := minf(4.0, r.end.y - y)
		if not _solid_at(Vector2(r.position.x - 1.0, y + hh * 0.5)):
			draw_rect(Rect2(r.position.x, y, 2.0 if _hash(int(y), 3) % 3 else 1.0, hh), RIM.darkened(0.3))
		if not _solid_at(Vector2(r.end.x + 1.0, y + hh * 0.5)):
			draw_rect(Rect2(r.end.x - 2.0, y, 2.0, hh), SHADE)
		y += 4.0
	var x := r.position.x
	while x < r.end.x:
		var w := minf(4.0, r.end.x - x)
		var h := _hash(int(x), int(r.position.y) + 5)
		if not _solid_at(Vector2(x + w * 0.5, r.position.y - 1.0)):
			var off := float(h % 3) - 1.0
			draw_rect(Rect2(x, r.position.y + minf(off, 0.0), w, 3.0 - minf(off, 0.0)), body)
			draw_rect(Rect2(x, r.position.y + off, w, 1.0), top_hot if h % 5 == 0 else top_lit)
			draw_rect(Rect2(x, r.position.y + off + 1.0, w, 1.0), RIM.darkened(0.4))
			if h % 9 == 0:
				draw_line(Vector2(x + 1.0, r.position.y + off), Vector2(x, r.position.y + off - 2.0), MOSS.darkened(0.2), 1.0)
		var hb := _hash(int(x), int(r.end.y) + 31)
		if not _solid_at(Vector2(x + w * 0.5, r.end.y + 1.0)):
			var lip := float(hb % 3)
			draw_rect(Rect2(x, r.end.y - 2.0, w, 2.0 + lip), body)
			draw_rect(Rect2(x, r.end.y + lip - 1.0, w, 1.0), RIM.darkened(0.5))
			if hb % 11 == 0:
				draw_line(Vector2(x + 2.0, r.end.y + lip), Vector2(x + 2.0, r.end.y + lip + 3.0 + float(hb % 5)), Color8(30, 22, 26), 1.0)
			elif hb % 17 == 0:
				draw_rect(Rect2(x + 1.0, r.end.y + lip + 1.0, 1.0, 2.0), RIM)
		x += 4.0


const BRICK := Color8(78, 42, 34)
const BRICK_LO := Color8(58, 30, 26)
const BRICK_HI := Color8(104, 58, 44)
const MORTAR := Color8(34, 34, 30)
const VERDIGRIS := Color8(79, 154, 132)
const VERDIGRIS_LO := Color8(42, 90, 76)
const COPING := Color8(132, 118, 98)
const COPING_HI := Color8(214, 176, 112)
const COPPER := Color8(168, 96, 58)
const COPPER_HI := Color8(226, 160, 104)
const COPPER_LO := Color8(98, 52, 34)
const BRASS := Color8(201, 150, 60)
const BRASS_HI := Color8(240, 207, 115)
const BRASS_LO := Color8(122, 84, 30)
const IRON := Color8(40, 40, 46)
const IRON_HI := Color8(90, 92, 100)


func _draw_brick(r: Rect2) -> void:
	draw_rect(r, MORTAR)
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var off := 8.0 if (int(floor(y / 6.0)) % 2) else 0.0
		var x := r.position.x - fposmod(r.position.x + off, 16.0)
		while x < r.end.x:
			var bx := maxf(x + 1.0, r.position.x)
			var bw := minf(x + 15.0, r.end.x) - bx
			var bh := minf(5.0, r.end.y - y - 1.0)
			if bw > 0.0 and bh > 0.0:
				var h := _hash(int(x), int(y))
				var c := BRICK if h % 5 else (BRICK_LO if h % 2 else BRICK_HI.darkened(0.1))
				draw_rect(Rect2(bx, y + 1.0, bw, bh), c)
				draw_rect(Rect2(bx, y + 1.0, bw, 1.0), c.lightened(0.08))
			x += 16.0
		y += 6.0
		row += 1
	var cx := r.position.x
	while cx < r.end.x:
		var w := minf(4.0, r.end.x - cx)
		var h := _hash(int(cx), int(r.position.y) + 3)
		if not _solid_at(Vector2(cx + w * 0.5, r.position.y - 1.0)):
			draw_rect(Rect2(cx, r.position.y, w, 4.0), COPING)
			draw_rect(Rect2(cx, r.position.y, w, 1.0), COPING_HI if h % 3 else COPING_HI.darkened(0.15))
			draw_rect(Rect2(cx, r.position.y + 4.0, w, 1.0), SHADE)
			if h % 13 == 0:
				draw_rect(Rect2(cx + 1.0, r.position.y - 1.0, 2.0, 1.0), MOSS.darkened(0.1))
		var hb := _hash(int(cx), int(r.end.y) + 17)
		if not _solid_at(Vector2(cx + w * 0.5, r.end.y + 1.0)):
			draw_rect(Rect2(cx, r.end.y - 2.0, w, 2.0), SHADE)
			if hb % 7 == 0:
				var drip := 3.0 + float(hb % 9)
				draw_rect(Rect2(cx + 1.0, r.end.y - 2.0, 2.0, drip), VERDIGRIS_LO)
				draw_rect(Rect2(cx + 1.0, r.end.y - 2.0, 1.0, drip - 2.0), VERDIGRIS)
		cx += 4.0
	var sy := r.position.y
	while sy < r.end.y:
		var hh := minf(4.0, r.end.y - sy)
		if not _solid_at(Vector2(r.position.x - 1.0, sy + hh * 0.5)):
			draw_rect(Rect2(r.position.x, sy, 2.0, hh), BRICK_HI.darkened(0.25))
		if not _solid_at(Vector2(r.end.x + 1.0, sy + hh * 0.5)):
			draw_rect(Rect2(r.end.x - 2.0, sy, 2.0, hh), SHADE)
		sy += 4.0


func _draw_pipe(r: Rect2) -> void:
	var vertical := r.size.y > r.size.x * 1.5
	var thick := r.size.x if vertical else r.size.y
	var bands := [COPPER_HI, COPPER, COPPER, COPPER.darkened(0.12), COPPER_LO, COPPER_LO.darkened(0.25)]
	for i in int(thick):
		var c: Color = bands[clampi(int(float(i) / thick * bands.size()), 0, bands.size() - 1)]
		if vertical:
			draw_rect(Rect2(r.position.x + i, r.position.y, 1, r.size.y), c)
		else:
			draw_rect(Rect2(r.position.x, r.position.y + i, r.size.x, 1), c)
	var length := r.size.y if vertical else r.size.x
	var t := 20.0
	while t < length - 8.0:
		var h := _hash(int(t), int(r.position.x + r.position.y))
		if vertical:
			draw_rect(Rect2(r.position.x - 1, r.position.y + t, r.size.x + 2, 4), BRASS_LO)
			draw_rect(Rect2(r.position.x - 1, r.position.y + t, r.size.x + 2, 1), BRASS_HI)
		else:
			draw_rect(Rect2(r.position.x + t, r.position.y - 1, 4, r.size.y + 2), BRASS_LO)
			draw_rect(Rect2(r.position.x + t, r.position.y - 1, 1, r.size.y + 2), BRASS_HI)
			draw_rect(Rect2(r.position.x + t + 1, r.position.y + 1, 1, 1), BRASS_HI)
			if h % 4 == 0:
				draw_rect(Rect2(r.position.x + t + 1, r.end.y, 1, 2 + h % 3), VERDIGRIS)
		t += 48.0
	if not vertical:
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), COPPER_HI.lightened(0.15))


func _draw_grate(r: Rect2) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), IRON_HI)
	draw_rect(Rect2(r.position.x, r.position.y + 2, r.size.x, 1), IRON)
	draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), IRON)
	var x := r.position.x + 2.0
	while x < r.end.x - 1.0:
		draw_rect(Rect2(x, r.position.y + 3, 1, r.size.y - 5), IRON)
		draw_rect(Rect2(x + 1, r.position.y + 3, 1, r.size.y - 5), Color(0.1, 0.1, 0.12, 0.6))
		x += 4.0
	for px in [r.position.x + 1.0, r.end.x - 2.0]:
		draw_rect(Rect2(px, r.position.y + 1, 1, 1), BRASS_HI)
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(0, 0, 0, 0.35))


func _draw_plate(r: Rect2) -> void:
	draw_rect(r, BRASS_LO)
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var w := minf(32.0, r.end.x - x)
			var h := minf(16.0, r.end.y - y)
			draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), BRASS.darkened(0.25))
			draw_rect(Rect2(x + 1, y + 1, w - 2, 1), BRASS.darkened(0.05))
			draw_rect(Rect2(x + 2, y + 3, 1, 1), BRASS_HI.darkened(0.1))
			draw_rect(Rect2(x + w - 3, y + 3, 1, 1), BRASS_HI.darkened(0.1))
			x += 32.0
		y += 16.0
	var cx := r.position.x
	while cx < r.end.x:
		var w := minf(4.0, r.end.x - cx)
		if not _solid_at(Vector2(cx + w * 0.5, r.position.y - 1.0)):
			draw_rect(Rect2(cx, r.position.y, w, 1), BRASS_HI)
			draw_rect(Rect2(cx, r.position.y + 1, w, 1), BRASS)
		if not _solid_at(Vector2(cx + w * 0.5, r.end.y + 1.0)):
			draw_rect(Rect2(cx, r.end.y - 1, w, 1), SHADE)
		cx += 4.0


func _draw_ceiling(r: Rect2) -> void:
	var body := GROUND.darkened(0.35)
	draw_rect(r, body)
	var gy := r.position.y + 4.0
	while gy + 12.0 <= r.end.y - 4.0:
		var gx := r.position.x + 3.0 + float(_hash(int(gy), 5) % 24)
		while gx + 14.0 <= r.end.x - 2.0:
			var h := _hash(int(gx), int(gy))
			if h % 3 == 0:
				draw_texture_rect_region(DECALS, Rect2(gx, gy + float(h % 5), 14, 10), Rect2((h / 3 % 6) * 14, 0, 14, 10), Color(0.7, 0.66, 0.72))
			gx += 22.0 + float(h % 27)
		gy += 13.0
	if _solid_at(Vector2(r.position.x + r.size.x * 0.5, r.end.y + 1.0)):
		return
	var x := r.position.x
	while x < r.end.x:
		var h := _hash(int(x), int(r.end.y) + 31)
		var lip := float(h % 4)
		draw_rect(Rect2(x, r.end.y - 2.0, 4.0, 2.0 + lip), body)
		draw_rect(Rect2(x, r.end.y + lip - 1.0, 4.0, 1.0), RIM.darkened(0.45))
		if h % 11 == 0:
			draw_line(Vector2(x + 2.0, r.end.y + lip), Vector2(x + 2.0, r.end.y + lip + 4.0 + float(h % 5)), Color8(30, 22, 26), 1.0)
		elif h % 17 == 0:
			draw_rect(Rect2(x + 1.0, r.end.y + lip + 1.0, 1.0, 2.0), RIM)
		x += 4.0


func _draw_girder(r: Rect2) -> void:
	var vertical := r.size.y > r.size.x * 1.5
	draw_rect(r, GIRDER_DARK)
	if vertical:
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), GIRDER_MID)
		draw_rect(Rect2(Vector2(r.end.x - 3.0, r.position.y), Vector2(3, r.size.y)), GIRDER)
		draw_line(Vector2(r.end.x - 0.5, r.position.y), Vector2(r.end.x - 0.5, r.end.y), RIM_HOT, 1.0)
		var y := r.position.y + 8.0
		while y < r.end.y - 4.0:
			draw_circle(Vector2(r.position.x + r.size.x * 0.5, y), minf(3.0, r.size.x * 0.5 - 4.0), GIRDER_HOLE)
			y += 16.0
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), RIM_HOT)
		return
	var h := r.size.y
	var hole := minf(3.0, (h - 6.0) * 0.5 - 1.0)
	var x := r.position.x + 8.0
	while x < r.end.x - 4.0:
		if hole > 0.5:
			draw_circle(Vector2(x, r.position.y + h * 0.5), hole, GIRDER_HOLE)
		x += 16.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), GIRDER)
	draw_line(Vector2(r.position.x, r.position.y + 0.5), Vector2(r.end.x, r.position.y + 0.5), RIM_HOT, 1.0)
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), GIRDER_MID)
	draw_line(Vector2(r.position.x, r.end.y - 0.5), Vector2(r.end.x, r.end.y - 0.5), SHADE, 1.0)
	x = r.position.x + 3.0
	while x < r.end.x - 2.0:
		draw_rect(Rect2(x, r.position.y + 1.0, 1, 1), Color8(214, 140, 100))
		x += 8.0
	draw_rect(Rect2(r.position.x, r.position.y, 2, h), GIRDER_MID)
	draw_rect(Rect2(r.end.x - 2.0, r.position.y, 2, h), GIRDER_MID)


func _draw_container(r: Rect2) -> void:
	draw_rect(r, CONT)
	var x := r.position.x + 4.0
	while x < r.end.x - 4.0:
		draw_line(Vector2(x + 0.5, r.position.y + 2.0), Vector2(x + 0.5, r.end.y - 2.0), CONT_RIDGE, 1.0)
		x += 4.0
	var h := _hash(int(r.position.x), int(r.position.y))
	draw_rect(Rect2(r.position.x + 10.0 + float(h % 20), r.end.y - 6.0, 9, 4), RUST)
	draw_rect(Rect2(r.position.x + 30.0 + float(h % 15), r.position.y + 4.0, 3, 6), RUST.darkened(0.2))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), CONT_LIGHT)
	draw_line(Vector2(r.position.x, r.position.y + 0.5), Vector2(r.end.x, r.position.y + 0.5), RIM_HOT, 1.0)
	draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), CONT_FRAME.darkened(0.3))
	draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), CONT_FRAME)
	draw_rect(Rect2(r.end.x - 3.0, r.position.y, 3, r.size.y), CONT_FRAME)
	draw_line(Vector2(r.end.x - 7.5, r.position.y + 2.0), Vector2(r.end.x - 7.5, r.end.y - 2.0), CONT_FRAME, 1.0)
	if r.size.x > 50.0:
		draw_rect(Rect2(r.position.x + 7.0, r.position.y + 5.0, 8, 2), Color(0.88, 0.85, 0.78, 0.55))


func _draw_tiles(r: Rect2, tex: Texture2D) -> void:
	var x := r.position.x
	while x < r.end.x - 0.01:
		var w := minf(T, r.end.x - x)
		var y := r.position.y
		while y < r.end.y - 0.01:
			var h := minf(T, r.end.y - y)
			var gx := int(floor(x / T))
			var gy := int(floor(y / T))
			var dest := Rect2(x, y, w, h)
			draw_texture_rect_region(tex, dest, Rect2(posmod(gx * 7 + gy * 13, 4) * T, 0, w, h))
			if not _solid_at(Vector2(x + w * 0.5, y - 1.0)):
				draw_texture_rect_region(tex, dest, Rect2((4 + posmod(gx * 5 + gy, 3)) * T, 0, w, h))
			if not _solid_at(Vector2(x - 1.0, y + h * 0.5)):
				draw_texture_rect_region(tex, dest, Rect2(7 * T, 0, w, h))
			if not _solid_at(Vector2(x + w + 1.0, y + h * 0.5)):
				draw_texture_rect_region(tex, dest, Rect2(8 * T + T - w, 0, w, h))
			if not _solid_at(Vector2(x + w * 0.5, y + h + 1.0)):
				draw_texture_rect_region(tex, dest, Rect2(9 * T, T - h, w, h))
			y += h
		x += w


func _solid_at(p: Vector2) -> bool:
	for rect in solids:
		if rect.has_point(p):
			return true
	return false
