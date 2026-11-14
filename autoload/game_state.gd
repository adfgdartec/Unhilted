extends Node

enum Gender { GIRL, BOY }
enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETE, TURNED_IN }

const BASE_PORTS := 3
const MAX_PORTS := 8
const START_ROOM := "res://scenes/rooms/heap/heap_01_pit.tscn"
const START_SPAWN := &"wake"

var gender: Gender = Gender.BOY

var shards: Array[bool] = [false, false, false, false, false]
var max_health_bonus := 0
var max_ports := BASE_PORTS
var owned_chips: Array[StringName] = []
var equipped_chips: Array[StringName] = []
var owned_cosmetics: Array[StringName] = []
var outfit: Dictionary = {}

var scrap := 0
var local_balance: Dictionary = {}
var local_found: Dictionary = {}
var consumables: Dictionary = {}
var key_items: Dictionary = {}
var lost_scrap: Dictionary = {}
var shop_bought: Dictionary = {}

var collected_ids: Dictionary = {}
var quest_states: Dictionary = {}
var flags: Dictionary = {}
var visited_rooms: Dictionary = {}
var lore: Dictionary = {}
var current_room := START_ROOM
var current_region: StringName = &"heap"
var respawn_room := START_ROOM
var respawn_spawn: StringName = START_SPAWN

var _ui_lock := 0


func reset() -> void:
	gender = Gender.BOY
	shards = [false, false, false, false, false]
	max_health_bonus = 0
	max_ports = BASE_PORTS
	owned_chips.clear()
	equipped_chips.clear()
	owned_cosmetics.clear()
	outfit.clear()
	scrap = 0
	local_balance.clear()
	local_found.clear()
	consumables.clear()
	key_items.clear()
	lost_scrap.clear()
	shop_bought.clear()
	collected_ids.clear()
	quest_states.clear()
	flags.clear()
	visited_rooms.clear()
	lore.clear()
	current_room = START_ROOM
	current_region = &"heap"
	respawn_room = START_ROOM
	respawn_spawn = START_SPAWN
	_ui_lock = 0


func give_starting_items() -> void:
	for id in [&"hood_navy", &"cloak_navy", &"pants_cargo", &"shoes_old_boots"]:
		add_cosmetic(id, false)
		var item: CosmeticItem = ItemDB.cosmetics.get(id)
		if item:
			outfit[item.slot] = id
	consumables[&"repair_kit"] = 1
	EventBus.cosmetics_changed.emit()


func lock_ui() -> void:
	_ui_lock += 1

func unlock_ui() -> void:
	_ui_lock = maxi(_ui_lock - 1, 0)

func is_ui_locked() -> bool:
	return _ui_lock > 0


func pronouns() -> Dictionary:
	if gender == Gender.GIRL:
		return {"they": "she", "them": "her", "their": "her", "theirs": "hers"}
	return {"they": "he", "them": "him", "their": "his", "theirs": "his"}


func has_shard(number: int) -> bool:
	return number >= 1 and number <= shards.size() and shards[number - 1]

func give_shard(number: int) -> void:
	if number < 1 or number > shards.size() or shards[number - 1]:
		return
	shards[number - 1] = true
	var names := ["I: Edge", "II: Swing", "III: Ricochet", "IV: Live Wire", "V: The Final Piece"]
	EventBus.toast.emit("Shard %s attached to the blade" % names[number - 1])
	EventBus.loadout_changed.emit()


func add_scrap(amount: int) -> void:
	scrap = maxi(scrap + amount, 0)
	EventBus.currency_changed.emit()

func add_local(region: StringName, amount: int, found := true) -> void:
	local_balance[region] = int(local_balance.get(region, 0)) + amount
	if found:
		local_found[region] = int(local_found.get(region, 0)) + amount
	EventBus.currency_changed.emit()

func get_balance(currency: StringName) -> int:
	if currency == &"scrap":
		return scrap
	return int(local_balance.get(currency, 0))

func spend(currency: StringName, amount: int) -> bool:
	if get_balance(currency) < amount:
		return false
	if currency == &"scrap":
		scrap -= amount
	else:
		local_balance[currency] = get_balance(currency) - amount
	EventBus.currency_changed.emit()
	return true


func add_chip(id: StringName, announce := true) -> void:
	if id in owned_chips or not ItemDB.chips.has(id):
		return
	owned_chips.append(id)
	if announce:
		EventBus.toast.emit("New chip: %s  (equip at a charging dock)" % ItemDB.chips[id].display_name)

func add_cosmetic(id: StringName, announce := true) -> void:
	if id in owned_cosmetics or not ItemDB.cosmetics.has(id):
		return
	owned_cosmetics.append(id)
	if announce:
		EventBus.toast.emit("New outfit piece: %s" % ItemDB.cosmetics[id].display_name)

func set_outfit(slot: int, id: StringName) -> void:
	if id == &"":
		outfit.erase(slot)
	else:
		outfit[slot] = id
	EventBus.cosmetics_changed.emit()

func add_port() -> void:
	max_ports = mini(max_ports + 1, MAX_PORTS)
	EventBus.toast.emit("Port expansion installed: %d ports" % max_ports)
	EventBus.loadout_changed.emit()

func add_core_cell() -> void:
	max_health_bonus += 1
	EventBus.toast.emit("Core cell installed: +1 max health")
	EventBus.loadout_changed.emit()

