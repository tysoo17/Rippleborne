extends CharacterBody2D
## Player movement for the 3/4 top-down view.
## The node's origin sits at the character's feet, and so does the collision box.

## Pixels per second. One tile is 32 px, so 120 is almost 4 tiles per second.
@export var speed: float = 120.0


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
