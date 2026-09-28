extends Node
## Simulation tests (Implementation Plan 10.3 / 10.4): economy, events, save.
## In the editor: open tests/test_simulation.tscn and press F6; results show in Output.
## From a terminal, without a window:
##   godot --headless --path . tests/test_simulation.tscn
## Prints PASS/FAIL per check; exit code = number of failures.

var failures := 0


func _ready() -> void:
	test_quiet_world_is_stable()
	test_mine_infestation_chain()
	test_bandit_chain()
	test_player_trades_move_prices()
	test_events_start_and_end()
	test_small_events()
	test_rumors_come_first()
	test_ten_thousand_days()
	test_save_round_trip()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(failures)


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func new_economy() -> EconomySystem:
	var economy := EconomySystem.new(Game.commodities, Game.settlement_data, Game.business_data)
	economy.rng.seed = 12345
	return economy


## True when every stock and price is a sane number inside its clamps.
func is_valid(economy: EconomySystem) -> bool:
	for s: Settlement in economy.settlements.values():
		for m: Market in s.markets.values():
			var c := m.commodity
			if not (is_finite(m.price) and is_finite(m.stock)) or m.stock < 0.0:
				return false
			if m.price < c.base_price * c.min_multiplier - 0.001 or m.price > c.base_price * c.max_multiplier + 0.001:
				return false
	return true


func run(economy: EconomySystem, world: WorldState, days: int) -> bool:
	for i in days:
		economy.daily_tick(world)
		if not is_valid(economy):
			return false
	return true


func price(economy: EconomySystem, settlement: StringName, commodity: StringName) -> float:
	return economy.market(settlement, commodity).price


func test_quiet_world_is_stable() -> void:
	var economy := new_economy()
	var world := WorldState.new()
	check(run(economy, world, 1000), "1000 quiet days: no NaN, negative stock or runaway price")
	var before := {}
	for s in Game.SETTLEMENT_IDS:
		for c in Game.COMMODITY_IDS:
			before[[s, c]] = price(economy, s, c)
	# With everyday ups and downs prices keep moving, but stay around a balance.
	var low := {}
	var high := {}
	var biggest_daily := 0.0
	for day in 100:
		economy.daily_tick(world)
		for s in Game.SETTLEMENT_IDS:
			for c in Game.COMMODITY_IDS:
				var m := economy.market(s, c)
				low[[s, c]] = minf(low.get([s, c], INF), m.price)
				high[[s, c]] = maxf(high.get([s, c], 0.0), m.price)
				biggest_daily = maxf(biggest_daily, absf(m.price / m.price_days_ago(1) - 1.0))
	var widest := 0.0
	var summary: Array[String] = []
	for key in low:
		widest = maxf(widest, high[key] / low[key])
		summary.append("%s %s %.1f-%.1f" % [key[0], key[1], low[key], high[key]])
	check(biggest_daily > 0.01, "prices move a little every day (biggest daily move %.1f%%)" % (biggest_daily * 100))
	check(widest < 1.6, "but stay near their balance without events (widest range x%.2f)" % widest)
	print("      100 quiet days: ", ", ".join(summary))
	var gap := price(economy, &"town", &"iron") - price(economy, &"village", &"iron")
	check(gap > 2.0, "iron is cheaper in the village than in town (gap %.2f)" % gap)


func test_mine_infestation_chain() -> void:
	var economy := new_economy()
	var world := WorldState.new()
	run(economy, world, 200)
	var calm := price(economy, &"town", &"iron")
	world.set_mine_infested(true, 6)
	run(economy, world, 12)
	var infested := price(economy, &"town", &"iron")
	check(infested > calm * 1.4, "12 days infested: town iron %.2f -> %.2f" % [calm, infested])
	var reasons := economy.explain(&"village", &"iron")
	check(reasons.size() > 0 and reasons[0].contains("monsters in the mine"),
			"village board explains why: \"%s\"" % reasons[0])
	world.set_mine_infested(false)
	run(economy, world, 1)
	check(price(economy, &"town", &"iron") > calm * 1.4, "day after clearing: price still high (no instant reset)")
	run(economy, world, 59)
	var recovered := price(economy, &"town", &"iron")
	check(absf(recovered - calm) < calm * 0.2, "60 days after clearing: %.2f, back near %.2f" % [recovered, calm])


func test_bandit_chain() -> void:
	var economy := new_economy()
	var world := WorldState.new()
	run(economy, world, 200)
	var food := price(economy, &"village", &"food")
	var iron := price(economy, &"town", &"iron")
	world.set_bandits_active(true, 4)
	run(economy, world, 15)
	var food_after := price(economy, &"village", &"food")
	var iron_after := price(economy, &"town", &"iron")
	var mine_rate := economy.business_efficiency(Game.business_data[3], world)
	check(food_after > food * 1.15, "bandits: village food %.2f -> %.2f (fewer caravans)" % [food, food_after])
	check(mine_rate < 0.95, "bandits: hungry miners work at %d%%" % roundi(mine_rate * 100))
	check(iron_after > iron * 1.1, "bandits: town iron %.2f -> %.2f without touching the mine" % [iron, iron_after])
	var reasons := economy.explain(&"village", &"food")
	check(" ".join(reasons).contains("Bandits"), "village food board mentions bandits")


