class_name EnemySpawner
extends Node2D
## Keeps a group of enemies alive around this point.
##
## Forest spawners always hold `count` enemies and refill every morning.
## Event spawners (mine, bandit camp) follow WorldState instead: they hold
## exactly as many enemies as the event has left, and none when it is over.

const ENEMY_SCENE := preload("res://game/combat/enemy.tscn")

## Reported with every kill, so WorldState knows which event lost an enemy.
@export var group: StringName = &"forest"
@export var enemy_ids: Array[StringName] = [&"slime"]
## Enemies kept alive when there is no condition.
@export var count: int = 3
@export var radius: float = 64.0
## Empty = always. Otherwise a WorldState flag: &"mine_infested" or &"bandits_active".
@export var condition: StringName = &""


func _ready() -> void:
	y_sort_enabled = true
	EventBus.mine_state_changed.connect(func(_on: bool): sync())
	EventBus.bandit_state_changed.connect(func(_on: bool): sync())
	EventBus.day_advanced.connect(func(_day: int): sync())
	sync.call_deferred()


func desired_count() -> int:
	match condition:
		&"mine_infested":
			return Game.world.mine_monsters_left if Game.world.mine_infested else 0
		&"bandits_active":
			return Game.world.bandits_left if Game.world.bandits_active else 0
	return count


func alive() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for child in get_children():
		var enemy := child as Enemy
		if enemy != null and not enemy.is_dying():
			result.append(enemy)
	return result


func sync() -> void:
	var living := alive()
	var wanted := desired_count()
	while living.size() > wanted:
		living.pop_back().queue_free()
	for i in wanted - living.size():
		_spawn()


func _spawn() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	var spot := _free_spot()
	enemy.setup(Game.enemies[enemy_ids.pick_random()], group, global_position + spot)
	enemy.position = spot
	add_child(enemy)


## A random point near the spawner that is not inside a wall or tree.
func _free_spot() -> Vector2:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	for attempt in 12:
		var spot := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * radius
		query.position = global_position + spot
		if space.intersect_point(query, 1).is_empty():
			return spot
	return Vector2.ZERO