func add_consumable(id: StringName, amount := 1) -> void:
	consumables[id] = int(consumables.get(id, 0)) + amount
	EventBus.consumables_changed.emit()

func use_consumable(id: StringName) -> bool:
	if int(consumables.get(id, 0)) <= 0:
		return false
	consumables[id] = int(consumables[id]) - 1
	EventBus.consumables_changed.emit()
	return true

func add_key_item(id: StringName) -> void:
	key_items[id] = int(key_items.get(id, 0)) + 1

func key_item_count(id: StringName) -> int:
	return int(key_items.get(id, 0))

func mark_collected(unique_id: String) -> void:
	collected_ids[unique_id] = true

func is_collected(unique_id: String) -> bool:
	return collected_ids.has(unique_id)


func ports_used() -> int:
	var total := 0
	for id in equipped_chips:
		var chip: UpgradeChip = ItemDB.chips.get(id)
		if chip:
			total += chip.port_cost
	return total

func can_equip(id: StringName) -> bool:
	var chip: UpgradeChip = ItemDB.chips.get(id)
	if chip == null or id in equipped_chips or not (id in owned_chips):
		return false
	if ports_used() >= max_ports + 1:
		return false
	return ports_used() + chip.port_cost <= max_ports + 1

func is_overclocked() -> bool:
	return ports_used() > max_ports

func toggle_chip(id: StringName) -> bool:
	if id in equipped_chips:
		equipped_chips.erase(id)
	elif can_equip(id):
		equipped_chips.append(id)
	else:
		return false
	EventBus.loadout_changed.emit()
	return true


func has_map(region: StringName) -> bool:
	return bool(flags.get("map_" + String(region), false))


func to_dict() -> Dictionary:
	var outfit_out := {}
	for slot in outfit:
		outfit_out[str(slot)] = String(outfit[slot])
	return {
		"version": 1,
		"gender": gender,
		"shards": shards,
		"max_health_bonus": max_health_bonus,
		"max_ports": max_ports,
		"owned_chips": _names_to_strings(owned_chips),
		"equipped_chips": _names_to_strings(equipped_chips),
		"owned_cosmetics": _names_to_strings(owned_cosmetics),
		"outfit": outfit_out,
		"scrap": scrap,
		"local_balance": _keys_to_strings(local_balance),
		"local_found": _keys_to_strings(local_found),
		"consumables": _keys_to_strings(consumables),
		"key_items": _keys_to_strings(key_items),
		"lost_scrap": lost_scrap.duplicate(true),
		"shop_bought": shop_bought.duplicate(true),
		"collected_ids": collected_ids.duplicate(true),
		"quest_states": _keys_to_strings(quest_states.duplicate(true)),
		"flags": flags.duplicate(true),
		"visited_rooms": visited_rooms.duplicate(true),
		"lore": lore.duplicate(true),
		"respawn_room": respawn_room,
		"respawn_spawn": String(respawn_spawn),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	gender = int(d.get("gender", Gender.BOY)) as Gender
	var s: Array = d.get("shards", [])
	for i in mini(s.size(), shards.size()):
		shards[i] = bool(s[i])
	max_health_bonus = int(d.get("max_health_bonus", 0))
	max_ports = int(d.get("max_ports", BASE_PORTS))
	owned_chips = _strings_to_names(d.get("owned_chips", []))
	equipped_chips = _strings_to_names(d.get("equipped_chips", []))
	owned_cosmetics = _strings_to_names(d.get("owned_cosmetics", []))
	var o: Dictionary = d.get("outfit", {})
	for key in o:
		outfit[int(key)] = StringName(o[key])
	scrap = int(d.get("scrap", 0))
	local_balance = _keys_to_names(d.get("local_balance", {}), true)
	local_found = _keys_to_names(d.get("local_found", {}), true)
	consumables = _keys_to_names(d.get("consumables", {}), true)
	key_items = _keys_to_names(d.get("key_items", {}), true)
	lost_scrap = (d.get("lost_scrap", {}) as Dictionary).duplicate(true)
	shop_bought = (d.get("shop_bought", {}) as Dictionary).duplicate(true)
	collected_ids = (d.get("collected_ids", {}) as Dictionary).duplicate(true)
	quest_states = _keys_to_names(d.get("quest_states", {}), false)
	for id in quest_states:
		var q: Dictionary = quest_states[id]
		q["state"] = int(q.get("state", 0))
		q["progress"] = (q.get("progress", []) as Array).map(func(v): return int(v))
	if lost_scrap.has("amount"):
		lost_scrap["amount"] = int(lost_scrap["amount"])
	for key in shop_bought:
		shop_bought[key] = int(shop_bought[key])
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	visited_rooms = (d.get("visited_rooms", {}) as Dictionary).duplicate(true)
	lore = (d.get("lore", {}) as Dictionary).duplicate(true)
	respawn_room = d.get("respawn_room", START_ROOM)
	respawn_spawn = StringName(d.get("respawn_spawn", START_SPAWN))


func _names_to_strings(arr: Array) -> Array:
	return arr.map(func(n): return String(n))

func _strings_to_names(arr: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in arr:
		out.append(StringName(s))
	return out

func _keys_to_strings(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out

func _keys_to_names(d: Dictionary, int_values: bool) -> Dictionary:
	var out := {}
	for k in d:
		out[StringName(k)] = int(d[k]) if int_values else d[k]
	return out
