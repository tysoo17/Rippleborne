class_name DayNight
extends CanvasModulate
## Tints the world by time of day. The HUD is on a CanvasLayer, so it stays bright.

const NIGHT := Color(0.4, 0.44, 0.7)
const DUSK := Color(1.0, 0.8, 0.68)


func _process(_delta: float) -> void:
	color = color_at(GameClock.exact_hour())


static func color_at(hour: float) -> Color:
	if hour < 5.0:
		return NIGHT
	if hour < 7.0:
		return NIGHT.lerp(Color.WHITE, (hour - 5.0) / 2.0)
	if hour < 17.0:
		return Color.WHITE
	if hour < 19.0:
		return Color.WHITE.lerp(DUSK, (hour - 17.0) / 2.0)
	if hour < 21.0:
		return DUSK.lerp(NIGHT, (hour - 19.0) / 2.0)
	return NIGHT
