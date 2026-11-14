class_name NPC
extends Interactable

@export var npc_id: StringName = &"npc"
@export var display_name := "???"

@export_group("Look")
@export var lineage: Lineage
@export_enum("adult", "teen", "child", "elder") var age := "adult"
@export var look_seed := 0
@export var pin_headwear := ""
@export var pin_goggles := ""
@export var pin_accessory := ""
@export_group("")
@export var idle_lines: Array[String] = ["..."]
@export var quest: QuestData
@export var shop_items: Array[ShopItem] = []
@export var shop_greeting := "Take a look."

var _t := 0.0
var _busy := false
var _frames: Array[ImageTexture] = []
var _facing := -1
var face_target: Node2D = null


func _ready() -> void:
	super._ready()
	_t = float(hash(npc_id) % 100) / 37.0
	if lineage:
		var seed_value := look_seed if look_seed != 0 else hash(npc_id)
		var traits := NPCLook.roll(lineage, seed_value, age, {
			"headwear": pin_headwear, "goggles": pin_goggles, "accessory": pin_accessory})
		_frames = NPCLook.build(lineage, traits)
		var lens := Fx.make_light(lineage.lens_color, 18.0, 0.55)
		lens.position = NPCLook.lens_offset(traits) + Vector2(NPCLook.W / 2, 0)
		add_child(lens)
	if age == "elder":
		var glow := Fx.make_light(Color(1.0, 0.78, 0.5), 44.0, 0.45)
		glow.position = Vector2(0, -14)
		add_child(glow)


func interact(_player: Player) -> void:
	if _busy:
		return
	_busy = true
	EventBus.npc_talked.emit(npc_id)
	await _talk()
	_busy = false


func _talk() -> void:
	if quest:
		var S := GameState.QuestState
		match QuestManager.get_state(quest.id):
			S.AVAILABLE:
				await DialogueManager.say(quest.offer_lines, display_name)
				QuestManager.accept(quest.id)
				return
			S.ACTIVE:
				await DialogueManager.say(quest.active_lines, display_name)
				return
			S.COMPLETE:
				await DialogueManager.say(quest.complete_lines, display_name)
				QuestManager.turn_in(quest.id)
				return
			S.TURNED_IN:
				if shop_items.is_empty():
					await DialogueManager.say(quest.done_lines, display_name)
					return
	if not shop_items.is_empty():
		await DialogueManager.say([shop_greeting], display_name)
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui:
			ui.open_shop(self)
		return
	await DialogueManager.say(idle_lines, display_name)


func _process(delta: float) -> void:
	_t += delta
	var target: Node2D = face_target if is_instance_valid(face_target) else WorldManager.player
	if target and global_position.distance_to(target.global_position) < 90.0:
		if absf(target.global_position.x - global_position.x) > 2.0:
			_facing = 1 if target.global_position.x > global_position.x else -1
	queue_redraw()


func _draw() -> void:
	if _frames.size() == 2:
		var f := 1 if fmod(_t, 2.4) > 1.6 else 0
		if _facing < 0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture(_frames[f], Vector2(-NPCLook.W / 2, -NPCLook.H))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if quest and QuestManager.get_state(quest.id) in [GameState.QuestState.AVAILABLE, GameState.QuestState.COMPLETE]:
		var mark := "!" if QuestManager.get_state(quest.id) == GameState.QuestState.AVAILABLE else "?"
		draw_string(ThemeDB.fallback_font, Vector2(-3, -44 + sin(_t * 4.0) * 2.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffb347"))