func test_player_trades_move_prices() -> void:
	var economy := new_economy()
	var world := WorldState.new()
	run(economy, world, 200)
	var before := price(economy, &"town", &"iron")
	economy.player_bought(&"town", &"iron", 10)
	var right_after := price(economy, &"town", &"iron")
	check(right_after > before * 1.03, "buying 10 iron nudges the price up at once (%.2f -> %.2f)" % [before, right_after])
	economy.player_sold(&"town", &"iron", 10)
	before = price(economy, &"town", &"iron")
	economy.player_sold(&"town", &"iron", 60)
	check(price(economy, &"town", &"iron") < before, "selling pushes it down at once")
	run(economy, world, 3)
	var after := price(economy, &"town", &"iron")
	check(after < before * 0.9, "player sells 60 iron in town: %.2f -> %.2f" % [before, after])
	check(economy.buy_price(&"town", &"iron") > economy.sell_price(&"town", &"iron"),
			"shop buys cheaper than it sells")


func test_events_start_and_end() -> void:
	var world := WorldState.new()
	var events := EventSystem.new(Game.event_data, 7)
	var started_on := -1
	for day in range(1, 40):
		events.daily_tick(world, day)
		if world.mine_infested and started_on < 0:
			started_on = day
	check(started_on >= 3, "an infestation starts on its own (day %d)" % started_on)
	world.set_mine_infested(false)
	events = EventSystem.new(Game.event_data, 7)
	world = WorldState.new()
	events.start_event(&"monster_infestation", world)
	check(world.mine_infested and world.mine_monsters_left == 6, "starting it puts 6 monsters in the mine")
	var cleared := false
	for i in 6:
		cleared = world.register_kill(&"mine")
	if cleared:
		events.end_event(&"monster_infestation", world, true)
	check(cleared and not world.mine_infested and not events.is_active(&"monster_infestation"),
			"killing all 6 clears the mine")


func test_small_events() -> void:
	var world := WorldState.new()
	var events := EventSystem.new([], 5, Game.minor_event_data)
	var started := 0
	var seen := {}
	for day in range(1, 201):
		var before := world.modifiers.keys()
		events.daily_tick(world, day)
		for id in world.modifiers:
			if not before.has(id):
				started += 1
				seen[id] = true
		if world.modifiers.size() > EventSystem.MAX_MINOR:
			started = -999
	check(started >= 40, "small events happen often (%d in 200 days, %d kinds)" % [started, seen.size()])

	var economy := new_economy()
	world = WorldState.new()
	run(economy, world, 100)
	var used_before := economy.market(&"town", &"food").last_used
	var events2 := EventSystem.new([], 1, Game.minor_event_data)
	events2.start_minor(&"harvest_festival", world)
	economy.daily_tick(world)
	var used_after := economy.market(&"town", &"food").last_used
	check(used_after > used_before * 1.2, "a harvest festival makes the Town eat more food (%.1f -> %.1f)" % [used_before, used_after])
	check(" ".join(economy.explain(&"town", &"food")).contains("Harvest festival"), "the board names the festival")
	events2.start_minor(&"rich_vein", world)
	economy.daily_tick(world)
	var made: float = economy.settlements[&"village"].last_ledger[&"iron"].produced
	check(made > 25.0, "a rich vein makes the mine dig more (%.1f iron)" % made)
	check(" ".join(economy.explain(&"village", &"iron")).contains("Rich vein"), "the board names the rich vein")


func test_rumors_come_first() -> void:
	var world := WorldState.new()
	var events := EventSystem.new(Game.event_data, 7)
	var rumor_day := -1
	var start_day := -1
	for day in range(1, 60):
		events.daily_tick(world, day)
		if rumor_day < 0 and not events.rumors().is_empty():
			rumor_day = day
		if start_day < 0 and (world.mine_infested or world.bandits_active):
			start_day = day
	check(rumor_day > 0 and start_day == rumor_day + EventSystem.WARNING_DAYS,
			"rumours spread %d days before an event (rumour day %d, event day %d)" % [EventSystem.WARNING_DAYS, rumor_day, start_day])


func test_ten_thousand_days() -> void:
	var economy := new_economy()
	var world := WorldState.new()
	var events := EventSystem.new(Game.event_data, 99, Game.minor_event_data)
	var ok := true
	var infestations := 0
	var raids := 0
	for day in range(1, 10001):
		var was_infested := world.mine_infested
		var was_raided := world.bandits_active
		events.daily_tick(world, day)
		infestations += int(world.mine_infested and not was_infested)
		raids += int(world.bandits_active and not was_raided)
		economy.daily_tick(world)
		if not is_valid(economy):
			ok = false
			break
	check(ok, "10000 days with events: always valid (%d infestations, %d bandit raids)" % [infestations, raids])


func test_save_round_trip() -> void:
	Game.new_game(1234)
	Game.player.money = 77
	Game.player.inventory.add(&"iron", 5)
	Game.player.position = Vector2(100, 200)
	Game.events.start_event(&"bandit_activity", Game.world)
	for day in range(1, 6):
		Game._on_day_advanced(day)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))
	var town_iron := price(Game.economy, &"town", &"iron")
	var roll := Game.events.rng.randf()
	Game.new_game(1)
	Game.from_dict(saved)
	check(Game.player.money == 77 and Game.player.inventory.count_of(&"iron") == 5,
			"save/load keeps money and inventory")
	check(Game.player.position == Vector2(100, 200), "save/load keeps position")
	check(Game.world.bandits_active and Game.events.is_active(&"bandit_activity"), "save/load keeps active events")
	check(is_equal_approx(price(Game.economy, &"town", &"iron"), town_iron), "save/load keeps prices")
	check(is_equal_approx(Game.events.rng.randf(), roll), "save/load keeps the random sequence")
	Game.new_game()
