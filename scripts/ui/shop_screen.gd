class_name ShopScreen
extends PanelContainer
## A shopkeeper's stall: a striped awning, the keeper's portrait in a frame,
## your wallet in a coin tray, the wares as riveted cards, and a lit display
## case with the selected item on a brass plinth, its price tag and a brass
## Buy plate. Buying flashes the card, counts the wallet down and stamps the
## card when it sells out. Art: tools/art/build_ui.py.

signal closed

var npc: NPC
var _grid: GridContainer
var _wallet: HBoxContainer
var _show: Showcase
var _name: Label
var _kind: Label
var _desc: Label
var _price: Label
var _price_icon: TextureRect
var _price_box: PanelContainer
var _buy: Button
var _selected: ShopItem
var _cards := {} ## item_id -> ShopCard
var _shown_balance := {} ## currency -> displayed number (for the count-down)

const ICON_SCRAP := preload("res://art/ui/icon_scrap.png")
const ICON_CAP := preload("res://art/ui/icon_cap.png")
const ICON_KIT := preload("res://art/ui/item_kit.png")
const ICON_PORT := preload("res://art/ui/socket_lit.png")
const ICON_CELL := preload("res://art/ui/item_cell.png")
const ICON_MAP := preload("res://art/ui/item_map.png")
const AWNING := preload("res://art/ui/awning.png")
const CASE := preload("res://art/ui/case.png")
const TRAY := preload("res://art/ui/tray.png")
const TAG := preload("res://art/ui/tag.png")
const BTN := preload("res://art/ui/btn.png")
const BTN_HOVER := preload("res://art/ui/btn_hover.png")
const BTN_OFF := preload("res://art/ui/btn_off.png")
const STAMP := preload("res://art/ui/stamp.png")


## The selected item floating over a brass plinth, with its shadow; bobs gently.
class Showcase extends Control:
	const PEDESTAL := preload("res://art/ui/pedestal.png")
	var tex: Texture2D
	var dimmed := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var cx := roundf(size.x * 0.5)
		var ped := Vector2(cx - PEDESTAL.get_width() * 0.5, size.y - PEDESTAL.get_height())
		draw_texture(PEDESTAL, ped)
		if tex == null:
			return
		var s := tex.get_size()
		var k := maxf(floorf(64.0 / maxf(s.x, s.y)), 1.0)
		if maxf(s.x, s.y) * k > 64.0:
			k = 64.0 / maxf(s.x, s.y)
		var d := (s * k).round()
		var bob := 0.0 if dimmed else roundf(sin(_t * 2.2) * 1.0)
		var at := Vector2(cx - d.x * 0.5, ped.y - d.y - 3 + bob).round()
		# its shadow on the plinth top shrinks a little as it rises
		var sw := roundf(d.x * (0.55 if bob < 0 else 0.62))
		draw_rect(Rect2(cx - sw * 0.5, ped.y + 1, sw, 2), Color(0.1, 0.06, 0.04, 0.55))
		draw_rect(Rect2(cx - sw * 0.5 + 2, ped.y, sw - 4, 1), Color(0.1, 0.06, 0.04, 0.35))
		draw_texture_rect(tex, Rect2(at, d), false, Color(0.55, 0.55, 0.6) if dimmed else Color.WHITE)


