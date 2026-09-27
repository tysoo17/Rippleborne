extends Node
## In-game time (autoload "GameClock").
##
## Movement and combat run every frame and don't use this clock.
## The simulation (production, trade, prices...) will run on the hour and day
## ticks that this clock announces through EventBus.

const HOURS_PER_DAY := 24

## Real seconds that one in-game hour lasts.
var seconds_per_hour: float = 10.0
var paused: bool = false

var day: int = 1
var hour: int = 6

var _seconds_into_hour: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	_seconds_into_hour += delta
	while _seconds_into_hour >= seconds_per_hour:
		_seconds_into_hour -= seconds_per_hour
		_advance_one_hour()


## Jump forward by a number of in-game hours (debug keys now, sleeping later).
func advance_time(hours: int) -> void:
	for i in hours:
		_advance_one_hour()


func _advance_one_hour() -> void:
	hour += 1
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		EventBus.day_advanced.emit(day)
	EventBus.hour_advanced.emit(day, hour)
