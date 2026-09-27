class_name WorldState
extends RefCounted
## What is currently true about the world, independent of any scene.
##
## Events and the player change these values; the economy only reads them.
## This is how clearing the mine can affect iron prices without combat code
## ever touching a price.

const SAFE_ROUTE_RISK := 0.05
const BANDIT_ROUTE_RISK := 0.6

var mine_infested: bool = false
var mine_monsters_left: int = 0
var bandits_active: bool = false
var bandits_left: int = 0
## Gather spots that were used: node id -> day they are ready again.
var depleted_until: Dictionary = {}


## Look up a flag by name, so data files can say "stopped_by = mine_infested".
func get_flag(flag: StringName) -> bool:
	match flag:
		&"mine_infested":
			return mine_infested
		&"bandits_active":
			return bandits_active
	return false


## Short human text for a flag, used in price explanations.
static func flag_reason(flag: StringName) -> String:
	match flag:
		&"mine_infested":
			return "monsters in the mine"
		&"bandits_active":
			return "bandits on the road"
	return String(flag)


## 0 = perfectly safe road, 1 = nobody dares to travel.
func route_risk() -> float:
	return BANDIT_ROUTE_RISK if bandits_active else SAFE_ROUTE_RISK


func set_mine_infested(infested: bool, monsters: int = 0) -> void:
	mine_monsters_left = monsters if infested else 0
	if infested == mine_infested:
		return
	mine_infested = infested
	EventBus.mine_state_changed.emit(infested)


func set_bandits_active(active: bool, count: int = 0) -> void:
	bandits_left = count if active else 0
	if active == bandits_active:
		return
	bandits_active = active
	EventBus.bandit_state_changed.emit(active)


## Count down an event's enemies when one dies.
## Returns true when that was the last one (the player cleared the event).
func register_kill(group: StringName) -> bool:
	if group == &"mine" and mine_infested and mine_monsters_left > 0:
		mine_monsters_left -= 1
		return mine_monsters_left == 0
	if group == &"bandit_camp" and bandits_active and bandits_left > 0:
		bandits_left -= 1
		return bandits_left == 0
	return false


func is_ready(node_id: String, today: int) -> bool:
	return today >= int(depleted_until.get(node_id, 0))


func to_dict() -> Dictionary:
	return {
		"mine_infested": mine_infested, "mine_monsters_left": mine_monsters_left,
		"bandits_active": bandits_active, "bandits_left": bandits_left,
		"depleted_until": depleted_until,
	}


func from_dict(data: Dictionary) -> void:
	mine_infested = bool(data.get("mine_infested", false))
	mine_monsters_left = int(data.get("mine_monsters_left", 0))
	bandits_active = bool(data.get("bandits_active", false))
	bandits_left = int(data.get("bandits_left", 0))
	depleted_until = {}
	var saved: Dictionary = data.get("depleted_until", {})
	for key in saved:
		depleted_until[String(key)] = int(saved[key])
