class_name EconomySimulation
extends RefCounted
## Daily economy tick for the sandbox: one commodity (iron), two markets
## (Mining Village and Town), one mine and one trade route between them.
##
## Every day runs in this order: production -> trade -> consumption -> prices.
## Nothing here reacts to an event by changing a price. Events change
## WorldState; prices follow from stock and demand.

var config: EconomyConfig
var world: WorldState
var village: Market
var town: Market
var day: int = 0
## One entry per simulated day: was the mine infested that day?
var mine_history: Array[bool] = []
## What happened on the most recent day and why (for the log).
var last_report: Dictionary = {}


func _init(p_config: EconomyConfig, iron: Commodity, p_world: WorldState) -> void:
	config = p_config
	world = p_world
	village = Market.new("Mining Village", iron, config.village_start_stock,
			config.village_demand_per_day, config.target_stock_days)
	town = Market.new("Town", iron, config.town_start_stock,
			config.town_demand_per_day, config.target_stock_days)


func daily_tick() -> Dictionary:
	day += 1
	var report := {"day": day, "mine_infested": world.mine_infested}

	# 1. Production: the mine only works while it is safe.
	var produced := 0.0 if world.mine_infested else config.mine_output_per_day
	village.stock += produced
	report.produced = produced

	# 2. Trade: merchants haul iron to the town when the price gap pays for the trip.
	var profit := town.price - village.price - config.transport_cost_per_unit
	var eagerness := clampf((profit - config.trade_threshold) / config.full_trade_margin, 0.0, 1.0)
	var shipped := minf(config.trade_cap_per_day * eagerness, village.stock)
	village.stock -= shipped
	town.stock += shipped
	report.trade_profit_per_unit = profit
	report.shipped = shipped

	# 3. Consumption: people use iron, less of it when it is expensive.
	report.village_used = village.consume()
	report.town_used = town.consume()

	# 4. Prices follow stock.
	village.update_price()
	town.update_price()

	mine_history.append(world.mine_infested)
	last_report = report
	return report


## Human-readable answer to "why did prices move today?"
func explain(report: Dictionary = last_report) -> String:
	if report.is_empty():
		return "No days simulated yet. Press \"Next day\"."
	var lines: Array[String] = []
	lines.append("Day %d: what happened" % report.day)
	if report.mine_infested:
		lines.append("Mine INFESTED: produced 0 iron")
	else:
		lines.append("Mine safe: produced %.0f iron at the village" % report.produced)
	if report.shipped > 0.0:
		lines.append("Merchants shipped %.1f to town (profit %.2f g/unit)" % [
			report.shipped, report.trade_profit_per_unit])
	else:
		lines.append("No trade: profit %.2f g/unit is below %.2f" % [
			report.trade_profit_per_unit, config.trade_threshold])
	lines.append(_market_line(village, report.village_used))
	lines.append(_market_line(town, report.town_used))
	return "\n".join(lines)


func _market_line(market: Market, used: float) -> String:
	var short := market.daily_demand - used
	var use_text := "used %.1f" % used
	if short > 0.05:
		use_text += " (%.1f less than normal)" % short
	var change := market.price - market.yesterday_price()
	return "%s: %s, stock %.0f/%.0f wanted, price %.2f g (%+.2f)" % [
		market.settlement_name, use_text, market.stock, market.desired_stock(),
		market.price, change]
