@tool
class_name WorldProp
extends Node2D
## A standing thing in the world: an NPC, a market stall, a notice board.
## It blocks movement at its feet and can open a UI panel when used.
## Everything is set from the Inspector, so one scene serves all of them.

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply()
## Size of the solid part at the feet. Zero = the player can walk through.
@export var body_size: Vector2 = Vector2(16, 8):
	set(value):
		body_size = value
		_apply()
@export var prompt: String = "":
	set(value):
		prompt = value
		_apply()
@export var panel: StringName = &"":
	set(value):
		panel = value
		_apply()
@export var settlement_id: StringName = &"":
	set(value):
		settlement_id = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var sprite: Sprite2D = $Sprite2D
	sprite.texture = texture
	sprite.offset = Vector2(0, -texture.get_height() / 2.0) if texture else Vector2.ZERO
	var shape: CollisionShape2D = $Body/CollisionShape2D
	shape.disabled = body_size == Vector2.ZERO
	var rect := RectangleShape2D.new()
	rect.size = body_size if body_size != Vector2.ZERO else Vector2.ONE
	shape.shape = rect
	shape.position = Vector2(0, -body_size.y / 2.0)
	var interactable: Interactable = $Interactable
	interactable.prompt = prompt
	interactable.panel = panel
	interactable.settlement_id = settlement_id
	interactable.enabled = prompt != ""
