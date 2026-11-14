@tool
extends Node2D
## Builds the Mars map: ground tiles, rock border, resource nodes and decoration.
##
## In the editor: select the World node and click "Generate Map" in the Inspector.
##   The result is saved into World.tscn, so you can then touch up tiles by hand.
## When the game runs: if Ground is empty, the map is generated automatically.
## Same seed = same map every time (so balance is testable).

const TILE := 16
const MAP_SIZE := Vector2i(48, 32)          # in tiles -> 768 x 512 pixels
const HAB_TILE := Vector2i(24, 16)          # map centre
const LAUNCH_PAD_TILE := Vector2i(40, 6)
const SOURCE_ID := 0                         # the atlas inside mars_tileset.tres

# Atlas coordinates in art/atlases/terrain_paths_autotile_16px.png (column, row)
const T_REGOLITH := Vector2i(0, 0)
const T_ORANGE_SAND := Vector2i(1, 0)
const T_CRACKED := Vector2i(2, 0)
const T_WALL_ROCK := Vector2i(4, 0)         # has collision in the TileSet
const T_PEBBLES := Vector2i(3, 1)
const T_ROCKY := Vector2i(4, 1)
const T_CRATERS := Vector2i(5, 1)
const T_RIPPLES := Vector2i(6, 1)

# How many resource nodes go in each distance ring around the hab: [min, max, metal, ice]
const RINGS := [
	[4.0, 8.0, 3, 2],     # close: first minutes are playable
	[8.0, 14.0, 4, 3],
	[14.0, 22.0, 5, 3],   # far: forces exploring
]
const MIN_NODE_GAP := 3.0                   # tiles between any two nodes

const TEX_METAL := preload("res://art/decor/ore_rock.png")
const TEX_ICE := preload("res://art/decor/ice_crystal_cluster.png")
const TEX_ROCKS := [
	preload("res://art/decor/small_rock.png"),
	preload("res://art/decor/rock_cluster_small.png"),
	preload("res://art/decor/rock_cluster_large.png"),
]
const TEX_CRATERS := [
	preload("res://art/craters/crater_single.png"),
	preload("res://art/craters/crater_2x2.png"),
	preload("res://art/craters/crater_3x3.png"),
]
const SPRITE_SCALE := Vector2(0.25, 0.25)   # decor art is drawn ~4x larger than tiles

@export var map_seed: int = 1337
@export var rock_count: int = 14
@export var crater_count: int = 8
@export var camera_zoom: float = 2.0
@export_tool_button("Generate Map", "TileMapLayer") var generate_button: Callable = generate


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if (get_node("Ground") as TileMapLayer).get_used_cells().is_empty():
		generate()
	_setup_camera()


func generate() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var walls := get_node("Walls") as TileMapLayer
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.08

	_paint_ground(ground, noise, rng)
	_paint_walls(walls)

	var nodes := get_node("Entities/Nodes")
	var decor := get_node("Entities/Decor")
	var craters := get_node("GroundDecor")
	for container in [nodes, decor, craters]:
		_clear_children(container)

	# Tiles nothing else may use: hab footprint (3x3) and launch pad (3x3).
	var taken: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			taken.append(HAB_TILE + Vector2i(dx, dy))
			taken.append(LAUNCH_PAD_TILE + Vector2i(dx, dy))

	var metal_i := 0
	var ice_i := 0
	for ring in RINGS:
		for i in ring[2]:
			metal_i += 1
			_place_sprite(nodes, "Metal%02d" % metal_i, TEX_METAL, SPRITE_SCALE,
				_pick_tile(rng, taken, ring[0], ring[1], MIN_NODE_GAP), "metal")
		for i in ring[3]:
			ice_i += 1
			_place_sprite(nodes, "Ice%02d" % ice_i, TEX_ICE, SPRITE_SCALE,
				_pick_tile(rng, taken, ring[0], ring[1], MIN_NODE_GAP), "ice")

	for i in rock_count:
		var tex: Texture2D = TEX_ROCKS[rng.randi() % TEX_ROCKS.size()]
		_place_sprite(decor, "Rock%02d" % (i + 1), tex, SPRITE_SCALE,
			_pick_tile(rng, taken, 5.0, 40.0, 2.0), "")
	for i in crater_count:
		var tex: Texture2D = TEX_CRATERS[rng.randi() % TEX_CRATERS.size()]
		_place_sprite(craters, "Crater%02d" % (i + 1), tex, Vector2(0.3, 0.3),
			_pick_tile(rng, taken, 6.0, 40.0, 4.0), "")


func _paint_ground(ground: TileMapLayer, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	ground.clear()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			var n := noise.get_noise_2d(x, y)
			var tile := T_REGOLITH
			if n > 0.38:
				tile = T_ORANGE_SAND
			elif n > 0.24:
				tile = T_RIPPLES
			elif n < -0.4:
				tile = T_CRACKED
			else:
				var r := rng.randf()
				if r < 0.08:
					tile = T_PEBBLES
				elif r < 0.11:
					tile = T_CRATERS
				elif r < 0.13:
					tile = T_ROCKY
			ground.set_cell(Vector2i(x, y), SOURCE_ID, tile)


func _paint_walls(walls: TileMapLayer) -> void:
	walls.clear()
	for x in MAP_SIZE.x:
		walls.set_cell(Vector2i(x, 0), SOURCE_ID, T_WALL_ROCK)
		walls.set_cell(Vector2i(x, MAP_SIZE.y - 1), SOURCE_ID, T_WALL_ROCK)
	for y in MAP_SIZE.y:
		walls.set_cell(Vector2i(0, y), SOURCE_ID, T_WALL_ROCK)
		walls.set_cell(Vector2i(MAP_SIZE.x - 1, y), SOURCE_ID, T_WALL_ROCK)


## Random tile inside the map (not on the border), between min_d and max_d tiles
## from the hab, at least `gap` tiles from everything already taken.
func _pick_tile(rng: RandomNumberGenerator, taken: Array[Vector2i], min_d: float, max_d: float, gap: float) -> Vector2i:
	for attempt in 1000:
		var t := Vector2i(rng.randi_range(2, MAP_SIZE.x - 3), rng.randi_range(2, MAP_SIZE.y - 3))
		var d := Vector2(t - HAB_TILE).length()
		if d < min_d or d > max_d:
			continue
		var ok := true
		for o in taken:
			if Vector2(t - o).length() < gap:
				ok = false
				break
		if ok:
			taken.append(t)
			return t
	push_warning("world_gen: could not find a free tile, map may be too crowded")
	return Vector2i(-1, -1)


func _place_sprite(parent: Node, node_name: String, tex: Texture2D, scl: Vector2, tile: Vector2i, kind: String) -> void:
	if tile.x < 0:
		return
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.scale = scl
	s.position = Vector2(tile * TILE) + Vector2(TILE, TILE) * 0.5
	if kind != "":
		s.set_meta("kind", kind)   # "metal" or "ice"; PART 3/4 turns these into ResourceNodes
	parent.add_child(s)
	s.owner = _scene_owner()


func _clear_children(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


## Nodes must be owned by the scene root to be saved in World.tscn.
func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree() != null:
		return get_tree().edited_scene_root
	return self


func _setup_camera() -> void:
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_SIZE.x * TILE
	cam.limit_bottom = MAP_SIZE.y * TILE
	cam.zoom = Vector2(camera_zoom, camera_zoom)
