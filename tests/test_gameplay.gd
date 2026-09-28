extends Node
## Plays the real game scene like a (very fast) player would: fights, loots,
## gathers, trades, upgrades, clears the mine, gets knocked out, saves.
## Open tests/test_gameplay.tscn and press F6, or run:
##   godot --headless --path . tests/test_gameplay.tscn

const MAIN_SCENE := preload("res://game/main.tscn")

var failures := 0
var main: Node
var player: Player
var news: Array[String] = []
var kills: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_path = "user://test_save.json"
	EventBus.news.connect(func(text: String, _kind: String): news.append(text))
	EventBus.enemy_killed.connect(func(id: StringName, _group: StringName): kills.append(id))
	await run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	print("RESULT: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(failures)


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func run() -> void:
	Game.new_game(42)
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await frames(5)
	player = get_tree().get_first_node_in_group("player") as Player
	check(player != null, "main scene has a player")
	Game.player.max_hp = 200
	Game.player.hp = 200
	var forest := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.group == &"forest")
	check(forest.size() >= 10, "forest spawners filled (%d enemies)" % forest.size())

	test_world_art()
	await test_movement_feel()
	await test_combo_and_special_moves()
	await test_fight_and_loot(forest)
	await test_gathering()
	await test_talking()
	await test_selling()
	await test_blacksmith()
	await test_clear_the_mine()
	await test_knock_out()
	await test_save_and_load()


## Stand next to an enemy and swing until it dies.
func kill(enemy) -> bool:
	for swing in 60:
		if not is_instance_valid(enemy) or enemy.is_dying():
			return true
		var side := Vector2(-18, 0) if swing % 2 == 0 else Vector2(18, 0)
		player.global_position = enemy.global_position + side
		player.facing = Vector2.RIGHT if side.x < 0 else Vector2.LEFT
		var press := InputEventAction.new()
		press.action = &"attack"
		press.pressed = true
		Input.parse_input_event(press)
		await frames(22)
	return not is_instance_valid(enemy) or enemy.is_dying()


## Wait until the sword is ready again (hit-stop slows the game for a moment).
func ready_to_attack() -> void:
	for i in 120:
		if player._attack_ready_in <= 0.05:
			return
		await frames(1)


func press_attack() -> void:
	var press := InputEventAction.new()
	press.action = &"attack"
	press.pressed = true
	Input.parse_input_event(press)


func spawn_enemy(id: StringName, at: Vector2, tweak: Callable = Callable()) -> Enemy:
	var data: EnemyData = Game.enemies[id].duplicate()
	if tweak.is_valid():
		tweak.call(data)
	var enemy: Enemy = load("res://game/combat/enemy.tscn").instantiate()
	enemy.setup(data, &"test", at)
	enemy.position = at
	main.get_node("World/Entities").add_child(enemy)
	return enemy


func test_world_art() -> void:
	var world := main.get_node("World")
	var edges: TileMapLayer = world.get_node("GrassEdges")
	var decor: TileMapLayer = world.get_node("Decor")
	var lamps := get_tree().get_nodes_in_group("lamps")
	check(edges.get_used_cells().size() > 100, "grass edges soften %d borders" % edges.get_used_cells().size())
	check(decor.get_used_cells().size() > 200, "%d flowers, pebbles and tufts on the grass" % decor.get_used_cells().size())
	check(lamps.size() == 8, "8 street lamps on the plazas")


func test_movement_feel() -> void:
	player.global_position = Vector2(19 * 32, 30 * 32)
	await frames(10)
	Input.action_press("move_right")
	await frames(2)
	var early := player.velocity.x
	await frames(20)
	var later := player.velocity.x
	Input.action_release("move_right")
	await frames(3)
	var stopping := player.velocity.x
	await frames(20)
	check(early > 0.0 and early < player.speed * 0.6 and later > player.speed * 0.95,
			"movement speeds up smoothly (%.0f after 2 frames, %.0f later)" % [early, later])
	check(stopping > 0.0 and absf(player.velocity.x) < 1.0, "and slows down smoothly when you let go")
	var on_screen := get_viewport().get_canvas_transform() * player.global_position
	check(on_screen.distance_to(Vector2(320, 196)) < 48.0, "the camera keeps the player near the middle of the screen (%s)" % on_screen)


