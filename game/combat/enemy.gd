class_name Enemy
extends CharacterBody2D
## One enemy. Behaviour is the same for every type; EnemyData decides how
## strong, fast and aggressive it is and what it drops.
##
## States: wander near home -> chase the player -> wind up (flash) -> lunge
## -> recover -> chase again. If the player runs too far, it walks home.

enum State { WANDER, CHASE, WINDUP, LUNGE, RECOVER, RETURN }

const PICKUP_SCENE := preload("res://game/items/item_pickup.tscn")
const LUNGE_TIME := 0.22
const RECOVER_TIME := 0.35
## How far from home an enemy follows the player before giving up.
const LEASH_RANGE := 280.0
const WANDER_RADIUS := 48.0

@export var data: EnemyData

## Spawner group ("forest", "mine", "bandit_camp"); reported when this enemy dies.
var group: StringName = &""
var home: Vector2 = Vector2.INF
var hp: int = 1
var state: State = State.WANDER

var _state_left: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _lunge_direction: Vector2 = Vector2.ZERO
var _attack_ready_in: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _dying: bool = false
var _player: Player = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox


func setup(p_data: EnemyData, p_group: StringName, p_home: Vector2) -> void:
	data = p_data
	group = p_group
	home = p_home


func _ready() -> void:
	if not home.is_finite():
		home = global_position
	hp = data.max_hp
	sprite.texture = data.texture
	sprite.hframes = data.hframes
	sprite.modulate = data.tint
	sprite.offset = Vector2(0, -data.frame_height / 2.0)
	var body := CircleShape2D.new()
	body.radius = data.body_radius
	body_shape.shape = body
	var hurt_shape := CircleShape2D.new()
	hurt_shape.radius = data.body_radius + 4.0
	hurtbox.get_child(0).shape = hurt_shape
	hurtbox.position = Vector2(0, -data.frame_height / 2.0)
	var hit_shape := CircleShape2D.new()
	hit_shape.radius = data.body_radius + 2.0
	hitbox.get_child(0).shape = hit_shape
	hitbox.position = hurtbox.position
	hitbox.damage = data.damage
	hitbox.active = data.contact_damage
	hurtbox.hurt.connect(_on_hurt)
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_attack_ready_in -= delta
	_state_left -= delta
	var player_ok := _player != null and not _player.is_dead()
	var to_player := _player.global_position - global_position if _player != null else Vector2.ZERO
	var distance := to_player.length()

	match state:
		State.WANDER:
			if player_ok and distance < data.detect_range and _player.global_position.distance_to(home) < LEASH_RANGE:
				state = State.CHASE
			elif global_position.distance_to(_wander_target) < 4.0 or _state_left <= 0.0:
				_pick_wander_target()
			velocity = global_position.direction_to(_wander_target) * data.wander_speed
		State.CHASE:
			if not player_ok or distance > data.detect_range * 1.8 or global_position.distance_to(home) > LEASH_RANGE:
				state = State.RETURN
			elif distance < data.attack_range and _attack_ready_in <= 0.0:
				_enter(State.WINDUP, data.attack_windup)
			velocity = to_player.normalized() * data.chase_speed
		State.WINDUP:
			velocity = Vector2.ZERO
			sprite.modulate = data.tint.lightened(0.6) if int(_state_left * 20.0) % 2 == 0 else data.tint
			if _state_left <= 0.0:
				_lunge_direction = to_player.normalized()
				sprite.modulate = data.tint
				hitbox.active = true
				_enter(State.LUNGE, LUNGE_TIME)
		State.LUNGE:
			velocity = _lunge_direction * data.lunge_speed
			if _state_left <= 0.0:
				hitbox.active = data.contact_damage
				_attack_ready_in = data.attack_cooldown
				_enter(State.RECOVER, RECOVER_TIME)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_left <= 0.0:
				state = State.CHASE
		State.RETURN:
			velocity = global_position.direction_to(home) * data.chase_speed
			if global_position.distance_to(home) < 8.0:
				hp = data.max_hp
				queue_redraw()
				state = State.WANDER
				_pick_wander_target()

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 800.0 * delta)
	move_and_slide()
	_animate(delta)


func _enter(new_state: State, seconds: float) -> void:
	state = new_state
	_state_left = seconds


func _pick_wander_target() -> void:
	_wander_target = home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_RADIUS
	_state_left = randf_range(2.0, 4.0)


func _animate(delta: float) -> void:
	var speed_factor := 2.0 if state == State.CHASE or state == State.LUNGE else 1.0
	_anim_time += delta * speed_factor
	sprite.frame = int(_anim_time / 0.25) % data.hframes
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0


func _on_hurt(from: Hitbox) -> void:
	if _dying:
		return
	hp -= from.damage
	_knockback = (global_position - from.global_position).normalized() * from.knockback * data.knockback_taken
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -data.frame_height - 8), str(from.damage), Color(1, 0.95, 0.5))
	Sfx.play(&"hit")
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", data.tint, 0.15)
	if state == State.WANDER or state == State.RETURN:
		state = State.CHASE
	queue_redraw()
	if hp <= 0:
		_die()


func _die() -> void:
	_dying = true
	hitbox.active = false
	hurtbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_drop_loot()
	EventBus.enemy_killed.emit(data.id, group)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.2), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func is_dying() -> bool:
	return _dying


func _drop_loot() -> void:
	var gold := randi_range(data.gold_min, data.gold_max)
	if gold > 0:
		_spawn_pickup(&"gold", gold)
	for i in data.loot_items.size():
		if randf() < data.loot_chances[i]:
			_spawn_pickup(data.loot_items[i], 1)


func _spawn_pickup(item_id: StringName, count: int) -> void:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_id = item_id
	pickup.count = count
	pickup.position = position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
	get_parent().call_deferred("add_child", pickup)


## Small health bar once the enemy has been hit.
func _draw() -> void:
	if _dying or hp >= data.max_hp:
		return
	var top := -data.frame_height - 5.0
	draw_rect(Rect2(-10, top, 20, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-10, top, 20.0 * hp / data.max_hp, 3), Color(0.9, 0.25, 0.25))
