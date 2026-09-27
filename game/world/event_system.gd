class_name EventSystem
extends RefCounted
## Starts and ends world events once per day.
##
## An event only flips something in WorldState (mine infested, bandits on the
## road). Production, trade and prices notice that on their own.

## After any event starts, no other event may start for this many days.
const GLOBAL_GAP_DAYS := 4

var events: Dictionary = {}  # id -> EventData
var rng := RandomNumberGenerator.new()
## Active events: id -> days until the locals deal with it.
var days_left: Dictionary = {}
## Events resting after they ended: id -> days.
var cooldown_left: Dictionary = {}
## Days each event has been allowed but did not happen (raises its chance).
var days_waiting: Dictionary = {}
var days_since_any_start: int = 99


func _init(list: Array[EventData], seed_value: int) -> void:
	for e in list:
		events[e.id] = e
	rng.seed = seed_value


func is_active(id: StringName) -> bool:
	return days_left.has(id)


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
	for id in events:
		var e: EventData = events[id]
		if is_active(id) or cooldown_left.has(id) or today < e.earliest_day:
			continue
		if days_since_any_start < GLOBAL_GAP_DAYS:
			continue
		var waited: int = days_waiting.get(id, 0)
		if rng.randf() < e.base_chance + e.chance_growth_per_day * waited:
			start_event(id, world)
		else:
			days_waiting[id] = waited + 1


func start_event(id: StringName, world: WorldState) -> void:
	if is_active(id):
		return
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


func to_dict() -> Dictionary:
	return {
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"days_left": days_left, "cooldown_left": cooldown_left,
		"days_waiting": days_waiting, "days_since_any_start": days_since_any_start,
	}


func from_dict(data: Dictionary) -> void:
	rng.seed = int(str(data.get("rng_seed", "0")))
	rng.state = int(str(data.get("rng_state", "0")))
	days_left = _int_dict(data.get("days_left", {}))
	cooldown_left = _int_dict(data.get("cooldown_left", {}))
	days_waiting = _int_dict(data.get("days_waiting", {}))
	days_since_any_start = int(data.get("days_since_any_start", 99))


## JSON gives String keys and float values; turn them back into StringName -> int.
func _int_dict(saved: Dictionary) -> Dictionary:
	var result := {}
	for key in saved:
		result[StringName(key)] = int(saved[key])
	return result
