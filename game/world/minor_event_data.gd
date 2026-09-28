class_name MinorEventData
extends Resource
## A small, short world event (festival, big order, rich vein...). Like the
## big events it only changes the world: it multiplies one business's output
## or one settlement's demand for a few days. Prices react on their own.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("What it changes")
## Business whose output is multiplied (e.g. &"mine"). Leave empty for a demand change.
@export var business_id: StringName = &""
## ...or the demand of this settlement for this commodity.
@export var settlement_id: StringName = &""
@export var commodity_id: StringName = &""
## 1.5 = +50%, 0.6 = -40%.
@export var factor: float = 1.5

@export_group("How long and how often")
@export var min_days: int = 3
@export var max_days: int = 4
## Higher weight = picked more often.
@export var weight: float = 1.0

@export_group("Text")
## Shown when it starts.
@export_multiline var news: String = ""
## Short name used in price explanations, e.g. "Harvest festival".
@export var reason: String = ""