func test_combo_and_special_moves() -> void:
	player.global_position = Vector2(19 * 32, 30 * 32)
	player.facing = Vector2.RIGHT
	var steps: Array[int] = []
	for i in 3:
		press_attack()
		await frames(2)
		steps.append(player.combo_step)
		await frames(14)
	check(steps == [0, 1, 2], "three quick swings make a combo %s" % str(steps))
	check(player.attack_hitbox.unblockable == false or player.combo_step == 2, "the third swing is the finisher")
	await frames(40)

	# A bandit that always blocks: normal hits bounce off, the finisher gets through.
	var bandit := spawn_enemy(&"bandit", player.global_position + Vector2(20, 0),
			func(d: EnemyData): d.block_chance = 1.0; d.detect_range = 0.0)
	await frames(3)
	player.global_position = bandit.global_position - Vector2(18, 0)
	player.facing = Vector2.RIGHT
	press_attack()
	await frames(5)
	check(bandit.hp == bandit.data.max_hp, "a bandit can block a normal hit")
	var before := bandit.hp
	for swing in 2:
		await ready_to_attack()
		player.global_position = bandit.global_position - Vector2(18, 0)
		press_attack()
		await frames(3)
	check(player.combo_step == 2 and bandit.hp <= before - 2,
			"the combo finisher hits hard through a block (hp %d -> %d)" % [before, bandit.hp])
	bandit.queue_free()
	await frames(40)

	# A wolf lunges twice in one attack.
	var wolf := spawn_enemy(&"wolf", player.global_position + Vector2(30, 0))
	var lunges := 0
	var was_lunging := false
	for i in 120:
		await frames(1)
		var lunging := wolf.state == Enemy.State.LUNGE
		if lunging and not was_lunging:
			lunges += 1
		was_lunging = lunging
		if wolf.state == Enemy.State.RECOVER:
			break
	check(lunges == 2, "a wolf lunges twice per attack (%d)" % lunges)
	wolf.queue_free()

	# A slime splits into two small slimes.
	var slime := spawn_enemy(&"slime", player.global_position + Vector2(40, 0))
	await frames(3)
	await kill(slime)
	await frames(4)
	var small := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.data.id == &"mini_slime")
	check(small.size() == 2, "a slime splits into 2 small slimes (%d)" % small.size())
	for s in small:
		await kill(s)
	await frames(30)


func test_fight_and_loot(forest: Array) -> void:
	var slime: Enemy = forest.filter(func(e): return e.data.id == &"slime")[0]
	var gold_before := Game.player.money
	var killed := await kill(slime)
	check(killed and kills.has(&"slime"), "a slime can be killed with the sword")
	await frames(20)
	var drops := main.find_children("*", "ItemPickup", true, false)
	for drop in drops:
		player.global_position = drop.global_position
		await frames(6)
	var gel := Game.player.inventory.count_of(&"slime_gel")
	check(drops.is_empty() or gel > 0 or Game.player.money > gold_before,
			"loot is picked up by walking over it (%d drops, gel %d, gold %d -> %d)" % [drops.size(), gel, gold_before, Game.player.money])
	var wolf_list := forest.filter(func(e): return is_instance_valid(e) and e.data.id == &"wolf")
	if not wolf_list.is_empty():
		check(await kill(wolf_list[0]), "a wolf can be killed too")


func test_gathering() -> void:
	var herb: GatherNode = main.find_child("Herb1", true, false)
	var before := Game.player.inventory.count_of(&"herbs")
	herb.get_node("Interactable").interact(player)
	check(Game.player.inventory.count_of(&"herbs") == before + 2, "picking a herb bush gives 2 herbs")
	herb.get_node("Interactable").interact(player)
	check(Game.player.inventory.count_of(&"herbs") == before + 2, "an empty bush gives nothing until it regrows")
	var ore: GatherNode = main.find_child("Ore1", true, false)
	check(ore.is_ready(), "ore can be dug while the mine is safe")


