class_name LoadoutScreen
extends PanelContainer
## Port Loadout: a grid of round port sockets on top, your chip collection in
## a tray below, and a readout on the right. Select a chip to press it into
## the next free socket (it flies over, clicks in, the contacts light up);
## select a seated chip, or the same chip in the tray, to pop it back out.
## A 2-port chip fills two sockets joined by a lit conduit. The socket after
## your limit is the red overclock socket. Locked sockets are bolted shut.

signal back_requested

const COLS := 4

var _sockets: GridContainer
var _tray: GridContainer
var _name: Label
var _cost: Label
var _desc: Label
var _big: TextureRect
var _ports_label: Label
var _warn: Label
var _stats: Label
var _busy := false
var _focus_id: StringName = &""
var _socket_slots: Array[ChipSlot] = []
var _tray_slots := {} ## chip id -> ChipSlot


func _init() -> void:
	custom_minimum_size = Vector2(490, 290)


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_child(UIKit.heading("PORT LOADOUT"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_ports_label = UIKit.label("", 8, UIKit.TEXT)
	top.add_child(_ports_label)
	col.add_child(top)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	body.add_child(left)
	left.add_child(UIKit.label("PORTS", 8, UIKit.QUIET))
	_sockets = GridContainer.new()
	_sockets.columns = COLS
	_sockets.add_theme_constant_override("h_separation", 6)
	_sockets.add_theme_constant_override("v_separation", 4)
	left.add_child(_sockets)
	left.add_child(UIKit.label("CHIPS", 8, UIKit.QUIET))
	_tray = GridContainer.new()
	_tray.columns = 5
	_tray.add_theme_constant_override("h_separation", 4)
	_tray.add_theme_constant_override("v_separation", 2)
	left.add_child(_tray)

	var case := UIKit.case_panel()
	case.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(case)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(190, 0)
	right.add_theme_constant_override("separation", 4)
	case.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	right.add_child(head)
	_big = TextureRect.new()
	_big.custom_minimum_size = Vector2(56, 56)
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_big)
	var head_text := VBoxContainer.new()
	head_text.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(head_text)
	_name = UIKit.label("", 8, UIKit.AMBER)
	head_text.add_child(_name)
	_cost = UIKit.label("", 8, UIKit.CYAN)
	head_text.add_child(_cost)
	_desc = UIKit.label("", 8, Color(0.75, 0.9, 0.95))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(190, 48)
	right.add_child(_desc)
	_warn = UIKit.label("", 8, Color(1, 0.4, 0.38))
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.custom_minimum_size = Vector2(190, 0)
	right.add_child(_warn)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	_stats = UIKit.label("", 8, UIKit.QUIET)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(190, 0)
	right.add_child(_stats)

	var back := UIKit.button("Back", func(): if not _busy: back_requested.emit())
	col.add_child(back)
	refresh()


## Rebuilds both grids from GameState and puts focus back where it was.
func refresh() -> void:
	for c in _sockets.get_children():
		c.queue_free()
	for c in _tray.get_children():
		c.queue_free()
	_socket_slots.clear()
	_tray_slots.clear()

	# --- sockets
	var owner_of := [] # socket index -> chip id (or &"")
	for id in GameState.equipped_chips:
		var chip: UpgradeChip = ItemDB.chips.get(id)
		if chip:
			for i in chip.port_cost:
				owner_of.append(id if i == 0 else StringName("+" + String(id)))
	var total := GameState.MAX_PORTS + (1 if GameState.max_ports >= GameState.MAX_PORTS else 0)
	for i in total:
		var slot := ChipSlot.new()
		var limit := GameState.max_ports
		if i < limit:
			slot.socket = "lit" if i < owner_of.size() else "empty"
		elif i == limit:
			slot.socket = "over"
		else:
			slot.socket = "locked"
		if i < owner_of.size():
			var key: StringName = owner_of[i]
			var is_link := String(key).begins_with("+")
			var id := StringName(String(key).trim_prefix("+"))
			slot.chip_id = id
			if is_link:
				slot.linked = i % COLS != 0
			else:
				slot.chip = _icon(id)
		if slot.socket == "locked":
			slot.focus_mode = Control.FOCUS_NONE
		var index := i
		slot.pressed.connect(func(): _on_socket(index))
		slot.focus_entered.connect(func(): _show_info_for_socket(index))
		_sockets.add_child(slot)
		_socket_slots.append(slot)

	# --- tray
	if GameState.owned_chips.is_empty():
		var none := UIKit.label("No chips yet.", 8, UIKit.QUIET)
		_tray.add_child(none)
	for id in GameState.owned_chips:
		if not ItemDB.chips.has(id):
			continue
		var slot := ChipSlot.new()
		slot.chip = _icon(id)
		slot.chip_id = id
		slot.dimmed = id in GameState.equipped_chips
		var chip_id: StringName = id
		slot.pressed.connect(func(): _on_tray(chip_id))
		slot.focus_entered.connect(func(): _show_info(chip_id))
		_tray.add_child(slot)
		_tray_slots[id] = slot

	_update_header()
	_restore_focus.call_deferred()


func _restore_focus() -> void:
	if _focus_id != &"" and _tray_slots.has(_focus_id):
		_tray_slots[_focus_id].grab_focus()
	elif not _tray_slots.is_empty():
		_tray_slots.values()[0].grab_focus()
	else:
		for s in _socket_slots:
			if s.focus_mode != Control.FOCUS_NONE:
				s.grab_focus()
				break


func _icon(id: StringName) -> Texture2D:
	var chip: UpgradeChip = ItemDB.chips.get(id)
	return chip.icon if chip else null


func _update_header() -> void:
	var used := GameState.ports_used()
	_ports_label.text = "PORTS  %d / %d" % [used, GameState.max_ports]
	_warn.text = "OVERCLOCKED: one port past the limit. You take double damage." if GameState.is_overclocked() else ""
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var s: PlayerStats = player.stats
		_stats.text = "HEALTH %d   WIRE %d\nBLADE %d   RECALL x%.1f" % [
			int(s.get_stat("max_health")), int(s.get_stat("wire_length")),
			int(s.get_stat("blade_damage")), s.get_stat("recall_damage_mult")]


func _show_info(id: StringName) -> void:
	_focus_id = id
	var chip: UpgradeChip = ItemDB.chips.get(id)
	if chip == null:
		return
	_big.texture = chip.icon
	_name.text = chip.display_name.to_upper()
	_cost.text = "%d PORT%s" % [chip.port_cost, "" if chip.port_cost == 1 else "S"] + ("   SEATED" if id in GameState.equipped_chips else "")
	_desc.text = chip.description
	if not (id in GameState.equipped_chips) and not GameState.can_equip(id):
		_desc.text += "\nNot enough free ports."


func _show_info_for_socket(index: int) -> void:
	var slot := _socket_slots[index]
	if slot.chip_id != &"":
		_show_info(slot.chip_id)
		return
	_big.texture = slot.SOCKETS[slot.socket]
	match slot.socket:
		"empty":
			_name.text = "EMPTY PORT"
			_desc.text = "Pick a chip from the tray to press it in."
		"over":
			_name.text = "OVERCLOCK PORT"
			_desc.text = "One chip may run past your limit here, but every hit you take does double damage."
		_:
			_name.text = "SEALED PORT"
			_desc.text = "Find port expansions to open more."
	_cost.text = ""


# ------------------------------------------------------------------ actions
func _on_tray(id: StringName) -> void:
	if _busy:
		return
	_focus_id = id
	if id in GameState.equipped_chips:
		_eject(id)
	elif GameState.can_equip(id):
		_insert(id)
	else:
		_reject(_tray_slots.get(id))


func _on_socket(index: int) -> void:
	if _busy:
		return
	var id := _socket_slots[index].chip_id
	if id != &"":
		_focus_id = id
		_eject(id)


## The chip flies from the tray to the next free socket, then clicks in.
func _insert(id: StringName) -> void:
	var from: ChipSlot = _tray_slots[id]
	var target_index := GameState.ports_used()
	if target_index >= _socket_slots.size():
		_reject(from)
		return
	var to := _socket_slots[target_index]
	_busy = true
	from.chip = null
	from.queue_redraw()
	var ghost := _ghost(_icon(id), from)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(ghost, "global_position", _slot_origin(to, ghost), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2(1.25, 1.25), 0.1).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(ghost, "scale", Vector2(0.85, 0.85), 0.06).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		ghost.queue_free()
		GameState.toggle_chip(id)
		refresh()
		AudioManager.sfx(&"chip_in")
		_seat_effect(target_index)
		if Fx.shake_enabled:
			_jolt())
	tw.tween_interval(0.05)
	tw.tween_callback(func(): _busy = false)


