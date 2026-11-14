class_name MapView
extends Control

var region: StringName = &"heap"

const FONT := preload("res://art/fonts/Silkscreen.ttf")
const PAPER := preload("res://art/ui/map/paper.png")
const BANNER := preload("res://art/ui/map/banner.png")
const COMPASS := preload("res://art/ui/map/compass.png")
const ICONS := preload("res://art/ui/map/icons.png")
const ICON_ORDER := ["dock", "shop", "boss", "miniboss", "exit", "town", "pin"]
const ICON_SIZE := Vector2(10, 12)
const LEGEND := [["dock", "DOCK"], ["shop", "SHOP"], ["boss", "BOSS"], ["exit", "WAY ON"]]

const INK := Color8(48, 32, 30)
const PENCIL := Color8(128, 106, 90)
const WASH := Color8(120, 88, 60, 80)
const WASH_HERE := Color8(214, 138, 50, 110)
const HATCH := Color8(48, 32, 30, 70)
const LABEL := Color8(60, 40, 34)

static var _geometry := {}

var _tex: ImageTexture
var _tex_at := Vector2.ZERO
var _k := 1.0
var _bounds := Rect2()
var _dirty := true
var _room_px := {}
var _hover: StringName = &""
var _t := 0.0
var _paper_box: StyleBoxTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_paper_box = StyleBoxTexture.new()
	_paper_box.texture = PAPER
	_paper_box.set_texture_margin_all(12)
	_paper_box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_paper_box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	resized.connect(func(): _dirty = true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h: StringName = &""
		for id in _room_px:
			if (_room_px[id] as Rect2).has_point(event.position):
				h = id
		_hover = h


static func room_geometry(region_id: StringName, room_id: StringName) -> Dictionary:
	if _geometry.has(room_id):
		return _geometry[room_id]
	var g := {"solids": [] as Array[Rect2]}
	var path := "res://scenes/rooms/%s/%s.tscn" % [region_id, room_id]
	if ResourceLoader.exists(path):
		var state := (load(path) as PackedScene).get_state()
		for p in state.get_node_property_count(0):
			if state.get_node_property_name(0, p) == &"solids":
				g["solids"] = state.get_node_property_value(0, p)
	_geometry[room_id] = g
	return g


func _rooms() -> Dictionary:
	return MapData.REGIONS[region]["rooms"]


func _visible(id: StringName) -> int:
	if GameState.visited_rooms.has(String(id)):
		return 2
	if GameState.has_map(region) and not ("secret" in _rooms()[id]["icons"]):
		return 1
	return 0


func _map_area() -> Rect2:
	return Rect2(16, 26, size.x - 32, size.y - 26 - 24)


func _build() -> void:
	_dirty = false
	_room_px.clear()
	_bounds = Rect2()
	var first := true
	for id in _rooms():
		var r := MapData.world_rect(region, id)
		_bounds = r if first else _bounds.merge(r)
		first = false
	var area := _map_area()
	_k = minf(area.size.x / _bounds.size.x, area.size.y / _bounds.size.y)
	var w := maxi(int(ceil(_bounds.size.x * _k)), 1)
	var h := maxi(int(ceil(_bounds.size.y * _k)), 1)
	_tex_at = (area.position + (area.size - Vector2(w, h)) * 0.5).round()
	var cells := PackedByteArray()
	cells.resize(w * h)
	var here := PackedByteArray()
	here.resize(w * h)
	var current := WorldManager.current_room.room_id if WorldManager.current_room else &""
	var owned := GameState.has_map(region)
	for id in _rooms():
		var vis := _visible(id)
		if vis == 0:
			continue
		var visited := vis == 2 and owned
		var rr := _px_rect(MapData.world_rect(region, id), w, h, false)
		_room_px[id] = Rect2(_tex_at + Vector2(rr.position), Vector2(rr.size))
		_fill(cells, w, rr, 1 if visited else 2)
		if id == current:
			_fill(here, w, rr, 1)
		var origin: Vector2 = _rooms()[id]["origin"]
		for s: Rect2 in room_geometry(region, id)["solids"]:
			var sr := _px_rect(Rect2(s.position + origin, s.size), w, h, true).intersection(rr)
			if sr.has_area():
				_fill(cells, w, sr, 3 if visited else 4)
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for y in h:
		for x in w:
			var i := y * w + x
			var c := cells[i]
			var col := Color(0, 0, 0, 0)
			if c == 1:
				col = WASH_HERE if here[i] == 1 else WASH
			elif c != 2:
				var edge := 0
				for n in [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]:
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
						var nc := cells[n.y * w + n.x]
						if nc == 1:
							edge = 2
						elif nc == 2 and edge == 0:
							edge = 1
				if edge == 2:
					col = INK
				elif edge == 1:
					if (x + y) % 3 != 0:
						col = PENCIL
				elif c == 3 and (x - y) % 4 == 0:
					col = HATCH
			data[i * 4] = int(col.r8)
			data[i * 4 + 1] = int(col.g8)
			data[i * 4 + 2] = int(col.b8)
			data[i * 4 + 3] = int(col.a8)
	_tex = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data))


