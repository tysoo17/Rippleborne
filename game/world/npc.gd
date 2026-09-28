@tool
class_name WorldProp
extends Node2D
## A standing thing in the world: an NPC, a market stall, a notice board.
## It blocks movement at its feet and can open a UI panel when used.
## Everything is set from the Inspector, so one scene serves all of them.
##
## People (props with a `role`) can be talked to, stroll around their spot
## during the day and go home at night if `sleeps_at_night` is on.

const WALK_SPEED := 18.0
const NIGHT_START := 21
const NIGHT_END := 6

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

@export_group("Person")
@export var npc_name: String = "":
	set(value):
		npc_name = value
		_apply()
## farmer, miner, villager, guard, townsperson, merchant, innkeeper...
## A role without a panel opens the dialogue window when you talk to them.
@export var role: StringName = &"":
	set(value):
		role = value
		_apply()
## Walks around within this many pixels of its spot. 0 = stands still.
@export var wander_radius: float = 0.0
@export var sleeps_at_night: bool = false

var _home: Vector2
var _target: Vector2
var _wait: float = 0.0
var _step_time: float = 0.0


func _ready() -> void:
	_apply()
	if Engine.is_editor_hint():
		return
	_home = position
	_target = position
	if sleeps_at_night:
		EventBus.hour_advanced.connect(func(_day: int, _hour: int): _update_awake())
		_update_awake()


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
	if prompt == "" and role != &"" and npc_name != "":
		interactable.prompt = "Talk to %s" % npc_name
	interactable.panel = panel if panel != &"" or role == &"" else &"dialogue"
	interactable.settlement_id = settlement_id
	interactable.npc_name = npc_name
	interactable.role = role
	interactable.portrait = texture
	interactable.enabled = interactable.prompt != ""


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or wander_radius <= 0.0 or not visible:
		return
	var sprite: Sprite2D = $Sprite2D
	if _wait > 0.0:
		_wait -= delta
		sprite.position.y = 0.0
		return
	var to_target := _target - position
	if to_target.length() < 2.0:
		_wait = randf_range(1.5, 4.0)
		_target = _home + Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * wander_radius
		return
	position += to_target.normalized() * WALK_SPEED * delta
	sprite.flip_h = to_target.x < 0.0
	_step_time += delta
	sprite.position.y = -absf(sin(_step_time * 10.0)) * 1.5


## At night people go home: hide them and let the player walk through.
func _update_awake() -> void:
	var hour := GameClock.hour
	var awake := hour >= NIGHT_END and hour < NIGHT_START
	visible = awake
	$Body/CollisionShape2D.set_deferred("disabled", not awake or body_size == Vector2.ZERO)
	$Interactable.enabled = awake and $Interactable.prompt != ""
	if not awake:
		position = _home
