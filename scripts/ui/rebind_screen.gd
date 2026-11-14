class_name RebindScreen
extends PanelContainer

signal closed

var _waiting := ""
var _box: VBoxContainer
var _hint: Label


func _init() -> void:
	custom_minimum_size = Vector2(380, 320)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build(focus_index := 0) -> void:
	for c in get_children():
		c.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	add_child(_box)
	_box.add_child(UIKit.heading("REBIND KEYS"))
	_box.add_child(UIKit.label("Scheme: " + Keybinds.PRESET_NAMES[Fx.control_preset] + "   (controllers always work)", 8, UIKit.QUIET))
	var first: Button = null
	var i := 0
	for entry in Keybinds.ACTIONS:
		var action: String = entry[0]
		var mark := "  *" if Fx.custom_binds.has(action) else ""
		var text := "%s:  %s%s" % [entry[1], Keybinds.label(action, Fx.control_preset, Fx.custom_binds), mark]
		var b := UIKit.button(text, func(): _start(action))
		_box.add_child(b)
		if i == focus_index:
			first = b
		i += 1
	_box.add_child(UIKit.button("Reset all keys to the scheme", _reset_all))
	_box.add_child(UIKit.button("Back", func(): closed.emit()))
	_hint = UIKit.label("Pick an action, then press a key or mouse button.  * = your own key", 8, UIKit.QUIET)
	_box.add_child(_hint)
	if first:
		first.grab_focus.call_deferred()


func _start(action: String) -> void:
	_waiting = action
	_hint.text = "Press a key or mouse button for %s   (Esc cancels, Backspace resets it)" % _name(action)
	_hint.add_theme_color_override("font_color", UIKit.AMBER)


func _name(action: String) -> String:
	for entry in Keybinds.ACTIONS:
		if entry[0] == action:
			return entry[1]
	return action


func _index(action: String) -> int:
	for i in Keybinds.ACTIONS.size():
		if Keybinds.ACTIONS[i][0] == action:
			return i
	return 0


func _input(event: InputEvent) -> void:
	if _waiting == "":
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _waiting
	_waiting = ""
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_build(_index(action))
		return
	if event is InputEventKey and event.physical_keycode == KEY_BACKSPACE:
		Fx.custom_binds.erase(action)
	else:
		var desc := Keybinds.describe_event(event)
		if desc == "":
			_build(_index(action))
			return
		Fx.custom_binds[action] = [desc]
	Fx.apply_controls()
	Fx.save_settings()
	AudioManager.sfx(&"ui_select", -6.0, 0.0)
	_build(_index(action))


func _reset_all() -> void:
	Fx.custom_binds = {}
	Fx.apply_controls()
	Fx.save_settings()
	_build()
