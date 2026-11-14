extends Node

signal player_spawned(player: Node)
signal player_died
signal player_dashed(at_position: Vector2, direction: int)
signal health_changed(current: int, maximum: int)

signal blade_thrown
signal blade_returned
signal blade_hooked(point: Node)

signal enemy_killed(enemy_id: StringName, at_position: Vector2)
signal item_collected(item_id: StringName)
signal npc_talked(npc_id: StringName)
signal room_entered(room_id: StringName)
signal quest_updated(quest_id: StringName)

signal currency_changed
signal loadout_changed
signal cosmetics_changed
signal consumables_changed

signal boss_started(boss_name: String, max_health: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_ended

signal toast(text: String)
signal camera_shake(strength: float)
signal interact_prompt(text: String)
signal interior_entered(interior_id: StringName)
signal heal_charge_changed(charge: int, needed: int)
signal region_title(title: String, subtitle: String)
