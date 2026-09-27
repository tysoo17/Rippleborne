extends Node
## Economy test (Implementation Plan 10.3 / 10.4).
## In the editor: open tests/test_economy.tscn and press F6, results show in Output.
## From a terminal, without a window:
##   godot --headless --path . tests/test_economy.tscn
## Prints PASS/FAIL per check; exit code = number of failures.

const IRON: Commodity = preload("res://data/commodities/iron.tres")
const CONFIG: EconomyConfig = preload("res://data/economy/sandbox_config.tres")

var failures := 0


func _ready() -> void:
	test_stable_without_events()
	test_mine_infestation_and_recovery()
	test_empty_markets()
	test_ten_thousand_random_days()
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(failures)


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func new_sim() -> EconomySimulation:
	return EconomySimulation.new(CONFIG, IRON, WorldState.new())


## True when every stock and price is a sane number inside the clamps.
func is_valid(sim: EconomySimulation) -> bool:
	var low := IRON.base_price * IRON.min_multiplier - 0.001
	var high := IRON.base_price * IRON.max_multiplier + 0.001
	for market in [sim.village, sim.town]:
		if not (is_finite(market.price) and is_finite(market.stock)):
			return false
		if market.stock < 0.0 or market.price < low or market.price > high:
			return false
	return true


func run_days(sim: EconomySimulation, days: int) -> bool:
	for i in days:
		sim.daily_tick()
		if not is_valid(sim):
			return false
	return true


func test_stable_without_events() -> void:
	var sim := new_sim()
	check(run_days(sim, 900), "900 days without events: no NaN, negative stock or runaway price")
	var lowest := INF
	var highest := -INF
	for i in 100:
		sim.daily_tick()
		lowest = minf(lowest, sim.town.price)
		highest = maxf(highest, sim.town.price)
	check(highest - lowest < 0.5, "last 100 days: town price settles (range %.3f)" % (highest - lowest))


func test_mine_infestation_and_recovery() -> void:
	var sim := new_sim()
	run_days(sim, 200)
	var calm_price := sim.town.price
	sim.world.set_mine_infested(true)
	run_days(sim, 10)
	var infested_price := sim.town.price
	check(infested_price > calm_price * 1.3,
			"10 days infested: town iron %.2f -> %.2f (rises)" % [calm_price, infested_price])

	sim.world.set_mine_infested(false)
	run_days(sim, 1)
	check(sim.town.price > calm_price * 1.3,
			"day after clearing: %.2f, no instant reset" % sim.town.price)
	run_days(sim, 59)
	check(absf(sim.town.price - calm_price) < calm_price * 0.1,
			"60 days after clearing: %.2f, back near %.2f" % [sim.town.price, calm_price])


func test_empty_markets() -> void:
	var sim := new_sim()
	sim.village.stock = 0.0
	sim.town.stock = 0.0
	sim.world.set_mine_infested(true)
	var ok := run_days(sim, 50)
	check(ok and sim.town.price <= IRON.base_price * IRON.max_multiplier,
			"no iron anywhere for 50 days: price %.2f stays at or below the cap" % sim.town.price)


func test_ten_thousand_random_days() -> void:
	var sim := new_sim()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok := true
	for i in 10000:
		if rng.randf() < 0.05:
			sim.world.set_mine_infested(not sim.world.mine_infested)
		sim.daily_tick()
		if not is_valid(sim):
			ok = false
			break
	check(ok, "10000 days with random infestations: always valid")
