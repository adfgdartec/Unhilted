extends CanvasLayer
## Always-on HUD: health pips, scrap, this region's local coins, consumables,
## quest tracker, interaction prompt and pop-up toasts.

var _pips: Control
var _scrap: Label
var _local: Label
var _items: Label
var _overclock: Label
var _quest: Label
var _prompt: Label
var _prompt_plate: PanelContainer
var _toast_box: VBoxContainer
const CELL_FULL := preload("res://art/ui/cell_full.png")
const CELL_EMPTY := preload("res://art/ui/cell_empty.png")
const ICON_SCRAP := preload("res://art/ui/icon_scrap.png")
const ICON_CAP := preload("res://art/ui/icon_cap.png")
const ICON_KIT := preload("res://art/ui/icon_kit.png")

var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: Control
var _boss_hp := 1
var _boss_max := 1
var _boss_lag := 1.0      ## the white "recent damage" chunk that catches up
var _cell_flash := 0.0
var _flash_from := 0
var _health := 5
var _max_health := 5


func _ready() -> void:
	layer = 20
	_build()
	EventBus.health_changed.connect(_on_health)
	EventBus.heal_charge_changed.connect(func(c, n): _heal_charge = c; _heal_needed = n; _pips.queue_redraw())
	EventBus.currency_changed.connect(_refresh_currency)
	EventBus.consumables_changed.connect(_refresh_items)
	EventBus.loadout_changed.connect(_refresh_items)
	EventBus.quest_updated.connect(func(_id): _refresh_quest())
	EventBus.interact_prompt.connect(func(t): _prompt.text = t; _prompt_plate.visible = t != "")
	EventBus.toast.connect(_show_toast)
	EventBus.region_title.connect(_show_region_title)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_health_changed.connect(func(c, m): _boss_hp = c; _boss_max = m)
	EventBus.boss_ended.connect(func(): _boss_box.hide())


func refresh_all() -> void:
	_refresh_currency()
	_refresh_items()
	_refresh_quest()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(10, 8)
	top_left.add_theme_constant_override("separation", 3)
	root.add_child(top_left)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(120, 11)
	_pips.draw.connect(_draw_pips)
	top_left.add_child(_pips)
	_scrap = _icon_row(top_left, ICON_SCRAP, Color.WHITE, Color(0.85, 0.86, 0.9))
	_local = _icon_row(top_left, ICON_CAP, Color.WHITE, UIKit.AMBER)
	_items = _icon_row(top_left, ICON_KIT, Color.WHITE, Color(0.95, 0.6, 0.55))
	_overclock = UIKit.label("OVERCLOCKED: double damage taken", 8, Color(1, 0.35, 0.3))
	top_left.add_child(_overclock)

	_quest = UIKit.label("", 8, Color(0.9, 0.9, 0.82))
	_quest.anchor_left = 1.0
	_quest.anchor_right = 1.0
	_quest.offset_left = -175
	_quest.offset_right = -10
	_quest.offset_top = 8
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_quest)

	# the interaction prompt sits on an iron plate, centred low on the screen
	var prompt_holder := CenterContainer.new()
	prompt_holder.anchor_left = 0.0
	prompt_holder.anchor_right = 1.0
	prompt_holder.anchor_top = 1.0
	prompt_holder.anchor_bottom = 1.0
	prompt_holder.offset_top = -44
	prompt_holder.offset_bottom = -20
	prompt_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_holder)
	_prompt_plate = PanelContainer.new()
	_prompt_plate.add_theme_stylebox_override("panel", UIKit.box("res://art/ui/card_sel.png", 7, 7, 7, 7, 10, 5, 10, 5))
	_prompt_plate.hide()
	prompt_holder.add_child(_prompt_plate)
	_prompt = UIKit.label("", 8, Color.WHITE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_plate.add_child(_prompt)

	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.anchor_top = 1.0
	_boss_box.anchor_bottom = 1.0
	_boss_box.offset_left = -150
	_boss_box.offset_right = 150
	_boss_box.offset_top = -40
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = UIKit.label("", 8, Color(1.0, 0.7, 0.45))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = Control.new()
	_boss_bar.custom_minimum_size = Vector2(300, 6)
	_boss_bar.draw.connect(_draw_boss_bar)
	_boss_box.add_child(_boss_bar)
	_boss_box.hide()
	root.add_child(_boss_box)

	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -140
	_toast_box.offset_right = 140
	_toast_box.offset_top = 8
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)


func _process(delta: float) -> void:
	if _boss_box.visible:
		var target := float(_boss_hp)
		if _boss_lag > target:
			_boss_lag = move_toward(_boss_lag, target, delta * maxf((_boss_lag - target) * 2.5, 1.5))
		_boss_bar.queue_redraw()
	if _cell_flash > 0.0:
		_cell_flash = maxf(_cell_flash - delta * 3.0, 0.0)
		_pips.queue_redraw()


