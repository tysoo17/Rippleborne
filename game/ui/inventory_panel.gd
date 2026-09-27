extends GamePanel
## The bag: 20 slots. Click a slot to read about the item; potions can be used.

var _stats: Label
var _grid: GridContainer
var _slots: Array[Button] = []
var _info: Label
var _use_button: Button
var _selected: int = -1


func build() -> void:
	custom_minimum_size = Vector2(300, 0)
	set_title("Bag")
	_stats = label("")
	body.add_child(_stats)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	body.add_child(_grid)
	for i in Inventory.SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(52, 30)
		slot.expand_icon = false
		slot.pressed.connect(_select.bind(i))
		_grid.add_child(slot)
		_slots.append(slot)
	_info = label("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(280, 44)
	_info.add_theme_font_size_override("font_size", 10)
	body.add_child(_info)
	_use_button = button("Use", _use_selected)
	body.add_child(_use_button)


func refresh() -> void:
	var p := Game.player
	_stats.text = "HP %d/%d    Gold %d    Sword level %d" % [p.hp, p.max_hp, p.money, p.weapon_level]
	for i in Inventory.SIZE:
		var slot = p.inventory.slots[i]
		var button_node := _slots[i]
		if slot == null:
			button_node.icon = null
			button_node.text = ""
			button_node.tooltip_text = ""
		else:
			var item: ItemData = Game.items[slot.id]
			button_node.icon = item.icon
			button_node.text = str(slot.count)
			button_node.tooltip_text = item.display_name
	_show_selected()


func _select(index: int) -> void:
	_selected = index
	_show_selected()


func _show_selected() -> void:
	var slot = null if _selected < 0 else Game.player.inventory.slots[_selected]
	_use_button.visible = false
	if slot == null:
		_info.text = "Click an item to read about it. Commodities (food, wood, iron, herbs) sell at the local market price."
		return
	var item: ItemData = Game.items[slot.id]
	var text := "%s x%d\n%s" % [item.display_name, slot.count, item.description]
	if item.is_commodity():
		text += "\nLast seen price: " + _seen_prices(item.commodity_id)
	else:
		text += "\nShops pay %d gold each." % item.base_value
	_info.text = text
	_use_button.visible = item.heal_amount > 0


func _seen_prices(commodity_id: StringName) -> String:
	var parts: Array[String] = []
	for s in Game.SETTLEMENT_IDS:
		var seen: Dictionary = Game.seen_prices.get(String(s), {})
		if not seen.is_empty():
			parts.append("%s %.1f g (day %d)" % [Game.settlement_name(s), seen.prices.get(String(commodity_id), 0.0), seen.day])
	return "unknown - visit a market" if parts.is_empty() else ", ".join(parts)


func _use_selected() -> void:
	var slot = Game.player.inventory.slots[_selected] if _selected >= 0 else null
	if slot == null:
		return
	var problem := Game.use_item(slot.id)
	if problem != "":
		EventBus.news.emit(problem, "info")
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()
		return
	super(event)
