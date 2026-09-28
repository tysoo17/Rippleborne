extends GamePanel
## Market stall: buy and sell at this settlement's current prices.
##
## Selling adds to the market's stock and buying takes from it, so the
## player's trades move tomorrow's price exactly like caravans do.

## Herbs the Town alchemist uses for one health potion.
const HERBS_PER_POTION := 1

var _money: Label
var _rows: VBoxContainer


func build() -> void:
	custom_minimum_size = Vector2(480, 0)
	_money = label("")
	body.add_child(_money)
	var header := HBoxContainer.new()
	for spec in [["", 16.0], ["Item", 92.0], ["Buy", 40.0], ["Sell", 40.0], ["Today", 40.0], ["Stock", 58.0], ["You have", 54.0]]:
		header.add_child(label(spec[0], spec[1], Color(0.65, 0.62, 0.58)))
	body.add_child(header)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	body.add_child(_rows)
	var note := label("Prices are set every midnight from stock and demand. What you sell adds to the stock and pushes the price down a little right away; what you buy does the opposite.", 0.0, Color(0.65, 0.62, 0.58))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 460
	note.add_theme_font_size_override("font_size", 10)
	body.add_child(note)


func settlement() -> StringName:
	return context.get("settlement", &"town")


func refresh() -> void:
	var s := settlement()
	Game.remember_prices(s)
	set_title("%s market" % Game.settlement_name(s))
	_money.text = "Your gold: %d      Shift + click = 10 at once" % Game.player.money
	for child in _rows.get_children():
		child.queue_free()
	for id in Game.COMMODITY_IDS:
		_rows.add_child(_commodity_row(s, id))
	if s == &"town":
		_rows.add_child(_potion_row())
	for id in Game.ITEM_IDS:
		var item: ItemData = Game.items[id]
		if not item.is_commodity() and item.heal_amount == 0 and Game.player.inventory.count_of(id) > 0:
			_rows.add_child(_loot_row(item))


func _quantity() -> int:
	return 10 if Input.is_key_pressed(KEY_SHIFT) else 1


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	return row


func _commodity_row(s: StringName, id: StringName) -> HBoxContainer:
	var economy := Game.economy
	var m := economy.market(s, id)
	var item: ItemData = Game.items[id]
	var have := Game.player.inventory.count_of(id)
	var buy := economy.buy_price(s, id)
	var sell := economy.sell_price(s, id)
	var row := _row()
	row.add_child(icon(item.icon))
	row.add_child(label(item.display_name, 88.0))
	row.add_child(label("%d g" % buy, 40.0))
	row.add_child(label("%d g" % sell, 40.0))
	var today := m.price / m.price_days_ago(1) - 1.0
	row.add_child(label("%+d%%" % roundi(today * 100), 40.0, change_color(today)))
	row.add_child(label("%d %s" % [floori(m.stock), m.stock_status().to_lower()], 58.0, status_color(m.stock_status())))
	row.add_child(label(str(have), 54.0))
	var buy_button := button("Buy", _buy.bind(s, id), 40.0)
	buy_button.disabled = Game.player.money < buy or m.stock < 1.0
	row.add_child(buy_button)
	var sell_button := button("Sell", _sell.bind(s, id), 40.0)
	sell_button.disabled = have == 0
	row.add_child(sell_button)
	return row


func _buy(s: StringName, id: StringName) -> void:
	var economy := Game.economy
	var price := economy.buy_price(s, id)
	var quantity := mini(_quantity(), floori(float(Game.player.money) / price))
	quantity = mini(quantity, floori(economy.market(s, id).stock))
	quantity = mini(quantity, Game.player.inventory.space_for(id))
	if quantity <= 0:
		EventBus.news.emit("You can't buy that right now.", "info")
		return
	Game.player.money -= quantity * price
	Game.player.inventory.add(id, quantity)
	economy.player_bought(s, id, quantity)
	Sfx.play(&"coin")
	refresh()


func _sell(s: StringName, id: StringName) -> void:
	var quantity := mini(_quantity(), Game.player.inventory.count_of(id))
	if quantity <= 0:
		return
	Game.player.inventory.remove(id, quantity)
	Game.player.money += quantity * Game.economy.sell_price(s, id)
	Game.economy.player_sold(s, id, quantity)
	Sfx.play(&"coin")
	refresh()


## Potions are brewed from Town herbs, so their price follows the herb price.
func potion_price() -> int:
	return ceili(Game.economy.buy_price(&"town", &"herbs") * 1.5) + 3


func _potion_row() -> HBoxContainer:
	var potion: ItemData = Game.items[&"health_potion"]
	var herbs := Game.economy.market(&"town", &"herbs")
	var price := potion_price()
	var row := _row()
	row.add_child(icon(potion.icon))
	row.add_child(label(potion.display_name, 88.0))
	row.add_child(label("%d g" % price, 40.0))
	row.add_child(label("-", 40.0))
	row.add_child(label("", 40.0))
	row.add_child(label("from herbs", 58.0, Color(0.65, 0.62, 0.58)))
	row.add_child(label(str(Game.player.inventory.count_of(potion.id)), 54.0))
	var buy_button := button("Buy", _buy_potion, 40.0)
	buy_button.disabled = Game.player.money < price or herbs.stock < HERBS_PER_POTION
	row.add_child(buy_button)
	return row


func _buy_potion() -> void:
	var price := potion_price()
	if Game.player.money < price or Game.player.inventory.space_for(&"health_potion") < 1:
		return
	Game.player.money -= price
	Game.player.inventory.add(&"health_potion", 1)
	Game.economy.player_bought(&"town", &"herbs", HERBS_PER_POTION)
	Sfx.play(&"coin")
	refresh()


func _loot_row(item: ItemData) -> HBoxContainer:
	var have := Game.player.inventory.count_of(item.id)
	var row := _row()
	row.add_child(icon(item.icon))
	row.add_child(label(item.display_name, 88.0))
	row.add_child(label("-", 40.0))
	row.add_child(label("%d g" % item.base_value, 40.0))
	row.add_child(label("", 40.0))
	row.add_child(label("fixed price", 58.0, Color(0.65, 0.62, 0.58)))
	row.add_child(label(str(have), 54.0))
	row.add_child(label("", 40.0))
	row.add_child(button("Sell", _sell_loot.bind(item), 40.0))
	return row


func _sell_loot(item: ItemData) -> void:
	var quantity := mini(_quantity(), Game.player.inventory.count_of(item.id))
	if quantity <= 0:
		return
	Game.player.inventory.remove(item.id, quantity)
	Game.player.money += quantity * item.base_value
	Sfx.play(&"coin")
	refresh()