static func _sbox(tex: Texture2D, l: int, t: int, r: int, b: int, cl := 0, ct := 0, cr := 0, cb := 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = l
	sb.texture_margin_top = t
	sb.texture_margin_right = r
	sb.texture_margin_bottom = b
	sb.content_margin_left = cl
	sb.content_margin_top = ct
	sb.content_margin_right = cr
	sb.content_margin_bottom = cb
	return sb


func _init() -> void:
	custom_minimum_size = Vector2(564, 310)


func _draw() -> void:
	# the awning hangs across the top of the stall, inside the frame
	var x := 3.0
	while x < size.x - 3.0:
		var w := minf(AWNING.get_width(), size.x - 3.0 - x)
		draw_texture_rect_region(AWNING, Rect2(x, 3, w, AWNING.get_height()), Rect2(0, 0, w, AWNING.get_height()))
		x += AWNING.get_width()


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var under_awning := Control.new()
	under_awning.custom_minimum_size = Vector2(0, 8)
	col.add_child(under_awning)

	# --- header: framed portrait, name + greeting, wallet tray
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var portrait := _portrait()
	if portrait:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", _sbox(CASE, 7, 7, 7, 7, 6, 5, 6, 5))
		frame.add_child(portrait)
		head.add_child(frame)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 4)
	head.add_child(who)
	who.add_child(UIKit.heading(npc.display_name.to_upper() + "'S STALL"))
	var greet := UIKit.label("\"" + npc.shop_greeting + "\"", 8, UIKit.QUIET)
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greet.custom_minimum_size = Vector2(300, 0)
	who.add_child(greet)
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _sbox(TRAY, 4, 4, 4, 4, 7, 4, 7, 3))
	tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tray)
	_wallet = HBoxContainer.new()
	_wallet.add_theme_constant_override("separation", 10)
	tray.add_child(_wallet)

	# --- body: wares | display case
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(UIKit.label("WARES", 8, UIKit.QUIET))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_grid)

	var case_panel := PanelContainer.new()
	case_panel.add_theme_stylebox_override("panel", _sbox(CASE, 7, 7, 7, 7, 9, 7, 9, 8))
	case_panel.custom_minimum_size = Vector2(226, 0)
	body.add_child(case_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 3)
	case_panel.add_child(detail)
	_show = Showcase.new()
	_show.custom_minimum_size = Vector2(190, 78)
	detail.add_child(_show)
	_name = UIKit.label("", 8, UIKit.AMBER)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(_name)
	_kind = UIKit.label("", 8, UIKit.QUIET)
	_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(_kind)
	_desc = UIKit.label("", 8, Color(0.82, 0.86, 0.88))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(190, 30)
	detail.add_child(_desc)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(fill)
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 6)
	detail.add_child(buy_row)
	_price_box = PanelContainer.new()
	_price_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(_price_box)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 2)
	_price_box.add_child(pr)
	_price_icon = TextureRect.new()
	_price_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pr.add_child(_price_icon)
	_price = UIKit.label("", 8, ShopCard.INK)
	pr.add_child(_price)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_row.add_child(gap)
	_buy = UIKit.button("BUY", _on_buy)
	_style_buy(_buy)
	buy_row.add_child(_buy)

	col.add_child(UIKit.button("Leave", func(): closed.emit()))
	refresh()


