extends Control
## Economy sandbox: check that "infest / clear the mine -> iron prices react"
## feels right, without playing through combat. Open this scene and press F6.
##
## Time comes from GameClock like everywhere else: the buttons only skip time,
## and the simulation runs once for every EventBus.day_advanced.

const IRON: Commodity = preload("res://data/commodities/iron.tres")
const CONFIG: EconomyConfig = preload("res://data/economy/sandbox_config.tres")
const VILLAGE_COLOR := Color(0.95, 0.75, 0.3)
const TOWN_COLOR := Color(0.4, 0.75, 1.0)

var world: WorldState
var sim: EconomySimulation

@onready var status_label: Label = %StatusLabel
@onready var village_label: Label = %VillageLabel
@onready var town_label: Label = %TownLabel
@onready var price_chart: Control = %PriceChart
@onready var log_label: Label = %LogLabel
@onready var mine_button: Button = %MineButton


func _ready() -> void:
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.mine_state_changed.connect(_on_mine_state_changed)
	%NextDayButton.pressed.connect(GameClock.advance_time.bind(GameClock.HOURS_PER_DAY))
	%NextWeekButton.pressed.connect(GameClock.advance_time.bind(GameClock.HOURS_PER_DAY * 7))
	%NextMonthButton.pressed.connect(GameClock.advance_time.bind(GameClock.HOURS_PER_DAY * 30))
	mine_button.pressed.connect(_on_mine_button_pressed)
	%ResetButton.pressed.connect(_reset)
	_reset()


func _reset() -> void:
	world = WorldState.new()
	sim = EconomySimulation.new(CONFIG, IRON, world)
	_refresh()


func _on_day_advanced(_day: int) -> void:
	sim.daily_tick()
	_refresh()


func _on_mine_button_pressed() -> void:
	# Stands in for "monsters arrive" and "the player clears the mine".
	world.set_mine_infested(not world.mine_infested)


func _on_mine_state_changed(_infested: bool) -> void:
	_refresh()


func _refresh() -> void:
	status_label.text = "Day %d    Mine: %s" % [sim.day, "INFESTED" if world.mine_infested else "safe"]
	mine_button.text = "Clear mine" if world.mine_infested else "Infest mine"
	village_label.text = _market_text(sim.village)
	town_label.text = _market_text(sim.town)
	price_chart.show_data([
		{"label": "Village", "color": VILLAGE_COLOR, "values": sim.village.price_history},
		{"label": "Town", "color": TOWN_COLOR, "values": sim.town.price_history},
	], sim.mine_history, IRON.base_price * IRON.max_multiplier, IRON.base_price)
	log_label.text = sim.explain()


func _market_text(market: Market) -> String:
	var change := market.price - market.yesterday_price()
	return "%s\nPrice  %.2f g (%+.2f)\nStock  %.0f (wants %.0f)\nUse    %.0f / day" % [
		market.settlement_name.to_upper(), market.price, change,
		market.stock, market.desired_stock(), market.daily_demand]
