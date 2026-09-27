class_name Settlement
extends RefCounted
## A settlement at runtime: one Market per commodity, plus a ledger of what
## happened today. The ledger is what lets the Market Board answer "why?".

var data: SettlementData
var markets: Dictionary = {}  # commodity id -> Market
## Today's events per commodity, reset every midnight.
var ledger: Dictionary = {}
## The finished ledger of the last simulated day.
var last_ledger: Dictionary = {}


func _init(p_data: SettlementData, commodities: Dictionary, business_demand: Dictionary) -> void:
	data = p_data
	for id in commodities:
		var demand := float(data.demand_per_day.get(id, 0.0)) + float(business_demand.get(id, 0.0))
		markets[id] = Market.new(commodities[id], demand * data.target_stock_days,
				demand, data.target_stock_days)
	ledger = _empty_ledger()


func close_day() -> void:
	last_ledger = ledger
	ledger = _empty_ledger()


func _empty_ledger() -> Dictionary:
	var result := {}
	for id in markets:
		result[id] = {
			"produced": 0.0, "normal_production": 0.0, "production_notes": [],
			"imported": 0.0, "exported": 0.0, "route_risk": 0.0,
			"used": 0.0, "wanted": 0.0,
			"player_bought": 0.0, "player_sold": 0.0,
		}
	return result


func to_dict() -> Dictionary:
	var market_data := {}
	for id in markets:
		market_data[String(id)] = markets[id].to_dict()
	return {"markets": market_data, "ledger": ledger, "last_ledger": last_ledger}


func from_dict(saved: Dictionary) -> void:
	var market_data: Dictionary = saved.get("markets", {})
	for id in markets:
		if market_data.has(String(id)):
			markets[id].from_dict(market_data[String(id)])
	ledger = _restore_ledger(saved.get("ledger", {}))
	last_ledger = _restore_ledger(saved.get("last_ledger", {}))


## JSON turns StringName keys into Strings; turn them back.
func _restore_ledger(saved: Dictionary) -> Dictionary:
	var result := {}
	for key in saved:
		result[StringName(key)] = saved[key]
	return result if not result.is_empty() else _empty_ledger()
