extends Node
## Undertale-style text box with typewriter text.
##   await DialogueManager.say(["Hello.", "{They} woke up!"], "Tinker")
## Pronoun tokens are swapped for she/her or he/him based on the chosen chassis.

signal finished

const CHARS_PER_SECOND := 45.0

var active := false

var _layer: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _name_plate: PanelContainer
var _text_label: Label
var _hint: Label
var _lines: Array[String] = []
var _index := 0
var _typing := false
var _shown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func say(lines: Array, speaker := "") -> void:
	if active:
		await finished
	_lines.clear()
	for line in lines:
		_lines.append(format_text(str(line)))
	if _lines.is_empty():
		return
	active = true
	_index = 0
	_name_label.text = speaker
	_name_plate.visible = speaker != ""
	_panel.show()
	_panel.modulate.a = 0.0
	_panel.position.y += 10.0
	var tw := _panel.create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.14)
	tw.tween_property(_panel, "position:y", _panel.position.y - 10.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	GameState.lock_ui()
	_show_line()
	await finished


## Replaces {they}/{them}/{their}/{theirs} (and capitalised versions).
func format_text(text: String) -> String:
	var p := GameState.pronouns()
	for key in p:
		text = text.replace("{%s}" % key, p[key])
		text = text.replace("{%s}" % key.capitalize(), p[key].capitalize())
	return text


func _show_line() -> void:
	_text_label.text = _lines[_index]
	_text_label.visible_characters = 0
	_shown = 0.0
	_typing = true
	_hint.hide()


func _process(delta: float) -> void:
	if not active or not _typing:
		return
	var before := int(_shown)
	_shown += delta * CHARS_PER_SECOND
	_text_label.visible_characters = int(_shown)
	if int(_shown) != before and int(_shown) % 2 == 0:
		AudioManager.sfx(&"blip", -12.0, 0.08)
	if _text_label.visible_characters >= _text_label.text.length():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_hint.show()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	active = false
	_panel.hide()
	# Wait one frame so the button press that closed the box doesn't also make the robot jump.
	await get_tree().process_frame
	GameState.unlock_ui()
	finished.emit()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 32
	_panel.offset_right = -32
	_panel.offset_top = -108
	_panel.offset_bottom = -10
	_layer.add_child(_panel)

	var box := VBoxContainer.new()
	_panel.add_child(box)
	_name_plate = PanelContainer.new()
	_name_plate.add_theme_stylebox_override("panel", UIKit.box("res://art/ui/nameplate.png", 6, 6, 6, 6, 10, 2, 10, 2))
	_name_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_name_plate)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color8(70, 44, 18))
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_plate.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_override("font", UIKit.prose_font())
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.add_theme_constant_override("line_spacing", -2)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text_label)
	_hint = Label.new()
	_hint.text = "v"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.add_theme_color_override("font_color", Color("ffb347"))
	box.add_child(_hint)
	_panel.hide()
