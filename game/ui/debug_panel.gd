extends GamePanel
## F12 developer panel (Implementation Plan 10.1): skip time, trigger events,
## teleport, and look at the raw world state.

## Teleport targets in tiles (32 px).
const PLACES := {
	"Town": Vector2i(19, 31), "Village": Vector2i(92, 31), "Mine": Vector2i(93, 11),
	"Forest": Vector2i(33, 52), "Bandit camp": Vector2i(56, 26),
}

var _state: Label


func build() -> void:
	custom_minimum_size = Vector2(420, 0)
	set_title("Debug")
	_state = label("")
	_state.add_theme_font_size_override("font_size", 10)
	body.add_child(_state)
	body.add_child(_buttons([
		["+1 hour", func(): GameClock.advance_time(1)],
		["+1 day", func(): GameClock.advance_time(24)],
		["+7 days", func(): GameClock.advance_time(24 * 7)],
		["+30 days", func(): GameClock.advance_time(24 * 30)],
	]))
	body.add_child(_buttons([
		["Infest mine", func(): Game.events.start_event(&"monster_infestation", Game.world)],
		["Clear mine", func(): Game.events.end_event(&"monster_infestation", Game.world, true)],
		["Bandits", func(): Game.events.start_event(&"bandit_activity", Game.world)],
		["Chase bandits", func(): Game.events.end_event(&"bandit_activity", Game.world, true)],
	]))
	body.add_child(_buttons([
		["+100 gold", func(): Game.player.money += 100],
		["Heal", func(): Game.player.hp = Game.player.max_hp],
		["+10 iron", func(): Game.player.inventory.add(&"iron", 10)],
		["Sword +1", func(): Game.player.weapon_level = mini(Game.player.weapon_level + 1, PlayerState.MAX_WEAPON_LEVEL)],
	]))
	var teleports := []
	for place in PLACES:
		teleports.append([place, _teleport.bind(PLACES[place])])
	body.add_child(_buttons(teleports))


func _buttons(specs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for spec in specs:
		row.add_child(button(spec[0], func():
			spec[1].call()
			refresh(), 96.0))
	return row


func refresh() -> void:
	var w := Game.world
	var e := Game.events
	var lines: Array[String] = [
		"Day %d, economy day %d, route risk %.2f" % [GameClock.day, Game.economy.day, w.route_risk()],
		"Mine infested: %s (%d monsters)   Bandits: %s (%d left)" % [w.mine_infested, w.mine_monsters_left, w.bandits_active, w.bandits_left],
		"Active events: %s   Cooldowns: %s" % [e.days_left, e.cooldown_left],
	]
	var prices: Array[String] = []
	for id in Game.COMMODITY_IDS:
		prices.append("%s T %.1f / V %.1f" % [id, Game.economy.market(&"town", id).price, Game.economy.market(&"village", id).price])
	lines.append(", ".join(prices))
	_state.text = "\n".join(lines)


func _teleport(tile: Vector2i) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.global_position = Vector2(tile * 32) + Vector2(16, 30)
		close()
