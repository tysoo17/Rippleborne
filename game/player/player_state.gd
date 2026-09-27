class_name PlayerState
extends RefCounted
## Everything about the player that must survive scene changes and saving.
## The Player scene only moves and fights; it reads and writes this.

const MAX_WEAPON_LEVEL := 3
const START_MONEY := 40

var max_hp: int = 10
var hp: int = 10:
	set(value):
		hp = clampi(value, 0, max_hp)
		EventBus.player_hp_changed.emit(hp, max_hp)
var money: int = START_MONEY:
	set(value):
		money = maxi(value, 0)
		EventBus.money_changed.emit(money)
var weapon_level: int = 1
var inventory: Inventory
## Where the player stands. Vector2.INF = use the default spawn point.
var position: Vector2 = Vector2.INF


func _init(items: Dictionary) -> void:
	inventory = Inventory.new(items)


func attack_damage() -> int:
	return weapon_level


func to_dict() -> Dictionary:
	return {
		"max_hp": max_hp, "hp": hp, "money": money, "weapon_level": weapon_level,
		"inventory": inventory.to_array(),
		"position": [position.x, position.y] if position.is_finite() else null,
	}


func from_dict(data: Dictionary) -> void:
	max_hp = int(data.get("max_hp", 10))
	hp = int(data.get("hp", max_hp))
	money = int(data.get("money", START_MONEY))
	weapon_level = int(data.get("weapon_level", 1))
	inventory.from_array(data.get("inventory", []))
	var pos = data.get("position")
	position = Vector2(pos[0], pos[1]) if pos is Array else Vector2.INF
