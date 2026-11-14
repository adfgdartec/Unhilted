class_name QuestObjective
extends Resource
## One step of a quest. target_id matches the id sent on the EventBus
## (item id, enemy id, npc id or room id).

enum Type { COLLECT, KILL, TALK, ENTER_ROOM }

@export var type: Type = Type.COLLECT
@export var target_id: StringName
@export var count := 1
@export var description := ""
