extends Node2D
## Mouse aiming helper.
##  - Blade in hand: a faint dotted line from the hand toward the cursor, cut
##    off at the wire's reach, plus brackets on a grapple point it would snap to.
##  - Gripping (left button held): the line follows the flick instead and
##    brightens, and a small ring marks where the grip started.
## Hidden with a gamepad, while the blade is out, or when a menu has control.

var player: Player


func _ready() -> void:
	player = get_parent() as Player
	z_index = 15


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not player.using_mouse or player.blade != null or player.is_dead or GameState.is_ui_locked():
		return
	var from := to_local(player.blade_anchor.global_position)
	var dir := player.aim_toward(get_global_mouse_position())
	var gripping := player.gripping and player.grip_from_mouse
	if gripping:
		var g := player.grip_preview()
		if g != Vector2.ZERO:
			dir = g
	var reach := player.stats.get_stat("wire_length")
	var target: Node2D = player.grapple_target(dir)
	if target == null:
		target = player.enemy_target(dir)
	var base := Color(1.0, 0.95, 0.75) if gripping else Color(0.4, 1.0, 1.0)
	var d := 6.0
	while d < reach:
		var a := (0.85 if gripping else 0.32) * (1.0 - d / reach) + 0.06
		draw_rect(Rect2(from + dir * d - Vector2(0.5, 0.5), Vector2(1, 1)), Color(base, a))
		d += 5.0 if gripping else 6.0
	if target:
		var p := to_local(target.global_position)
		var c := Color(1.0, 0.8, 0.35, 0.9) if target is GrapplePoint else Color(1.0, 0.45, 0.4, 0.85)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := p + Vector2(sx * 9.0, sy * 9.0)
				draw_line(corner, corner - Vector2(sx * 4.0, 0), c, 1.0)
				draw_line(corner, corner - Vector2(0, sy * 4.0), c, 1.0)
