class_name EventData
extends Resource
## Static data for a world event (Monster Infestation, Bandit Activity).
## Events change WorldState only; everything else reacts to that.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("When")
## The event cannot happen before this day.
@export var earliest_day: int = 3
## Chance per day once it is allowed to happen...
@export_range(0.0, 1.0) var base_chance: float = 0.05
## ...growing by this much for every day it did not happen.
@export_range(0.0, 1.0) var chance_growth_per_day: float = 0.03
## After it ends, it cannot happen again for this many days.
@export var cooldown_days: int = 10

@export_group("How long")
## If the player does nothing, locals deal with it after this many days.
@export var min_duration: int = 20
@export var max_duration: int = 30
## Enemies the player must defeat to end it early.
@export var enemy_count: int = 6

@export_group("News")
## What NPCs whisper in the days before it starts.
@export_multiline var rumor: String = ""
@export_multiline var start_news: String = ""
@export_multiline var end_news_natural: String = ""
@export_multiline var end_news_player: String = ""
