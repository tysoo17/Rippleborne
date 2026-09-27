class_name Market
extends RefCounted
## One commodity's market in one settlement: stock, demand and price.
##
## Price is never set by hand. Each day it moves toward a target price that
## comes from how much stock the market holds compared to how much it wants.

## Consumption never drops below half or rises above 1.5x of normal demand.
const MIN_DEMAND_FACTOR := 0.5
const MAX_DEMAND_FACTOR := 1.5
## Days of price history kept in memory (the save file keeps fewer).
const MAX_HISTORY := 400

var commodity: Commodity
var stock: float
## Units wanted per day at the base price (people + businesses).
var daily_demand: float
var target_stock_days: float
var price: float
## Price at the end of every simulated day, oldest first.
var price_history: Array[float] = []
## Result of the most recent consume(): how much was wanted and actually used.
var last_wanted: float = 0.0
var last_used: float = 0.0


func _init(p_commodity: Commodity, p_stock: float, p_daily_demand: float,
		p_target_stock_days: float) -> void:
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
	last_wanted = daily_demand * clampf(factor, MIN_DEMAND_FACTOR, MAX_DEMAND_FACTOR)
	last_used = minf(last_wanted, stock)
	stock -= last_used
	return last_used


## Share of normal demand that people actually got today (0..1).
## Below 1 when stock ran out, or when it was so expensive they cut back.
func satisfaction() -> float:
	if daily_demand <= 0.0:
		return 1.0
	return minf(1.0, last_used / daily_demand)


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
	if price_history.size() > MAX_HISTORY:
		price_history.pop_front()


## Price n days ago (1 = yesterday). Falls back to the oldest known price.
func price_days_ago(days: int) -> float:
	var index := price_history.size() - 1 - days
	if price_history.is_empty():
		return price
	return price_history[maxi(index, 0)]


## Stock compared to what the market wants: "Shortage", "Low", "Normal" or "Surplus".
func stock_status() -> String:
	var ratio := stock / maxf(desired_stock(), 1.0)
	if ratio < 0.4:
		return "Shortage"
	if ratio < 0.8:
		return "Low"
	if ratio < 1.4:
		return "Normal"
	return "Surplus"


func to_dict() -> Dictionary:
	return {"stock": stock, "price": price, "history": price_history.slice(-90),
			"last_wanted": last_wanted, "last_used": last_used}


func from_dict(data: Dictionary) -> void:
	stock = float(data.get("stock", stock))
	price = float(data.get("price", price))
	price_history.clear()
	for value in data.get("history", []):
		price_history.append(float(value))
	last_wanted = float(data.get("last_wanted", 0.0))
	last_used = float(data.get("last_used", 0.0))
