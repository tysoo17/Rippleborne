class_name Player
extends CharacterBody2D
## The player character: walking, attacking, dashing, taking hits, interacting.
## HP, money and items live in Game.player (PlayerState), not in this node.
## The node's origin is at the character's feet (3/4 view).

## Sprite sheet rows, in order: down, left, right, up.
const ROWS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const WALK_FRAMES := 4
const WALK_FRAME_TIME := 0.13
const SLASH_FRAMES := 4
## Height of the sword arm above the feet.
const HAND_HEIGHT := 14.0

@export_group("Movement")
@export var speed: float = 120.0
## How fast the character reaches full speed (pixels/s per second).
@export var acceleration: float = 1300.0
## How fast the character stops when you let go.
@export var friction: float = 1500.0
@export var dash_speed: float = 330.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.7
## How far the camera looks ahead in the walking direction.
@export var camera_lead: float = 22.0

@export_group("Attack")
@export var attack_time: float = 0.14
@export var attack_cooldown: float = 0.26
## After a swing, pressing attack within this time continues the combo.
@export var combo_window: float = 0.45
## Pressing attack this early (before the cooldown ends) still counts.
@export var input_buffer: float = 0.15
@export var attack_reach: float = 18.0
@export var attack_knockback: float = 170.0
## Small step forward with every swing.
@export var attack_step: float = 90.0

@export_group("Getting hurt")
@export var hurt_invincibility: float = 0.8
## Share of gold lost when knocked out.
@export var knockout_gold_loss: float = 0.2

var facing: Vector2 = Vector2.DOWN
## 0, 1 or 2: which swing of the combo comes next. The third one is strong.
var combo_step: int = 0

var _walk_time: float = 0.0
var _dust_timer: float = 0.0
var _attack_left: float = 0.0
var _attack_ready_in: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _combo_left: float = 0.0
var _buffered_attack: bool = false
var _buffered_with_mouse: bool = false
var _dash_left: float = 0.0
var _dash_ready_in: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _afterimage_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _move_velocity: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
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
@onready var _camera_base: Vector2 = camera.position


func _ready() -> void:
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.invincible_time = hurt_invincibility
	attack_hitbox.active = false
	slash.visible = false
	slash.hframes = SLASH_FRAMES
	EventBus.panel_visibility_changed.connect(func(count: int): _open_panels = count)
	EventBus.camera_shake.connect(_on_camera_shake)
	if Game.player.position.is_finite():
		global_position = Game.player.position
	reset_physics_interpolation()


func is_dead() -> bool:
	return _dead


func is_attacking() -> bool:
	return _attack_left > 0.0


func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y


func _physics_process(delta: float) -> void:
	_attack_ready_in -= delta
	_dash_ready_in -= delta
	_combo_left -= delta
	_update_attack(delta)
	_update_camera(delta)
	if _dead:
		return
	if _buffered_attack and _attack_ready_in <= 0.0:
		_buffered_attack = false
		_attack(_buffered_with_mouse)

	var input := Vector2.ZERO
	if _open_panels == 0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_left > 0.0:
		_update_dash(delta)
	else:
		var target := input * speed * (0.45 if _attack_left > 0.0 else 1.0)
		var rate := acceleration if input != Vector2.ZERO else friction
		_move_velocity = _move_velocity.move_toward(target, rate * delta)
		velocity = _move_velocity + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	_move_velocity = _move_velocity.limit_length(get_real_velocity().length() + 1.0)

	if input != Vector2.ZERO and _attack_left <= 0.0:
		facing = _four_way(input)
	_animate(delta, _move_velocity.length() > 10.0)
	Game.player.position = global_position
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or _open_panels > 0:
		return
	if event.is_action_pressed("attack"):
		var with_mouse := event is InputEventMouseButton
		if _attack_ready_in <= 0.0:
			_attack(with_mouse)
		elif _attack_ready_in <= input_buffer:
			_buffered_attack = true
			_buffered_with_mouse = with_mouse
	elif event.is_action_pressed("dash"):
		_dash()
	elif event.is_action_pressed("interact"):
		if _prompt_target != null:
			_prompt_target.interact(self)
	elif event.is_action_pressed("use_potion"):
		_drink_potion()


# --- Movement, animation and camera ----------------------------------------

