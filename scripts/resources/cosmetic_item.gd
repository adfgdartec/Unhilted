class_name CosmeticItem
extends Resource
## One outfit piece. Purely cosmetic: stats come from ports, never from clothes.
## Real art: give it a SpriteFrames whose animation names, frame counts and
## canvas size match the robot body exactly, so every layer stays in sync.

enum Slot { HOOD, MASK, CLOAK, SHIRT, PANTS, SHOES }
const SLOT_NAMES := ["Hood", "Mask", "Cloak", "Shirt", "Pants", "Shoes"]

@export var id: StringName
@export var display_name := ""
@export var slot: Slot = Slot.CLOAK
@export var color := Color.WHITE ## Placeholder colour (later: palette-swap tint).
@export var accent := Color.BLACK ## Secondary placeholder colour.
@export var sprite_frames: SpriteFrames
## Cloaks only: the drape behind the body (sprite_frames is the capelet in front).
@export var sprite_frames_back: SpriteFrames
@export var icon: Texture2D ## Shop / wardrobe icon (generated with the sprites).
