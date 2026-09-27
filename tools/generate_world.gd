extends SceneTree
## Builds game/world/world_tileset.tres and game/world/world.tscn from the
## layout below.
##
## WARNING: this OVERWRITES world.tscn, including anything painted in the
## editor. Use it only to rebuild the map from scratch:
##   godot --headless --path . -s tools/generate_world.gd

const W := 110
const H := 62
const T := 32
const OUT_TILESET := "res://game/world/world_tileset.tres"
const OUT_SCENE := "res://game/world/world.tscn"

# Tile ids = column in assets/tiles/world_tiles.png
enum { GRASS, DIRT, STONE_WALL, COBBLE, CAVE_FLOOR, CAVE_ROCK, TREE, WATER, ROOF, HOUSE_WALL, DOOR, FENCE, FARMLAND, TENT }
const TILE_COUNT := 14
const SOLID_FULL := [STONE_WALL, CAVE_ROCK, WATER, ROOF, HOUSE_WALL, DOOR]

var ground := {}    # Vector2i -> tile id
var obstacle := {}  # Vector2i -> tile id
var reserved := {}  # cells where random trees must not grow
var rng := RandomNumberGenerator.new()

var world_root: Node2D
var entities: Node2D
var locations: Node2D

var npc_scene: PackedScene
var gather_scene: PackedScene


