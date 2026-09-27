class_name Enemy
extends CharacterBody2D
## One enemy. Behaviour is the same for every type; EnemyData decides how
## strong, fast and aggressive it is, its special moves and what it drops.
##
## States: wander near home -> chase the player -> wind up (flash) -> lunge
## (wolves lunge twice) -> recover -> chase again. A hit staggers it for a
## moment. If the player runs too far, it walks home.

enum State { WANDER, CHASE, WINDUP, LUNGE, RECOVER, RETURN, STAGGER }

const ENEMY_SCENE := "res://game/combat/enemy.tscn"
const PICKUP_SCENE := preload("res://game/items/item_pickup.tscn")
const LUNGE_TIME := 0.22
## Pause between two lunges of the same attack.
const LUNGE_GAP := 0.14
const RECOVER_TIME := 0.35
const STAGGER_TIME := 0.18
## How far from home an enemy follows the player before giving up.
const LEASH_RANGE := 280.0
const WANDER_RADIUS := 48.0

@export var data: EnemyData

## Spawner group ("forest", "mine", "bandit_camp"); reported when this enemy dies.
var group: StringName = &""
var home: Vector2 = Vector2.INF
## Seconds it can't be hurt right after appearing (small slimes from a split).
var spawn_protection: float = 0.0
var hp: int = 1
var state: State = State.WANDER

var _state_left: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _lunge_direction: Vector2 = Vector2.ZERO
var _lunges_left: int = 0
var _attack_ready_in: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _dying: bool = false
var _player: Player = null
## On-screen height of the sprite, from its texture (feet are at the origin).
var _height: float = 20.0

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
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.offset = Vector2(0, -data.texture.get_height() / 2.0)
	_height = data.texture.get_height() * data.sprite_scale
	var body := CircleShape2D.new()
	body.radius = data.body_radius
	body_shape.shape = body
	var hurt_shape := CircleShape2D.new()
	hurt_shape.radius = data.body_radius + 4.0
	hurtbox.get_child(0).shape = hurt_shape
	hurtbox.position = Vector2(0, -_height / 2.0)
	var hit_shape := CircleShape2D.new()
	hit_shape.radius = data.body_radius + 2.0
	hitbox.get_child(0).shape = hit_shape
	hitbox.position = hurtbox.position
	hitbox.damage = data.damage
	hitbox.active = data.contact_damage
	hurtbox.hurt.connect(_on_hurt)
	if spawn_protection > 0.0:
		hurtbox.make_invincible(spawn_protection)
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
	sprite.position = Vector2.ZERO

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
				_lunges_left = maxi(1, data.lunge_count)
				_enter(State.WINDUP, data.attack_windup)
			velocity = to_player.normalized() * data.chase_speed
		State.WINDUP:
			# Telegraph: flash and tremble, so the player can see it coming.
			velocity = Vector2.ZERO
			sprite.modulate = data.tint.lightened(0.6) if int(_state_left * 20.0) % 2 == 0 else data.tint
			sprite.position = Vector2(randf_range(-1, 1), 0)
			if _state_left <= 0.0:
				_start_lunge(to_player)
		State.LUNGE:
			velocity = _lunge_direction * data.lunge_speed
			if _state_left <= 0.0:
				_lunges_left -= 1
				if _lunges_left > 0 and player_ok:
					hitbox.active = data.contact_damage
					_enter(State.WINDUP, LUNGE_GAP)
				else:
					hitbox.active = data.contact_damage
					_attack_ready_in = data.attack_cooldown
					_enter(State.RECOVER, RECOVER_TIME)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_left <= 0.0:
				state = State.CHASE
		State.STAGGER:
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


func _start_lunge(to_player: Vector2) -> void:
	_lunge_direction = to_player.normalized()
	sprite.modulate = data.tint
	hitbox.active = true
	_enter(State.LUNGE, LUNGE_TIME)


func _pick_wander_target() -> void:
	_wander_target = home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_RADIUS
	_state_left = randf_range(2.0, 4.0)


func _animate(delta: float) -> void:
	var speed_factor := 2.0 if state == State.CHASE or state == State.LUNGE else 1.0
	_anim_time += delta * speed_factor
	sprite.frame = int(_anim_time / 0.25) % data.hframes
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0


# --- Getting hit -----------------------------------------------------------

func _on_hurt(from: Hitbox) -> void:
	if _dying:
		return
	var hit_direction := (global_position - from.global_position).normalized()
	var hit_point := global_position + Vector2(0, -_height / 2.0) - hit_direction * 6.0
	if _blocks(from):
		_knockback = hit_direction * from.knockback * 0.3
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -_height - 8), "Block!", Color(0.7, 0.85, 1))
		Feel.burst(get_parent(), hit_point, &"block", Color.WHITE, -hit_direction)
		Feel.shake(1.5, 0.1)
		Sfx.play(&"block", -6.0)
		# A block is followed by a quick counter-attack.
		_attack_ready_in = 0.0
		_lunges_left = 1
		_enter(State.WINDUP, data.attack_windup * 0.6)
		return
	hp -= from.damage
	_knockback = hit_direction * from.knockback * data.knockback_taken
	var big_hit := from.unblockable
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -_height - 8), str(from.damage),
			Color(1, 0.6, 0.3) if big_hit else Color(1, 0.95, 0.5))
	Feel.burst(get_parent(), hit_point, &"sparks", Color.WHITE, hit_direction)
	Feel.hit_stop(0.09 if big_hit else 0.05)
	Feel.shake(2.5 if big_hit else 1.2, 0.12)
	Sfx.play(&"heavy_hit" if big_hit else &"hit")
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", data.tint, 0.15)
	hitbox.active = data.contact_damage
	if state != State.STAGGER or big_hit:
		_enter(State.STAGGER, STAGGER_TIME * (1.6 if big_hit else 1.0))
	queue_redraw()
	if hp <= 0:
		_die()


## Bandits can block normal hits, but not the combo finisher or while attacking.
func _blocks(from: Hitbox) -> bool:
	if data.block_chance <= 0.0 or from.unblockable:
		return false
	if state == State.WINDUP or state == State.LUNGE or state == State.STAGGER:
		return false
	return randf() < data.block_chance


func _die() -> void:
	_dying = true
	hitbox.active = false
	hurtbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_drop_loot()
	_split()
	EventBus.enemy_killed.emit(data.id, group)
	Feel.burst(get_parent(), global_position + Vector2(0, -_height / 2.0), &"poof", data.tint)
	Feel.hit_stop(0.08)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.2) * data.sprite_scale, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func is_dying() -> bool:
	return _dying


## Big slimes burst into small ones.
func _split() -> void:
	if data.split_into == &"" or data.split_count <= 0:
		return
	var scene: PackedScene = load(ENEMY_SCENE)
	for i in data.split_count:
		var child: Enemy = scene.instantiate()
		var offset := Vector2(randf_range(-10, 10), randf_range(-6, 6))
		child.setup(Game.enemies[data.split_into], group, home)
		child.position = position + offset
		child._knockback = offset.normalized() * 120.0
		child.spawn_protection = 0.4
		child.state = State.CHASE
		get_parent().call_deferred("add_child", child)


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
	pickup.position = position
	get_parent().call_deferred("add_child", pickup)


## Small health bar once the enemy has been hit.
func _draw() -> void:
	if _dying or hp >= data.max_hp:
		return
	var top := -_height - 5.0
	draw_rect(Rect2(-10, top, 20, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-10, top, 20.0 * hp / data.max_hp, 3), Color(0.9, 0.25, 0.25))
