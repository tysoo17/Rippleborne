extends Node
## In-game time (autoload "GameClock").
##
## Movement and combat run every frame and don't use this clock.
## The simulation (production, trade, prices, events) runs on the day ticks
## that this clock announces through EventBus.

const HOURS_PER_DAY := 24
const START_HOUR := 6

## Real seconds that one in-game hour lasts. 10 -> one day is 4 minutes.
var seconds_per_hour: float = 10.0

var day: int = 1
var hour: int = START_HOUR

var _seconds_into_hour: float = 0.0


func _process(delta: float) -> void:
	_seconds_into_hour += delta
	while _seconds_into_hour >= seconds_per_hour:
		_seconds_into_hour -= seconds_per_hour
		_advance_one_hour()


## Jump forward by a number of in-game hours (debug keys, sleeping).
func advance_time(hours: int) -> void:
	for i in hours:
		_advance_one_hour()


## Skip to the next morning at START_HOUR (used when sleeping or knocked out).
func advance_to_next_morning() -> void:
	var hours := (HOURS_PER_DAY - hour + START_HOUR) % HOURS_PER_DAY
	if hours == 0:
		hours = HOURS_PER_DAY
	advance_time(hours)
	_seconds_into_hour = 0.0


## Hour with minutes as a fraction, e.g. 14.5 = 14:30. Used for smooth day/night.
func exact_hour() -> float:
	return hour + _seconds_into_hour / seconds_per_hour


func time_text() -> String:
	var minutes := int(_seconds_into_hour / seconds_per_hour * 6.0) * 10
	return "Day %d  %02d:%02d" % [day, hour, minutes]


func reset() -> void:
	day = 1
	hour = START_HOUR
	_seconds_into_hour = 0.0


func to_dict() -> Dictionary:
	return {"day": day, "hour": hour, "seconds_into_hour": _seconds_into_hour}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = int(data.get("hour", START_HOUR))
	_seconds_into_hour = float(data.get("seconds_into_hour", 0.0))


func _advance_one_hour() -> void:
	hour += 1
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		EventBus.day_advanced.emit(day)
	EventBus.hour_advanced.emit(day, hour)
