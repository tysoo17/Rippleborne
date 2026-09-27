class_name SettlementData
extends Resource
## Static data for a settlement (Town, Mining Village).

@export var id: StringName = &""
@export var display_name: String = ""
@export var population: int = 100
## Units of each commodity the people here want per day at base price,
## e.g. {&"food": 22.0, &"wood": 6.0}. Businesses add their own inputs on top.
@export var demand_per_day: Dictionary = {}
## Markets start with this many days of demand in stock.
@export var target_stock_days: float = 5.0
