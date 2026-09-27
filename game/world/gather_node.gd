class_name GatherNode
extends Node2D
## A spot the player can harvest with E: herb bush, fallen logs, iron ore.
## After use it regrows after some days. What was taken only reaches the
## economy when the player sells it at a market.

## Unique name, used to remember in WorldState when it regrows.
@export var node_id: String = ""
@export var texture: Texture2D
@export var item_id: StringName = &"herbs"
@export var amount: int = 2
@export var regrow_days: int = 2
@export var verb: String = "Pick herbs"
## Ore inside the mine cannot be dug while monsters are there.
@export var needs_safe_mine: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	sprite.texture = texture
	sprite.hframes = 2
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	interactable.used.connect(_on_used)
	EventBus.day_advanced.connect(func(_day: int): _refresh())
	EventBus.mine_state_changed.connect(func(_on: bool): _refresh())
	_refresh()


func is_ready() -> bool:
	if needs_safe_mine and Game.world.mine_infested:
		return false
	return Game.world.is_ready(node_id, GameClock.day)


func _refresh() -> void:
	var ready := is_ready()
	sprite.frame = 0 if ready else 1
	if ready:
		interactable.prompt = verb
	elif needs_safe_mine and Game.world.mine_infested:
		interactable.prompt = "Too dangerous while monsters are here"
	else:
		var days := int(Game.world.depleted_until.get(node_id, 0)) - GameClock.day
		interactable.prompt = "Regrows in %d day%s" % [days, "" if days == 1 else "s"]


func _on_used(_player: Player) -> void:
	if not is_ready():
		return
	var left := Game.player.inventory.add(item_id, amount)
	if left == amount:
		EventBus.news.emit("Your bag is full.", "info")
		return
	Game.world.depleted_until[node_id] = GameClock.day + regrow_days
	var item: ItemData = Game.items[item_id]
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -30), "+%d %s" % [amount - left, item.display_name], Color(0.8, 1, 0.8))
	Sfx.play(&"pickup")
	_refresh()
