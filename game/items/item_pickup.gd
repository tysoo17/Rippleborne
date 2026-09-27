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

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if item_id == &"gold":
		sprite.texture = preload("res://assets/icons/gold.png")
	else:
		sprite.texture = Game.items[item_id].icon
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	sprite.position.y = -8.0 - absf(sin(_age * 3.0)) * 3.0
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
