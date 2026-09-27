class_name EconomyConfig
extends Resource
## Balance numbers for the economy sandbox.
## Edit data/economy/sandbox_config.tres in the Inspector and rerun to experiment.

@export_group("Production")
## Iron the mine produces per day while it is safe.
@export var mine_output_per_day: float = 20.0

@export_group("Demand")
## Iron each settlement wants to use per day at the base price.
@export var village_demand_per_day: float = 6.0
@export var town_demand_per_day: float = 14.0
## A market is "comfortable" when it holds this many days of demand.
@export var target_stock_days: float = 5.0

@export_group("Trade")
## Cost for merchants to haul one unit from the village to the town.
@export var transport_cost_per_unit: float = 2.0
## Merchants ignore the route if profit per unit is below this.
@export var trade_threshold: float = 1.0
## Profit per unit (above the threshold) at which merchants ship the full cap.
@export var full_trade_margin: float = 5.0
## Most units the caravan can carry per day.
@export var trade_cap_per_day: float = 20.0

@export_group("Start")
@export var village_start_stock: float = 30.0
@export var town_start_stock: float = 70.0
