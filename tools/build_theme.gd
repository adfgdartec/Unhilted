extends Node
## Saves UIKit's theme to res://art/ui/theme.tres (the project theme).
## Run: godot --headless --path . res://tools/build_theme.tscn

func _ready() -> void:
	var t := UIKit.build_theme()
	var err := ResourceSaver.save(t, UIKit.THEME_PATH)
	print("theme saved: ", err == OK)
	get_tree().quit()
