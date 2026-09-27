extends Control
## Line chart of price history (economy sandbox and Market Board).
## Optional red bands mark days when the mine was infested.

const DAYS_SHOWN := 60
const FONT_SIZE := 9
const PAD_LEFT := 20.0
const PAD_BOTTOM := 12.0

var _series: Array = []  # [{label: String, color: Color, values: Array[float]}]
var _infested_days: Array = []
var _max_price := 40.0
var _base_price := 10.0


func show_data(series: Array, infested_days: Array, max_price: float, base_price: float) -> void:
	_series = series
	_infested_days = infested_days
	_max_price = max_price
	_base_price = base_price
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var plot := Rect2(PAD_LEFT, 2.0, size.x - PAD_LEFT - 2.0, size.y - PAD_BOTTOM - 2.0)
	var faint := Color(1, 1, 1, 0.45)
	draw_rect(plot, Color(0, 0, 0, 0.3))

	# Horizontal grid every 10 g, plus a dashed line at the base price.
	var value := 0.0
	while value <= _max_price:
		var y := _y(value, plot)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.08))
		draw_string(font, Vector2(2, y + 3), "%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, faint)
		value += 10.0
	var base_y := _y(_base_price, plot)
	draw_dashed_line(Vector2(plot.position.x, base_y), Vector2(plot.end.x, base_y), faint, 1.0, 3.0)

	var days := _infested_days.size()
	for s in _series:
		days = maxi(days, s.values.size())
	var first := maxi(0, days - DAYS_SHOWN)
	var dx := plot.size.x / float(DAYS_SHOWN - 1)

	for i in range(first, _infested_days.size()):
		if _infested_days[i]:
			var x := plot.position.x + (i - first) * dx
			draw_rect(Rect2(x - dx / 2.0, plot.position.y, dx, plot.size.y), Color(0.9, 0.2, 0.2, 0.2))

	for s in _series:
		var values: Array[float] = s.values
		var points := PackedVector2Array()
		for i in range(first, values.size()):
			points.append(Vector2(plot.position.x + (i - first) * dx, _y(values[i], plot)))
		if points.size() >= 2:
			draw_polyline(points, s.color, 1.0)

	var legend_x := plot.position.x + 4.0
	for s in _series:
		draw_rect(Rect2(legend_x, plot.position.y + 5.0, 8.0, 3.0), s.color)
		draw_string(font, Vector2(legend_x + 11.0, plot.position.y + 10.0), s.label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, s.color)
		legend_x += 60.0
	if _infested_days.has(true):
		draw_string(font, Vector2(legend_x, plot.position.y + 10.0), "red = mine infested",
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.9, 0.4, 0.4))

	if days > 1:
		draw_string(font, Vector2(plot.position.x, size.y - 1.0), "%d days ago" % (mini(days, DAYS_SHOWN) - 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, faint)
		draw_string(font, Vector2(plot.end.x - 60.0, size.y - 1.0), "today",
				HORIZONTAL_ALIGNMENT_RIGHT, 60.0, FONT_SIZE, faint)


func _y(price: float, plot: Rect2) -> float:
	return plot.end.y - clampf(price / _max_price, 0.0, 1.0) * plot.size.y
