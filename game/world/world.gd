extends Node2D
## The game world: ground tiles, obstacles, NPCs, gather spots, enemy
## spawners and named areas. First built by tools/generate_world.gd, then
## free to edit in the editor.

## Map size in tiles (32 px each); the camera never shows beyond it.
@export var map_size: Vector2i = Vector2i(110, 62)


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.set_camera_limits(Rect2i(Vector2i.ZERO, map_size * 32))
