class_name Hitbox
extends Area2D
## An area that hurts any Hurtbox overlapping it while `active` is true.
## The Hurtbox does the detecting; this only carries the numbers.

@export var damage: int = 1
@export var knockback: float = 150.0
@export var active: bool = true
## Enemies that can block (bandits) cannot block this hit (combo finisher).
@export var unblockable: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
