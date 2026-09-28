extends GamePanel
## Talking to someone. What they say depends on what is happening in the
## world (see Dialogue), so it is worth asking around.

var _portrait: TextureRect
var _name: Label
var _reputation: Label
var _text: Label
var _tip_button: Button


func build() -> void:
	custom_minimum_size = Vector2(380, 0)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(32, 48)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	header.add_child(_portrait)
	var names := VBoxContainer.new()
	header.add_child(names)
	_name = label("", 0.0, Color(1, 0.85, 0.55))
	names.add_child(_name)
	_reputation = label("", 0.0, Color(0.65, 0.62, 0.58))
	_reputation.add_theme_font_size_override("font_size", 10)
	names.add_child(_reputation)
	_text = label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(360, 44)
	body.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	body.add_child(buttons)
	buttons.add_child(button("Any news?", func(): _say(Dialogue.news(role()))))
	_tip_button = button("Prices elsewhere?", func(): _say(Dialogue.price_tip(settlement())))
	buttons.add_child(_tip_button)
	buttons.add_child(button("Bye", close))


func settlement() -> StringName:
	return context.get("settlement", &"town")


func role() -> StringName:
	return context.get("role", &"")


func refresh() -> void:
	set_title("Talking")
	_name.text = context.get("name", "Someone")
	var points := Game.jobs.reputation_of(settlement())
	_reputation.text = "%s  -  %s reputation: %s (%d)" % [String(role()).capitalize(),
			Game.settlement_name(settlement()), JobSystem.title_for(points), points]
	_portrait.texture = context.get("portrait")
	_tip_button.visible = role() == &"merchant"
	_say(Dialogue.greeting(role(), settlement()))


func _say(text: String) -> void:
	_text.text = "\"%s\"" % text
