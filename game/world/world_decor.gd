class_name WorldDecor
extends RefCounted
## Dresses up the map when it loads, from whatever is painted in the Ground
## layer, so it keeps working after you edit the map by hand:
## - grass edges that overlap dirt, cobble, fields and water (no hard squares)
## - flowers, pebbles and grass tufts scattered on the grass
## - moving highlights on the water
## - street lamps on the plazas that light up at night, and a small lantern
##   around the player

const T := 32
# Ground tile ids = column in world_tiles.png
const GRASS := 0
const EDGED := [1, 3, 7, 12]  # dirt, cobble, water, farmland
const WATER := 7
## Share of grass cells that get a flower or pebble.
const DECOR_DENSITY := 0.11
const DECOR_KINDS := 8
## Plaza corners (tile coordinates) that get a street lamp.
const LAMPS := [Vector2i(12, 23), Vector2i(26, 23), Vector2i(12, 33), Vector2i(26, 33),
		Vector2i(86, 26), Vector2i(98, 26), Vector2i(86, 33), Vector2i(98, 33)]


static func decorate(world: Node2D) -> void:
	var ground: TileMapLayer = world.get_node("Ground")
	var obstacles: TileMapLayer = world.get_node("Entities/Obstacles")
	var edges := _layer("GrassEdges", "res://assets/tiles/grass_edges.png", 16)
	var water := _layer("WaterShine", "res://assets/tiles/water_anim.png", 1, 3)
	var decor := _layer("Decor", "res://assets/tiles/decor.png", DECOR_KINDS)
	for layer in [decor, water, edges]:
		world.add_child(layer)
		world.move_child(layer, 1)

	for cell in ground.get_used_cells():
		var tile := ground.get_cell_atlas_coords(cell).x
		if tile in EDGED:
			var mask := 0
			for side in 4:
				var neighbour: Vector2i = cell + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][side]
				if ground.get_cell_atlas_coords(neighbour).x == GRASS:
					mask |= 1 << side
			if mask != 0:
				edges.set_cell(cell, 0, Vector2i(mask, 0))
		if tile == WATER:
			water.set_cell(cell, 0, Vector2i.ZERO)
		elif tile == GRASS and obstacles.get_cell_source_id(cell) == -1:
			var roll := _hash01(cell)
			if roll < DECOR_DENSITY:
				decor.set_cell(cell, 0, Vector2i(int(roll / DECOR_DENSITY * DECOR_KINDS), 0))

	var entities: Node2D = world.get_node("Entities")
	for spot in LAMPS:
		entities.add_child(_lamp(Vector2(spot.x * T + T / 2.0, spot.y * T + T - 2.0)))
	var player := world.get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.add_child(_light(0.9, Color(1.0, 0.9, 0.7), Vector2(0, -16), 0.5))


## A TileMapLayer with its own one-row atlas. frames > 1 makes tile 0 animated.
static func _layer(layer_name: String, texture_path: String, tiles: int, frames: int = 1) -> TileMapLayer:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(T, T)
	for i in tiles:
		source.create_tile(Vector2i(i, 0))
	if frames > 1:
		source.set_tile_animation_columns(Vector2i.ZERO, frames)
		source.set_tile_animation_frames_count(Vector2i.ZERO, frames)
		for f in frames:
			source.set_tile_animation_frame_duration(Vector2i.ZERO, f, 0.45)
	tileset.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	return layer


## Same cell -> same number every time, so the decoration never changes.
static func _hash01(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	return float(absi(h) % 10000) / 10000.0


static func _lamp(at: Vector2) -> Node2D:
	var lamp := Node2D.new()
	lamp.name = "Lamp"
	lamp.add_to_group("lamps")
	lamp.position = at
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/lamp.png")
	sprite.offset = Vector2(0, -22)
	lamp.add_child(sprite)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	shape.position = Vector2(0, -2)
	body.add_child(shape)
	lamp.add_child(body)
	lamp.add_child(_light(1.4, Color(1.0, 0.78, 0.45), Vector2(0, -36), 0.7))
	return lamp


## A warm light that only shines when it is dark (see NightLight).
static func _light(size: float, color: Color, offset: Vector2, strength: float) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = size
	light.color = color
	light.position = offset
	light.set_script(preload("res://game/world/night_light.gd"))
	light.max_energy = strength
	return light
