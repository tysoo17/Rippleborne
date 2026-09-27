extends CanvasLayer
## Developer overlay: shows the in-game clock and lets us skip time.
## F1 = +1 hour, F2 = +1 day, F3 = +30 days.
##
## It only listens to EventBus; it never changes the clock on its own
## except through GameClock.advance_time().

@onready var clock_label: Label = $ClockLabel


func _ready() -> void:
	EventBus.hour_advanced.connect(_show_time)
	_show_time(GameClock.day, GameClock.hour)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_advance_hour"):
		GameClock.advance_time(1)
	elif event.is_action_pressed("debug_advance_day"):
		GameClock.advance_time(GameClock.HOURS_PER_DAY)
	elif event.is_action_pressed("debug_advance_30_days"):
		GameClock.advance_time(GameClock.HOURS_PER_DAY * 30)


func _show_time(day: int, hour: int) -> void:
	clock_label.text = "Day %d  %02d:00" % [day, hour]
