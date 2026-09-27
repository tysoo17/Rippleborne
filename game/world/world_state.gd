class_name WorldState
extends RefCounted
## What is currently true about the world, independent of any scene.
##
## Events and the player change these values; economy systems only read them.
## This is how "clear the mine" can affect iron prices without combat code
## ever touching a price.

var mine_infested: bool = false


func set_mine_infested(infested: bool) -> void:
	if infested == mine_infested:
		return
	mine_infested = infested
	EventBus.mine_state_changed.emit(infested)
