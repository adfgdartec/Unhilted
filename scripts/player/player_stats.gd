class_name PlayerStats
extends Node
## Every tunable number for the robot lives here. Movement and blade code
## ask get_stat("name") instead of using fixed values, so port chips can
## change anything. Final stat = (base + chip adds) * chip multipliers.
## Tweak `base` in the Inspector while the game runs to tune the feel.

signal stats_changed

@export var base := {
	# Movement (tuned for an Ultrakill-like flow: ~1.5x the original speeds;
	# momentum rules live in Player.move_horizontal and the slide/dash/grapple states)
	"max_speed": 185.0,
	"ground_accel": 3800.0,
	"ground_friction": 3600.0,
	"air_accel": 2300.0,
	# Jump (gravity is calculated from height + time, which is much easier to tune)
	"jump_height": 58.0,
	"jump_time_to_apex": 0.34,
	"fall_gravity_mult": 1.6,
	"terminal_velocity": 520.0,
	"jump_cut": 0.25,          # velocity kept when jump is released early (short hop)
	"apex_gravity_mult": 0.55,  # lighter gravity near the top of a held jump (hang time)
	"coyote_time": 0.1,
	"jump_buffer": 0.12,
	# Dash
	"dash_speed": 470.0,
	"dash_duration": 0.13,
	"dash_cooldown": 0.3,
	# Defence
	"max_health": 5.0,
	"invuln_time": 0.9,
	# Blade
	"melee_damage": 1.0,
	"blade_damage": 2.0,      # thrown blade hits harder than melee (1): reward the throw, not swing-spam
	"recall_damage_mult": 1.0,
	"throw_speed": 560.0,
	"wire_length": 150.0,
	"recall_speed": 520.0,
	"grapple_speed": 480.0,
	# Misc
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


## Spawns the effect scene of every equipped chip under Player/Upgrades.
func _rebuild_effects() -> void:
	if _upgrades_node == null:
		return
	for child in _upgrades_node.get_children():
		child.queue_free()
	for id in GameState.equipped_chips:
		var chip: UpgradeChip = ItemDB.chips.get(id)
		if chip and chip.effect_scene:
			_upgrades_node.add_child(chip.effect_scene.instantiate())
