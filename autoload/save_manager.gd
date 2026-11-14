extends Node
## Writes GameState to a JSON file and reads it back.
## Saves happen at charging docks and on every room transition (pickups stick),
## but you always *respawn* at the last dock, Hollow Knight style.

const SAVE_PATH := "user://save_slot_1.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if DemoMode.enabled():
		return # the showcase demo never writes a save
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write save (%s)" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: save file is corrupt")
		return false
	GameState.from_dict(data)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
