extends GamePanel
## Market Board: today's prices, their trend, and WHY they moved.
## This is where the simulation becomes information the player can use.

var selected: StringName = &"iron"

var _news: Label
var _rows: VBoxContainer
var _chart: PriceChart
var _detail_title: Label
var _reasons: Label
var _elsewhere: Label


func build() -> void:
	custom_minimum_size = Vector2(560, 0)
	_news = label("")
	_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news.custom_minimum_size.x = 540
	body.add_child(_news)
	var header := HBoxContainer.new()
	for spec in [["Item", 104.0], ["Price", 56.0], ["Today", 56.0], ["7 days", 56.0], ["Stock", 70.0]]:
		header.add_child(label(spec[0], spec[1], Color(0.65, 0.62, 0.58)))
	body.add_child(header)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	body.add_child(_rows)
	body.add_child(HSeparator.new())
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	_chart = PriceChart.new()
	_chart.custom_minimum_size = Vector2(250, 120)
	detail.add_child(_chart)
	var text := VBoxContainer.new()
	detail.add_child(text)
	_detail_title = label("", 0.0, Color(1, 0.85, 0.55))
	text.add_child(_detail_title)
	_reasons = label("")
	_reasons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reasons.custom_minimum_size.x = 285
	_reasons.add_theme_font_size_override("font_size", 10)
	text.add_child(_reasons)
	_elsewhere = label("", 0.0, Color(0.65, 0.62, 0.58))
	_elsewhere.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_elsewhere.custom_minimum_size.x = 285
	_elsewhere.add_theme_font_size_override("font_size", 10)
	text.add_child(_elsewhere)


func settlement() -> StringName:
	return context.get("settlement", &"town")


func other_settlement() -> StringName:
	return &"village" if settlement() == &"town" else &"town"


func refresh() -> void:
	var s := settlement()
	set_title("%s market board  -  Day %d" % [Game.settlement_name(s), GameClock.day])
	_news.text = _news_text()
	for child in _rows.get_children():
		child.queue_free()
	for id in Game.COMMODITY_IDS:
		_rows.add_child(_row(s, id))
	_show_detail()
	Game.remember_prices(s)


func _news_text() -> String:
	var lines: Array[String] = []
	if Game.world.mine_infested:
		lines.append("Monsters are in the mine: no iron is being dug. (%d left)" % Game.world.mine_monsters_left)
	if Game.world.bandits_active:
		lines.append("Bandits camp by the road: few caravans dare to travel. (%d left)" % Game.world.bandits_left)
	if lines.is_empty():
		_news.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		return "No trouble reported. Prices update every midnight."
	_news.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
	return "\n".join(lines)


func _row(s: StringName, id: StringName) -> HBoxContainer:
	var m := Game.economy.market(s, id)
	var row := HBoxContainer.new()
	var name_button := button(("> " if id == selected else "") + m.commodity.display_name, _select.bind(id), 100.0)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.icon = m.commodity.icon
	row.add_child(name_button)
	row.add_child(label("", 4.0))
	row.add_child(label("%.1f g" % m.price, 56.0))
	var today := m.price - m.price_days_ago(1)
	row.add_child(label("%+.1f" % today, 56.0, change_color(today)))
	var week_ago := m.price_days_ago(7)
	var week := (m.price - week_ago) / week_ago * 100.0
	row.add_child(label("%+d%%" % roundi(week), 56.0, change_color(week / 100.0)))
	row.add_child(label(m.stock_status(), 70.0, status_color(m.stock_status())))
	return row


func _select(id: StringName) -> void:
	selected = id
	refresh()


func _show_detail() -> void:
	var s := settlement()
	var m := Game.economy.market(s, selected)
	var c := m.commodity
	_detail_title.text = "%s in %s: why this price?" % [c.display_name, Game.settlement_name(s)]
	_reasons.text = "- " + "\n- ".join(Game.economy.explain(s, selected))
	_chart.show_data([{"label": Game.settlement_name(s), "color": Color(1, 0.8, 0.4), "values": m.price_history}],
			[], c.base_price * c.max_multiplier, c.base_price)
	var other := other_settlement()
	var seen: Dictionary = Game.seen_prices.get(String(other), {})
	if seen.is_empty():
		_elsewhere.text = "You don't know %s prices yet. Visit its market to find out." % Game.settlement_name(other)
	else:
		var price: float = seen.prices.get(String(selected), 0.0)
		var age := GameClock.day - int(seen.day)
		var when := "today" if age == 0 else ("yesterday" if age == 1 else "%d days ago" % age)
		_elsewhere.text = "%s price when you were last there (%s): %.1f g" % [Game.settlement_name(other), when, price]
