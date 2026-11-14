class_name CosmeticItem
extends Resource

enum Slot { HOOD, MASK, CLOAK, SHIRT, PANTS, SHOES }
const SLOT_NAMES := ["Hood", "Mask", "Cloak", "Shirt", "Pants", "Shoes"]

@export var id: StringName
@export var display_name := ""
@export var slot: Slot = Slot.CLOAK
@export var color := Color.WHITE
@export var accent := Color.BLACK
@export var sprite_frames: SpriteFrames
@export var sprite_frames_back: SpriteFrames
@export var icon: Texture2D
