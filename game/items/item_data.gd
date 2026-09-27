class_name ItemData
extends Resource
## Static data for anything that fits in the inventory.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
## Price a shop pays for items that are NOT commodities (loot).
@export var base_value: int = 1
## If set, this item is a commodity: shops use the local market price
## and selling it adds to that market's stock.
@export var commodity_id: StringName = &""
## Hit points restored when used. 0 = cannot be used.
@export var heal_amount: int = 0


func is_commodity() -> bool:
	return commodity_id != &""
