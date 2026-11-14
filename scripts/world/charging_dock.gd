class_name ChargingDock
extends Interactable
## Your bench: heals, sets the respawn point, saves, and opens the dock menu
## (Loadout / Wardrobe). Chips can only be swapped here.

@export var spawn_name: StringName = &"dock"

const TEX := preload("res://art/items/charging_dock.png")

var _t := 0.0


func _init() -> void:
	prompt = "Charge"


func interact(player: Player) -> void:
	player.health.refill()
	AudioManager.sfx(&"dock")
	GameState.respawn_room = GameState.current_room
	GameState.respawn_spawn = spawn_name
	SaveManager.save_game()
	Fx.ring(global_position + Vector2(0, -24), Color(0.3, 0.95, 1.0), 48.0, 0.5, 2.5)
	EventBus.toast.emit("Systems charged. Progress saved.")
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.open_dock_menu()


func _ready() -> void:
	super._ready()
	var glow := Sprite2D.new()
	glow.texture = preload("res://art/fx/glow.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate = Color(0.22, 0.95, 1.0, 0.55)
	glow.scale = Vector2(1.3, 1.6)
	glow.position = Vector2(0, -24)
	glow.modulate.a = 0.35
	add_child(glow)
	var light := Fx.make_light(Color(0.3, 0.95, 1.0), 80.0, 0.9)
	light.position = Vector2(0, -26)
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f := int(_t * 8.0) % 4
	draw_texture_rect_region(TEX, Rect2(-17, -50, 34, 50), Rect2(f * 34, 0, 34, 50))
