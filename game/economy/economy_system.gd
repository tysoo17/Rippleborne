class_name EconomySystem
extends RefCounted
## The daily economy of the whole world: 4 commodities, 2 settlements,
## businesses that produce and consume, and caravans on the road between them.
##
## Every midnight runs: production -> trade -> consumption -> prices.
## Nothing here reacts to an event by changing a price. Events change
## WorldState; production and trade read it; prices follow from stock.

const TOWN := &"town"
const VILLAGE := &"village"
## Caravans need at least this much profit per unit (share of base price).
const TRADE_THRESHOLD_SHARE := 0.1
## At this profit per unit above the threshold they send a full caravan.
const FULL_TRADE_MARGIN_SHARE := 0.5
## Extra cost caravans add for danger: route risk x price x this.
const RISK_COST_FACTOR := 0.5
## Share of caravans that still travel when the road is at risk 1.0.
const MIN_ROUTE_EFFICIENCY := 0.1
## Hungry workers still produce at least this share of normal output.
const MIN_FED_EFFICIENCY := 0.3
## Shops add this margin when selling to the player and take it when buying.
const SHOP_MARGIN := 0.1
## Everyday ups and downs: production and demand vary by up to this share.
const DAILY_NOISE := 0.07
## Buying a tenth of what a market wants raises its price by this / 10.
const PLAYER_PRICE_IMPACT := 0.5

var commodities: Dictionary = {}  # id -> Commodity
var settlements: Dictionary = {}  # id -> Settlement
var businesses: Array[BusinessData] = []
var day: int = 0
var last_route_risk: float = 0.0
var rng := RandomNumberGenerator.new()
## Shop margin per settlement; a good reputation lowers it (set by the job system).
var shop_margins: Dictionary = {}


func _init(p_commodities: Array[Commodity], p_settlements: Array[SettlementData],
		p_businesses: Array[BusinessData]) -> void:
	for c in p_commodities:
		commodities[c.id] = c
	businesses = p_businesses
	for s in p_settlements:
		var business_demand := {}
		for b in businesses:
			if b.settlement_id != s.id:
				continue
			for i in b.input_commodities.size():
				var input := b.input_commodities[i]
				business_demand[input] = float(business_demand.get(input, 0.0)) + b.input_per_day[i]
		settlements[s.id] = Settlement.new(s, commodities, business_demand)


func market(settlement_id: StringName, commodity_id: StringName) -> Market:
	return settlements[settlement_id].markets[commodity_id]


func daily_tick(world: WorldState) -> void:
	day += 1
	_produce(world)
	_trade(world)
	for s: Settlement in settlements.values():
		for id in s.markets:
			var m: Market = s.markets[id]
			var event_factor := world.demand_factor(s.data.id, id)
			m.consume(event_factor * _noise())
			for reason in world.modifier_reasons(&"", s.data.id, id):
				s.ledger[id].demand_notes.append(reason)
			s.ledger[id].used = m.last_used
			s.ledger[id].wanted = m.last_wanted
			m.update_price()
		s.close_day()


# --- 1. Production ---------------------------------------------------------

## 0..1: how well a business works today given the world state.
func business_efficiency(b: BusinessData, world: WorldState) -> float:
	if b.stopped_by != &"" and world.get_flag(b.stopped_by):
		return 0.0
	var efficiency := 1.0
	if b.needs_fed_workers and commodities.has(&"food"):
		var food: Market = settlements[b.settlement_id].markets[&"food"]
		efficiency *= maxf(MIN_FED_EFFICIENCY, food.satisfaction())
	return efficiency


func _produce(world: WorldState) -> void:
	for b in businesses:
		if b.output_commodity == &"":
			continue
		var s: Settlement = settlements[b.settlement_id]
		var efficiency := business_efficiency(b, world)
		var event_factor := world.production_factor(b.id)
		var amount := b.output_per_day * efficiency * event_factor * _noise()
		s.markets[b.output_commodity].stock += amount
		var entry: Dictionary = s.ledger[b.output_commodity]
		entry.produced += amount
		entry.normal_production += b.output_per_day
		if efficiency <= 0.0:
			entry.production_notes.append("%s stopped (%s)" % [b.display_name, WorldState.flag_reason(b.stopped_by)])
		elif efficiency < 0.95:
			entry.production_notes.append("%s at %d%%: workers short on food" % [b.display_name, roundi(efficiency * 100)])
		for reason in world.modifier_reasons(b.id):
			entry.production_notes.append("%s: %s" % [b.display_name, reason])


## Random everyday variation around 1.0.
func _noise() -> float:
	return 1.0 + rng.randf_range(-DAILY_NOISE, DAILY_NOISE)


# --- 2. Trade ----------------------------------------------------------------

## 0..1: share of normal caravan traffic that dares to use the road.
func route_efficiency(risk: float) -> float:
	return lerpf(1.0, MIN_ROUTE_EFFICIENCY, clampf(risk, 0.0, 1.0))


func _trade(world: WorldState) -> void:
	last_route_risk = world.route_risk()
	var efficiency := route_efficiency(last_route_risk)
	var town: Settlement = settlements[TOWN]
	var village: Settlement = settlements[VILLAGE]
	for id in commodities:
		town.ledger[id].route_risk = last_route_risk
		village.ledger[id].route_risk = last_route_risk
		_ship(id, town, village, last_route_risk, efficiency)
		_ship(id, village, town, last_route_risk, efficiency)


