class_name EventSystem
extends RefCounted
## Starts and ends world events once per day.
##
## An event only changes WorldState (mine infested, bandits on the road, a
## festival raising food demand...). Production, trade and prices notice
## that on their own.
##
## Big events are announced by rumours WARNING_DAYS before they start: people
## who talk to the right NPC can prepare (or profit).

## After any big event starts, no other big event may start for this many days.
const GLOBAL_GAP_DAYS := 4
## Days between "people start whispering" and the big event actually starting.
const WARNING_DAYS := 2
## Chance per day that a new small event starts.
const MINOR_CHANCE := 0.45
## At most this many small events at the same time.
const MAX_MINOR := 2

var events: Dictionary = {}  # id -> EventData
var minor_events: Dictionary = {}  # id -> MinorEventData
var rng := RandomNumberGenerator.new()
## Active big events: id -> days until the locals deal with it.
var days_left: Dictionary = {}
## Big events about to start: id -> days until they start (rumours spread now).
var pending: Dictionary = {}
## Events resting after they ended: id -> days.
var cooldown_left: Dictionary = {}
## Days each event has been allowed but did not happen (raises its chance).
var days_waiting: Dictionary = {}
var days_since_any_start: int = 99


func _init(list: Array[EventData], seed_value: int, minor_list: Array[MinorEventData] = []) -> void:
	for e in list:
		events[e.id] = e
	for m in minor_list:
		minor_events[m.id] = m
	rng.seed = seed_value


func is_active(id: StringName) -> bool:
	return days_left.has(id)


func is_pending(id: StringName) -> bool:
	return pending.has(id)


func daily_tick(world: WorldState, today: int) -> void:
	days_since_any_start += 1
	for id in days_left.keys():
		days_left[id] -= 1
		if days_left[id] <= 0:
			end_event(id, world, false)
	for id in cooldown_left.keys():
		cooldown_left[id] -= 1
		if cooldown_left[id] <= 0:
			cooldown_left.erase(id)
	for id in pending.keys():
		pending[id] -= 1
		if pending[id] <= 0:
			pending.erase(id)
			start_event(id, world)
	for id in events:
		var e: EventData = events[id]
		if is_active(id) or is_pending(id) or cooldown_left.has(id) or today < e.earliest_day:
			continue
		if days_since_any_start < GLOBAL_GAP_DAYS or not pending.is_empty():
			continue
		var waited: int = days_waiting.get(id, 0)
		if rng.randf() < e.base_chance + e.chance_growth_per_day * waited:
			pending[id] = WARNING_DAYS
			days_waiting[id] = 0
			days_since_any_start = 0
		else:
			days_waiting[id] = waited + 1
	_tick_minor(world)


func start_event(id: StringName, world: WorldState) -> void:
	if is_active(id):
		return
	pending.erase(id)
	var e: EventData = events[id]
	days_left[id] = rng.randi_range(e.min_duration, e.max_duration)
	days_waiting[id] = 0
	days_since_any_start = 0
	_apply(id, world, true)
	EventBus.news.emit(e.start_news, "warning")


func end_event(id: StringName, world: WorldState, by_player: bool) -> void:
	if not is_active(id):
		return
	var e: EventData = events[id]
	days_left.erase(id)
	cooldown_left[id] = e.cooldown_days
	_apply(id, world, false)
	EventBus.news.emit(e.end_news_player if by_player else e.end_news_natural, "good")


func _apply(id: StringName, world: WorldState, active: bool) -> void:
	var count: int = events[id].enemy_count
	match id:
		&"monster_infestation":
			world.set_mine_infested(active, count)
		&"bandit_activity":
			world.set_bandits_active(active, count)


## What people are whispering about: big events that are about to happen.
func rumors() -> Array[String]:
	var result: Array[String] = []
	for id in pending:
		result.append(events[id].rumor)
	return result


# --- Small events ------------------------------------------------------------

func _tick_minor(world: WorldState) -> void:
	for id in world.modifiers.keys():
		world.modifiers[id].days_left = int(world.modifiers[id].days_left) - 1
		if world.modifiers[id].days_left <= 0:
			world.modifiers.erase(id)
	if minor_events.is_empty() or world.modifiers.size() >= MAX_MINOR or rng.randf() >= MINOR_CHANCE:
		return
	var choices: Array[MinorEventData] = []
	var total := 0.0
	for m: MinorEventData in minor_events.values():
		if not world.modifiers.has(String(m.id)):
			choices.append(m)
			total += m.weight
	var roll := rng.randf() * total
	for m in choices:
		roll -= m.weight
		if roll <= 0.0:
			start_minor(m.id, world)
			return


func start_minor(id: StringName, world: WorldState) -> void:
	var m: MinorEventData = minor_events[id]
	world.modifiers[String(id)] = {
		"business": String(m.business_id), "settlement": String(m.settlement_id),
		"commodity": String(m.commodity_id), "factor": m.factor, "reason": m.reason,
		"news": m.news, "days_left": rng.randi_range(m.min_days, m.max_days),
	}
	EventBus.news.emit(m.news, "info")


# --- Save ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"days_left": days_left, "pending": pending, "cooldown_left": cooldown_left,
		"days_waiting": days_waiting, "days_since_any_start": days_since_any_start,
	}


func from_dict(data: Dictionary) -> void:
	rng.seed = int(str(data.get("rng_seed", "0")))
	rng.state = int(str(data.get("rng_state", "0")))
	days_left = _int_dict(data.get("days_left", {}))
	pending = _int_dict(data.get("pending", {}))
	cooldown_left = _int_dict(data.get("cooldown_left", {}))
	days_waiting = _int_dict(data.get("days_waiting", {}))
	days_since_any_start = int(data.get("days_since_any_start", 99))


## JSON gives String keys and float values; turn them back into StringName -> int.
func _int_dict(saved: Dictionary) -> Dictionary:
	var result := {}
	for key in saved:
		result[StringName(key)] = int(saved[key])
	return result
