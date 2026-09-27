class_name FloatingText
extends Label
## Small text that floats up and fades out: damage numbers, "+1 Iron"...


static func spawn(parent: Node, at: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var label := FloatingText.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(80, 14)
	label.position = at - Vector2(40, 7)
	label.z_index = 50
	parent.add_child(label)


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(queue_free)
