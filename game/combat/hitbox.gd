class_name Hitbox
extends Area2D
## An area that hurts any Hurtbox overlapping it while `active` is true.
## The Hurtbox does the detecting; this only carries the numbers.

@export var damage: int = 1
@export var knockback: float = 150.0
@export var active: bool = true


func _ready() -> void:
	monitoring = false
	monitorable = true
