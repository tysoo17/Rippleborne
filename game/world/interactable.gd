class_name Interactable
extends Area2D
## Something the player can use with E: a market stall, a board, the inn,
## a herb bush... The player shows "E: <prompt>" when it is in reach.
##
## Either set `panel` (the UI opens that panel for `settlement_id`), or
## connect to `used` and handle it in code.

signal used(player: Player)

@export var prompt: String = "Talk"
## UI panel to open: &"shop", &"market_board", &"inn" or &"blacksmith".
@export var panel: StringName = &""
@export var settlement_id: StringName = &""
@export var enabled: bool = true


func _ready() -> void:
	collision_layer = 128  # layer 8 "Interact"
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt


func interact(player: Player) -> void:
	if panel != &"":
		EventBus.open_panel.emit(panel, {"settlement": settlement_id})
	used.emit(player)
