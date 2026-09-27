class_name Commodity
extends Resource
## Static data for one tradable good (iron, food...).
## The numbers live in data/commodities/*.tres so they can be tuned in the
## Inspector without touching code.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Price")
## Price when a market holds exactly the stock it wants.
@export var base_price: float = 10.0
## How strongly price reacts to shortage or surplus. 0 = never moves.
@export_range(0.0, 2.0) var elasticity: float = 0.6
## Share of the gap to the target price closed each day (0.15 = 15%).
@export_range(0.01, 1.0) var smoothing: float = 0.15
## Price floor and ceiling, as multiples of base_price.
@export var min_multiplier: float = 0.4
@export var max_multiplier: float = 4.0

@export_group("Demand")
## How much people cut back when it is expensive (and buy more when cheap).
## 0 = they always buy the same amount.
@export_range(0.0, 2.0) var demand_sensitivity: float = 0.5
