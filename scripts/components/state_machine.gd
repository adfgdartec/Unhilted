class_name StateMachine
extends Node

signal state_changed(new_state: String)

@export var initial_state: State

var current: State
var states: Dictionary = {}


func setup(controlled: Node) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.actor = controlled
			child.machine = self
	current = initial_state if initial_state else get_child(0)
	current.enter({})


func transition(state_name: String, msg := {}) -> void:
	var next: State = states.get(state_name.to_lower())
	if next == null:
		push_error("StateMachine: no state named " + state_name)
		return
	if current:
		current.exit()
	current = next
	current.enter(msg)
	state_changed.emit(state_name)


func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)


func current_name() -> String:
	return String(current.name).to_lower() if current else ""
