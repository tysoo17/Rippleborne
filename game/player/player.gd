class_name Player
extends CharacterBody2D
## The player character: walking, attacking, dashing, taking hits, interacting.
## HP, money and items live in Game.player (PlayerState), not in this node.
## The node's origin is at the character's feet (3/4 view).

## Sprite sheet rows, in order: down, left, right, up.
const ROWS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const WALK_FRAMES := 4
const WALK_FRAME_TIME := 0.13

@export var speed: float = 120.0
@export var dash_speed: float = 330.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.7
@export var attack_time: float = 0.14
@export var attack_cooldown: float = 0.32
@export var attack_reach: float = 18.0
@export var attack_knockback: float = 170.0
@export var hurt_invincibility: float = 0.8
## Share of gold lost when knocked out.
@export var knockout_gold_loss: float = 0.2

var facing: Vector2 = Vector2.DOWN

var _walk_time: float = 0.0
var _attack_left: float = 0.0
var _attack_ready_in: float = 0.0
var _dash_left: float = 0.0
var _dash_ready_in: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO
var _shake_left: float = 0.0
var _open_panels: int = 0
var _dead: bool = false
var _prompt_target: Interactable = null
var _prompt_text: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var slash: Sprite2D = $Slash
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.invincible_time = hurt_invincibility
	attack_hitbox.active = false
	attack_hitbox.knockback = attack_knockback
	slash.visible = false
	EventBus.panel_visibility_changed.connect(func(count: int): _open_panels = count)
	if Game.player.position.is_finite():
		global_position = Game.player.position


func is_dead() -> bool:
	return _dead


func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y


func _physics_process(delta: float) -> void:
	_attack_ready_in -= delta
	_dash_ready_in -= delta
	_update_attack(delta)
	_update_shake(delta)
	if _dead:
		return

	var input := Vector2.ZERO
	if _open_panels == 0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_direction * dash_speed
		if _dash_left <= 0.0:
			sprite.modulate.a = 1.0
	else:
		var slow := 0.5 if _attack_left > 0.0 else 1.0
		velocity = input * speed * slow + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	if input != Vector2.ZERO and _attack_left <= 0.0:
		facing = _four_way(input)
	_animate(delta, input != Vector2.ZERO)
	Game.player.position = global_position
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or _open_panels > 0:
		return
	if event.is_action_pressed("attack"):
		_attack()
	elif event.is_action_pressed("dash"):
		_dash()
	elif event.is_action_pressed("interact"):
		if _prompt_target != null:
			_prompt_target.interact(self)
	elif event.is_action_pressed("use_potion"):
		_drink_potion()


# --- Movement and animation ------------------------------------------------

func _four_way(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


func _animate(delta: float, moving: bool) -> void:
	var step := 0
	if moving:
		_walk_time += delta
		step = int(_walk_time / WALK_FRAME_TIME) % WALK_FRAMES
	else:
		_walk_time = 0.0
	sprite.frame = ROWS.find(facing) * WALK_FRAMES + step


# --- Attack and dash -------------------------------------------------------

func _attack() -> void:
	if _attack_ready_in > 0.0 or _dash_left > 0.0:
		return
	_attack_left = attack_time
	_attack_ready_in = attack_cooldown
	var offset := facing * attack_reach + Vector2(0, -14)
	attack_hitbox.position = offset
	attack_hitbox.damage = Game.player.attack_damage()
	attack_hitbox.active = true
	slash.position = offset
	slash.rotation = facing.angle()
	slash.visible = true
	Sfx.play(&"swing", -10.0)


func _update_attack(delta: float) -> void:
	if _attack_left <= 0.0:
		return
	_attack_left -= delta
	if _attack_left <= 0.0:
		attack_hitbox.active = false
		slash.visible = false


func _dash() -> void:
	if _dash_ready_in > 0.0:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input.normalized() if input != Vector2.ZERO else facing
	_dash_left = dash_time
	_dash_ready_in = dash_cooldown
	hurtbox.make_invincible(dash_time + 0.05)
	sprite.modulate.a = 0.6
	Sfx.play(&"dash", -12.0)


# --- Getting hurt ----------------------------------------------------------

func _on_hurt(hitbox: Hitbox) -> void:
	if _dead or _dash_left > 0.0:
		return
	Game.player.hp -= hitbox.damage
	_knockback = (global_position - hitbox.global_position).normalized() * hitbox.knockback
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -52), "-%d" % hitbox.damage, Color(1, 0.4, 0.4))
	Sfx.play(&"hurt")
	_shake_left = 0.2
	var tween := create_tween()
	sprite.modulate = Color(1, 0.3, 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if Game.player.hp <= 0:
		_knock_out()


func _update_shake(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	else:
		camera.offset = Vector2.ZERO


## HP reached 0: lose some gold, wake up at the inn next morning.
func _knock_out() -> void:
	_dead = true
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	attack_hitbox.active = false
	EventBus.player_died.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	await tween.finished
	var lost := int(Game.player.money * knockout_gold_loss)
	Game.player.money -= lost
	Game.player.hp = Game.player.max_hp
	var respawn := get_tree().get_first_node_in_group("respawn_point") as Node2D
	if respawn != null:
		global_position = respawn.global_position
	GameClock.advance_to_next_morning()
	EventBus.news.emit("You were knocked out and woke up at the inn. You lost %d gold." % lost, "warning")
	sprite.modulate = Color.WHITE
	hurtbox.make_invincible(1.5)
	_dead = false


# --- Items and interaction -------------------------------------------------

func _drink_potion() -> void:
	var potion: ItemData = Game.items[&"health_potion"]
	if Game.player.inventory.count_of(potion.id) == 0:
		EventBus.news.emit("No health potions. The Town market sells them.", "info")
		return
	var problem := Game.use_item(potion.id)
	if problem != "":
		EventBus.news.emit(problem, "info")
		return
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -52), "+%d" % potion.heal_amount, Color(0.5, 1, 0.5))


## Show "E: ..." for the nearest thing in reach.
func _update_prompt() -> void:
	var nearest: Interactable = null
	var best := INF
	for area in interact_area.get_overlapping_areas():
		var target := area as Interactable
		if target == null or not target.enabled:
			continue
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < best:
			best = distance
			nearest = target
	var text := "" if nearest == null else nearest.get_prompt()
	if nearest != _prompt_target or text != _prompt_text:
		_prompt_target = nearest
		_prompt_text = text
		EventBus.interact_prompt_changed.emit(text)
