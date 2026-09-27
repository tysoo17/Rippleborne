extends GamePanel
## The blacksmith upgrades the player's sword. The materials are bought from
## the Town market at today's price and taken out of its stock, so iron
## prices (and the mine!) decide how expensive getting stronger is.

## Level -> materials and work needed to reach it.
const UPGRADES := {
	2: {"iron": 4, "wood": 3, "work": 15},
	3: {"iron": 8, "wood": 4, "work": 30},
}

var _info: Label
var _upgrade_button: Button


func build() -> void:
	custom_minimum_size = Vector2(320, 0)
	set_title("Blacksmith")
	_info = label("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 300
	body.add_child(_info)
	_upgrade_button = button("Upgrade", _upgrade)
	body.add_child(_upgrade_button)


## Total gold for the next level, or -1 if already at the top.
func upgrade_cost() -> int:
	var next := Game.player.weapon_level + 1
	if not UPGRADES.has(next):
		return -1
	var u: Dictionary = UPGRADES[next]
	return u.iron * Game.economy.buy_price(&"town", &"iron") \
			+ u.wood * Game.economy.buy_price(&"town", &"wood") + u.work


func refresh() -> void:
	var level := Game.player.weapon_level
	var next := level + 1
	if not UPGRADES.has(next):
		_info.text = "Your sword is level %d (%d damage). I can't make it any better." % [level, level]
		_upgrade_button.visible = false
		return
	var u: Dictionary = UPGRADES[next]
	var iron_price := Game.economy.buy_price(&"town", &"iron")
	var wood_price := Game.economy.buy_price(&"town", &"wood")
	var cost := upgrade_cost()
	var lines: Array[String] = [
		"Your sword: level %d, %d damage per hit." % [level, level],
		"Level %d would hit for %d." % [next, next],
		"",
		"I buy the materials at the Town market today:",
		"  %d iron x %d g = %d g" % [u.iron, iron_price, u.iron * iron_price],
		"  %d wood x %d g = %d g" % [u.wood, wood_price, u.wood * wood_price],
		"  My work: %d g" % u.work,
		"Total: %d gold" % cost,
		"",
		"When iron is cheap, upgrades are cheap.",
	]
	var iron_stock := Game.economy.market(&"town", &"iron").stock
	var wood_stock := Game.economy.market(&"town", &"wood").stock
	_upgrade_button.visible = true
	_upgrade_button.text = "Upgrade for %d gold" % cost
	_upgrade_button.disabled = false
	if iron_stock < u.iron:
		lines.append("The market has only %d iron. I can't work without it!" % floori(iron_stock))
		_upgrade_button.disabled = true
	elif wood_stock < u.wood:
		lines.append("The market has only %d wood." % floori(wood_stock))
		_upgrade_button.disabled = true
	elif Game.player.money < cost:
		lines.append("You have %d gold." % Game.player.money)
		_upgrade_button.disabled = true
	_info.text = "\n".join(lines)


func _upgrade() -> void:
	var next := Game.player.weapon_level + 1
	var cost := upgrade_cost()
	if cost < 0 or Game.player.money < cost:
		return
	var u: Dictionary = UPGRADES[next]
	Game.player.money -= cost
	Game.economy.player_bought(&"town", &"iron", u.iron)
	Game.economy.player_bought(&"town", &"wood", u.wood)
	Game.player.weapon_level = next
	EventBus.weapon_upgraded.emit(next)
	EventBus.news.emit("Your sword is now level %d!" % next, "good")
	Sfx.play(&"upgrade")
	refresh()
