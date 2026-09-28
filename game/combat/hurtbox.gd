class_name Hurtbox
extends Area2D
## The part of a character that can be hit. Every physics frame it looks for
## an active Hitbox; after a hit it ignores new hits for a short while.

signal hurt(hitbox: Hitbox)

## Seconds of immunity after being hit.
@export var invincible_time: float = 0.3

var _invincible_left: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	if not monitoring:
		return
	if _invincible_left > 0.0:
		_invincible_left -= delta
		return
	for area in get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox != null and hitbox.active and hitbox.damage > 0:
			_invincible_left = invincible_time
			hurt.emit(hitbox)
			return


func make_invincible(seconds: float) -> void:
	_invincible_left = maxf(_invincible_left, seconds)


func is_invincible() -> bool:
	return _invincible_left > 0.0
