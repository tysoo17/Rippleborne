class_name JobSystem
extends RefCounted
## Work that comes from the world instead of a story script:
## - Deliveries appear where a commodity runs short ("Bring 12 food to the
##   Mining Village"). Delivering adds the goods to that market, so you really
##   do ease the shortage.
## - Bounties appear while a big event is active and pay when YOU end it.
## Finished jobs raise your reputation with that settlement, and a good
## reputation gets you better prices at its market.

const MAX_DELIVERIES_PER_SETTLEMENT := 2
## Deliveries pay this much more than the goods are worth at the market.
const REWARD_MARKUP := 1.25
const DELIVERY_DAYS := 4
const REP_PER_DELIVERY := 6
const REP_PER_BOUNTY := 15
## At 100 reputation the shop margin drops from 10% to this.
const BEST_SHOP_MARGIN := 0.04
const BOUNTIES := {
	&"monster_infestation": {"settlement": "village", "reward": 60,
			"text": "Clear the monsters out of the mine"},
	&"bandit_activity": {"settlement": "town", "reward": 80,
			"text": "Break up the bandit camp by the road"},
}

## Each job: {"id", "kind" ("deliver"/"bounty"), "settlement", "commodity",
## "amount", "reward", "days_left", "event", "text"}. Strings only, so it saves as JSON.
var jobs: Array = []
## settlement id (String) -> 0..100
var reputation: Dictionary = {}
var next_id: int = 1


func jobs_for(settlement_id: StringName) -> Array:
	return jobs.filter(func(job): return job.settlement == String(settlement_id))


func daily_tick(economy: EconomySystem, events: EventSystem) -> void:
	for job in jobs.duplicate():
		if job.kind == "deliver":
			job.days_left = int(job.days_left) - 1
			if job.days_left <= 0:
				jobs.erase(job)
		elif job.kind == "bounty" and not events.is_active(StringName(job.event)):
			jobs.erase(job)
	refresh(economy, events)


## Post new jobs / remove bounties that no longer apply (no time passes).
func refresh(economy: EconomySystem, events: EventSystem) -> void:
	_update_bounties(events)
	_post_deliveries(economy)


func _update_bounties(events: EventSystem) -> void:
	for event_id in BOUNTIES:
		var existing := _bounty(event_id)
		if events.is_active(event_id) and existing.is_empty():
			var b: Dictionary = BOUNTIES[event_id]
			jobs.append({"id": _take_id(), "kind": "bounty", "settlement": b.settlement,
					"commodity": "", "amount": 0, "reward": b.reward, "days_left": 0,
					"event": String(event_id), "text": b.text})


func _post_deliveries(economy: EconomySystem) -> void:
	for s: Settlement in economy.settlements.values():
		var sid := String(s.data.id)
		var posted := jobs.filter(func(job): return job.kind == "deliver" and job.settlement == sid)
		for id in s.markets:
			if posted.size() >= MAX_DELIVERIES_PER_SETTLEMENT:
				break
			var m: Market = s.markets[id]
			if m.stock_status() != "Shortage" and m.stock_status() != "Low":
				continue
			if posted.any(func(job): return job.commodity == String(id)):
				continue
			var amount := clampi(roundi(m.desired_stock() * 0.15), 4, 12)
			var job := {"id": _take_id(), "kind": "deliver", "settlement": sid,
					"commodity": String(id), "amount": amount,
					"reward": ceili(amount * m.price * REWARD_MARKUP),
					"days_left": DELIVERY_DAYS, "event": "",
					"text": "Bring %d %s to %s" % [amount, m.commodity.display_name.to_lower(), s.data.display_name]}
			jobs.append(job)
			posted.append(job)


## Hand in a delivery. Returns "" on success, otherwise what is missing.
func deliver(job: Dictionary, economy: EconomySystem, player: PlayerState) -> String:
	var commodity := StringName(job.commodity)
	var have := player.inventory.count_of(commodity)
	if have < int(job.amount):
		return "You need %d, you have %d." % [job.amount, have]
	player.inventory.remove(commodity, int(job.amount))
	economy.player_sold(StringName(job.settlement), commodity, int(job.amount))
	player.money += int(job.reward)
	jobs.erase(job)
	change_reputation(StringName(job.settlement), REP_PER_DELIVERY, economy)
	return ""


## A big event ended. If the player ended it, pay its bounty (returns the reward).
func close_bounty(event_id: StringName, by_player: bool, economy: EconomySystem, player: PlayerState) -> int:
	var job := _bounty(event_id)
	if job.is_empty():
		return 0
	jobs.erase(job)
	if not by_player:
		return 0
	player.money += int(job.reward)
	change_reputation(StringName(job.settlement), REP_PER_BOUNTY, economy)
	return int(job.reward)


func reputation_of(settlement_id: StringName) -> int:
	return int(reputation.get(String(settlement_id), 0))


static func title_for(points: int) -> String:
	if points >= 80:
		return "Hero"
	if points >= 50:
		return "Friend"
	if points >= 20:
		return "Known"
	return "Stranger"


func change_reputation(settlement_id: StringName, amount: int, economy: EconomySystem) -> void:
	reputation[String(settlement_id)] = clampi(reputation_of(settlement_id) + amount, 0, 100)
	apply_margins(economy)


## Better reputation -> smaller shop margin at that settlement's market.
func apply_margins(economy: EconomySystem) -> void:
	for id in economy.settlements:
		var t := reputation_of(id) / 100.0
		economy.shop_margins[id] = lerpf(EconomySystem.SHOP_MARGIN, BEST_SHOP_MARGIN, t)


func _bounty(event_id: StringName) -> Dictionary:
	for job in jobs:
		if job.kind == "bounty" and job.event == String(event_id):
			return job
	return {}


func _take_id() -> int:
	next_id += 1
	return next_id - 1


func to_dict() -> Dictionary:
	return {"jobs": jobs, "reputation": reputation, "next_id": next_id}


func from_dict(data: Dictionary, economy: EconomySystem) -> void:
	jobs = data.get("jobs", [])
	reputation = data.get("reputation", {})
	next_id = int(data.get("next_id", 1))
	apply_margins(economy)
