extends Node
## The whole game's state (autoload "Game"): world, economy, events, player.
##
## Scenes read from here and ask it to change things. It runs the daily
## simulation when GameClock announces a new day, and SaveManager writes
## it to disk.

const COMMODITY_IDS: Array[StringName] = [&"food", &"wood", &"iron", &"herbs"]
const SETTLEMENT_IDS: Array[StringName] = [&"town", &"village"]
const BUSINESS_IDS: Array[StringName] = [&"farm", &"woodcutters", &"herbalists", &"mine", &"blacksmith"]
const EVENT_IDS: Array[StringName] = [&"monster_infestation", &"bandit_activity"]
const MINOR_EVENT_IDS: Array[StringName] = [&"harvest_festival", &"big_order", &"rich_vein",
		&"wolves_at_farm", &"herb_bloom", &"cold_snap", &"storm"]
const ITEM_IDS: Array[StringName] = [&"food", &"wood", &"iron", &"herbs", &"slime_gel",
		&"wolf_pelt", &"bandit_insignia", &"health_potion"]
const ENEMY_IDS: Array[StringName] = [&"slime", &"mini_slime", &"cave_slime", &"wolf", &"bandit"]
## Quiet days simulated before day 1 so markets start near their natural balance.
const WARM_UP_DAYS := 30
## The morning report mentions price moves at least this big (8%).
const MORNING_REPORT_MIN_CHANGE := 0.08

var items: Dictionary = {}    # id -> ItemData
var enemies: Dictionary = {}  # id -> EnemyData
var commodities: Array[Commodity] = []
var settlement_data: Array[SettlementData] = []
var business_data: Array[BusinessData] = []
var event_data: Array[EventData] = []
var minor_event_data: Array[MinorEventData] = []

var world: WorldState
var economy: EconomySystem
var events: EventSystem
var player: PlayerState
## Prices the player last saw at each settlement: id -> {"day": int, "prices": {id: float}}
var seen_prices: Dictionary = {}
## Location the player is in right now ("Town", "Forest"...).
var location: String = ""
## Show the "How to play" window when the next game scene starts.
var show_intro: bool = false


func _ready() -> void:
	_load_static_data()
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.location_changed.connect(func(location_name: String): location = location_name)
	# A valid state exists even when a single scene is run with F6.
	new_game()


func new_game(seed_value: int = 0) -> void:
	GameClock.reset()
	world = WorldState.new()
	var seed_to_use := seed_value if seed_value != 0 else randi()
	economy = EconomySystem.new(commodities, settlement_data, business_data)
	economy.rng.seed = seed_to_use + 1
	events = EventSystem.new(event_data, seed_to_use, minor_event_data)
	player = PlayerState.new(items)
	seen_prices = {}
	for i in WARM_UP_DAYS:
		economy.daily_tick(world)
	economy.day = 0


## One simulated day: events first (they change the world), then the economy.
func _on_day_advanced(day: int) -> void:
	events.daily_tick(world, day)
	economy.daily_tick(world)
	EventBus.economy_updated.emit(day)
	for line in morning_report():
		EventBus.news.emit(line, "info")


## The two biggest price moves since yesterday, with their main reason.
func morning_report() -> Array[String]:
	var moves: Array = []  # [abs change, text]
	for s in SETTLEMENT_IDS:
		for id in COMMODITY_IDS:
			var m := economy.market(s, id)
			var change := m.price / m.price_days_ago(1) - 1.0
			if absf(change) >= MORNING_REPORT_MIN_CHANGE:
				var why := economy.explain(s, id)[0]
				moves.append([absf(change), "Morning prices: %s in %s %+d%% (%s)" % [
					m.commodity.display_name, settlement_name(s), roundi(change * 100), why]])
	moves.sort_custom(func(a, b): return a[0] > b[0])
	var result: Array[String] = []
	for move in moves.slice(0, 2):
		result.append(move[1])
	return result


func _on_enemy_killed(_enemy_id: StringName, group: StringName) -> void:
	if not world.register_kill(group):
		return
	match group:
		&"mine":
			events.end_event(&"monster_infestation", world, true)
		&"bandit_camp":
			events.end_event(&"bandit_activity", world, true)


## Use an item from the bag (only potions for now). Returns a message for the player.
func use_item(id: StringName) -> String:
	var item: ItemData = items[id]
	if item.heal_amount <= 0:
		return "%s can't be used." % item.display_name
	if player.hp >= player.max_hp:
		return "You are already at full health."
	if not player.inventory.remove(id, 1):
		return "You have no %s." % item.display_name
	player.hp += item.heal_amount
	Sfx.play(&"pickup")
	return ""


## Remember what the player saw at a board or shop (information has a date).
func remember_prices(settlement_id: StringName) -> void:
	var prices := {}
	for id in COMMODITY_IDS:
		prices[String(id)] = economy.market(settlement_id, id).price
	seen_prices[String(settlement_id)] = {"day": GameClock.day, "prices": prices}


func settlement_name(settlement_id: StringName) -> String:
	return economy.settlements[settlement_id].data.display_name


func to_dict() -> Dictionary:
	return {
		"clock": GameClock.to_dict(), "world": world.to_dict(), "economy": economy.to_dict(),
		"events": events.to_dict(), "player": player.to_dict(), "seen_prices": seen_prices,
	}


func from_dict(data: Dictionary) -> void:
	new_game()
	GameClock.from_dict(data.get("clock", {}))
	world.from_dict(data.get("world", {}))
	economy.from_dict(data.get("economy", {}))
	events.from_dict(data.get("events", {}))
	player.from_dict(data.get("player", {}))
	seen_prices = data.get("seen_prices", {})


func _load_static_data() -> void:
	for id in ITEM_IDS:
		items[id] = load("res://data/items/%s.tres" % id)
	for id in ENEMY_IDS:
		enemies[id] = load("res://data/enemies/%s.tres" % id)
	for id in COMMODITY_IDS:
		commodities.append(load("res://data/commodities/%s.tres" % id))
	for id in SETTLEMENT_IDS:
		settlement_data.append(load("res://data/settlements/%s.tres" % id))
	for id in BUSINESS_IDS:
		business_data.append(load("res://data/businesses/%s.tres" % id))
	for id in EVENT_IDS:
		event_data.append(load("res://data/events/%s.tres" % id))
	for id in MINOR_EVENT_IDS:
		minor_event_data.append(load("res://data/events/minor/%s.tres" % id))
