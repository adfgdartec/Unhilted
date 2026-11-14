class_name Keybinds
extends RefCounted

const PRESET_ORDER := ["standard", "arrows", "jkl"]
const PRESET_NAMES := {
	"standard": "Standard (WASD + mouse)",
	"arrows": "Arrows + Z X C",
	"jkl": "WASD + J K L",
}

const ACTIONS := [
	["move_left", "Move left"], ["move_right", "Move right"], ["move_up", "Look / aim up"],
	["move_down", "Look / aim down"], ["jump", "Jump"], ["attack", "Attack"], ["throw", "Throw blade"],
	["dash", "Dash"], ["slide", "Slide"], ["interact", "Interact"], ["use_item", "Repair kit"],
	["map", "Map"],
]

const PRESETS := {
	"standard": {
		"move_left": ["key:A", "key:Left"], "move_right": ["key:D", "key:Right"],
		"move_up": ["key:W", "key:Up"], "move_down": ["key:S", "key:Down"],
		"jump": ["key:Space"], "attack": ["mouse:2"], "throw": ["mouse:1"],
		"dash": ["key:Shift", "key:L"], "slide": ["key:Ctrl", "key:C"],
		"interact": ["key:E"], "use_item": ["key:Q"], "map": ["key:Tab", "key:M"],
	},
	"arrows": {
		"move_left": ["key:Left"], "move_right": ["key:Right"],
		"move_up": ["key:Up"], "move_down": ["key:Down"],
		"jump": ["key:Z"], "attack": ["key:X"], "throw": ["key:C"],
		"dash": ["key:Shift", "key:V"], "slide": ["key:A"],
		"interact": ["key:Up", "key:E"], "use_item": ["key:Q"], "map": ["key:Tab"],
	},
	"jkl": {
		"move_left": ["key:A"], "move_right": ["key:D"],
		"move_up": ["key:W"], "move_down": ["key:S"],
		"jump": ["key:K", "key:Space"], "attack": ["key:J"], "throw": ["key:L"],
		"dash": ["key:Semicolon", "key:Shift"], "slide": ["key:I"],
		"interact": ["key:E"], "use_item": ["key:Q"], "map": ["key:Tab"],
	},
}


static func _targets(action: String) -> Array:
	match action:
		"move_left": return ["move_left", "aim_left"]
		"move_right": return ["move_right", "aim_right"]
		"move_up": return ["aim_up"]
		"move_down": return ["aim_down"]
	return [action]


static func _event(desc: String) -> InputEvent:
	var parts := desc.split(":", true, 1)
	if parts.size() != 2:
		return null
	if parts[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	var code := OS.find_keycode_from_string(parts[1])
	if code == KEY_NONE:
		return null
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k


static func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		var name := OS.get_keycode_string(code)
		return "key:" + name if name != "" else ""
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return "mouse:%d" % event.button_index
	return ""


static func pretty(desc: String) -> String:
	match desc:
		"mouse:1": return "Left click"
		"mouse:2": return "Right click"
		"mouse:3": return "Middle click"
	return desc.trim_prefix("key:")


static func bindings(action: String, preset: String, custom: Dictionary) -> Array:
	if custom.has(action):
		return custom[action]
	return PRESETS.get(preset, PRESETS["standard"]).get(action, [])


static func label(action: String, preset: String, custom: Dictionary) -> String:
	return " / ".join(bindings(action, preset, custom).map(func(d): return pretty(d)))


static func apply(preset: String, custom: Dictionary) -> void:
	for entry in ACTIONS:
		var action: String = entry[0]
		var descs: Array = bindings(action, preset, custom)
		for target in _targets(action):
			if not InputMap.has_action(target):
				continue
			for e in InputMap.action_get_events(target):
				if e is InputEventKey or e is InputEventMouseButton:
					InputMap.action_erase_event(target, e)
			for d in descs:
				var ev := _event(d)
				if ev:
					InputMap.action_add_event(target, ev)


static func summary(preset: String, custom: Dictionary) -> String:
	var mv := "%s %s %s %s" % [label("move_up", preset, custom).get_slice(" / ", 0), label("move_left", preset, custom).get_slice(" / ", 0),
		label("move_down", preset, custom).get_slice(" / ", 0), label("move_right", preset, custom).get_slice(" / ", 0)]
	return "%s / stick: move   %s / A: jump   %s / X: attack   %s / RB: throw blade\n%s / B: dash   %s / LT: slide   Esc: pause, Settings > Controls to change keys" % [
		mv, label("jump", preset, custom), label("attack", preset, custom), label("throw", preset, custom),
		label("dash", preset, custom), label("slide", preset, custom)]
