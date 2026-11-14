class_name NPCLook
extends RefCounted

const W := 28
const H := 48

static func roll(lineage: Lineage, seed_value: int, age: String, pins: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t := {}
	t.age = age
	var h_lo := lineage.height_range.x
	var h_hi := lineage.height_range.y
	if age == "child":
		h_lo = 9; h_hi = 11
	elif age == "teen":
		h_lo = 13; h_hi = 15
	t.height = rng.randi_range(h_lo, h_hi)
	t.width = rng.randi_range(lineage.width_range.x, lineage.width_range.y) - (2 if age == "child" else 0)
	t.hunch = 0 if age == "child" else rng.randi_range(0, lineage.hunch_max) + (1 if age == "elder" else 0)
	t.head_r = 4 if age == "child" else rng.randi_range(4, 5)
	var coat: Color = lineage.coat_colors[rng.randi() % lineage.coat_colors.size()]
	t.coat = coat.lightened(rng.randf_range(-0.06, 0.08))
	t.skin = lineage.skin_tones[rng.randi() % lineage.skin_tones.size()]
	t.hair = Color8(170, 164, 156) if age == "elder" else lineage.hair_colors[rng.randi() % lineage.hair_colors.size()]
	t.accent = lineage.accent_colors[rng.randi() % lineage.accent_colors.size()]
	t.scarf = rng.randf() < 0.7
	t.headwear = lineage.headwear[rng.randi() % lineage.headwear.size()]
	t.goggles = lineage.goggle_styles[rng.randi() % lineage.goggle_styles.size()]
	t.accessory = lineage.accessories[rng.randi() % lineage.accessories.size()]
	t.patches = []
	for i in (rng.randi_range(1, 3) if not lineage.patch_colors.is_empty() else 0):
		t.patches.append([rng.randi_range(0, 6), rng.randi_range(0, 8), lineage.patch_colors[rng.randi() % lineage.patch_colors.size()]])
	t.style = "cowl"
	for key in pins:
		if pins[key] != null and str(pins[key]) != "":
			t[key] = pins[key]
	return t


static func build(lineage: Lineage, traits: Dictionary) -> Array[ImageTexture]:
	var frames: Array[ImageTexture] = []
	for breath in 2:
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		_paint(img, lineage, traits, breath)
		_outline(img, lineage.outline_color)
		frames.append(ImageTexture.create_from_image(img))
	return frames


static func lens_offset(traits: Dictionary) -> Vector2:
	var head := _head_center(traits, 0)
	if traits.get("style", "cowl") == "cowl":
		return Vector2(head.x - W / 2, head.y - 1 - H)
	var y: int = head.y - (int(traits.head_r) if traits.goggles == "raised" else 0)
	if traits.goggles == "monocle":
		return Vector2(head.x + 2 - W / 2, head.y - H)
	return Vector2(head.x + 2 - W / 2, y - H)


static func _head_center(t: Dictionary, breath: int) -> Vector2i:
	var cx := W / 2
	var hem := H - 6
	var top := hem - int(t.height) - breath
	return Vector2i(cx + int(t.hunch), top - int(t.head_r) + 1 + int(t.hunch) / 2)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < W and yy < H:
				img.set_pixel(xx, yy, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


static func _paint(img: Image, L: Lineage, t: Dictionary, breath: int) -> void:
	if t.get("style", "cowl") == "cowl":
		_paint_cowl(img, L, t, breath)
		return
	var cx := W / 2
	var w: int = t.width
	var hem := H - 6
	var top := hem - int(t.height) - breath
	var coat: Color = t.coat
	var dark := coat.darkened(0.28)
	var light := coat.lightened(0.16)

	if t.accessory == "pack":
		_rect(img, cx - w / 2 - 4, top + 3, 5, 8, dark.darkened(0.2))
		_rect(img, cx - w / 2 - 4, top + 3, 5, 1, coat)

	var bw := w / 2 + 2
	_rect(img, cx - w / 2 - 1, H - 4, bw, 4, L.boot_color)
	_rect(img, cx, H - 4, bw + 1, 4, L.boot_color)
	_rect(img, cx - w / 2 - 1, H - 4, bw, 1, L.boot_color.lightened(0.2))
	_rect(img, cx, H - 4, bw + 1, 1, L.boot_color.lightened(0.2))
	_rect(img, cx - w / 2 + 1, H - 6, w - 2, 2, L.trouser_color)

	var rows := hem - top
	for i in rows:
		var y := top + i
		var half := w / 2
		if i == 0:
			half -= 2
		elif i == 1:
			half -= 1
		if w >= 10 and i > rows / 3 and i < rows - 3:
			half += 1
		var x0 := cx - half
		var x1 := cx + (w - w / 2) - (w / 2 - half)
		if int(t.hunch) > 0 and i >= 2 and i <= 2 + int(t.hunch) * 2:
			x0 -= 1 + (1 if int(t.hunch) > 1 and i == 3 else 0)
		if i >= rows - 3 and L.coat_style == "patchwork":
			x0 -= 1
			x1 += 1
		_rect(img, x0, y, x1 - x0, 1, coat)
		_px(img, x0, y, dark)
		if i > 0:
			_px(img, x1 - 1, y, light)
	if L.coat_style == "tailored":
		for y in range(top + 1, top + 4):
			_px(img, cx - 2 + (y - top), y, dark)
		for y in range(top + 4, hem - 1, 3):
			_px(img, cx - 1, y, Color8(201, 150, 60))
		_rect(img, cx - w / 2, hem - 1, w, 1, dark)
	else:
		for x in range(cx - w / 2 - 1, cx + w / 2 + 1, 2):
			_px(img, x, hem - 1, Color(0, 0, 0, 0))
		for y in range(top + 1, hem, 2):
			_px(img, cx - 1, y, dark)
	for p in t.patches:
		var px := cx - w / 2 + 1 + int(p[0]) % maxi(w - 4, 1)
		var py := top + 3 + int(p[1]) % maxi(int(t.height) - 6, 1)
		_rect(img, px, py, 3, 3, p[2])
		_px(img, px, py, (p[2] as Color).darkened(0.3))
		_px(img, px + 2, py + 2, (p[2] as Color).darkened(0.3))

	if t.accessory == "apron":
		var cloth := Color8(176, 150, 112) if L.coat_style == "patchwork" else Color8(112, 72, 46)
		_rect(img, cx - w / 2 + 2, top + int(t.height) / 2, w - 3, hem - top - int(t.height) / 2 + 1, cloth)
		_rect(img, cx - w / 2 + 2, top + int(t.height) / 2, w - 3, 1, cloth.darkened(0.2))
	if t.accessory == "belt":
		_rect(img, cx - w / 2, top + int(t.height) * 2 / 3, w, 1, Color8(84, 56, 40))
		_rect(img, cx + w / 2 - 3, top + int(t.height) * 2 / 3 + 1, 1, 4, Color8(150, 146, 140))
		_rect(img, cx + w / 2 - 4, top + int(t.height) * 2 / 3 + 4, 3, 1, Color8(150, 146, 140))

	var arm_x := cx + w / 2 - 2
	var arm_h := mini(int(t.height) - 5, 14)
	var hand_y := top + 2 + arm_h
	if t.accessory == "brass_arm":
		var brass := Color8(201, 150, 60)
		_rect(img, arm_x, top + 2, 3, arm_h, Color8(140, 100, 40))
		_rect(img, arm_x, top + 2, 1, arm_h, brass)
		_px(img, arm_x + 1, top + 2 + arm_h / 2, Color8(240, 207, 115))
		for y in range(top + 4, top + 2 + arm_h, 3):
			_px(img, arm_x + 2, y, Color8(90, 63, 28))
		_rect(img, arm_x, hand_y, 1, 2, brass)
		_rect(img, arm_x + 2, hand_y, 1, 2, brass)
	else:
		_rect(img, arm_x, top + 2, 3, arm_h, light.darkened(0.08))
		_rect(img, arm_x + 2, top + 2, 1, arm_h, dark)
		_rect(img, arm_x, hand_y, 2, 2, t.skin)
	if t.accessory == "lantern":
		_rect(img, arm_x + 1, hand_y + 2, 3, 4, Color8(70, 54, 44))
		_rect(img, arm_x + 2, hand_y + 3, 1, 2, L.lens_color)
	if t.accessory == "cane":
		_rect(img, arm_x + 2, hand_y, 1, H - hand_y, Color8(110, 78, 52))

	var head := _head_center(t, breath)
	var r: int = t.head_r
	if t.scarf:
		_rect(img, head.x - r + 1, head.y + r - 1, r * 2, 2, t.accent)
		_rect(img, head.x - r, head.y + r + 1, 2, 4, (t.accent as Color).darkened(0.15))

	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + 1:
				_px(img, head.x + x, head.y + y, t.skin)
	_px(img, head.x + r - 1, head.y - r + 2, (t.skin as Color).lightened(0.15))

	match t.headwear:
		"hood":
			for y in range(-r - 1, 2):
				for x in range(-r - 1, r + 2):
					var d := x * x + y * y
					if d <= (r + 1) * (r + 1) + 1 and d >= (r - 1) * (r - 1) and x <= r - 1:
						_px(img, head.x + x, head.y + y, coat)
			_rect(img, head.x - r - 2, head.y - 1, 2, r + 2, dark)
		"cap":
			_rect(img, head.x - r, head.y - r - 1, r * 2 + 1, 3, dark)
			_rect(img, head.x + r - 1, head.y - r + 1, 3, 1, dark.darkened(0.2))
		"bandana":
			_rect(img, head.x - r, head.y - r + 1, r * 2 + 1, 2, t.accent)
			_rect(img, head.x - r - 2, head.y - r + 2, 2, 3, t.accent)
		"stovepipe":
			var hat := Color8(34, 28, 30)
			_rect(img, head.x - r - 1, head.y - r, r * 2 + 3, 1, hat)
			_rect(img, head.x - r + 1, head.y - r - 8, r * 2 - 1, 8, hat)
			_rect(img, head.x - r + 1, head.y - r - 2, r * 2 - 1, 1, t.accent)
			_rect(img, head.x + r - 1, head.y - r - 8, 1, 6, hat.lightened(0.18))
		"bowler":
			var hat := Color8(52, 40, 36)
			_rect(img, head.x - r - 1, head.y - r, r * 2 + 3, 1, hat)
			for y in range(-r - 4, -r):
				for x in range(-r + 1, r):
					if x * x + (y + r) * (y + r) * 2 <= r * r + 3:
						_px(img, head.x + x, head.y + y, hat)
			_px(img, head.x + r - 2, head.y - r - 3, hat.lightened(0.2))
		"beanie":
			for y in range(-r - 1, -1):
				for x in range(-r, r + 1):
					if x * x + y * y <= r * r + 2:
						_px(img, head.x + x, head.y + y, t.accent)
			_px(img, head.x, head.y - r - 2, (t.accent as Color).lightened(0.3))
		_:
			_rect(img, head.x - r + 1, head.y - r - 1, r * 2 - 1, 2, t.hair)
			_px(img, head.x - 1, head.y - r - 2, t.hair)

	var lens: Color = L.lens_color
	var band := Color8(60, 42, 34)
	var gy := head.y - (r if t.goggles == "raised" else 0)
	if t.goggles != "monocle":
		_rect(img, head.x - r, gy, r * 2 + 1, 1, band)
	match t.goggles:
		"single":
			_rect(img, head.x + 1, gy - 1, 3, 3, Color8(70, 50, 40))
			_rect(img, head.x + 2, gy, 1, 1, lens)
			_px(img, head.x + 2, gy - 1, lens.lightened(0.4))
		"double":
			_rect(img, head.x, gy - 1, 2, 2, lens)
			_rect(img, head.x + 3, gy - 1, 2, 2, lens)
			_px(img, head.x, gy - 1, lens.lightened(0.4))
		"monocle":
			var rim := Color8(201, 150, 60)
			_rect(img, head.x + 1, gy - 2, 4, 4, rim)
			_rect(img, head.x + 2, gy - 1, 2, 2, lens)
			_px(img, head.x + 2, gy - 1, lens.lightened(0.4))
			_px(img, head.x + 4, gy + 2, rim)
			_px(img, head.x + 4, gy + 3, rim)
		"raised":
			_rect(img, head.x + 1, gy - 1, 2, 2, lens.darkened(0.15))
			_rect(img, head.x + 4, gy - 1, 1, 2, lens.darkened(0.15))
			_px(img, head.x + 3, head.y, Color8(40, 28, 26))


static func _outline(img: Image, c: Color) -> void:
	var add: Array[Vector2i] = []
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + o
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and img.get_pixel(n.x, n.y).a > 0.0:
					add.append(Vector2i(x, y))
					break
	for p in add:
		img.set_pixel(p.x, p.y, c)


static func _paint_cowl(img: Image, L: Lineage, t: Dictionary, breath: int) -> void:
	var cx := W / 2 + int(t.hunch) / 2
	var w: int = t.width
	var hem := H - 5
	var top := hem - int(t.height) - breath
	var robe: Color = t.coat
	var dark := robe.darkened(0.3)
	var deep := robe.darkened(0.5)
	var light := robe.lightened(0.18)
	var elder: bool = t.age == "elder"

	if t.accessory == "pack":
		_rect(img, cx - w / 2 - 4, top + 3, 5, 8, deep)
		_rect(img, cx - w / 2 - 4, top + 3, 5, 1, robe)

	var boot: Color = L.boot_color
	_rect(img, cx - w / 2, H - 4, w / 2, 4, boot)
	_rect(img, cx + 1, H - 4, w / 2 + 1, 4, boot)
	_rect(img, cx - w / 2, H - 4, w / 2, 1, boot.lightened(0.25))
	_rect(img, cx + 1, H - 4, w / 2 + 1, 1, boot.lightened(0.25))
	_px(img, cx - w / 2 + 1, H - 2, boot.darkened(0.3))
	_px(img, cx + 2, H - 2, boot.darkened(0.3))

	var rows := hem - top
	for i in rows:
		var y := top + i
		var k := float(i) / maxf(rows - 1, 1)
		var half := int(round(lerpf(w / 2.0 - 1.0, w / 2.0 + 2.0, k)))
		if int(t.hunch) > 0 and i >= 1 and i <= 1 + int(t.hunch) * 2:
			_px(img, cx - half - 1, y, robe)
		_rect(img, cx - half, y, half * 2 + 1, 1, robe)
		_px(img, cx - half, y, dark)
		_px(img, cx + half, y, light)
	for f in [-3, 0, 3]:
		for y in range(top + 4, hem):
			if (y + f) % 5 != 0:
				_px(img, cx + f + (1 if y > top + rows / 2 and f != 0 else 0) * signi(f), y, dark)
	_rect(img, cx - w / 2 - 1, hem - 1, w + 3, 1, dark)

	if t.accessory == "belt" or t.accessory == "apron":
		var by := top + int(t.height) / 2
		_rect(img, cx - w / 2, by, w + 1, 1, Color8(84, 56, 40))
		_px(img, cx + 1, by, Color8(201, 150, 60))

	var arm_h := mini(int(t.height) - 4, 13)
	for side in [-1, 1]:
		var sx: int = cx + side * (w / 2 + 1)
		var x0: int = sx - (2 if side < 0 else 0)
		_rect(img, x0, top + 2, 3, arm_h, robe if side > 0 else dark)
		_rect(img, x0 + (2 if side > 0 else 0), top + 2, 1, arm_h, light if side > 0 else deep)
		var cy: int = top + 2 + arm_h
		var cuff := robe.lightened(0.1) if side > 0 else robe.darkened(0.1)
		_rect(img, x0, cy, 3, 2, cuff)
		_px(img, x0 + 1, cy, cuff.darkened(0.3))
		_px(img, x0 + 1, cy + 1, cuff.darkened(0.3))
		if side > 0 and t.accessory == "lantern":
			_rect(img, x0, cy + 2, 3, 4, Color8(70, 54, 44))
			_rect(img, x0 + 1, cy + 3, 1, 2, L.lens_color)
		if side > 0 and (t.accessory == "cane" or elder):
			_rect(img, x0 + 1, cy + 2, 1, H - cy - 2, Color8(110, 78, 52))

	var head := _head_center(t, breath)
	var r: int = t.head_r
	var hr := r + 2
	for y in range(-hr - 1, hr + 3):
		for x in range(-hr - 1, hr + 2):
			var inside := x * x + y * y * 0.8 <= hr * hr + 2
			if inside or (y > 1 and absf(x) <= hr and y <= hr + 2):
				_px(img, head.x + x, head.y + y, robe)
	for y in range(-hr - 1, hr + 3):
		for x in range(-hr - 1, 0):
			var px_ := Vector2i(head.x + x, head.y + y)
			if px_.x >= 0 and px_.y >= 0 and px_.x < W and px_.y < H and img.get_pixel(px_.x, px_.y).a > 0.0:
				img.set_pixel(px_.x, px_.y, dark)
				break
		for x in range(hr + 1, 0, -1):
			var px_ := Vector2i(head.x + x, head.y + y)
			if px_.x >= 0 and px_.y >= 0 and px_.x < W and px_.y < H and img.get_pixel(px_.x, px_.y).a > 0.0:
				img.set_pixel(px_.x, px_.y, light.darkened(0.05))
				break
	for y in range(-r + 1, r):
		for x in range(-r + 1, r):
			if x * x + y * y <= (r - 1) * (r - 1) + 1:
				_px(img, head.x + x, head.y + y, t.skin)
	_rect(img, head.x - r + 2, head.y - r + 1, r * 2 - 3, 1, deep)
	_rect(img, head.x - r + 1, head.y - r + 2, r * 2 - 1, 1, (t.skin as Color).darkened(0.35))
	if elder:
		_px(img, head.x - 2, head.y + 2, (t.skin as Color).darkened(0.25))
		_px(img, head.x + 2, head.y + 2, (t.skin as Color).darkened(0.25))
	var mouth := (t.skin as Color).darkened(0.45)
	_px(img, head.x - 1, head.y + 2, mouth)
	_px(img, head.x, head.y + 3, mouth)
	_px(img, head.x + 1, head.y + 2, mouth)

	var lens: Color = L.lens_color
	var frame := Color8(40, 30, 28)
	var gy := head.y - 1
	for gx in [head.x - 3, head.x + 1]:
		_rect(img, gx, gy - 1, 3, 3, frame)
		_rect(img, gx, gy, 3, 1, lens)
		_px(img, gx, gy, lens.lightened(0.45))
	_px(img, head.x, gy, frame)
	if t.goggles == "cracked":
		_px(img, head.x + 1, gy, Color8(235, 235, 225))
		_px(img, head.x + 2, gy - 1, Color8(235, 235, 225))
		_px(img, head.x + 3, gy + 1, Color8(235, 235, 225))
		_rect(img, head.x - 3, gy, 3, 1, lens.darkened(0.35))

	match t.headwear:
		"stovepipe":
			var hat := Color8(34, 28, 30)
			_rect(img, head.x - hr, head.y - hr - 1, hr * 2 + 1, 1, hat)
			_rect(img, head.x - r + 1, head.y - hr - 8, r * 2 - 1, 7, hat)
			_rect(img, head.x - r + 1, head.y - hr - 3, r * 2 - 1, 1, t.accent)
		"bowler":
			var hat := Color8(52, 40, 36)
			_rect(img, head.x - hr, head.y - hr, hr * 2 + 1, 1, hat)
			_rect(img, head.x - r + 1, head.y - hr - 3, r * 2 - 1, 3, hat)
