class_name Market
extends RefCounted
## One commodity's market in one settlement: stock, demand and price.
##
## Price is never set by hand. Each day it moves toward a target price that
## comes from how much stock the market holds compared to how much it wants.

## Consumption never drops below half or rises above 1.5x of normal demand.
const MIN_DEMAND_FACTOR := 0.5
const MAX_DEMAND_FACTOR := 1.5

var settlement_name: String
var commodity: Commodity
var stock: float
## Units people want per day at the base price.
var daily_demand: float
var target_stock_days: float
var price: float
## Price at the end of every simulated day, oldest first.
var price_history: Array[float] = []


func _init(p_settlement_name: String, p_commodity: Commodity, p_stock: float,
		p_daily_demand: float, p_target_stock_days: float) -> void:
	settlement_name = p_settlement_name
	commodity = p_commodity
	stock = p_stock
	daily_demand = p_daily_demand
	target_stock_days = p_target_stock_days
	price = commodity.base_price


## Stock level the market is comfortable with.
func desired_stock() -> float:
	return daily_demand * target_stock_days


## People buy less when price is high and more when it is low.
## Returns how many units were actually used today.
func consume() -> float:
	var factor := pow(commodity.base_price / price, commodity.demand_sensitivity)
	var wanted := daily_demand * clampf(factor, MIN_DEMAND_FACTOR, MAX_DEMAND_FACTOR)
	var used := minf(wanted, stock)
	stock -= used
	return used


## Price the market is heading toward, from the stock it holds.
## Less stock than desired -> above base price; more -> below.
func target_price() -> float:
	var ratio := desired_stock() / maxf(stock, 1.0)
	var target := commodity.base_price * pow(ratio, commodity.elasticity)
	return clampf(target,
			commodity.base_price * commodity.min_multiplier,
			commodity.base_price * commodity.max_multiplier)


## Move price part of the way toward the target (smoothing), then record it.
func update_price() -> void:
	price += (target_price() - price) * commodity.smoothing
	price_history.append(price)


func yesterday_price() -> float:
	if price_history.size() < 2:
		return commodity.base_price
	return price_history[-2]
