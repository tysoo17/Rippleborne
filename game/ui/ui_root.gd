extends CanvasLayer
## Owns the HUD and every pop-up panel. Opens a panel when anyone emits
## EventBus.open_panel, and pauses the game while one is open.

var _current: GamePanel = null

@onready var panels: Dictionary = {
	&"shop": $Center/ShopPanel,
	&"market_board": $Center/MarketBoardPanel,
	&"inventory": $Center/InventoryPanel,
	&"blacksmith": $Center/BlacksmithPanel,
	&"inn": $Center/InnPanel,
	&"pause": $Center/PauseMenu,
	&"help": $Center/HelpPanel,
	&"debug": $Center/DebugPanel,
	&"dialogue": $Center/DialoguePanel,
	&"jobs": $Center/JobsPanel,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.open_panel.connect(open)
	for panel: GamePanel in panels.values():
		panel.closed.connect(_on_closed.bind(panel))
	if Game.show_intro:
		Game.show_intro = false
		open.call_deferred(&"help", {})


func open(panel_name: StringName, context: Dictionary = {}) -> void:
	var panel: GamePanel = panels[panel_name]
	if _current != null and _current != panel:
		var previous := _current
		_current = null
		previous.close()
	_current = panel
	panel.open(context)
	get_tree().paused = true
	EventBus.panel_visibility_changed.emit(1)


func _on_closed(panel: GamePanel) -> void:
	if panel != _current:
		return
	_current = null
	get_tree().paused = false
	EventBus.panel_visibility_changed.emit(0)


func _unhandled_input(event: InputEvent) -> void:
	if _current != null:
		return
	if event.is_action_pressed("pause"):
		open(&"pause")
	elif event.is_action_pressed("inventory"):
		open(&"inventory")
	elif event.is_action_pressed("debug_panel"):
		open(&"debug")
	elif event.is_action_pressed("debug_advance_hour"):
		GameClock.advance_time(1)
	elif event.is_action_pressed("debug_advance_day"):
		GameClock.advance_time(GameClock.HOURS_PER_DAY)
	elif event.is_action_pressed("debug_advance_30_days"):
		GameClock.advance_time(GameClock.HOURS_PER_DAY * 30)
	else:
		return
	get_viewport().set_input_as_handled()
