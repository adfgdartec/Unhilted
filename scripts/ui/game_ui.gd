extends CanvasLayer

signal quit_to_title

var _root: Control
var _open := false
var _last_focus := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_ui")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_root.hide()


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _show(content: Control) -> void:
	for child in _root.get_children():
		if child is CenterContainer:
			child.queue_free()
	var holder := UIKit.centered(content)
	_root.add_child(holder)
	_root.show()
	if not _open:
		content.modulate.a = 0.0
		content.pivot_offset = content.custom_minimum_size * 0.5
		content.scale = Vector2(0.97, 0.97)
		var tw := content.create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(content, "modulate:a", 1.0, 0.12)
		tw.tween_property(content, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _open:
		_open = true
		GameState.lock_ui()
		get_tree().paused = true
	_focus_first.call_deferred(content)


func close() -> void:
	if not _open:
		return
	AudioManager.sfx(&"ui_back", -6.0, 0.0)
	_open = false
	_root.hide()
	for child in _root.get_children():
		if child is CenterContainer:
			child.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	GameState.unlock_ui()


func _focus_first(content: Control) -> void:
	var buttons := content.find_children("*", "Button", true, false)
	if buttons.is_empty():
		return
	var index := clampi(_last_focus, 0, buttons.size() - 1)
	(buttons[index] as Button).grab_focus()


func _remember_focus(content: Control) -> void:
	var buttons := content.find_children("*", "Button", true, false)
	for i in buttons.size():
		if (buttons[i] as Button).has_focus():
			_last_focus = i
			return


func open_dock_menu() -> void:
	_last_focus = 0
	var p := UIKit.panel(Vector2(250, 150))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	p.add_child(box)
	box.add_child(UIKit.heading("CHARGING DOCK"))
	var note := HBoxContainer.new()
	note.add_theme_constant_override("separation", 6)
	var cell := TextureRect.new()
	cell.texture = load("res://art/ui/item_cell.png")
	note.add_child(cell)
	var lines := UIKit.label("Health restored.\nProgress saved.", 8, Color(0.75, 0.82, 0.85))
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.add_child(lines)
	box.add_child(note)
	box.add_child(UIKit.button("Port Loadout", func(): _last_focus = 0; open_loadout()))
	box.add_child(UIKit.button("Wardrobe", func(): _last_focus = 0; open_wardrobe()))
	box.add_child(UIKit.button("Leave", close))
	_show(p)


func open_loadout() -> void:
	var screen := LoadoutScreen.new()
	screen.back_requested.connect(func(): _last_focus = 0; open_dock_menu())
	_show(screen)


func _find_player_stats() -> PlayerStats:
	var player := get_tree().get_first_node_in_group("player")
	return player.stats if player else null


func open_wardrobe() -> void:
	var p := UIKit.panel(Vector2(500, 280))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	col.add_child(UIKit.heading("WARDROBE"))
	col.add_child(UIKit.label("Looks only. Power comes from your ports. Select a slot to cycle what you own.", 8, UIKit.QUIET))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	var case := UIKit.case_panel()
	row.add_child(case)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(150, 196)
	case.add_child(stage)
	var ped := UIKit.pedestal()
	ped.position = Vector2(75 - 22, 176)
	stage.add_child(ped)
	var preview := PlayerVisuals.new()
	preview.preview = true
	preview.preview_gender = GameState.gender
	preview.position = Vector2(75, 169)
	preview.scale = Vector2(3, 3)
	stage.add_child(preview)
	preview.refresh.call_deferred(GameState.outfit)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	row.add_child(grid)
	for slot in CosmeticItem.SLOT_NAMES.size():
		var current: StringName = GameState.outfit.get(slot, &"")
		var item: CosmeticItem = ItemDB.cosmetics.get(current)
		var c := ShopCard.new()
		c.title = CosmeticItem.SLOT_NAMES[slot]
		c.subtitle = item.display_name if item else "None"
		c.icon_tex = item.icon if item else null
		var s: int = slot
		c.pressed.connect(func(): AudioManager.sfx(&"ui_select", -6.0, 0.0); _cycle_slot(s, p))
		grid.add_child(c)
	var chassis := ShopCard.new()
	chassis.title = "Chassis"
	chassis.subtitle = "Girl" if GameState.gender == GameState.Gender.GIRL else "Boy"
	chassis.icon_tex = load("res://art/ui/socket_lit.png")
	chassis.pressed.connect(func(): AudioManager.sfx(&"ui_select", -6.0, 0.0); _toggle_chassis(p))
	grid.add_child(chassis)
	col.add_child(UIKit.button("Back", func(): _last_focus = 0; open_dock_menu()))
	_show(p)


func _cycle_slot(slot: int, panel: Control) -> void:
	_remember_focus(panel)
	var options: Array[StringName] = [&""]
	for id in GameState.owned_cosmetics:
		var item: CosmeticItem = ItemDB.cosmetics.get(id)
		if item and item.slot == slot:
			options.append(id)
	var current: StringName = GameState.outfit.get(slot, &"")
	var next := options[(options.find(current) + 1) % options.size()]
	GameState.set_outfit(slot, next)
	open_wardrobe()


func _toggle_chassis(panel: Control) -> void:
	_remember_focus(panel)
	GameState.gender = GameState.Gender.BOY if GameState.gender == GameState.Gender.GIRL else GameState.Gender.GIRL
	EventBus.cosmetics_changed.emit()
	open_wardrobe()


func open_shop(npc: NPC) -> void:
	var screen := ShopScreen.new()
	screen.npc = npc
	screen.closed.connect(close)
	_show(screen)


func open_settings() -> void:
	var p := UIKit.panel(Vector2(340, 330))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	p.add_child(box)
	box.add_child(UIKit.heading("SETTINGS"))
	box.add_child(UIKit.button("Music volume:  %d%%" % roundi(Fx.music_volume * 100), func(): _toggle_setting("music", p)))
	box.add_child(UIKit.button("Sound volume:  %d%%" % roundi(Fx.sfx_volume * 100), func(): _toggle_setting("sfx", p)))
	box.add_child(UIKit.button("Display:  " + ("Fullscreen" if Fx.fullscreen else "Windowed") + "   (F11)", func(): _toggle_setting("fullscreen", p)))
	box.add_child(UIKit.button("Damage numbers:  " + ("On" if Fx.damage_numbers else "Off"), func(): _toggle_setting("numbers", p)))
	box.add_child(UIKit.button("Controls:  " + Keybinds.PRESET_NAMES[Fx.control_preset] + ("  + your keys" if not Fx.custom_binds.is_empty() else ""), func(): _toggle_setting("controls", p)))
	box.add_child(UIKit.button("Rebind keys...", func(): _remember_focus(p); open_rebind()))
	box.add_child(UIKit.button("Mouse throw:  " + ("Click (aim at cursor)" if Fx.click_throw else "Flick"), func(): _toggle_setting("click_throw", p)))
	box.add_child(UIKit.button("Flick sensitivity:  " + ["Low", "Normal", "High"][Fx.flick_sensitivity], func(): _toggle_setting("flick", p)))
	box.add_child(UIKit.button("Screen shake:  " + ("On" if Fx.shake_enabled else "Off"), func(): _toggle_setting("shake", p)))
	box.add_child(UIKit.button("Hit-stop (freeze frames):  " + ("On" if Fx.hitstop_enabled else "Off"), func(): _toggle_setting("hitstop", p)))
	box.add_child(UIKit.button("Post effects (bloom, grade):  " + ("On" if Fx.post_enabled else "Off"), func(): _toggle_setting("post", p)))
	box.add_child(UIKit.button("Flashing effects:  " + ("On" if Fx.flashes_enabled else "Off"), func(): _toggle_setting("flash", p)))
	box.add_child(UIKit.label("Music and sound step up by 10%; past 100% wraps to off.", 8, UIKit.QUIET))
	box.add_child(UIKit.button("Back", func(): _last_focus = 1; open_pause_menu()))
	_show(p)


func open_rebind() -> void:
	var r := RebindScreen.new()
	r.closed.connect(open_settings)
	_show(r)


func _toggle_setting(key: String, panel: Control) -> void:
	_remember_focus(panel)
	match key:
		"shake": Fx.shake_enabled = not Fx.shake_enabled
		"hitstop": Fx.hitstop_enabled = not Fx.hitstop_enabled
		"post": Fx.post_enabled = not Fx.post_enabled
		"flash": Fx.flashes_enabled = not Fx.flashes_enabled
		"click_throw": Fx.click_throw = not Fx.click_throw
		"fullscreen":
			Fx.fullscreen = not Fx.fullscreen
			Fx.apply_display()
		"numbers": Fx.damage_numbers = not Fx.damage_numbers
		"music": Fx.music_volume = 0.0 if Fx.music_volume >= 0.99 else snappedf(Fx.music_volume + 0.1, 0.1)
		"sfx": Fx.sfx_volume = 0.0 if Fx.sfx_volume >= 0.99 else snappedf(Fx.sfx_volume + 0.1, 0.1)
		"flick": Fx.flick_sensitivity = (Fx.flick_sensitivity + 1) % 3
		"controls":
			var order: Array = Keybinds.PRESET_ORDER
			Fx.control_preset = order[(order.find(Fx.control_preset) + 1) % order.size()]
			Fx.apply_controls()
	Fx.save_settings()
	open_settings()


func toggle_pause() -> void:
	if _open:
		close()
		return
	_last_focus = 0
	open_pause_menu()


func open_pause_menu(tab := -1) -> void:
	var j := JournalScreen.new()
	j.start_tab = tab if tab >= 0 else _journal_tab
	j.resume_requested.connect(close)
	j.settings_requested.connect(func(): _journal_tab = j.current_tab(); _last_focus = 0; open_settings())
	j.quit_to_title_requested.connect(func(): await close(); quit_to_title.emit())
	j.tree_exiting.connect(func(): _journal_tab = j.current_tab())
	_show(j)


var _journal_tab := 0


func open_journal_map() -> void:
	if _open:
		return
	open_pause_menu(0)
