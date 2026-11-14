class_name ChipSlot
extends Button
## One round slot in the loadout screen: either a port socket (with or
## without a chip seated in it) or a chip in the collection tray.
## Draws itself from pixel textures; focus/hover shows a cyan ring.

const SOCKETS := {
	"empty": preload("res://art/ui/socket_empty.png"),
	"lit": preload("res://art/ui/socket_lit.png"),
	"over": preload("res://art/ui/socket_over.png"),
	"locked": preload("res://art/ui/socket_locked.png"),
}
const CONDUIT := preload("res://art/ui/socket_conduit.png")

var socket := ""                ## "" = a tray slot (no socket ring), else a SOCKETS key
var chip: Texture2D = null      ## chip seated here / shown in the tray
var chip_id: StringName = &""
var linked := false             ## second socket of a 2-port chip: draw the conduit in from the left
var dimmed := false             ## tray chip that's already in use / can't fit
var seat := 1.0                 ## chip scale, animated when a chip clicks in
var flash := 0.0                ## 1 -> 0 ring flash after inserting


func _init() -> void:
	custom_minimum_size = Vector2(34, 34)
	focus_mode = Control.FOCUS_ALL
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(grab_focus) # mouse and pad share one "selected" slot
	focus_entered.connect(queue_redraw)
	focus_entered.connect(func(): AudioManager.sfx(&"ui_move", -10.0, 0.02))
	focus_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(flash - delta * 3.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	if socket != "":
		var tex: Texture2D = SOCKETS[socket]
		draw_texture(tex, (c - tex.get_size() * 0.5).round())
	else:
		draw_circle(c, 13.0, Color(0, 0, 0, 0.35)) # tray: a soft shadow under the chip
	if linked:
		draw_texture(CONDUIT, Vector2(-7, c.y - 3).round())
	if chip:
		var s := chip.get_size() * seat
		var col := Color(0.45, 0.45, 0.5, 0.75) if dimmed else Color.WHITE
		draw_texture_rect(chip, Rect2((c - s * 0.5).round(), s.round()), false, col)
	if flash > 0.0:
		draw_arc(c, 15.0 + (1.0 - flash) * 6.0, 0, TAU, 32, Color(0.5, 1.0, 1.0, flash), 1.0)
	if has_focus():
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, 16.5, 0, TAU, 32, Color(0.22, 0.95, 1.0, 0.75 + 0.25 * sin(t * 6.0)), 1.0)
		queue_redraw()