func _style_buy(b: Button) -> void:
	b.custom_minimum_size = Vector2(60, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var normal := _sbox(BTN, 6, 6, 6, 7, 8, 3, 8, 6)
	var hover := _sbox(BTN_HOVER, 6, 6, 6, 7, 8, 3, 8, 6)
	var pressed := _sbox(BTN, 6, 6, 6, 7, 8, 4, 8, 5)
	var off := _sbox(BTN_OFF, 6, 6, 6, 7, 8, 3, 8, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	var ink := Color8(48, 28, 20)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color8(30, 24, 26))


func _portrait() -> Control:
	if npc._frames.is_empty():
		return null
	var t := TextureRect.new()
	t.texture = npc._frames[0]
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = npc._frames[0].get_size() * 2.0
	t.flip_h = true # face the wares
	return t


func _visible_items() -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for item: ShopItem in npc.shop_items:
		if item.required_quest != &"" and QuestManager.get_state(item.required_quest) != GameState.QuestState.TURNED_IN:
			continue
		out.append(item)
	return out


func refresh() -> void:
	_refresh_wallet()
	var keep := _selected
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var items := _visible_items()
	for item in items:
		var card := ShopCard.new()
		_fill_card(card, item)
		var it := item
		card.pressed.connect(func(): _select(it); _on_buy())
		card.focus_entered.connect(func(): _select(it))
		_grid.add_child(card)
		_cards[item.item_id] = card
	if items.is_empty():
		_grid.add_child(UIKit.label("Sold out. Come back later.", 8, UIKit.QUIET))
	var target: ShopItem = keep if keep and _cards.has(keep.item_id) else (items[0] if not items.is_empty() else null)
	if target:
		_select(target)
		_cards[target.item_id].grab_focus.call_deferred()


func _fill_card(card: ShopCard, item: ShopItem) -> void:
	card.title = item.display_name
	card.price = item.price
	card.icon_tex = item_icon(item)
	card.currency_icon = _currency_icon(item.currency)
	card.affordable = GameState.get_balance(item.currency) >= item.price
	card.stamp = _stamp(item)
	if card.icon_tex == null and item.item_type == ShopItem.ItemType.COSMETIC:
		var c: CosmeticItem = ItemDB.cosmetics.get(item.item_id)
		if c:
			card.swatch = c.color
	card.queue_redraw()


func _stamp(item: ShopItem) -> String:
	if item.item_type == ShopItem.ItemType.MAP and GameState.has_map(item.item_id):
		return "OWNED"
	if _sold_out(item):
		return "SOLD OUT"
	match item.item_type:
		ShopItem.ItemType.CHIP:
			if item.item_id in GameState.owned_chips:
				return "OWNED"
		ShopItem.ItemType.COSMETIC:
			if item.item_id in GameState.owned_cosmetics:
				return "OWNED"
	return ""


func _sold_out(item: ShopItem) -> bool:
	var bought := int(GameState.shop_bought.get(_key(item), 0))
	return item.stock >= 0 and bought >= item.stock


func _key(item: ShopItem) -> String:
	return "%s:%s" % [npc.npc_id, item.item_id]


static func item_icon(item: ShopItem) -> Texture2D:
	match item.item_type:
		ShopItem.ItemType.CHIP:
			var chip: UpgradeChip = ItemDB.chips.get(item.item_id)
			return chip.icon if chip else null
		ShopItem.ItemType.COSMETIC:
			var c: CosmeticItem = ItemDB.cosmetics.get(item.item_id)
			return c.icon if c else null
		ShopItem.ItemType.CONSUMABLE:
			return ICON_KIT
		ShopItem.ItemType.PORT_EXPANSION:
			return ICON_PORT
		ShopItem.ItemType.CORE_CELL:
			return ICON_CELL
		ShopItem.ItemType.MAP:
			return ICON_MAP
	return null


func _currency_icon(currency: StringName) -> Texture2D:
	if currency == &"scrap":
		return ICON_SCRAP
	var region := ItemDB.region(currency)
	return region.hud_icon if region and region.hud_icon else ICON_CAP


func _describe(item: ShopItem) -> Array:
	if item.description != "":
		return [_kind_name(item), item.description]
	match item.item_type:
		ShopItem.ItemType.CHIP:
			var chip: UpgradeChip = ItemDB.chips.get(item.item_id)
			if chip:
				return ["CHIP  -  %d PORT%s" % [chip.port_cost, "" if chip.port_cost == 1 else "S"], chip.description + "\nSeat it at a charging dock."]
		ShopItem.ItemType.COSMETIC:
			var c: CosmeticItem = ItemDB.cosmetics.get(item.item_id)
			if c:
				return ["OUTFIT  -  " + CosmeticItem.SLOT_NAMES[c.slot].to_upper(), "Looks only. Change outfits at a charging dock."]
		ShopItem.ItemType.CONSUMABLE:
			return ["CONSUMABLE", "Patches you up for 2 health. Use with Q. You have %d." % int(GameState.consumables.get(item.item_id, 0))]
		ShopItem.ItemType.PORT_EXPANSION:
			return ["UPGRADE", "Opens one more port, so you can seat more chips at once."]
		ShopItem.ItemType.CORE_CELL:
			return ["UPGRADE", "A spare core cell: +1 max health."]
		ShopItem.ItemType.MAP:
			return ["MAP", "Dot's map of the region. Open it from the journal (Tab or M). Rooms you've walked through are filled in."]
	return [_kind_name(item), ""]


func _kind_name(item: ShopItem) -> String:
	return ["CHIP", "OUTFIT", "CONSUMABLE", "UPGRADE", "UPGRADE", "MAP"][item.item_type]


func _select(item: ShopItem) -> void:
	_selected = item
	_name.text = ShopCard.clean_name(item.display_name).to_upper()
	var d := _describe(item)
	_kind.text = d[0]
	_desc.text = d[1]
	var stamp := _stamp(item)
	_show.tex = item_icon(item)
	_show.dimmed = stamp != ""
	if stamp != "":
		var sb := _sbox(STAMP, 4, 4, 4, 4, 5, 2, 5, 2)
		sb.modulate_color = ShopCard.STAMP_GREEN if stamp == "OWNED" else ShopCard.STAMP_RED
		_price_box.add_theme_stylebox_override("panel", sb)
		_price_icon.hide()
		_price.text = stamp
		_price.add_theme_color_override("font_color", sb.modulate_color)
		_buy.disabled = true
	else:
		_price_box.add_theme_stylebox_override("panel", _sbox(TAG, 7, 3, 2, 3, 8, 2, 4, 1))
		_price_icon.show()
		_price_icon.texture = _currency_icon(item.currency)
		var have := GameState.get_balance(item.currency)
		_price.text = "%d  (HAVE %d)" % [item.price, have]
		_price.add_theme_color_override("font_color", ShopCard.INK if have >= item.price else ShopCard.INK_RED)
		_buy.disabled = have < item.price


func _on_buy() -> void:
	var item := _selected
	if item == null or _stamp(item) != "":
		return
	var card: ShopCard = _cards.get(item.item_id)
	if GameState.get_balance(item.currency) < item.price:
		EventBus.toast.emit("Not enough %s." % ItemDB.currency_name(item.currency))
		if card:
			_shake(card)
		return
	if not buy(npc, item):
		return
	AudioManager.sfx(&"buy")
	if card:
		card.flash = 1.0
		_fill_card(card, item)
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		card.pivot_offset = card.size * 0.5
		tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.05)
		tw.tween_property(card, "scale", Vector2.ONE, 0.1)
	for other in _visible_items():
		if _cards.has(other.item_id):
			_fill_card(_cards[other.item_id], other)
	_select(item)
	_refresh_wallet(true)