func _four_way(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


func _animate(delta: float, moving: bool) -> void:
	var step := 0
	if moving:
		_walk_time += delta
		step = int(_walk_time / WALK_FRAME_TIME) % WALK_FRAMES
		_dust_timer -= delta
		if _dust_timer <= 0.0 and _move_velocity.length() > speed * 0.8:
			_dust_timer = 0.3
			Feel.burst(get_parent(), global_position, &"dust")
	else:
		_walk_time = 0.0
	sprite.frame = ROWS.find(facing) * WALK_FRAMES + step


## Camera leans toward where you walk, and shakes when asked.
func _update_camera(delta: float) -> void:
	var lead := Vector2.ZERO
	if _move_velocity.length() > 10.0:
		lead = _move_velocity.normalized() * camera_lead
	camera.position = camera.position.lerp(_camera_base + lead, clampf(3.0 * delta, 0.0, 1.0))
	if _shake_left > 0.0:
		_shake_left -= delta
		var strength := _shake_strength * clampf(_shake_left / 0.2, 0.3, 1.0)
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	else:
		camera.offset = Vector2.ZERO


func _on_camera_shake(strength: float, seconds: float) -> void:
	if strength >= _shake_strength or _shake_left <= 0.0:
		_shake_strength = strength
	_shake_left = maxf(_shake_left, seconds)


# --- Attack ----------------------------------------------------------------

## Swing the sword. With the mouse it goes toward the cursor, otherwise
## toward where you are walking (or facing).
func _attack(with_mouse: bool = false) -> void:
	if _dash_left > 0.0:
		return
	var hand := global_position + Vector2(0, -HAND_HEIGHT)
	var aim := facing
	if with_mouse:
		aim = (get_global_mouse_position() - hand).normalized()
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input != Vector2.ZERO:
			aim = input.normalized()
	if aim == Vector2.ZERO:
		aim = facing
	_attack_direction = aim
	facing = _four_way(aim)

	combo_step = combo_step + 1 if _combo_left > 0.0 and combo_step < 2 else 0
	var finisher := combo_step == 2
	_attack_left = attack_time * (1.3 if finisher else 1.0)
	_attack_ready_in = attack_cooldown * (1.6 if finisher else 1.0)
	_combo_left = combo_window + _attack_left

	var offset := aim * attack_reach * (1.2 if finisher else 1.0) + Vector2(0, -HAND_HEIGHT)
	attack_hitbox.position = offset
	attack_hitbox.damage = Game.player.attack_damage() + (1 if finisher else 0)
	attack_hitbox.knockback = attack_knockback * (1.9 if finisher else 1.0)
	attack_hitbox.unblockable = finisher
	attack_hitbox.active = true
	slash.position = offset
	slash.rotation = aim.angle()
	slash.flip_v = combo_step == 1  # alternate the swing direction
	slash.scale = Vector2.ONE * (1.35 if finisher else 1.0)
	slash.frame = 0
	slash.visible = true
	_move_velocity = aim * attack_step * (1.6 if finisher else 1.0)
	sprite.scale = Vector2(1.12, 0.9)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.12)
	Sfx.play(&"swing", -8.0 if finisher else -10.0, 0.1)


func _update_attack(delta: float) -> void:
	if _attack_left <= 0.0:
		return
	_attack_left -= delta
	var total := attack_time * (1.3 if combo_step == 2 else 1.0)
	slash.frame = clampi(int((1.0 - _attack_left / total) * SLASH_FRAMES), 0, SLASH_FRAMES - 1)
	if _attack_left <= 0.0:
		attack_hitbox.active = false
		slash.visible = false


# --- Dash ------------------------------------------------------------------

func _dash() -> void:
	if _dash_ready_in > 0.0:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input.normalized() if input != Vector2.ZERO else facing
	_dash_left = dash_time
	_dash_ready_in = dash_cooldown
	_afterimage_timer = 0.0
	hurtbox.make_invincible(dash_time + 0.05)
	Feel.burst(get_parent(), global_position, &"dust", Color.WHITE, -_dash_direction)
	Sfx.play(&"dash", -12.0)


func _update_dash(delta: float) -> void:
	_dash_left -= delta
	velocity = _dash_direction * dash_speed
	_move_velocity = _dash_direction * speed
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = 0.03
		_spawn_afterimage()


## A fading copy of the sprite left behind while dashing.
func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.offset = sprite.offset
	ghost.global_position = global_position
	ghost.modulate = Color(0.55, 0.75, 1.0, 0.55)
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


# --- Getting hurt ----------------------------------------------------------

func _on_hurt(hitbox: Hitbox) -> void:
	if _dead or _dash_left > 0.0:
		return
	Game.player.hp -= hitbox.damage
	_knockback = (global_position - hitbox.global_position).normalized() * hitbox.knockback
	_move_velocity = Vector2.ZERO
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -52), "-%d" % hitbox.damage, Color(1, 0.4, 0.4))
	Sfx.play(&"hurt")
	Feel.hit_stop(0.08)
	Feel.shake(3.0, 0.25)
	var tween := create_tween()
	sprite.modulate = Color(1, 0.3, 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if Game.player.hp <= 0:
		_knock_out()


## HP reached 0: lose some gold, wake up at the inn next morning.
func _knock_out() -> void:
	_dead = true
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_move_velocity = Vector2.ZERO
	attack_hitbox.active = false
	slash.visible = false
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
		reset_physics_interpolation()
		camera.reset_physics_interpolation()
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
