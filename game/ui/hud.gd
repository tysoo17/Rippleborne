extends Control
## Always-visible info: health, gold, time, place, trouble in the world,
## the "E: ..." hint and news messages. It only listens to EventBus.

const TOAST_SECONDS := 5.0
const MAX_TOASTS := 4
const TOAST_COLORS := {"info": Color(0.9, 0.9, 0.85), "warning": Color(1, 0.6, 0.45), "good": Color(0.6, 1, 0.6)}

var _hp_bar: ProgressBar
var _hp_text: Label
var _gold: Label
var _sword: Label
var _time: Label
var _place: Label
var _trouble: Label
var _prompt: Label
var _toasts: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.money_changed.connect(func(money: int): _gold.text = "%d gold" % money)
	EventBus.weapon_upgraded.connect(func(level: int): _sword.text = "Sword lv %d" % level)
	EventBus.location_changed.connect(func(place: String): _place.text = place)
	EventBus.interact_prompt_changed.connect(_on_prompt)
	EventBus.news.connect(show_toast)
	EventBus.mine_state_changed.connect(func(_on: bool): _update_trouble())
	EventBus.bandit_state_changed.connect(func(_on: bool): _update_trouble())
	_on_hp_changed(Game.player.hp, Game.player.max_hp)
	_gold.text = "%d gold" % Game.player.money
	_sword.text = "Sword lv %d" % Game.player.weapon_level
	_place.text = Game.location
	_update_trouble()


func _process(_delta: float) -> void:
	_time.text = GameClock.time_text()


func _build() -> void:
	var top_left := _box(Vector2(6, 6))
	var hp_row := HBoxContainer.new()
	top_left.add_child(hp_row)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(80, 8)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.25)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.2, 0.08, 0.08)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", back)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_bar)
	_hp_text = _label("", hp_row)
	var gold_row := HBoxContainer.new()
	top_left.add_child(gold_row)
	gold_row.add_child(GamePanel.icon(preload("res://assets/icons/gold.png")))
	_gold = _label("", gold_row, Color(1, 0.85, 0.4))
	_sword = _label("", top_left, Color(0.8, 0.8, 0.85))

	var top_right := _box(Vector2.ZERO)
	_place_at(top_right, Vector2(1, 0), Rect2(-200, 6, 194, 60))
	_time = _label("", top_right)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place = _label("", top_right, Color(1, 0.85, 0.55))
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trouble = _label("", top_right, Color(1, 0.55, 0.45))
	_trouble.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trouble.add_theme_font_size_override("font_size", 10)

	_prompt = Label.new()
	_place_at(_prompt, Vector2(0, 1), Rect2(8, -22, 300, 16))
	_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_outline(_prompt)
	add_child(_prompt)

	var hints := Label.new()
	hints.text = "I bag   Q potion   Esc menu"
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place_at(hints, Vector2(1, 1), Rect2(-200, -18, 194, 14))
	hints.add_theme_font_size_override("font_size", 9)
	hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_outline(hints)
	add_child(hints)

	_toasts = VBoxContainer.new()
	_place_at(_toasts, Vector2(0.5, 1), Rect2(-215, -130, 430, 100))
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


## Pin a control to a corner/edge: anchor (0..1, 0..1) plus a rect of offsets from it.
func _place_at(control: Control, anchor: Vector2, rect: Rect2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _box(at: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = at
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	return box


func _label(text: String, parent: Node, color: Color = Color(0.95, 0.93, 0.88)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	_outline(l)
	parent.add_child(l)
	return l


func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d/%d" % [hp, max_hp]


func _on_prompt(text: String) -> void:
	_prompt.text = "" if text == "" else "[E] " + text


func _update_trouble() -> void:
	var lines: Array[String] = []
	if Game.world.mine_infested:
		lines.append("Monsters in the mine")
	if Game.world.bandits_active:
		lines.append("Bandits on the road")
	_trouble.text = "\n".join(lines)


## A short message at the bottom of the screen that fades away.
func show_toast(text: String, kind: String = "info") -> void:
	if text == "":
		return
	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.x = 420
	toast.add_theme_color_override("font_color", TOAST_COLORS.get(kind, Color.WHITE))
	_outline(toast)
	_toasts.add_child(toast)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	if kind == "warning":
		Sfx.play(&"news", -8.0)
	var tween := toast.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(toast.queue_free)
