class_name JournalScreen
extends PanelContainer
## Pause screen and journal in one: MAP, QUESTS, LORE and CONTROLS tabs,
## plus Resume / Settings / Quit. Opened with Esc (pause) or Tab/M (map).

signal resume_requested
signal settings_requested
signal quit_to_title_requested

const TABS := ["MAP", "QUESTS", "LORE", "CONTROLS"]

var start_tab := 0
var _content: Control
var _tab_buttons: Array[Button] = []
var _tab := 0


func _init() -> void:
	custom_minimum_size = Vector2(608, 336)


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	tabs.add_theme_constant_override("separation", 2)
	for i in TABS.size():
		var idx := i
		var b := UIKit.button(TABS[i], func(): show_tab(idx))
		b.custom_minimum_size = Vector2(76, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tabs.add_child(b)
		_tab_buttons.append(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(gap)
	tabs.add_child(UIKit.heading("JOURNAL"))
	_content = Control.new()
	_content.custom_minimum_size = Vector2(584, 250)
	col.add_child(_content)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	bottom.add_child(UIKit.button("Resume", func(): resume_requested.emit()))
	bottom.add_child(UIKit.button("Settings", func(): settings_requested.emit()))
	bottom.add_child(UIKit.button("Quit to Title", func(): quit_to_title_requested.emit()))
	bottom.add_child(UIKit.button("Quit Game", func(): get_tree().quit()))
	show_tab(start_tab)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if _tab == 0:
			resume_requested.emit()
		else:
			show_tab(0)


func current_tab() -> int:
	return _tab


func show_tab(i: int) -> void:
	_tab = i
	for c in _content.get_children():
		c.queue_free()
	for j in _tab_buttons.size():
		_style_tab(_tab_buttons[j], j == i)
	match i:
		0: _map()
		1: _quests()
		2: _lore()
		3: _controls()
	_tab_buttons[i].grab_focus.call_deferred()


const TAB_TEX := preload("res://art/ui/tab.png")
const TAB_ON_TEX := preload("res://art/ui/tab_on.png")


## Folder tabs: the open one is teal with a lit top edge; the others are dark.
func _style_tab(b: Button, on: bool) -> void:
	var off := _tab_box(TAB_TEX)
	var lit := _tab_box(TAB_ON_TEX)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, lit if on else off)
	for st in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, lit if on else off)
	b.add_theme_color_override("font_color", Color.WHITE if on else Color(0.6, 0.62, 0.68))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE if on else Color(0.85, 0.87, 0.9))


func _tab_box(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 5
	sb.texture_margin_right = 5
	sb.texture_margin_top = 5
	sb.texture_margin_bottom = 3
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 2
	return sb


func _map() -> void:
	var m := MapView.new()
	m.region = MapData.region_of(WorldManager.current_room.room_id) if WorldManager.current_room else &"heap"
	if m.region == &"":
		m.region = &"heap"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(m)


func _scroll(child: Control) -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(sc)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)


