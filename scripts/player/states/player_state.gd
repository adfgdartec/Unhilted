class_name PlayerState
extends State
## Base for all player states. `player` is a typed shortcut to the actor.

var player: Player:
	get:
		return actor as Player
