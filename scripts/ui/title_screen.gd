extends CanvasLayer

signal new_game_requested(gender: int)
signal continue_requested
signal demo_run_requested

var _root: Control


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)


func show_title(has_save: bool) -> void:
	_clear()
	show()
	var near: Texture2D = load("res://art/backdrops/heap_near.png")
	var img := near.get_image()
	var ground := ColorRect.new()
	ground.color = img.get_pixel(img.get_width() / 2, img.get_height() - 1)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(ground)
	var sky_img: Image = (load("res://art/backdrops/heap_sky.png") as Texture2D).get_image()
	var sky := ColorRect.new()
	sky.color = sky_img.get_pixel(0, 0)
	sky.anchor_right = 1.0
	sky.offset_bottom = 200
	_root.add_child(sky)
	for path in ["res://art/backdrops/heap_sky.png", "res://art/backdrops/heap_city.png",
			"res://art/backdrops/heap_far.png", "res://art/backdrops/heap_near.png"]:
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.anchor_right = 1.0
		tr.offset_top = -30
		tr.offset_bottom = tr.texture.get_height() - 30
		tr.stretch_mode = TextureRect.STRETCH_TILE
		_root.add_child(tr)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.position = Vector2(48, 92)
	var logo := UIKit.label("UNHILTED", 16, UIKit.CYAN)
	logo.add_theme_font_size_override("font_size", 32)
	box.add_child(logo)
	box.add_child(UIKit.label("the last shard was never set", 8, UIKit.QUIET))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	menu.custom_minimum_size = Vector2(130, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(menu)
	if has_save:
		menu.add_child(UIKit.button("Continue", func(): continue_requested.emit()))
	menu.add_child(UIKit.button("New Game", show_chassis_select))
	menu.add_child(UIKit.button("Quit", func(): get_tree().quit()))
	_root.add_child(box)
	_focus_first.call_deferred(box)


func show_demo_title() -> void:
	show_title(false)
	var box: VBoxContainer = null
	for c in _root.get_children():
		if c is VBoxContainer:
			box = c
	var menu: VBoxContainer = box.get_child(box.get_child_count() - 1)
	for b in menu.get_children():
		b.queue_free()
	var tag := UIKit.label("SHOWCASE DEMO  -  BOUNCING BACK", 8, UIKit.AMBER)
	box.add_child(tag)
	box.move_child(tag, 2)
	menu.add_child(UIKit.button("Play", func(): hide(); _clear(); demo_run_requested.emit()))
	var blurb := UIKit.label("They threw you away. Get back up, bounce back, and take the first shard.", 8, Color(0.92, 0.88, 0.8))
	blurb.add_theme_constant_override("outline_size", 4)
	blurb.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.07))
	menu.add_child(blurb)
	var controls := UIKit.label(Keybinds.summary(Fx.control_preset, Fx.custom_binds), 8, UIKit.QUIET)
	controls.position = Vector2(48, 316)
	_root.add_child(controls)
	_focus_first.call_deferred(box)


func show_chassis_select() -> void:
	_clear()
	var bg := ColorRect.new()
	bg.color = Color("05070a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var term := UIKit.label("> SIGNAL DETECTED\n> REACTIVATING UNIT...  DORMANT 2,000 YEARS", 8, Color(0.4, 1.0, 0.6))
	box.add_child(term)
	var h := UIKit.heading("SELECT CHASSIS")
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(h)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for g in [GameState.Gender.GIRL, GameState.Gender.BOY]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var case := UIKit.case_panel()
		col.add_child(case)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(110, 150)
		case.add_child(holder)
		var ped := UIKit.pedestal()
		ped.position = Vector2(55 - 22, 134)
		holder.add_child(ped)
		var preview := PlayerVisuals.new()
		preview.preview = true
		preview.preview_gender = g
		preview.position = Vector2(55, 126)
		preview.scale = Vector2(3.5, 3.5)
		holder.add_child(preview)
		preview.refresh.call_deferred({0: &"hood_navy", 2: &"cloak_navy", 4: &"pants_cargo", 5: &"shoes_old_boots"})
		var gender: int = g
		var b := UIKit.button("GIRL" if g == GameState.Gender.GIRL else "BOY", func(): _choose(gender))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(b)
		row.add_child(col)
	box.add_child(UIKit.label("Only your look and pronouns change. You can switch later at a charging dock.", 8, UIKit.QUIET))
	_root.add_child(UIKit.centered(box))
	_focus_first.call_deferred(box)


func _choose(gender: int) -> void:
	hide()
	_clear()
	new_game_requested.emit(gender)


func _clear() -> void:
	for child in _root.get_children():
		child.queue_free()


func _focus_first(box: Control) -> void:
	var buttons := box.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()
