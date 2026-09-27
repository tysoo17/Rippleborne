extends Node
## Global signal hub (autoload "EventBus").
##
## Systems announce what happened here instead of calling each other directly.
## Example: GameClock emits day_advanced; later the ProductionSystem and the
## MarketSystem will listen to it without GameClock knowing they exist.
##
## Rule: only signals live in this file, never game logic.

## One in-game hour has passed. Emitted by GameClock.
@warning_ignore("unused_signal")
signal hour_advanced(day: int, hour: int)

## A new in-game day has started. Emitted by GameClock.
@warning_ignore("unused_signal")
signal day_advanced(day: int)