## The purchase itself (also used by tests). Returns true if it went through.
static func buy(shop_npc: NPC, item: ShopItem) -> bool:
	var key := "%s:%s" % [shop_npc.npc_id, item.item_id]
	var bought := int(GameState.shop_bought.get(key, 0))
	if item.stock >= 0 and bought >= item.stock:
		return false
	if not GameState.spend(item.currency, item.price):
		return false
	GameState.shop_bought[key] = bought + 1
	match item.item_type:
		ShopItem.ItemType.CHIP:
			GameState.add_chip(item.item_id)
		ShopItem.ItemType.COSMETIC:
			GameState.add_cosmetic(item.item_id)
		ShopItem.ItemType.CONSUMABLE:
			GameState.add_consumable(item.item_id)
			EventBus.toast.emit("Bought: " + item.display_name)
		ShopItem.ItemType.PORT_EXPANSION:
			GameState.add_port()
		ShopItem.ItemType.CORE_CELL:
			GameState.add_core_cell()
		ShopItem.ItemType.MAP:
			GameState.flags["map_" + String(item.item_id)] = true
			EventBus.toast.emit("Map of %s added to your journal (Tab)" % ItemDB.region(item.item_id).display_name if ItemDB.region(item.item_id) else "Map added")
	return true


func _refresh_wallet(animate := false) -> void:
	for c in _wallet.get_children():
		c.queue_free()
	var currencies: Array[StringName] = [&"scrap"]
	var region := ItemDB.region(GameState.current_region)
	if region:
		currencies.append(region.id)
	for cur in currencies:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var ic := TextureRect.new()
		ic.texture = _currency_icon(cur)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var value := GameState.get_balance(cur)
		var lbl := UIKit.label(str(value), 8, UIKit.AMBER)
		row.add_child(lbl)
		_wallet.add_child(row)
		var from: int = _shown_balance.get(cur, value)
		_shown_balance[cur] = value
		if animate and from != value:
			lbl.text = str(from)
			var tw := lbl.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_method(func(v: float): lbl.text = str(int(round(v))), float(from), float(value), 0.35)


func _shake(c: Control) -> void:
	var x := c.position.x
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for dx in [3.0, -3.0, 2.0, -1.0, 0.0]:
		tw.tween_property(c, "position:x", x + dx, 0.03)
