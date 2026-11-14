class_name NPCLook
extends RefCounted
## Paints a resident as pixel art from their Lineage plus a seed.
## Shared (inherited from the lineage): silhouette, palette, stitched patchwork
## coat, oversized boots, the signature lens colour.
## Rolled per resident: height, build, hunch, coat shade, patches, headwear,
## goggle style, scarf, accessory, skin and hair. Designers can pin any trait.
## Returns two idle frames (the second is the breath-in).
## The canvas leaves headroom above the tallest resident for tall hats
## (Bellows Kin stovepipes); feet are always on the bottom row.

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


## Where the goggle lens sits (for the glow light), relative to the feet.
static func lens_offset(traits: Dictionary) -> Vector2:
	var head := _head_center(traits, 0)
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
	var cx := W / 2
	var w: int = t.width
	var hem := H - 6
	var top := hem - int(t.height) - breath
	var coat: Color = t.coat
	var dark := coat.darkened(0.28)
	var light := coat.lightened(0.16)

	# backpack sits behind everything
	if t.accessory == "pack":
		_rect(img, cx - w / 2 - 4, top + 3, 5, 8, dark.darkened(0.2))
		_rect(img, cx - w / 2 - 4, top + 3, 5, 1, coat)

	# oversized boots (family trait), toes forward
	var bw := w / 2 + 2
	_rect(img, cx - w / 2 - 1, H - 4, bw, 4, L.boot_color)
	_rect(img, cx, H - 4, bw + 1, 4, L.boot_color)
	_rect(img, cx - w / 2 - 1, H - 4, bw, 1, L.boot_color.lightened(0.2))
	_rect(img, cx, H - 4, bw + 1, 1, L.boot_color.lightened(0.2))
	_rect(img, cx - w / 2 + 1, H - 6, w - 2, 2, L.trouser_color)

	# patchwork coat, shaped row by row: rounded shoulders, a belly on the
	# stout, a hump on the hunched, a flared and ragged hem; lit from the right
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
		# long fitted coat: a lapel line, a row of brass buttons, a clean dark hem
		for y in range(top + 1, top + 4):
			_px(img, cx - 2 + (y - top), y, dark)
		for y in range(top + 4, hem - 1, 3):
			_px(img, cx - 1, y, Color8(201, 150, 60))
		_rect(img, cx - w / 2, hem - 1, w, 1, dark)
	else:
		for x in range(cx - w / 2 - 1, cx + w / 2 + 1, 2):  # ragged hem
			_px(img, x, hem - 1, Color(0, 0, 0, 0))
		for y in range(top + 1, hem, 2):  # the family's stitched seam
			_px(img, cx - 1, y, dark)
	for p in t.patches:
		var px := cx - w / 2 + 1 + int(p[0]) % maxi(w - 4, 1)
		var py := top + 3 + int(p[1]) % maxi(int(t.height) - 6, 1)
		_rect(img, px, py, 3, 3, p[2])
		_px(img, px, py, (p[2] as Color).darkened(0.3))
		_px(img, px + 2, py + 2, (p[2] as Color).darkened(0.3))

	if t.accessory == "apron":
		# canvas for the Heap; heavy leather for the Bellows Kin's workshops
		var cloth := Color8(176, 150, 112) if L.coat_style == "patchwork" else Color8(112, 72, 46)
		_rect(img, cx - w / 2 + 2, top + int(t.height) / 2, w - 3, hem - top - int(t.height) / 2 + 1, cloth)
		_rect(img, cx - w / 2 + 2, top + int(t.height) / 2, w - 3, 1, cloth.darkened(0.2))
	if t.accessory == "belt":
		_rect(img, cx - w / 2, top + int(t.height) * 2 / 3, w, 1, Color8(84, 56, 40))
		_rect(img, cx + w / 2 - 3, top + int(t.height) * 2 / 3 + 1, 1, 4, Color8(150, 146, 140))   # wrench
		_rect(img, cx + w / 2 - 4, top + int(t.height) * 2 / 3 + 4, 3, 1, Color8(150, 146, 140))

	# front arm and hand
	var arm_x := cx + w / 2 - 2  # one pixel proud of the coat, so the arm breaks the silhouette
	var arm_h := mini(int(t.height) - 5, 14)
	var hand_y := top + 2 + arm_h
	if t.accessory == "brass_arm":
		# a brass prosthetic: segmented, with a bright elbow joint and pincer fingers
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

	# scarf
	var head := _head_center(t, breath)
	var r: int = t.head_r
	if t.scarf:
		_rect(img, head.x - r + 1, head.y + r - 1, r * 2, 2, t.accent)
		_rect(img, head.x - r, head.y + r + 1, 2, 4, (t.accent as Color).darkened(0.15))

	# round head (family trait)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r + 1:
				_px(img, head.x + x, head.y + y, t.skin)
	_px(img, head.x + r - 1, head.y - r + 2, (t.skin as Color).lightened(0.15))

	# headwear
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
			# a tall hat (the Bellows Kin): brim, crown, a band in the accent colour
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

	# goggles: the family signature
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
			# one round glass in a brass rim over the right eye
			var rim := Color8(201, 150, 60)
			_rect(img, head.x + 1, gy - 2, 4, 4, rim)
			_rect(img, head.x + 2, gy - 1, 2, 2, lens)
			_px(img, head.x + 2, gy - 1, lens.lightened(0.4))
			_px(img, head.x + 4, gy + 2, rim) # the chain
			_px(img, head.x + 4, gy + 3, rim)
		"raised":
			_rect(img, head.x + 1, gy - 1, 2, 2, lens.darkened(0.15))
			_rect(img, head.x + 4, gy - 1, 1, 2, lens.darkened(0.15))
			_px(img, head.x + 3, head.y, Color8(40, 28, 26))  # eye, visible when goggles are up


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
