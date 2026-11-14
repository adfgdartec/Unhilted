extends Node
## Loads every data Resource (.tres) once at startup so any script can look
## things up by id: ItemDB.chips[&"long_tether"], ItemDB.cosmetics[...], etc.
## To add a new chip/outfit/quest, just drop a new .tres file in the right folder.

var chips: Dictionary = {}      ## id -> UpgradeChip
var cosmetics: Dictionary = {}  ## id -> CosmeticItem
var quests: Dictionary = {}     ## id -> QuestData
var regions: Dictionary = {}    ## id -> RegionData
var shards: Dictionary = {}     ## id -> ShardData


func _ready() -> void:
	chips = _load_folder("res://data/chips")
	cosmetics = _load_folder("res://data/cosmetics")
	quests = _load_folder("res://data/quests")
	regions = _load_folder("res://data/regions")
	shards = _load_folder("res://data/shards")


func _load_folder(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ItemDB: missing folder " + path)
		return out
	for file in dir.get_files():
		file = file.trim_suffix(".remap") # exported games rename resources to *.remap
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(path.path_join(file))
		if res != null and "id" in res:
			out[res.id] = res
	return out


func region(id: StringName) -> RegionData:
	return regions.get(id)


func currency_name(currency: StringName) -> String:
	if currency == &"scrap":
		return "Scrap"
	var r: RegionData = regions.get(currency)
	return r.currency_name if r else String(currency)
