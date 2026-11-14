class_name PlayerStats
extends Node

signal stats_changed

@export var base := {
	"max_speed": 185.0,
	"ground_accel": 3800.0,
	"ground_friction": 3600.0,
	"air_accel": 2300.0,
	"jump_height": 58.0,
	"jump_time_to_apex": 0.34,
	"fall_gravity_mult": 1.6,
	"terminal_velocity": 520.0,
	"jump_cut": 0.25,
	"apex_gravity_mult": 0.55,
	"coyote_time": 0.1,
	"jump_buffer": 0.12,
	"dash_speed": 470.0,
	"dash_duration": 0.13,
	"dash_cooldown": 0.3,
	"max_health": 5.0,
	"invuln_time": 0.9,
	"melee_damage": 1.0,
	"blade_damage": 2.0,
	"recall_damage_mult": 1.0,
	"throw_speed": 560.0,
	"wire_length": 150.0,
	"recall_speed": 520.0,
	"grapple_speed": 480.0,
	"magnet_radius": 18.0,
}

var _current: Dictionary = {}
var _upgrades_node: Node


func setup(upgrades_node: Node) -> void:
	_upgrades_node = upgrades_node
	if not EventBus.loadout_changed.is_connected(recalculate):
		EventBus.loadout_changed.connect(recalculate)
	recalculate()


func get_stat(stat: String) -> float:
	return _current.get(stat, base.get(stat, 0.0))


func recalculate() -> void:
	var adds := {}
	var mults := {}
	for id in GameState.equipped_chips:
		var chip: UpgradeChip = ItemDB.chips.get(id)
		if chip == null:
			continue
		for key in chip.add_modifiers:
			adds[key] = adds.get(key, 0.0) + float(chip.add_modifiers[key])
		for key in chip.mult_modifiers:
			mults[key] = mults.get(key, 1.0) * float(chip.mult_modifiers[key])
	adds["max_health"] = adds.get("max_health", 0.0) + GameState.max_health_bonus

	for key in base:
		_current[key] = (float(base[key]) + adds.get(key, 0.0)) * mults.get(key, 1.0)

	_rebuild_effects()
	stats_changed.emit()


func _rebuild_effects() -> void:
	if _upgrades_node == null:
		return
	for child in _upgrades_node.get_children():
		child.queue_free()
	for id in GameState.equipped_chips:
		var chip: UpgradeChip = ItemDB.chips.get(id)
		if chip and chip.effect_scene:
			_upgrades_node.add_child(chip.effect_scene.instantiate())
