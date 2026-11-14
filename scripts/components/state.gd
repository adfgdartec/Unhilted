class_name State
extends Node
## Base class for one state in a StateMachine. Override what you need.

var actor: Node          ## The node this machine controls (e.g. the Player).
var machine: StateMachine


func enter(_msg := {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
