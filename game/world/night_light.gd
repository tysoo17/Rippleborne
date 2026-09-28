extends PointLight2D
## A light that fades in as the day gets dark (lamps, the player's lantern).

@export var max_energy: float = 1.0


func _process(_delta: float) -> void:
	var tint := DayNight.color_at(GameClock.exact_hour())
	var darkness := 1.0 - (tint.r + tint.g + tint.b) / 3.0
	energy = clampf(darkness * 2.5, 0.0, 1.0) * max_energy
	visible = energy > 0.01
