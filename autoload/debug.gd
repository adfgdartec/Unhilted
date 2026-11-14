extends Node

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			GameState.give_shard(1)
		KEY_F2:
			GameState.add_scrap(50)
		KEY_F3:
			GameState.add_local(GameState.current_region, 5, false)
		KEY_F4:
			for id in ItemDB.chips:
				GameState.add_chip(id, false)
			for id in ItemDB.cosmetics:
				GameState.add_cosmetic(id, false)
			GameState.max_ports = GameState.MAX_PORTS
			EventBus.loadout_changed.emit()
			EventBus.toast.emit("DEBUG: everything unlocked")
		KEY_F5:
			SaveManager.save_game()
			EventBus.toast.emit("DEBUG: saved")
		KEY_F9:
			SaveManager.delete_save()
			EventBus.toast.emit("DEBUG: save deleted")