func _initialize() -> void:
	rng.seed = 7
	npc_scene = load("res://game/world/npc.tscn")
	gather_scene = load("res://game/world/gather_node.tscn")
	var tileset := _build_tileset()

	world_root = Node2D.new()
	world_root.name = "World"
	world_root.set_script(load("res://game/world/world.gd"))
	var ground_layer := TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = tileset
	_add(world_root, ground_layer)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	_add(world_root, entities)
	var obstacle_layer := TileMapLayer.new()
	obstacle_layer.name = "Obstacles"
	obstacle_layer.tile_set = tileset
	obstacle_layer.y_sort_enabled = true
	_add(entities, obstacle_layer)
	locations = Node2D.new()
	locations.name = "Locations"
	_add(world_root, locations)

	_layout()

	for y in H:
		for x in W:
			var cell := Vector2i(x, y)
			ground_layer.set_cell(cell, 0, Vector2i(ground.get(cell, GRASS), 0))
			if obstacle.has(cell):
				obstacle_layer.set_cell(cell, 0, Vector2i(obstacle[cell], 0))

	var player: Node2D = load("res://game/player/player.tscn").instantiate()
	player.position = _px(19, 31)
	_add(entities, player)
	var respawn := Marker2D.new()
	respawn.name = "RespawnPoint"
	respawn.position = _px(8, 18) + Vector2(0, 10)
	respawn.add_to_group("respawn_point", true)
	_add(entities, respawn)

	var packed := PackedScene.new()
	packed.pack(world_root)
	var err := ResourceSaver.save(packed, OUT_SCENE)
	print("world saved: ", err == OK, "  obstacles: ", obstacle.size())
	quit()


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	# Town
	_reserve(3, 10, 34, 48)
	_fence_box(3, 11, 33, 47, [Rect2i(33, 27, 1, 5), Rect2i(16, 47, 5, 1)])
	_ground(12, 23, 26, 33, COBBLE)
	_ground(27, 28, 33, 30, DIRT)
	_ground(17, 34, 19, 47, DIRT)
	_ground(5, 37, 13, 45, FARMLAND)
	_house(5, 13, 6, 4, 2)    # inn
	_house(26, 13, 6, 4, 2)   # blacksmith
	_house(14, 13, 5, 3, 2)
	_house(20, 13, 4, 3, 1)
	_house(5, 22, 5, 3, 2)
	_house(5, 28, 5, 3, 2)
	_house(28, 36, 5, 3, 2)
	_prop("Innkeeper", 8, 18, "npc_innkeeper", Vector2(14, 8), "Rest at the inn", &"inn", &"town")
	_prop("Blacksmith", 29, 18, "npc_blacksmith", Vector2(14, 8), "Talk to the blacksmith", &"blacksmith", &"town")
	_prop("TownMerchant", 19, 25, "npc_merchant", Vector2(14, 8))
	_prop("TownStall", 19, 26, "market_stall", Vector2(56, 10), "Trade at the market", &"shop", &"town")
	_prop("TownBoard", 23, 27, "market_board", Vector2(26, 6), "Read the market board", &"market_board", &"town")
	_prop("Farmer", 10, 35, "npc_villager", Vector2(14, 8))
	_location("Town", 3, 10, 34, 48)

	# Road and bandit camp
	_ground(34, 28, 86, 30, DIRT)
	_reserve(33, 26, 86, 32)
	_ground(52, 19, 60, 25, DIRT)
	_ground(55, 26, 56, 27, DIRT)
	_reserve(50, 17, 62, 27)
	_obstacle(53, 20, 53, 20, TENT)
	_obstacle(58, 20, 58, 20, TENT)
	_obstacle(51, 24, 51, 24, FENCE)
	_obstacle(61, 24, 61, 24, FENCE)
	_spawner("BanditCamp", 56, 22, &"bandit_camp", [&"bandit"], 0, 70.0, &"bandits_active")
	_location("Road", 34, 11, 78, 33)

	# Mining Village
	_reserve(78, 16, 107, 45)
	_ground(86, 26, 98, 33, DIRT)
	_house(80, 19, 5, 3, 2)
	_house(99, 19, 5, 3, 2)
	_house(80, 37, 5, 3, 2)
	_house(99, 37, 5, 3, 2)
	_house(90, 37, 5, 3, 2)
	_prop("VillageMerchant", 91, 27, "npc_merchant", Vector2(14, 8))
	_prop("VillageStall", 91, 28, "market_stall", Vector2(56, 10), "Trade at the market", &"shop", &"village")
	_prop("VillageBoard", 95, 29, "market_board", Vector2(26, 6), "Read the market board", &"market_board", &"village")
	_prop("Miner", 88, 32, "npc_villager", Vector2(14, 8))
	_prop("Villager", 97, 24, "npc_villager", Vector2(14, 8))
	_location("Mining Village", 78, 14, 107, 45)

	# Mine: rock walls around a cave, entrance at the bottom middle
	_ground(91, 13, 93, 25, DIRT)
	_reserve(79, 0, 107, 15)
	_ground(80, 1, 106, 13, CAVE_FLOOR)
	for x in range(80, 107):
		obstacle[Vector2i(x, 1)] = CAVE_ROCK
		if x < 91 or x > 93:
			obstacle[Vector2i(x, 13)] = CAVE_ROCK
	for y in range(1, 14):
		obstacle[Vector2i(80, y)] = CAVE_ROCK
		obstacle[Vector2i(106, y)] = CAVE_ROCK
	for cell in [Vector2i(85, 5), Vector2i(86, 5), Vector2i(100, 8), Vector2i(101, 8), Vector2i(95, 4), Vector2i(89, 9)]:
		obstacle[cell] = CAVE_ROCK
	_gather("Ore1", "ore_1", 84, 10, "ore_rock", &"iron", 2, 2, "Dig iron ore", true)
	_gather("Ore2", "ore_2", 97, 3, "ore_rock", &"iron", 2, 2, "Dig iron ore", true)
	_gather("Ore3", "ore_3", 103, 11, "ore_rock", &"iron", 2, 2, "Dig iron ore", true)
	_gather("Ore4", "ore_4", 88, 3, "ore_rock", &"iron", 2, 2, "Dig iron ore", true)
	_spawner("MineMonsters", 93, 7, &"mine", [&"cave_slime"], 0, 90.0, &"mine_infested")
	_location("Mine", 79, 0, 107, 13)

	# Forest: paths and clearings first, then trees everywhere else
	_ground(17, 48, 19, 52, DIRT)
	_ground(17, 51, 72, 52, DIRT)
	_ground(45, 31, 46, 50, DIRT)
	_reserve(16, 47, 73, 53)
	_reserve(44, 30, 47, 51)
	for clearing in [Rect2i(29, 53, 9, 6), Rect2i(55, 37, 10, 8), Rect2i(65, 53, 9, 6), Rect2i(22, 42, 6, 4)]:
		_reserve(clearing.position.x, clearing.position.y, clearing.end.x, clearing.end.y)
	_ground(48, 55, 52, 57, WATER)
	_reserve(47, 54, 53, 58)
	_gather("Herb1", "herb_1", 31, 55, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Herb2", "herb_2", 35, 57, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Herb3", "herb_3", 57, 39, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Herb4", "herb_4", 63, 43, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Herb5", "herb_5", 67, 55, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Herb6", "herb_6", 24, 43, "herb_bush", &"herbs", 2, 2, "Pick herbs")
	_gather("Logs1", "logs_1", 33, 54, "log_pile", &"wood", 3, 3, "Collect wood")
	_gather("Logs2", "logs_2", 60, 42, "log_pile", &"wood", 3, 3, "Collect wood")
	_gather("Logs3", "logs_3", 71, 57, "log_pile", &"wood", 3, 3, "Collect wood")
	_gather("Logs4", "logs_4", 40, 50, "log_pile", &"wood", 3, 3, "Collect wood")
	_spawner("ForestSlimes", 33, 56, &"forest", [&"slime"], 3, 60.0)
	_spawner("ForestDeep", 60, 41, &"forest", [&"wolf", &"slime"], 3, 70.0)
	_spawner("ForestWolves", 69, 55, &"forest", [&"wolf"], 2, 60.0)
	_spawner("ForestEdge", 25, 44, &"forest", [&"slime"], 2, 40.0)
	_location("Forest", 3, 48, 79, 61)
	_location("Forest", 34, 34, 78, 47)

	# Map border and wild trees
	for y in H:
		for x in W:
			var cell := Vector2i(x, y)
			if x < 2 or x >= W - 2 or y < 1 or y >= H - 2:
				if not obstacle.has(cell):
					obstacle[cell] = TREE
				continue
			if reserved.has(cell) or obstacle.has(cell) or ground.get(cell, GRASS) != GRASS:
				continue
			var in_forest := (y >= 48 and x < 79) or (y >= 34 and x >= 34 and x < 79)
			if rng.randf() < (0.24 if in_forest else 0.05):
				obstacle[cell] = TREE


# --- Helpers ---------------------------------------------------------------

func _px(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T - 2.0)


func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = world_root


func _ground(x0: int, y0: int, x1: int, y1: int, tile: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			ground[Vector2i(x, y)] = tile


func _obstacle(x0: int, y0: int, x1: int, y1: int, tile: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			obstacle[Vector2i(x, y)] = tile


func _reserve(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			reserved[Vector2i(x, y)] = true


func _fence_box(x0: int, y0: int, x1: int, y1: int, gaps: Array) -> void:
	for x in range(x0, x1 + 1):
		for y in [y0, y1]:
			obstacle[Vector2i(x, y)] = FENCE
	for y in range(y0, y1 + 1):
		for x in [x0, x1]:
			obstacle[Vector2i(x, y)] = FENCE
	for gap: Rect2i in gaps:
		for y in range(gap.position.y, gap.end.y):
			for x in range(gap.position.x, gap.end.x):
				obstacle.erase(Vector2i(x, y))


## Roof rows on top, one wall row with a door at the bottom.
func _house(x: int, y: int, w: int, h: int, door_dx: int) -> void:
	_obstacle(x, y, x + w - 1, y + h - 2, ROOF)
	_obstacle(x, y + h - 1, x + w - 1, y + h - 1, HOUSE_WALL)
	obstacle[Vector2i(x + door_dx, y + h - 1)] = DOOR


func _prop(node_name: String, x: int, y: int, texture: String, body: Vector2,
		prompt := "", panel := &"", settlement := &"") -> void:
	var prop = npc_scene.instantiate()
	prop.name = node_name
	prop.position = _px(x, y)
	prop.texture = load("res://assets/sprites/%s.png" % texture)
	prop.body_size = body
	prop.prompt = prompt
	prop.panel = panel
	prop.settlement_id = settlement
	_add(entities, prop)


func _gather(node_name: String, id: String, x: int, y: int, texture: String, item: StringName,
		amount: int, regrow: int, verb: String, needs_safe_mine := false) -> void:
	var node = gather_scene.instantiate()
	node.name = node_name
	node.position = _px(x, y)
	node.node_id = id
	node.texture = load("res://assets/sprites/%s.png" % texture)
	node.item_id = item
	node.amount = amount
	node.regrow_days = regrow
	node.verb = verb
	node.needs_safe_mine = needs_safe_mine
	_add(entities, node)
	_reserve(x - 1, y - 1, x + 1, y + 1)


func _spawner(node_name: String, x: int, y: int, group: StringName, ids: Array[StringName],
		count: int, radius: float, condition := &"") -> void:
	var spawner = Node2D.new()
	spawner.name = node_name
	spawner.set_script(load("res://game/combat/enemy_spawner.gd"))
	spawner.position = _px(x, y)
	spawner.group = group
	spawner.enemy_ids = ids
	spawner.count = count
	spawner.radius = radius
	spawner.condition = condition
	spawner.y_sort_enabled = true
	_add(entities, spawner)


func _location(location_name: String, x0: int, y0: int, x1: int, y1: int) -> void:
	var area = Area2D.new()
	area.name = location_name.replace(" ", "") + "Area"
	area.set_script(load("res://game/world/location_area.gd"))
	area.location_name = location_name
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2((x1 - x0 + 1) * T, (y1 - y0 + 1) * T)
	shape.shape = rect
	shape.position = Vector2(x0 * T, y0 * T) + rect.size / 2.0
	var suffix := 2
	while locations.has_node(NodePath(area.name)):
		area.name = location_name.replace(" ", "") + "Area%d" % suffix
		suffix += 1
	_add(locations, area)
	_add(area, shape)


# --- Tileset ---------------------------------------------------------------

func _build_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/tiles/world_tiles.png")
	source.texture_region_size = Vector2i(T, T)
	for i in TILE_COUNT:
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)
	var h := T / 2.0
	for i in TILE_COUNT:
		var tile := source.get_tile_data(Vector2i(i, 0), 0)
		var points := PackedVector2Array()
		if i in SOLID_FULL:
			points = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
		elif i == TREE:
			points = [Vector2(-6, 2), Vector2(6, 2), Vector2(6, 14), Vector2(-6, 14)]
		elif i == FENCE:
			points = [Vector2(-h, -6), Vector2(h, -6), Vector2(h, 10), Vector2(-h, 10)]
		elif i == TENT:
			points = [Vector2(-14, -2), Vector2(14, -2), Vector2(14, 14), Vector2(-14, 14)]
		if not points.is_empty():
			tile.add_collision_polygon(0)
			tile.set_collision_polygon_points(0, 0, points)
			# Things drawn in the y-sorted Obstacles layer sort by their base.
			tile.y_sort_origin = 14
	ResourceSaver.save(tileset, OUT_TILESET)
	return load(OUT_TILESET)
