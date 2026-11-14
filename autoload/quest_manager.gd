extends Node

const S := GameState.QuestState


func _ready() -> void:
	EventBus.item_collected.connect(func(id): _progress(QuestObjective.Type.COLLECT, id))
	EventBus.enemy_killed.connect(func(id, _pos): _progress(QuestObjective.Type.KILL, id))
	EventBus.npc_talked.connect(func(id): _progress(QuestObjective.Type.TALK, id))
	EventBus.room_entered.connect(func(id): _progress(QuestObjective.Type.ENTER_ROOM, id))


func get_state(id: StringName) -> int:
	if GameState.quest_states.has(id):
		return int(GameState.quest_states[id]["state"])
	var quest: QuestData = ItemDB.quests.get(id)
	if quest == null:
		return S.LOCKED
	for pre in quest.prerequisite_quests:
		if get_state(pre) != S.TURNED_IN:
			return S.LOCKED
	return S.AVAILABLE


func accept(id: StringName) -> void:
	var quest: QuestData = ItemDB.quests.get(id)
	if quest == null or get_state(id) != S.AVAILABLE:
		return
	var progress := []
	for obj in quest.objectives:
		if obj.type == QuestObjective.Type.COLLECT:
			progress.append(mini(GameState.key_item_count(obj.target_id), obj.count))
		else:
			progress.append(0)
	GameState.quest_states[id] = {"state": S.ACTIVE, "progress": progress}
	EventBus.toast.emit("Quest started: " + quest.title)
	_check_complete(id)
	EventBus.quest_updated.emit(id)


func turn_in(id: StringName) -> void:
	var quest: QuestData = ItemDB.quests.get(id)
	if quest == null or get_state(id) != S.COMPLETE:
		return
	for obj in quest.objectives:
		if obj.type == QuestObjective.Type.COLLECT:
			GameState.key_items[obj.target_id] = maxi(GameState.key_item_count(obj.target_id) - obj.count, 0)
	if quest.reward_scrap > 0:
		GameState.add_scrap(quest.reward_scrap)
	if quest.reward_local > 0:
		GameState.add_local(quest.region_id, quest.reward_local, true)
		EventBus.toast.emit("+%d %s" % [quest.reward_local, ItemDB.currency_name(quest.region_id)])
	for chip_id in quest.reward_chips:
		GameState.add_chip(chip_id)
	for cos_id in quest.reward_cosmetics:
		GameState.add_cosmetic(cos_id)
	GameState.quest_states[id]["state"] = S.TURNED_IN
	EventBus.toast.emit("Quest complete: " + quest.title)
	EventBus.quest_updated.emit(id)


func tracker_text() -> String:
	for id in GameState.quest_states:
		var state := get_state(id)
		if state != S.ACTIVE and state != S.COMPLETE:
			continue
		var quest: QuestData = ItemDB.quests.get(id)
		if quest == null:
			continue
		var text := quest.title
		if state == S.COMPLETE:
			return text + "\n  > Return to " + quest.giver_name
		var progress: Array = GameState.quest_states[id]["progress"]
		for i in quest.objectives.size():
			var obj: QuestObjective = quest.objectives[i]
			text += "\n  > %s  %d/%d" % [obj.description, int(progress[i]), obj.count]
		return text
	return ""


func _progress(type: int, target: StringName) -> void:
	for id in GameState.quest_states.keys():
		if get_state(id) != S.ACTIVE:
			continue
		var quest: QuestData = ItemDB.quests.get(id)
		if quest == null:
			continue
		var progress: Array = GameState.quest_states[id]["progress"]
		var changed := false
		for i in quest.objectives.size():
			var obj: QuestObjective = quest.objectives[i]
			if obj.type == type and obj.target_id == target and int(progress[i]) < obj.count:
				progress[i] = int(progress[i]) + 1
				changed = true
		if changed:
			_check_complete(id)
			EventBus.quest_updated.emit(id)


func _check_complete(id: StringName) -> void:
	var quest: QuestData = ItemDB.quests.get(id)
	var progress: Array = GameState.quest_states[id]["progress"]
	for i in quest.objectives.size():
		if int(progress[i]) < quest.objectives[i].count:
			return
	GameState.quest_states[id]["state"] = S.COMPLETE
	EventBus.toast.emit("Objective done! Return to " + quest.giver_name)
