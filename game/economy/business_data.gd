class_name BusinessData
extends Resource
## Static data for a business (Farm, Mine, Blacksmith...). Businesses are
## abstract: they are numbers in the simulation, not NPCs walking around.

@export var id: StringName = &""
@export var display_name: String = ""
## Settlement whose market receives the output and pays for the inputs.
@export var settlement_id: StringName = &""

@export_group("Output")
## Commodity produced (empty = produces nothing the market trades).
@export var output_commodity: StringName = &""
@export var output_per_day: float = 0.0

@export_group("Inputs")
## Commodities used every day. They are added to the settlement's demand.
@export var input_commodities: Array[StringName] = []
@export var input_per_day: Array[float] = []

@export_group("Conditions")
## WorldState flag that stops production completely, e.g. &"mine_infested".
@export var stopped_by: StringName = &""
## If true, output falls when workers in this settlement lack food.
@export var needs_fed_workers: bool = false
