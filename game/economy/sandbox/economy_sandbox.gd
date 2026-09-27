extends Control
## Economy sandbox: watch the real game economy (Game.economy) react to world
## events without playing. Open this scene and press F6.
##
## Time comes from GameClock like everywhere else: the buttons only skip time.
## Game runs events + economy on every EventBus.day_advanced; this screen just
## redraws when EventBus.economy_updated arrives.

const TOWN_COLOR := Color(0.4, 0.75, 1.0)
const VILLAGE_COLOR := Color(0.95, 0.75, 0.3)

var commodity_id: StringName = &"iron"

@onready var status_label: Label = %StatusLabel
@onready var village_label: Label = %VillageLabel
@onready var town_label: Label = %TownLabel
@onready var price_chart: PriceChart = %PriceChart
@onready var log_label: Label = %LogLabel
@onready var commodity_picker: OptionButton = %CommodityPicker
@onready var mine_button: Button = %MineButton
@onready var bandit_button: Button = %BanditButton


func _ready() -> void:
	EventBus.economy_updated.connect(func(_day: int): _refresh())
	EventBus.mine_state_changed.connect(func(_infested: bool): _refresh())
	EventBus.bandit_state_changed.connect(func(_active: bool): _refresh())
	for id in Game.COMMODITY_IDS:
		commodity_picker.add_item(String(id).capitalize())
	commodity_picker.select(Game.COMMODITY_IDS.find(commodity_id))
	commodity_picker.item_selected.connect(_on_commodity_selected)
	%NextDayButton.pressed.connect(GameClock.advance_to_next_morning)
	%NextWeekButton.pressed.connect(GameClock.advance_time.bind(GameClock.HOURS_PER_DAY * 7))
	%NextMonthButton.pressed.connect(GameClock.advance_time.bind(GameClock.HOURS_PER_DAY * 30))
	mine_button.pressed.connect(_toggle_event.bind(&"monster_infestation"))
	bandit_button.pressed.connect(_toggle_event.bind(&"bandit_activity"))
	%ResetButton.pressed.connect(func():
		Game.new_game()
		_refresh())
	_refresh()


func _on_commodity_selected(index: int) -> void:
	commodity_id = Game.COMMODITY_IDS[index]
	_refresh()


## Stands in for "the event happens" and "the player deals with it".
func _toggle_event(event_id: StringName) -> void:
	if Game.events.is_active(event_id):
		Game.events.end_event(event_id, Game.world, true)
	else:
		Game.events.start_event(event_id, Game.world)


func _refresh() -> void:
	var world := Game.world
	status_label.text = "Day %d   Mine: %s   Road: %s" % [GameClock.day,
			"INFESTED" if world.mine_infested else "safe",
			"BANDITS" if world.bandits_active else "safe"]
	mine_button.text = "Clear mine" if world.mine_infested else "Infest mine"
	bandit_button.text = "Chase bandits" if world.bandits_active else "Bandits"
	var town := Game.economy.market(&"town", commodity_id)
	var village := Game.economy.market(&"village", commodity_id)
	town_label.text = _market_text("TOWN", town)
	village_label.text = _market_text("MINING VILLAGE", village)
	var c := town.commodity
	price_chart.show_data([
		{"label": "Village", "color": VILLAGE_COLOR, "values": village.price_history},
		{"label": "Town", "color": TOWN_COLOR, "values": town.price_history},
	], [], c.base_price * c.max_multiplier, c.base_price)
	log_label.text = "Why? Town: %s\nWhy? Village: %s" % [
		" | ".join(Game.economy.explain(&"town", commodity_id).slice(0, 3)),
		" | ".join(Game.economy.explain(&"village", commodity_id).slice(0, 3))]


func _market_text(title: String, market: Market) -> String:
	var change := market.price - market.price_days_ago(1)
	return "%s\nPrice  %.2f g (%+.2f)\nStock  %.0f (wants %.0f)\nUse    %.1f / day" % [
		title, market.price, change, market.stock, market.desired_stock(), market.last_used]
