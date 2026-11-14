class_name FxParticles
extends RefCounted

static var _streak: Texture2D


static func _base(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	return p


static func _fade(c: Color, hold := 0.5) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.add_point(hold, c)
	g.set_color(g.get_point_count() - 1, Color(c, 0.0))
	return g


static func burst(color: Color, amount := 12, speed := 130.0, gravity := 380.0) -> CPUParticles2D:
	var p := _base(amount, 0.5)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 30.0
	p.damping_max = 80.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _fade(color, 0.45)
	return p


static func puff(color: Color, amount := 8, speed := 60.0) -> CPUParticles2D:
	var p := _base(amount, 0.45)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 85.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, -12)
	p.damping_min = 90.0
	p.damping_max = 140.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color_ramp = _fade(color, 0.3)
	return p


static func motes(area: Rect2, color: Color, amount: int) -> CPUParticles2D:
	var p := _base(amount, 7.0)
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area.size * 0.5
	p.position = area.get_center()
	p.direction = Vector2(1, -0.4)
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector2(1.5, -1.0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.0))
	g.add_point(0.25, color)
	g.add_point(0.75, color)
	g.set_color(g.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = g
	return p


static func rain(area: Rect2) -> CPUParticles2D:
	if _streak == null:
		var img := Image.create(1, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			img.set_pixel(0, y, Color(1, 1, 1, float(y + 1) / 6.0))
		_streak = ImageTexture.create_from_image(img)
	var p := _base(int(area.size.x / 3.5), (area.size.y + 60.0) / 300.0)
	p.preprocess = 2.0
	p.texture = _streak
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x * 0.5 + 80.0, 2.0)
	p.position = Vector2(area.get_center().x - 40.0, area.position.y - 12.0)
	p.direction = Vector2(0.22, 1.0)
	p.spread = 2.0
	p.initial_velocity_min = 280.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2.ZERO
	p.particle_flag_align_y = true
	p.color = Color(0.7, 0.8, 0.95, 0.22)
	return p


static func embers() -> CPUParticles2D:
	var p := _base(12, 1.6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2.UP
	p.spread = 22.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(4, -14)
	p.color_ramp = _fade(Color(1.0, 0.75, 0.3), 0.35)
	return p


static func smoke() -> CPUParticles2D:
	var p := _base(10, 2.4)
	p.direction = Vector2.UP
	p.spread = 15.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(5, -4)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = _fade(Color(0.55, 0.52, 0.6, 0.35), 0.4)
	return p


static func sparks() -> CPUParticles2D:
	var p := _base(7, 2.8)
	p.explosiveness = 1.0
	p.direction = Vector2.DOWN
	p.spread = 70.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 260)
	p.color_ramp = _fade(Color(0.6, 1.0, 1.0), 0.12)
	return p


static func trickle(color: Color) -> CPUParticles2D:
	var p := _base(14, 1.8)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(9, 1)
	p.direction = Vector2.DOWN
	p.spread = 6.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(0, 140)
	p.color_ramp = _fade(color, 0.6)
	return p
