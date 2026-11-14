extends SceneTree

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e

func _mouse(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func _axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _init() -> void:
	var actions := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _pad(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _pad(JOY_BUTTON_DPAD_RIGHT)],
		"aim_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _pad(JOY_BUTTON_DPAD_LEFT)],
		"aim_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _pad(JOY_BUTTON_DPAD_RIGHT)],
		"aim_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _pad(JOY_BUTTON_DPAD_UP)],
		"aim_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _pad(JOY_BUTTON_DPAD_DOWN)],
		"jump": [_key(KEY_SPACE), _pad(JOY_BUTTON_A)],
		"attack": [_mouse(MOUSE_BUTTON_RIGHT), _pad(JOY_BUTTON_X)],
		"throw": [_mouse(MOUSE_BUTTON_LEFT), _pad(JOY_BUTTON_RIGHT_SHOULDER)],
		"dash": [_key(KEY_L), _key(KEY_SHIFT), _pad(JOY_BUTTON_B)],
		"slide": [_key(KEY_CTRL), _key(KEY_C), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"interact": [_key(KEY_E), _pad(JOY_BUTTON_Y)],
		"use_item": [_key(KEY_Q), _pad(JOY_BUTTON_LEFT_SHOULDER)],
		"pause": [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)],
		"fullscreen": [_key(KEY_F11)],
		"map": [_key(KEY_TAB), _key(KEY_M), _pad(JOY_BUTTON_BACK)],
	}
	for action_name in actions:
		ProjectSettings.set_setting("input/" + action_name, {
			"deadzone": 0.3,
			"events": actions[action_name],
		})
	ProjectSettings.save()
	print("Input map written.")
	quit()
