class_name QuestObjective
extends Resource

enum Type { COLLECT, KILL, TALK, ENTER_ROOM }

@export var type: Type = Type.COLLECT
@export var target_id: StringName
@export var count := 1
@export var description := ""
