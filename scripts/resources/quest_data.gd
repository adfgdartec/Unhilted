class_name QuestData
extends Resource

@export var id: StringName
@export var title := ""
@export_multiline var description := ""
@export var region_id: StringName = &"heap"
@export var giver_name := ""
@export var prerequisite_quests: Array[StringName] = []
@export var objectives: Array[QuestObjective] = []

@export_group("Rewards")
@export var reward_scrap := 0
@export var reward_local := 0
@export var reward_chips: Array[StringName] = []
@export var reward_cosmetics: Array[StringName] = []

@export_group("Dialogue")
@export var offer_lines: Array[String] = []
@export var active_lines: Array[String] = []
@export var complete_lines: Array[String] = []
@export var done_lines: Array[String] = []
