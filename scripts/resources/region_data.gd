class_name RegionData
extends Resource
## One of the five regions (The Heap, The Underworks, ...). Holds the local
## currency info. total_local_coins = coins hidden in the world + quest rewards.

@export var id: StringName
@export var display_name := ""
@export var currency_name := ""
@export var currency_color := Color.ORANGE
@export var total_local_coins := 0
## The coin as it lies in the world, and the small white HUD/shop icon
## (tinted with currency_color). Empty = the Heap's bottlecap.
@export var coin_icon: Texture2D
@export var hud_icon: Texture2D
@export var music: AudioStream
