extends Node

func _ready() -> void:
	var t := UIKit.build_theme()
	var err := ResourceSaver.save(t, UIKit.THEME_PATH)
	print("theme saved: ", err == OK)
	get_tree().quit()