## Caravans buy where it is cheap and sell where it is expensive, if the
## price gap pays for transport and danger.
func _ship(id: StringName, from: Settlement, to: Settlement, risk: float, efficiency: float) -> void:
	var c: Commodity = commodities[id]
	var buy: Market = from.markets[id]
	var sell: Market = to.markets[id]
	var profit := sell.price - buy.price - c.transport_cost_per_unit - risk * buy.price * RISK_COST_FACTOR
	var eagerness := clampf((profit - c.base_price * TRADE_THRESHOLD_SHARE)
			/ (c.base_price * FULL_TRADE_MARGIN_SHARE), 0.0, 1.0)
	var quantity := minf(c.trade_cap_per_day * eagerness * efficiency, buy.stock)
	if quantity <= 0.0:
		return
	buy.stock -= quantity
	sell.stock += quantity
	from.ledger[id].exported += quantity
	to.ledger[id].imported += quantity


# --- Player trades -------------------------------------------------------

func shop_margin(settlement_id: StringName) -> float:
	return float(shop_margins.get(settlement_id, SHOP_MARGIN))


## What the shop charges the player for one unit.
func buy_price(settlement_id: StringName, id: StringName) -> int:
	return maxi(1, ceili(market(settlement_id, id).price * (1.0 + shop_margin(settlement_id))))


## What the shop pays the player for one unit.
func sell_price(settlement_id: StringName, id: StringName) -> int:
	return maxi(1, floori(market(settlement_id, id).price * (1.0 - shop_margin(settlement_id))))


## The player takes goods out of the market. Stock changes now and the price
## nudges up right away; the big move still comes at midnight.
func player_bought(settlement_id: StringName, id: StringName, quantity: int) -> void:
	var s: Settlement = settlements[settlement_id]
	s.markets[id].stock = maxf(0.0, s.markets[id].stock - quantity)
	s.markets[id].apply_player_trade(quantity, PLAYER_PRICE_IMPACT)
	s.ledger[id].player_bought += quantity


func player_sold(settlement_id: StringName, id: StringName, quantity: int) -> void:
	var s: Settlement = settlements[settlement_id]
	s.markets[id].stock += quantity
	s.markets[id].apply_player_trade(-quantity, PLAYER_PRICE_IMPACT)
	s.ledger[id].player_sold += quantity


# --- Explanations --------------------------------------------------------

## Reasons behind a market's latest price move, most important first.
func explain(settlement_id: StringName, id: StringName) -> Array[String]:
	var s: Settlement = settlements[settlement_id]
	var m: Market = s.markets[id]
	var e: Dictionary = s.last_ledger.get(id, {})
	var result: Array[String] = []
	if e.is_empty() or day == 0:
		result.append("Prices update every midnight.")
		return result
	var reasons: Array = []  # [weight, text]
	var normal: float = e.normal_production
	if normal > 0.0:
		if not e.production_notes.is_empty():
			for note in e.production_notes:
				reasons.append([absf(normal - e.produced) + 50.0, "%s: made %.0f instead of %.0f" % [note, e.produced, normal]])
		else:
			reasons.append([e.produced * 0.2, "Made here: %.0f" % e.produced])
	if e.route_risk >= 0.3:
		reasons.append([40.0, "Bandits on the road: caravans run at %d%%" % roundi(route_efficiency(e.route_risk) * 100)])
	if e.imported >= 0.5:
		reasons.append([e.imported * 0.5, "Caravans brought in %.0f" % e.imported])
	if e.exported >= 0.5:
		reasons.append([e.exported * 0.5, "Caravans took %.0f away" % e.exported])
	for note in e.get("demand_notes", []):
		reasons.append([45.0, "Demand: %s" % note])
	var shortfall: float = e.wanted - e.used
	if shortfall >= 0.5:
		reasons.append([shortfall * 2.0 + 20.0, "Shortage: people wanted %.0f, got %.0f" % [e.wanted, e.used]])
	if e.player_sold >= 1.0:
		reasons.append([e.player_sold + 10.0, "You sold %.0f here" % e.player_sold])
	if e.player_bought >= 1.0:
		reasons.append([e.player_bought + 10.0, "You bought %.0f here" % e.player_bought])
	reasons.sort_custom(func(a, b): return a[0] > b[0])
	for r in reasons:
		result.append(r[1])
	result.append("Stock %.0f, wants about %.0f (%s)" % [m.stock, m.desired_stock(), m.stock_status().to_lower()])
	return result


# --- Save ----------------------------------------------------------------

func to_dict() -> Dictionary:
	var data := {}
	for id in settlements:
		data[String(id)] = settlements[id].to_dict()
	return {"day": day, "last_route_risk": last_route_risk, "settlements": data,
			"rng_seed": str(rng.seed), "rng_state": str(rng.state)}


func from_dict(saved: Dictionary) -> void:
	day = int(saved.get("day", 0))
	last_route_risk = float(saved.get("last_route_risk", 0.0))
	if saved.has("rng_state"):
		rng.seed = int(str(saved.rng_seed))
		rng.state = int(str(saved.rng_state))
	var data: Dictionary = saved.get("settlements", {})
	for id in settlements:
		if data.has(String(id)):
			settlements[id].from_dict(data[String(id)])
