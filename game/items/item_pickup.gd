class_name ItemPickup
extends Area2D
## An item lying on the ground. Walk over it to pick it up.
## item_id &"gold" is money instead of an inventory item.

const MAGNET_RANGE := 44.0
const MAGNET_SPEED := 160.0
## Seconds before it can be picked up (so drops visibly pop out first).
const PICKUP_DELAY := 0.35

@export var item_id: StringName = &"gold"
@export var count: int = 1

var _age: float = 0.0
var _full_warning_shown: bool = false
## Drops pop out in a little arc: sideways speed, and height above the ground.
var _pop_velocity: Vector2 = Vector2.ZERO
var _height: float = 0.0
var _height_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if item_id == &"gold":
		sprite.texture = preload("res://assets/icons/gold.png")
	else:
		sprite.texture = Game.items[item_id].icon
	body_entered.connect(_on_body_entered)
	_pop_velocity = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 50.0)
	_height_speed = randf_range(80.0, 110.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _pop_velocity != Vector2.ZERO or _height > 0.0 or _height_speed > 0.0:
		position += _pop_velocity * delta
		_pop_velocity = _pop_velocity.move_toward(Vector2.ZERO, 90.0 * delta)
		_height_speed -= 320.0 * delta
		_height += _height_speed * delta
		if _height <= 0.0:
			_height = 0.0
			_height_speed = -_height_speed * 0.35 if absf(_height_speed) > 25.0 else 0.0
	var bob := absf(sin(_age * 3.0)) * 3.0 if _height == 0.0 and _height_speed == 0.0 else 0.0
	sprite.position.y = -8.0 - _height - bob
	if _age < PICKUP_DELAY:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var distance := global_position.distance_to(player.global_position)
	if distance < MAGNET_RANGE:
		global_position = global_position.move_toward(player.global_position, MAGNET_SPEED * delta)
	if distance < 10.0:
		_collect()


func _on_body_entered(body: Node) -> void:
	if body is Player and _age >= PICKUP_DELAY:
		_collect()


func _collect() -> void:
	if item_id == &"gold":
		Game.player.money += count
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -20), "+%d gold" % count, Color(1, 0.85, 0.3))
		Sfx.play(&"coin")
		queue_free()
		return
	var left := Game.player.inventory.add(item_id, count)
	if left == count:
		if not _full_warning_shown:
			_full_warning_shown = true
			EventBus.news.emit("Your bag is full.", "info")
		return
	var item: ItemData = Game.items[item_id]
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -20), "+%d %s" % [count - left, item.display_name], Color(0.8, 1, 0.8))
	Sfx.play(&"pickup")
	count = left
	if count == 0:
		queue_free()
