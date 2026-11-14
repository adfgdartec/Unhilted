class_name InteriorNPC
extends Node2D

@export var npc_path: NodePath
@export var footprint := Vector2(12, 6)
@export var reach := 30.0

var npc: NPC
var prompt := "Talk"


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	npc = get_node_or_null(npc_path) as NPC
	if npc == null:
		push_warning("InteriorNPC %s: no NPC at %s" % [name, npc_path])
		return
	npc.set_deferred("monitoring", false)
	npc.set_deferred("monitorable", false)
	npc.collision_layer = 0
	npc.collision_mask = 0
	var room := get_parent() as InteriorRoom
	if room:
		npc.face_target = room.player
	prompt = npc.prompt
	if footprint != Vector2.ZERO:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = footprint
		cs.shape = r
		cs.position = Vector2(0, -footprint.y * 0.5)
		body.add_child(cs)
		add_child(body)
	add_to_group("interior_interactable")


func interact() -> void:
	if npc:
		npc.interact(null)