func _px_rect(r: Rect2, w: int, h: int, at_least_one: bool) -> Rect2i:
	var x0 := int(round((r.position.x - _bounds.position.x) * _k))
	var y0 := int(round((r.position.y - _bounds.position.y) * _k))
	var x1 := int(round((r.end.x - _bounds.position.x) * _k))
	var y1 := int(round((r.end.y - _bounds.position.y) * _k))
	if at_least_one:
		x1 = maxi(x1, x0 + 1)
		y1 = maxi(y1, y0 + 1)
	x0 = clampi(x0, 0, w); x1 = clampi(x1, 0, w)
	y0 = clampi(y0, 0, h); y1 = clampi(y1, 0, h)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _fill(arr: PackedByteArray, w: int, r: Rect2i, v: int) -> void:
	for y in range(r.position.y, r.end.y):
		var row := y * w
		for x in range(r.position.x, r.end.x):
			arr[row + x] = v


func _draw() -> void:
	if not MapData.REGIONS.has(region):
		return
	draw_style_box(_paper_box, Rect2(Vector2.ZERO, size))
	if _dirty:
		_build()
	if _tex:
		draw_texture(_tex, _tex_at)
	var rooms := _rooms()
	var current := WorldManager.current_room.room_id if WorldManager.current_room else &""
	for id in _room_px:
		var icons: Array = []
		for ic in rooms[id]["icons"]:
			if ic in ICON_ORDER:
				icons.append(ic)
		if icons.is_empty():
			continue
		var r: Rect2 = _room_px[id]
		var x := r.get_center().x - icons.size() * 6.0 + 1.0
		for ic in icons:
			_icon(ic, Vector2(x, r.get_center().y - 5).round())
			x += 12.0
	draw_texture(COMPASS, Vector2(size.x - COMPASS.get_width() - 12, size.y - COMPASS.get_height() - 26))
	var title := String(MapData.REGIONS[region]["name"]).to_upper()
	var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var bw := tw + 24.0
	var banner := StyleBoxTexture.new()
	banner.texture = BANNER
	banner.texture_margin_left = 8
	banner.texture_margin_right = 8
	banner.texture_margin_top = 4
	banner.texture_margin_bottom = 5
	var bx := roundf((size.x - bw) * 0.5)
	draw_style_box(banner, Rect2(bx, 6, bw, 15))
	draw_string(FONT, Vector2(bx + 12, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(242, 230, 205))
	var shown := _hover if _hover != &"" else current
	if rooms.has(shown) and (_room_px.has(shown)):
		var prefix := "" if shown != current else "YOU ARE IN  "
		draw_string(FONT, Vector2(16, size.y - 10), prefix + String(rooms[shown]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LABEL)
	if not GameState.has_map(region):
		draw_string(FONT, Vector2(16, size.y - 10 - 10), "SKETCHED FROM MEMORY. DOT IN THE CAMP SELLS A PROPER MAP.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PENCIL)
	else:
		_legend()
	if current != &"" and rooms.has(current) and WorldManager.player and is_instance_valid(WorldManager.player):
		var p: Vector2 = (rooms[current]["origin"] + WorldManager.player.global_position - _bounds.position) * _k + _tex_at
		var bob := -1.0 if fmod(_t, 0.9) < 0.45 else 0.0
		draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 1)), Color(INK, 0.45))
		_icon("pin", (p + Vector2(-4, -8 + bob)).round())


func _legend() -> void:
	var x := size.x - 14.0 - COMPASS.get_width() - 10.0
	for i in range(LEGEND.size() - 1, -1, -1):
		var text: String = LEGEND[i][1]
		x -= FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(FONT, Vector2(x, size.y - 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LABEL)
		x -= 12.0
		_icon(LEGEND[i][0], Vector2(x, size.y - 19))
		x -= 10.0


func _icon(kind: String, at: Vector2) -> void:
	var i := ICON_ORDER.find(kind)
	if i < 0:
		return
	draw_texture_rect_region(ICONS, Rect2(at, ICON_SIZE), Rect2(Vector2(i * ICON_SIZE.x, 0), ICON_SIZE))
