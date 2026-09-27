extends Node
## Global signal hub (autoload "EventBus").
##
## Systems announce what happened here instead of calling each other directly.
## Example: GameClock emits day_advanced; the economy, the event system and the
## HUD all listen to it without GameClock knowing they exist.
##
## Rule: only signals live in this file, never game logic.
@warning_ignore_start("unused_signal")

# --- Time ----------------------------------------------------------------
## One in-game hour has passed. Emitted by GameClock.
signal hour_advanced(day: int, hour: int)
## A new in-game day has started. Emitted by GameClock.
signal day_advanced(day: int)

# --- World and economy ---------------------------------------------------
## The daily simulation (events + economy) has finished for this day.
signal economy_updated(day: int)
## Monsters took over the mine (true) or the mine was cleared (false).
signal mine_state_changed(infested: bool)
## Bandits started (true) or stopped (false) raiding the road.
signal bandit_state_changed(active: bool)
## A message for the player. kind: "info", "warning" or "good".
signal news(text: String, kind: String)
## An enemy died. group is the spawner group, e.g. "mine" or "forest".
signal enemy_killed(enemy_id: StringName, group: StringName)

# --- Player --------------------------------------------------------------
signal player_hp_changed(hp: int, max_hp: int)
signal money_changed(money: int)
signal inventory_changed
signal weapon_upgraded(level: int)
signal player_died
## The player walked into another area (Town, Forest...).
signal location_changed(location_name: String)
## Text for the "E: ..." hint; empty when nothing is in reach.
signal interact_prompt_changed(text: String)

# --- UI ------------------------------------------------------------------
## Ask the UI to open a panel, e.g. open_panel.emit(&"shop", {"settlement": &"town"}).
signal open_panel(panel: StringName, context: Dictionary)
## A panel was opened or closed. The player ignores input while any panel is open.
signal panel_visibility_changed(open_count: int)

@warning_ignore_restore("unused_signal")
