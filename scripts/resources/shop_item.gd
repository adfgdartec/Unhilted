class_name ShopItem
extends Resource

enum ItemType { CHIP, COSMETIC, CONSUMABLE, PORT_EXPANSION, CORE_CELL, MAP }

@export var item_type: ItemType = ItemType.CHIP
@export var item_id: StringName
@export var display_name := ""
@export var price := 1
@export var currency: StringName = &"scrap"
@export var stock := 1
@export var required_quest: StringName
@export_multiline var description := ""
