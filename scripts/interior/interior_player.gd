class_name InteriorPlayer
extends CharacterBody2D
## The robot indoors, seen from above (Undertale style): walks in 8 directions,
## shows its front, back or side, no jumping or fighting. [E] uses the nearest
## thing in reach (people first): talk, look, shop. Feet are at the origin.

const SPEED := 92.0

var visuals: OverworldVisuals
var _target: Node = null
var _step_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 6)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	visuals = OverworldVisuals.new()
	add_child(visuals)


func _physics_process(delta: float) -> void:
	var locked := GameState.is_ui_locked() or WorldManager.is_busy()
	var dir := Vector2.ZERO
	if not locked:
		dir = Input.get_vector("move_left", "move_right", "aim_up", "aim_down")
	velocity = dir * SPEED
	move_and_slide()
	var moving := dir.length() > 0.1
	visuals.walking = moving
	if moving:
		# the strongest axis picks the view; ties go to the side view, like Undertale
		if absf(dir.x) >= absf(dir.y) - 0.01:
			visuals.facing = OverworldVisuals.Facing.SIDE
			visuals.flip = dir.x < 0.0
		else:
			visuals.facing = OverworldVisuals.Facing.DOWN if dir.y > 0.0 else OverworldVisuals.Facing.UP
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.3
			AudioManager.sfx(&"step", -14.0, 0.1)
	_update_target(locked)
	if not locked and _target and not DialogueManager.active and Input.is_action_just_pressed("interact"):
		var t := _target
		_target = null
		EventBus.interact_prompt.emit("")
		t.interact()


func _update_target(locked: bool) -> void:
	# people first (a shopkeeper behind her counter beats the counter), then the nearest thing
	var best: Node = null
	var best_score := INF
	if not locked:
		for n in get_tree().get_nodes_in_group("interior_interactable"):
			var d: float = (n.global_position - global_position).length()
			if d < n.reach:
				var score := d - (1000.0 if n is InteriorNPC else 0.0)
				if score < best_score:
					best = n
					best_score = score
	if best != _target:
		_target = best
		EventBus.interact_prompt.emit("[E] " + best.prompt if best else "")