func _empty_note(text: String) -> void:
	var c := UIKit.case_panel(14)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := UIKit.label(text, 8, Color(0.75, 0.78, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	_content.add_child(c)


## One quest per iron card: title, who gave it, an ink stamp for its state,
## the description and a brass checkbox per objective.
func _quests() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	var S := GameState.QuestState
	for id in ItemDB.quests:
		var q: QuestData = ItemDB.quests[id]
		var st := QuestManager.get_state(id)
		if st == S.LOCKED or st == S.AVAILABLE:
			continue
		var card := UIKit.card_panel()
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		card.add_child(col)
		var top := HBoxContainer.new()
		col.add_child(top)
		top.add_child(UIKit.label(q.title.to_upper(), 8, UIKit.AMBER))
		top.add_child(UIKit.label("   from " + q.giver_name, 8, UIKit.QUIET))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(gap)
		var tag: String = {S.ACTIVE: "ACTIVE", S.COMPLETE: "TURN IN", S.TURNED_IN: "DONE"}.get(st, "")
		top.add_child(_stamp(tag))
		var d := UIKit.label(q.description, 8, Color(0.8, 0.84, 0.86))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		if GameState.quest_states.has(id) or st == S.TURNED_IN:
			var progress: Array = GameState.quest_states.get(id, {}).get("progress", [])
			for k in q.objectives.size():
				var o: QuestObjective = q.objectives[k]
				var n := int(progress[k]) if k < progress.size() else 0
				var done := st == S.TURNED_IN or n >= o.count
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 5)
				var box := TextureRect.new()
				box.texture = load("res://art/ui/check_on.png" if done else "res://art/ui/check_off.png")
				box.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				line.add_child(box)
				line.add_child(UIKit.label("%s  %d/%d" % [o.description, mini(n, o.count) if not done else o.count, o.count], 8, UIKit.QUIET if done else UIKit.TEXT))
				col.add_child(line)
		list.add_child(card)
	if list.get_child_count() == 0:
		list.free()
		_empty_note("No jobs yet. Talk to people in the camp.")
		return
	_scroll(list)


func _stamp(text: String) -> Control:
	var c := Control.new()
	var w := ShopCard.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
	c.custom_minimum_size = Vector2(w, 12)
	var col: Color = {"DONE": ShopCard.STAMP_GREEN, "ACTIVE": UIKit.AMBER, "TURN IN": UIKit.CYAN}.get(text, ShopCard.STAMP_RED)
	c.draw.connect(func(): ShopCard.draw_stamp(c, Vector2.ZERO, text, col))
	return c


## Entries down the left as iron plates; the text in a display case.
func _lore() -> void:
	if GameState.lore.is_empty():
		_empty_note("Nothing written down yet. Read tablets, notes and signs (press E) to fill this in.")
		return
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(170, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var case := UIKit.case_panel(12)
	case.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(case)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	case.add_child(right)
	var title := UIKit.label("", 8, UIKit.AMBER)
	right.add_child(title)
	var text := UIKit.label("", 8, Color(0.84, 0.86, 0.86))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(370, 0)
	right.add_child(text)
	var first := true
	for id in GameState.lore:
		var e: Dictionary = GameState.lore[id]
		var body := "\n\n".join(PackedStringArray(e.get("lines", [])))
		var name := String(e.get("title", id))
		var show := func(): text.text = body; title.text = name.to_upper()
		var b := UIKit.button(name, show)
		b.focus_entered.connect(show)
		b.clip_text = true
		list.add_child(b)
		if first:
			show.call()
			first = false


const CONTROLS := [
	[["A", "D"], "Move", ["W", "S"], "Aim up / down"],
	[["SPACE"], "Jump (hold for higher)", ["SHIFT"], "Dash (blade stuck in an enemy: zip to it)"],
	[["R-CLICK"], "Attack (hold to keep swinging)", ["L-CLICK"], "Hold, flick, release: throw. Again: recall / reel in"],
	[["E"], "Talk / read / enter", ["Q"], "Use a repair kit"],
	[["TAB", "M"], "Journal map", ["ESC"], "Pause"],
	[["F11"], "Fullscreen", [], ""],
]


## Two columns of key caps and what they do. Gamepad: A jump, B dash, X attack, RB throw, Y talk, LB heal.
func _controls() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for r in CONTROLS:
		for pair in [[r[0], r[1]], [r[2], r[3]]]:
			var keys := HBoxContainer.new()
			keys.add_theme_constant_override("separation", 2)
			keys.custom_minimum_size = Vector2(84, 0)
			keys.alignment = BoxContainer.ALIGNMENT_END
			for k in pair[0]:
				keys.add_child(_keycap(k))
			grid.add_child(keys)
			var l := UIKit.label(pair[1], 8, Color(0.82, 0.84, 0.86))
			l.custom_minimum_size = Vector2(190, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(l)
	var pad := UIKit.card_panel()
	pad.add_child(UIKit.label("GAMEPAD   A jump   B dash   X attack   RB throw / recall   Y talk   LB heal   START pause", 8, UIKit.QUIET))
	col.add_child(pad)
	_scroll(col)


func _keycap(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box("res://art/ui/keycap.png", 4, 4, 4, 6, 5, 2, 5, 5))
	p.add_child(UIKit.label(text, 8, Color8(40, 28, 26)))
	return p
