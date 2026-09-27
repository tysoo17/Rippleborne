class_name GamePanel
extends PanelContainer
## Base for pop-up windows: shop, market board, inventory, inn...
## The UI root opens one at a time and pauses the game while it is open.
## Subclasses fill `body` in build() and update it in refresh().

signal closed

## Filled by open(), e.g. {"settlement": &"town"}.
var context: Dictionary = {}
var body: VBoxContainer
var _title: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 4)
	add_child(frame)
	var header := HBoxContainer.new()
	frame.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "Close [Esc]"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	frame.add_child(HSeparator.new())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	frame.add_child(body)
	build()


## Create the controls that never change. Override.
func build() -> void:
	pass


## Update the controls from the game state. Override.
func refresh() -> void:
	pass


func set_title(text: String) -> void:
	_title.text = text


func open(p_context: Dictionary = {}) -> void:
	context = p_context
	refresh()
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


# --- Small helpers for building rows ----------------------------------------

static func label(text: String, width: float = 0.0, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if width > 0.0:
		l.custom_minimum_size.x = width
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func icon(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(16, 16)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return rect


static func button(text: String, action: Callable, width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if width > 0.0:
		b.custom_minimum_size.x = width
	b.pressed.connect(func():
		Sfx.play(&"click", -14.0)
		action.call())
	return b


static func change_color(change: float) -> Color:
	if change > 0.005:
		return Color(1, 0.55, 0.45)
	if change < -0.005:
		return Color(0.55, 0.9, 0.55)
	return Color(0.7, 0.7, 0.7)


static func status_color(status: String) -> Color:
	match status:
		"Shortage":
			return Color(1, 0.4, 0.35)
		"Low":
			return Color(1, 0.75, 0.4)
		"Surplus":
			return Color(0.5, 0.8, 1)
	return Color(0.75, 0.9, 0.7)