func test_talking() -> void:
	var farmer := main.find_child("Farmer", true, false)
	farmer.get_node("Interactable").interact(player)
	await frames(2)
	var panel := main.get_node("UI/Center/DialoguePanel")
	check(panel.visible and panel._name.text == "Hob", "talking to the farmer opens a conversation with Hob")
	check(panel._text.text.length() > 10, "he says something: %s" % panel._text.text)
	panel.close()
	await frames(2)
	main.find_child("TownJobBoard", true, false).get_node("Interactable").interact(player)
	await frames(2)
	var board := main.get_node("UI/Center/JobsPanel")
	check(board.visible, "the job board opens")
	board.close()
	await frames(2)
	var hours := (22 - GameClock.hour + 24) % 24
	GameClock.advance_time(hours)
	await frames(2)
	check(not farmer.visible, "people go home at night")
	GameClock.advance_to_next_morning()
	await frames(2)
	check(farmer.visible, "and come back in the morning")


func test_selling() -> void:
	EventBus.open_panel.emit(&"shop", {"settlement": &"town"})
	await frames(2)
	check(get_tree().paused, "opening the shop pauses the game")
	var shop := main.get_node("UI/Center/ShopPanel")
	var stock := Game.economy.market(&"town", &"herbs").stock
	var money := Game.player.money
	shop._sell(&"town", &"herbs")
	check(Game.player.money > money, "selling herbs pays gold (%d -> %d)" % [money, Game.player.money])
	check(Game.economy.market(&"town", &"herbs").stock == stock + 1, "the herbs go into the Town's stock")
	var potions := Game.player.inventory.count_of(&"health_potion")
	Game.player.money += 50
	shop._buy_potion()
	check(Game.player.inventory.count_of(&"health_potion") == potions + 1, "a potion can be bought")
	shop.close()
	await frames(2)
	check(not get_tree().paused, "closing the shop unpauses")


func test_blacksmith() -> void:
	Game.player.money += 1000
	Game.economy.market(&"town", &"iron").stock = maxf(Game.economy.market(&"town", &"iron").stock, 20.0)
	var iron := Game.economy.market(&"town", &"iron").stock
	EventBus.open_panel.emit(&"blacksmith", {})
	await frames(2)
	var smith := main.get_node("UI/Center/BlacksmithPanel")
	var cost: int = smith.upgrade_cost()
	var money := Game.player.money
	smith._upgrade()
	check(Game.player.weapon_level == 2 and Game.player.money == money - cost,
			"the blacksmith upgrades the sword for %d gold" % cost)
	check(is_equal_approx(Game.economy.market(&"town", &"iron").stock, iron - 4), "the upgrade uses 4 iron from the Town market")
	smith.close()
	await frames(2)


func test_clear_the_mine() -> void:
	Game.events.start_event(&"monster_infestation", Game.world)
	await frames(3)
	var monsters := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.group == &"mine" and not e.is_dying())
	check(monsters.size() == 6, "an infestation puts 6 monsters in the mine (%d)" % monsters.size())
	var ore: GatherNode = main.find_child("Ore1", true, false)
	check(not ore.is_ready(), "ore can't be dug while monsters are there")
	for monster in monsters:
		await kill(monster)
	await frames(3)
	check(not Game.world.mine_infested and not Game.events.is_active(&"monster_infestation"),
			"killing all 6 clears the mine")
	check(news.any(func(t: String): return t.begins_with("You cleared the mine")), "the player gets told they cleared it")
	check(ore.is_ready(), "ore can be dug again")


func test_knock_out() -> void:
	Game.player.max_hp = 10
	Game.player.hp = 1
	var money := Game.player.money
	var day := GameClock.day
	var hit := Hitbox.new()
	hit.damage = 5
	main.get_node("World/Entities").add_child(hit)
	hit.global_position = player.global_position + Vector2(10, 0)
	player._on_hurt(hit)
	hit.queue_free()
	await frames(80)
	check(Game.player.hp == 10 and not player.is_dead(), "after a knock-out the player wakes up healed")
	check(Game.player.money == money - int(money * 0.2), "a knock-out costs 20%% of gold (%d -> %d)" % [money, Game.player.money])
	check(GameClock.day > day or GameClock.hour == GameClock.START_HOUR, "and it is the next morning")
	var respawn := get_tree().get_first_node_in_group("respawn_point") as Node2D
	check(player.global_position.distance_to(respawn.global_position) < 4.0, "at the inn")


func test_save_and_load() -> void:
	check(SaveManager.save_game(), "the game can be saved")
	var money := Game.player.money
	var position := Game.player.position
	Game.player.money = 1
	check(SaveManager.load_game() == "", "the game can be loaded")
	check(Game.player.money == money and Game.player.position.distance_to(position) < 1.0,
			"loading restores gold and position")
