class_name LocationArea
extends Area2D
## A named region of the map (Town, Forest...). Tells everyone when the
## player walks in, so the HUD can show where they are.

@export var location_name: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player's body
	monitorable = false
	body_entered.connect(func(body: Node):
		if body is Player:
			EventBus.location_changed.emit(location_name))