## The chip pops out of its socket and drops back into the tray.
func _eject(id: StringName) -> void:
	var socket_index := -1
	for i in _socket_slots.size():
		if _socket_slots[i].chip_id == id and _socket_slots[i].chip:
			socket_index = i
			break
	var to: ChipSlot = _tray_slots.get(id)
	if socket_index < 0 or to == null:
		GameState.toggle_chip(id)
		refresh()
		return
	_busy = true
	AudioManager.sfx(&"chip_out")
	var from := _socket_slots[socket_index]
	from.chip = null
	from.queue_redraw()
	var ghost := _ghost(_icon(id), from)
	ghost.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(ghost, "scale", Vector2(1.2, 1.2), 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "global_position", _slot_origin(to, ghost), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2.ONE, 0.18)
	tw.tween_callback(func():
		ghost.queue_free()
		GameState.toggle_chip(id)
		refresh()
		_busy = false)


func _reject(slot: ChipSlot) -> void:
	if slot == null:
		return
	EventBus.toast.emit("Not enough free ports.")
	AudioManager.sfx(&"glance", -6.0)
	var x := slot.position.x
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for dx in [3.0, -3.0, 2.0, -1.0, 0.0]:
		tw.tween_property(slot, "position:x", x + dx, 0.03)


func _ghost(tex: Texture2D, at: ChipSlot) -> TextureRect:
	var g := TextureRect.new()
	g.texture = tex
	g.top_level = true
	g.z_index = 10
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.size = tex.get_size()
	g.pivot_offset = g.size * 0.5
	add_child(g)
	g.global_position = _slot_origin(at, g)
	return g


func _slot_origin(slot: Control, ghost: Control) -> Vector2:
	return (slot.global_position + slot.size * 0.5 - ghost.size * 0.5).round()


func _seat_effect(index: int) -> void:
	if index >= _socket_slots.size():
		return
	var s := _socket_slots[index]
	s.flash = 1.0
	s.seat = 0.82
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(s, "seat", 1.08, 0.06)
	tw.tween_property(s, "seat", 1.0, 0.08)
	tw.tween_method(func(_v): s.queue_redraw(), 0.0, 1.0, 0.14)


func _jolt() -> void:
	var y := position.y
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "position:y", y + 1.0, 0.03)
	tw.tween_property(self, "position:y", y, 0.05)