func _on_health(current: int, maximum: int) -> void:
	if current < _health:
		_cell_flash = 1.0
		_flash_from = current
	_health = current
	_max_health = maximum
	_pips.queue_redraw()


var _heal_charge := 0
var _heal_needed := 3

func _draw_pips() -> void:
	# close-hit heal charge: three small green notches after the cells
	var hx := _max_health * 10 + 3
	for k in _heal_needed:
		var r := Rect2(hx, 2 + k * 3, 4, 2)
		_pips.draw_rect(r.grow(1), Color8(20, 16, 20))
		_pips.draw_rect(r, Color(0.45, 1.0, 0.6) if k < _heal_charge else Color8(54, 60, 58))
	for i in _max_health:
		_pips.draw_texture(CELL_FULL if i < _health else CELL_EMPTY, Vector2(i * 10, 0))
		if _cell_flash > 0.0 and i >= _flash_from and i < _health + 1 + (_flash_from - _health):
			_pips.draw_rect(Rect2(i * 10, 1, 8, 10), Color(1.0, 0.45, 0.4, _cell_flash))


## One HUD line: a small icon followed by a label. Returns the label.
func _icon_row(parent: Control, icon: Texture2D, tint: Color, text_color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var tr := TextureRect.new()
	tr.texture = icon
	tr.modulate = tint
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(tr)
	var l := UIKit.label("", 8, text_color)
	row.add_child(l)
	parent.add_child(row)
	return l


func _on_boss_started(boss_name: String, max_health: int) -> void:
	_boss_name.text = boss_name
	_boss_hp = max_health
	_boss_max = max_health
	_boss_lag = max_health
	_boss_box.show()
	_boss_box.modulate.a = 0.0
	_boss_box.create_tween().tween_property(_boss_box, "modulate:a", 1.0, 0.4)
	_boss_bar.queue_redraw()


func _draw_boss_bar() -> void:
	var w := _boss_bar.size.x
	_boss_bar.draw_rect(Rect2(0, 0, w, 6), Color(0.1, 0.08, 0.1))
	_boss_bar.draw_rect(Rect2(1, 1, (w - 2) * _boss_lag / maxf(_boss_max, 1), 4), Color(1.0, 0.92, 0.85))
	_boss_bar.draw_rect(Rect2(1, 1, (w - 2) * float(_boss_hp) / maxf(_boss_max, 1), 4), Color(1.0, 0.55, 0.2))
	_boss_bar.draw_rect(Rect2(0, 0, w, 6), Color(0.6, 0.4, 0.3), false, 1.0)


func _refresh_currency() -> void:
	_scrap.text = "%d" % GameState.scrap
	var region := ItemDB.region(GameState.current_region)
	var row := _local.get_parent()
	if region:
		_local.text = "%d   %s %d/%d" % [GameState.get_balance(region.id), region.currency_name,
				int(GameState.local_found.get(region.id, 0)), region.total_local_coins]
		_local.add_theme_color_override("font_color", region.currency_color)
		(row.get_child(0) as TextureRect).modulate = region.currency_color
		if region.hud_icon:
			(row.get_child(0) as TextureRect).texture = region.hud_icon
		row.show()
	else:
		row.hide()


func _refresh_items() -> void:
	var kits := int(GameState.consumables.get(&"repair_kit", 0))
	_items.text = "x%d  [Q]" % kits
	_items.get_parent().visible = kits > 0
	_overclock.visible = GameState.is_overclocked()


func _refresh_quest() -> void:
	_quest.text = QuestManager.tracker_text()


## A big title card the first time you enter a region: the name drawn in
## with a rule underneath, the room's name small below, then it fades.
func _show_region_title(title: String, subtitle: String) -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.3
	box.offset_top = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var t := UIKit.label(title, 16, UIKit.AMBER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 4)
	t.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.06))
	box.add_child(t)
	var rule := ColorRect.new()
	rule.color = Color(UIKit.AMBER, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	var sub := UIKit.label(subtitle, 8, Color(0.92, 0.88, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	add_child(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(rule, "custom_minimum_size:x", 180.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)
	AudioManager.sfx(&"shard", -14.0)


func _show_toast(text: String) -> void:
	var l := UIKit.label(text, 8, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UIKit.box("res://art/ui/card.png", 7, 7, 7, 7, 10, 5, 10, 5))
	bg.add_child(l)
	_toast_box.add_child(bg)
	bg.modulate.a = 0.0
	var tween := bg.create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.4)
	tween.tween_property(bg, "modulate:a", 0.0, 0.5)
	tween.tween_callback(bg.queue_free)
	_refresh_quest()
