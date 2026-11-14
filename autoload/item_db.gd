extends Node

var chips: Dictionary = {}
var cosmetics: Dictionary = {}
var quests: Dictionary = {}
var regions: Dictionary = {}
var shards: Dictionary = {}


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
		file = file.trim_suffix(".remap")
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
