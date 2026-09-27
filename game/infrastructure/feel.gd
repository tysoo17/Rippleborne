extends Node
## "Game feel" helpers (autoload "Feel"): hit-stop, camera shake, particles.
## Small effects, but they are what makes a hit feel like a hit.
##
##   Feel.hit_stop(0.06)                 freeze the action for a moment
##   Feel.shake(3.0, 0.2)                shake the camera (pixels, seconds)
##   Feel.burst(parent, pos, &"sparks")  spray of particles

## Speed of the game during hit-stop (almost frozen).
const STOP_TIME_SCALE := 0.05

## Particle recipes: amount, speed range, lifetime, size range, colours, upward drift.
const BURSTS := {
	&"sparks": {"amount": 10, "speed": Vector2(70, 140), "life": 0.22, "size": Vector2(1, 2),
			"from": Color(1, 1, 0.8), "to": Color(1, 0.6, 0.2, 0), "rise": 0.0},
	&"dust": {"amount": 4, "speed": Vector2(8, 22), "life": 0.4, "size": Vector2(2, 3),
			"from": Color(0.8, 0.72, 0.6, 0.8), "to": Color(0.8, 0.72, 0.6, 0), "rise": 18.0},
	&"poof": {"amount": 16, "speed": Vector2(40, 90), "life": 0.45, "size": Vector2(2, 4),
			"from": Color(1, 1, 1), "to": Color(1, 1, 1, 0), "rise": 10.0},
	&"block": {"amount": 8, "speed": Vector2(50, 100), "life": 0.2, "size": Vector2(1, 2),
			"from": Color(0.8, 0.9, 1), "to": Color(0.6, 0.7, 1, 0), "rise": 0.0},
}

var _stop_until: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freeze the game for a moment (real seconds). Calls while frozen extend it.
func hit_stop(seconds: float = 0.06) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _stop_until:
		return
	var already_stopped := _stop_until > Time.get_ticks_msec()
	_stop_until = until
	if already_stopped:
		return
	Engine.time_scale = STOP_TIME_SCALE
	while Time.get_ticks_msec() < _stop_until:
		await get_tree().process_frame
	Engine.time_scale = 1.0


## Ask the player's camera to shake. strength in pixels.
func shake(strength: float, seconds: float = 0.2) -> void:
	EventBus.camera_shake.emit(strength, seconds)


## One-shot particles at a world position. tint multiplies the recipe colours.
func burst(parent: Node, at: Vector2, kind: StringName, tint: Color = Color.WHITE, direction: Vector2 = Vector2.ZERO) -> void:
	var recipe: Dictionary = BURSTS[kind]
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = recipe.amount
	particles.lifetime = recipe.life
	particles.initial_velocity_min = recipe.speed.x
	particles.initial_velocity_max = recipe.speed.y
	particles.scale_amount_min = recipe.size.x
	particles.scale_amount_max = recipe.size.y
	particles.gravity = Vector2(0, -recipe.rise)
	particles.damping_min = 40.0
	particles.damping_max = 80.0
	if direction == Vector2.ZERO:
		particles.spread = 180.0
	else:
		particles.direction = direction
		particles.spread = 50.0
	var ramp := Gradient.new()
	ramp.set_color(0, recipe.from * tint)
	ramp.set_color(1, recipe.to * tint)
	particles.color_ramp = ramp
	particles.position = at
	particles.z_index = 5
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
