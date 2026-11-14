@tool
extends Node2D
## Builds the SURFACE map: the base around the crash site.
##
## What is on it:
##   - the hab on a sand plaza, with a street running past it
##   - marked BUILD PADS on both sides of the street (machines go there)
##   - the launch pad on its own plaza at the east end of the street
##   - the crashed rocket in the north-west
##   - one dark CAVE ENTRANCE per cave in Config.CAVES, each at the end of a trail
##   - a few starter deposits far from the hab (the rest of the loot is in the caves)
##   - rocks, rock pillars, craters and debris, so no part of the floor is empty
##
## The base layout is fixed (the constants below). The seed only changes the
## decoration: ground texture, the rough rock border and what fills the gaps.
##
## In the editor: select the World node and click "Generate Map" in the Inspector.
##   The result is saved into World.tscn. Do not edit World.tscn by hand.
##   (From a terminal: godot --headless --path . --script res://tools/bake_world.gd)
## When the game runs: if Ground is empty, the map is generated automatically.

# ---------------------------------------------------------------------------
# Layout (tile coordinates). Counts and rules are in config.gd.
# ---------------------------------------------------------------------------
const TILE := 16
const MAP_SIZE := Vector2i(48, 34)          # in tiles -> 768 x 544 pixels
const FLOOR := Rect2i(3, 5, 42, 26)         # the walkable area before rocks are added
const BORDER_ROUGHNESS := 2                  # how many tiles the rock border may bulge inward

const STREET_Y := 17                         # the main street runs along this row
const HAB_TILE := Vector2i(23, 14)
const HAB_PLAZA := Rect2i(21, 12, 5, 5)     # sand square under the hab
const SPAWN_TILE := Vector2i(23, 17)         # on the street, in front of the hab
const LAUNCH_PAD_TILE := Vector2i(37, 17)
const PAD_PLAZA := Rect2i(35, 15, 5, 5)     # sand square under the launch pad
const ROCKET_TILE := Vector2i(8, 13)         # bottom-centre of the crashed ship
const SHIP_HEIGHT := 128.0                   # pixels: how tall the ship is drawn
const SHIP_AREA := Rect2i(5, 6, 7, 8)       # tiles the ship covers: kept free of rocks
## Where each repair module's port is on the ground (tile). The engine goes on the
## ship's tail; the other five sit next to their coloured port, joined by a pipe.
const SHIP_SLOTS: Dictionary = {
	"power_station": Vector2i(13, 7), "avionics": Vector2i(16, 8), "thermal": Vector2i(13, 10),
	"life_support": Vector2i(16, 11), "propellant": Vector2i(13, 12), "engine": Vector2i(8, 13),
}

## Top-left tile of every build pad (each pad is PAD_SIZE x PAD_SIZE tiles).
## The first Config.BUILD_PAD_COUNT entries are used.
const PAD_SIZE := 2
const BUILD_PAD_TILES: Array[Vector2i] = [
	Vector2i(9, 15), Vector2i(13, 15), Vector2i(17, 15), Vector2i(27, 15), Vector2i(31, 15),   # north of the street
	Vector2i(9, 18), Vector2i(13, 18), Vector2i(17, 18), Vector2i(23, 18), Vector2i(27, 18),   # south of the street
]

## Solid rock masses inside the floor. The cave mouths sit in their south faces.
const ROCK_BLOCKS: Array[Rect2i] = [
	Rect2i(39, 5, 6, 6),                     # north-east corner (Ore Cave)
	Rect2i(17, 23, 8, 4),                    # outcrop south of the base (Deep Cave)
]

## Cave entrances. "tile" is the floor tile right in front of the mouth; the mouth
## is in the cliff just north of it. Ids must match Config.CAVES.
const ENTRANCES: Array[Dictionary] = [
	{"cave": "ice", "tile": Vector2i(29, 5)},
	{"cave": "ore", "tile": Vector2i(41, 11)},
	{"cave": "deep", "tile": Vector2i(20, 27)},
]

## Sand trails, as corner points. Each one is 1 tile wide.
const TRAILS: Array = [
	[Vector2i(6, 17), Vector2i(34, 17)],                                              # the main street
	[Vector2i(12, 17), Vector2i(12, 14), Vector2i(9, 14)],                           # to the wreck
	[Vector2i(29, 5), Vector2i(29, 17)],                                              # to the Ice Cave
	[Vector2i(37, 14), Vector2i(37, 12), Vector2i(41, 12), Vector2i(41, 11)],         # to the Ore Cave
	[Vector2i(20, 17), Vector2i(20, 21), Vector2i(15, 21), Vector2i(15, 28), Vector2i(20, 28), Vector2i(20, 27)],  # to the Deep Cave
	[Vector2i(15, 28), Vector2i(8, 28)],                                              # to the starter ice
	[Vector2i(37, 20), Vector2i(37, 26), Vector2i(41, 26)],                           # to the starter metal
]

## Where starter deposits may go. The first Config.SURFACE_*_NODES of each are used.
const METAL_SPOTS: Array[Vector2i] = [Vector2i(43, 25), Vector2i(42, 28), Vector2i(44, 27)]
const ICE_SPOTS: Array[Vector2i] = [Vector2i(6, 27), Vector2i(5, 29)]
const ICE_CRYSTAL_TILES: Array[Vector2i] = [Vector2i(4, 27), Vector2i(7, 29)]   # decoration next to the ice

const FOOTPRINT_TILES: Array[Vector2i] = [
	Vector2i(11, 11), Vector2i(13, 13), Vector2i(21, 18), Vector2i(22, 20),
	Vector2i(28, 8), Vector2i(30, 11), Vector2i(36, 13), Vector2i(26, 16)]

const SOURCE_ID := 0                         # the atlas inside mars_tileset.tres

# Atlas coordinates in art/atlases/terrain_paths_autotile_16px.png (column, row)
const T_REGOLITH := Vector2i(0, 0)
const T_ORANGE_SAND := Vector2i(1, 0)
const T_CRACKED := Vector2i(2, 0)
const T_ROCKS := Vector2i(3, 0)
const T_WALL_ROCK := Vector2i(4, 0)         # has collision in the TileSet
const T_ICE := Vector2i(5, 0)
const T_PATH_V := Vector2i(7, 0)            # 1-wide sand path, open up and down
const T_PATH_T := Vector2i(1, 1)            # path T-junction, open left, right and down
const T_PATH_CROSS := Vector2i(2, 1)
const T_PEBBLES := Vector2i(3, 1)
const T_ROCKY := Vector2i(4, 1)
const T_CRATERS := Vector2i(5, 1)
const T_RIPPLES := Vector2i(6, 1)
# Sand square with a regolith edge: corners, edges and centre.
const T_SAND_TL := Vector2i(7, 1)
const T_SAND_T := Vector2i(0, 2)
const T_SAND_TR := Vector2i(1, 2)
const T_SAND_L := Vector2i(2, 2)
const T_SAND_C := Vector2i(3, 2)
const T_SAND_R := Vector2i(4, 2)
const T_SAND_BL := Vector2i(5, 2)
const T_SAND_B := Vector2i(6, 2)
const T_SAND_BR := Vector2i(7, 2)

const FLIP_H := TileSetAtlasSource.TRANSFORM_FLIP_H
const FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V
const TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE

const TEX_METAL := preload("res://art/decor/metal_ore_full.png")
const TEX_ICE := preload("res://art/decor/ice_deposit_full.png")
const TEX_ICE_CRYSTAL := preload("res://art/decor/ice_crystal.png")
const TEX_ROCKS := [
	preload("res://art/decor/small_rock.png"),
	preload("res://art/decor/rock_cluster_small.png"),
	preload("res://art/decor/rock_cluster_large.png"),
]
const TEX_CRATER_SMALL := preload("res://art/craters/crater_single.png")
const TEX_CLIFF_LEFT := preload("res://art/cliffs/cliff_left.png")
const TEX_CLIFF_RIGHT := preload("res://art/cliffs/cliff_right.png")
const TEX_FOOTPRINTS := preload("res://art/overlays/footprints.png")
## PLACEHOLDER art. Swap these files (or these paths) when the real art exists.
const TEX_BROKEN_ROCKET := preload("res://art/new_sprites/spaceship_components/Crashed Pixel Spaceship Sprite.png")
const TEX_IRON := preload("res://art/new_sprites/new_ores/iron_ore.png")
const SHIP_SCRIPT := preload("res://scripts/ship.gd")
const SLOT_SCRIPT := preload("res://scripts/ship_slot.gd")
const TEX_ROCKET_DEBRIS := preload("res://art/placeholders/rocket_debris_placeholder.png")
const TEX_CAVE_MOUTH := preload("res://art/placeholders/cave_entrance_placeholder.png")
const TEX_BUILD_PAD := preload("res://art/placeholders/build_pad_placeholder.png")

const RESOURCE_NODE_SCRIPT := preload("res://scripts/resource_node.gd")
const CRATER_SCRIPT := preload("res://scripts/crater_hazard.gd")
const BUILD_PAD_SCRIPT := preload("res://scripts/build_pad.gd")
const CAVE_ENTRANCE_SCRIPT := preload("res://scripts/cave_entrance.gd")

const DECOR_SCALE := Vector2(0.25, 0.25)    # rock art is drawn ~4x larger than tiles
const NODE_SCALE := Vector2(2.0, 2.0)       # metal / ice deposits (16 px art)
const PILLAR_SIZE := 2                       # rock pillars that fill big gaps are 2x2 tiles
const PILLAR_MIN_GAP := 6                    # a gap this wide (tiles) gets a pillar instead of a rock
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

@export var map_seed: int = 1337
@export var camera_zoom: float = 2.0
@export_tool_button("Generate Map", "TileMapLayer") var generate_button: Callable = generate

## Numbers from the last generate(): what was placed and whether the rules hold.
var last_report: Dictionary = {}

# Working data, only valid while generate() runs.
var _walk := PackedByteArray()              # 1 = walkable tile
var _used := PackedByteArray()              # 1 = wall or a tile with something on it
var _keep := {}                             # tile -> true: must stay free of rocks and craters
var _dist := PackedInt32Array()             # walking distance from the spawn, in tiles
var _trail := {}                            # tile -> true, the sand trails
var _fillers: Array[Dictionary] = []        # what fills the gaps: {type, tile}
var _pillars := 0                           # rock pillars added to fill big gaps


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if (get_node("Ground") as TileMapLayer).get_used_cells().is_empty():
		generate()
	_place_arrival()
	_setup_camera()
	get_viewport().size_changed.connect(_setup_camera)
	_setup_day_night()
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue != null:
		dialogue.once("intro", true)


## The surface gets darker at night (GameState runs the clock).
func _setup_day_night() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var tint := CanvasModulate.new()
	tint.name = "DayNight"
	add_child(tint)

	# The lamp: a soft glow around the player that comes on as it gets dark.
	var player := get_node_or_null("Entities/Player") as Node2D
	if player != null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color.BLACK)
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.width = 128
		tex.height = 128
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var lamp := PointLight2D.new()
		lamp.name = "Lamp"
		lamp.texture = tex
		lamp.color = Color(1.0, 0.92, 0.75)
		lamp.scale = Vector2.ONE / player.scale       # the player node is scaled down
		lamp.texture_scale = Config.LAMP_RADIUS * TILE * 2.0 / tex.width
		player.add_child(lamp)

	state.day_night_changed.connect(_on_day_night)
	_on_day_night(state.sol_number, state.sun)


func _on_day_night(_sol: int, sun_level: float) -> void:
	if not is_inside_tree():
		return                                   # the scene is being unloaded
	(get_node("DayNight") as CanvasModulate).color = Config.NIGHT_COLOR.lerp(Color.WHITE, sun_level)
	var lamp := get_node_or_null("Entities/Player/Lamp") as PointLight2D
	if lamp != null:
		lamp.energy = (1.0 - sun_level) * 0.9
	# The first nightfall: the story of the lamp, told once.
	var state := get_node("/root/GameState")
	if sun_level < 0.5 and not state.lamp_found:
		state.lamp_found = true
		var dialogue := get_node_or_null("/root/Dialogue")
		if dialogue != null:
			dialogue.once("lamp")


## Coming back out of a cave: the player stands in front of that cave's entrance.
func _place_arrival() -> void:
	var state := get_node_or_null("/root/GameState")
	var player := get_node_or_null("Entities/Player") as Node2D
	if state == null or player == null:
		return
	var how: String = state.arrival
	if how == "shelter_exit":
		# Out of the Emergency Shelter: just in front of its door.
		for p in get_tree().get_nodes_in_group("build_pads"):
			if state.machines.get(p.get("pad_id"), "") == "shelter":
				player.global_position = (p as Node2D).global_position + Vector2(0, 12)
		return
	if not how.begins_with("entrance:"):
		return
	var entrance := get_node_or_null("CaveEntrances/Entrance_%s" % how.trim_prefix("entrance:"))
	if entrance != null:
		player.global_position = entrance.exit_position()


func generate() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var walls := get_node("Walls") as TileMapLayer
	var nodes := get_node("Entities/Nodes")
	var decor := get_node("Entities/Decor")
	var ground_decor := get_node("GroundDecor")
	var pads := _get_or_make("BuildPads", ground_decor)
	var cliffs := _get_or_make("Cliffs", walls)
	var entrances := _get_or_make("CaveEntrances", cliffs)
	for container in [nodes, decor, ground_decor, pads, cliffs, entrances]:
		_clear_children(container)

	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.08

	# 1. Layout: which tiles can be walked on, and which are already taken.
	_build_layout(noise)
	# 2. No dead space: fill every empty patch that is too big.
	_fill_gaps(rng)
	_dist = _flood_from(SPAWN_TILE)

	# 3. Paint and place.
	_paint_ground(ground, noise, rng)
	_paint_walls(walls)
	_place_cliffs(cliffs)
	_build_base(ground_decor)
	_place_build_pads(pads)
	_place_entrances(entrances)
	_place_starter_nodes(nodes, decor)
	_place_fillers(ground_decor, decor, rng)

	_make_report()


# ---------------------------------------------------------------------------
# 1. Layout
# ---------------------------------------------------------------------------

func build_pad_tiles() -> Array[Vector2i]:
	return BUILD_PAD_TILES.slice(0, mini(Config.BUILD_PAD_COUNT, BUILD_PAD_TILES.size()))


func metal_tiles() -> Array[Vector2i]:
	return METAL_SPOTS.slice(0, mini(Config.SURFACE_METAL_NODES, METAL_SPOTS.size()))


func ice_tiles() -> Array[Vector2i]:
	return ICE_SPOTS.slice(0, mini(Config.SURFACE_ICE_NODES, ICE_SPOTS.size()))


## Fills _walk, _trail, _keep and _used.
func _build_layout(noise: FastNoiseLite) -> void:
	_walk.resize(MAP_SIZE.x * MAP_SIZE.y)
	_walk.fill(0)
	_used.resize(MAP_SIZE.x * MAP_SIZE.y)
	_used.fill(0)
	_keep.clear()
	_trail.clear()
	_fillers.clear()
	_pillars = 0

	# Open floor, minus the solid rock masses.
	for x in range(FLOOR.position.x, FLOOR.end.x):
		for y in range(FLOOR.position.y, FLOOR.end.y):
			_walk[_index(Vector2i(x, y))] = 1
	for block in ROCK_BLOCKS:
		for x in range(block.position.x, block.end.x):
			for y in range(block.position.y, block.end.y):
				_walk[_index(Vector2i(x, y))] = 0

	# Trails.
	for corners: Array in TRAILS:
		for i in corners.size() - 1:
			var p: Vector2i = corners[i]
			var to: Vector2i = corners[i + 1]
			_trail[p] = true
			while p != to:
				p += Vector2i(signi(to.x - p.x), signi(to.y - p.y))
				_trail[p] = true

	# Everything that has a fixed place. These tiles are "taken", and they and
	# the tiles around them stay free of rocks, pillars and craters.
	var fixed: Array[Vector2i] = []
	fixed.append_array(_trail.keys())
	fixed.append_array(_rect_tiles(HAB_PLAZA))
	fixed.append_array(_rect_tiles(PAD_PLAZA))
	for pad in build_pad_tiles():
		fixed.append_array(_rect_tiles(Rect2i(pad, Vector2i(PAD_SIZE, PAD_SIZE))))
	fixed.append_array(_rect_tiles(Rect2i(ROCKET_TILE.x - 2, ROCKET_TILE.y - 2, 5, 3)))
	fixed.append_array(_rect_tiles(SHIP_AREA))
	fixed.append_array(SHIP_SLOTS.values())
	for e in ENTRANCES:
		fixed.append(e.tile)
	fixed.append_array(metal_tiles())
	fixed.append_array(ice_tiles())
	fixed.append_array(ICE_CRYSTAL_TILES)
	fixed.append_array(FOOTPRINT_TILES)
	fixed.append(SPAWN_TILE)
	for t in fixed:
		_used[_index(t)] = 1
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_keep[t + Vector2i(dx, dy)] = true

	# A rough rock border: the wall bulges inward here and there, never over
	# anything that has a fixed place. Depth 0 first, so a bulge is always attached.
	var bumps := FastNoiseLite.new()
	bumps.seed = noise.seed + 1
	bumps.frequency = 0.21
	for depth in BORDER_ROUGHNESS:
		for x in range(FLOOR.position.x, FLOOR.end.x):
			for y in range(FLOOR.position.y, FLOOR.end.y):
				var t := Vector2i(x, y)
				if _border_depth(t) != depth or _keep.has(t) or not _is_walk(t):
					continue
				if depth > 0 and not _touches_wall(t):
					continue
				if bumps.get_noise_2d(x, y) > 0.05 + depth * 0.2:
					_walk[_index(t)] = 0

	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			if _walk[_index(Vector2i(x, y))] == 0:
				_used[_index(Vector2i(x, y))] = 1


## How many tiles a floor tile is away from the edge of FLOOR (0 = on the edge).
func _border_depth(t: Vector2i) -> int:
	return mini(mini(t.x - FLOOR.position.x, FLOOR.end.x - 1 - t.x), mini(t.y - FLOOR.position.y, FLOOR.end.y - 1 - t.y))


func _touches_wall(t: Vector2i) -> bool:
	for d in DIRS:
		if not _is_walk(t + d):
			return true
	return false


func _rect_tiles(rect: Rect2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			tiles.append(Vector2i(x, y))
	return tiles


func _index(t: Vector2i) -> int:
	return t.y * MAP_SIZE.x + t.x


func _in_map(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < MAP_SIZE.x and t.y < MAP_SIZE.y


func _is_walk(t: Vector2i) -> bool:
	return _in_map(t) and _walk[_index(t)] == 1


## Walking distance (in tiles) from `start` to every tile. -1 = cannot be reached.
func _flood_from(start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(MAP_SIZE.x * MAP_SIZE.y)
	dist.fill(-1)
	dist[_index(start)] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var d := dist[_index(cur)]
		for dir in DIRS:
			var n := cur + dir
			if _is_walk(n) and dist[_index(n)] == -1:
				dist[_index(n)] = d + 1
				queue.append(n)
	return dist


func _distance_to(t: Vector2i) -> int:
	return _dist[_index(t)] if _in_map(t) else -1


# ---------------------------------------------------------------------------
# 2. No dead space
# ---------------------------------------------------------------------------

## The biggest square of plain, empty floor (walkable, nothing on it).
func largest_empty_square() -> Rect2i:
	var w := MAP_SIZE.x
	var sizes := PackedInt32Array()
	sizes.resize(w * MAP_SIZE.y)
	var best := 0
	var best_pos := Vector2i.ZERO
	for y in MAP_SIZE.y:
		for x in w:
			var i := y * w + x
			if _walk[i] == 0 or _used[i] == 1:
				sizes[i] = 0
				continue
			var v := 1
			if x > 0 and y > 0:
				v = 1 + mini(mini(sizes[i - 1], sizes[i - w]), sizes[i - w - 1])
			sizes[i] = v
			if v > best:
				best = v
				best_pos = Vector2i(x - v + 1, y - v + 1)
	return Rect2i(best_pos, Vector2i(best, best))


## Puts something into every empty patch bigger than Config.SURFACE_MAX_EMPTY_SQUARE:
## a rock pillar in the big ones, otherwise a rock, a crater or rocket debris.
func _fill_gaps(rng: RandomNumberGenerator) -> void:
	for guard in 500:
		var gap := largest_empty_square()
		var size := gap.size.x
		if size <= Config.SURFACE_MAX_EMPTY_SQUARE:
			return
		var centre := gap.position + Vector2i(size, size) / 2

		# A big gap gets a pillar: 2x2 solid rock with floor all around it.
		if size >= PILLAR_MIN_GAP:
			var corner := gap.position + Vector2i(size - PILLAR_SIZE, size - PILLAR_SIZE) / 2
			var pillar := _rect_tiles(Rect2i(corner, Vector2i(PILLAR_SIZE, PILLAR_SIZE)))
			if pillar.all(func(t: Vector2i) -> bool: return not _keep.has(t)):
				for t in pillar:
					_walk[_index(t)] = 0
					_used[_index(t)] = 1
				_pillars += 1
				continue

		# Otherwise one object, near the middle, on a tile that may be blocked.
		var options: Array = []                  # [score, tile]
		for t in _rect_tiles(gap):
			if not _keep.has(t):
				options.append([Vector2(t - centre).length() + rng.randf() * 1.5, t])
		if options.is_empty():
			_used[_index(centre)] = 1            # nothing may stand here: leave it open
			continue
		options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var tile: Vector2i = options[0][1]
		var type := "rock"
		var roll := rng.randf()
		if _chebyshev(tile, ROCKET_TILE) <= 6 and roll < 0.5:
			type = "debris"
		elif _chebyshev(tile, HAB_TILE) >= Config.BASE_SAFE_RADIUS and roll < 0.3:
			type = "crater"
		_fillers.append({"type": type, "tile": tile})
		_used[_index(tile)] = 1
	push_warning("world_gen: could not fill all the empty space")


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ---------------------------------------------------------------------------
# 3. Painting
# ---------------------------------------------------------------------------

func _paint_ground(ground: TileMapLayer, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	ground.clear()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			var t := Vector2i(x, y)
			var tile := T_REGOLITH
			var n := noise.get_noise_2d(x, y)
			var r := rng.randf()                 # always drawn, so the map stays the same per seed
			if n > 0.38:
				tile = T_ORANGE_SAND
			elif n > 0.24:
				tile = T_RIPPLES
			elif n < -0.4:
				tile = T_CRACKED
			elif r < 0.07:
				tile = T_PEBBLES
			elif r < 0.10:
				tile = T_ROCKS
			elif r < 0.12:
				tile = T_ROCKY
			elif r < 0.135:
				tile = T_CRATERS
			ground.set_cell(t, SOURCE_ID, tile)

	# The ground hints at what is near: icy around the ice, rocky around the metal.
	for spot in ice_tiles():
		_paint_patch(ground, spot, T_ICE, T_ICE, rng)
	for spot in metal_tiles():
		_paint_patch(ground, spot, T_ROCKY, T_ROCKS, rng)

	# Scorched ground under the wreck.
	for t in _rect_tiles(Rect2i(ROCKET_TILE.x - 2, ROCKET_TILE.y - 2, 5, 3)):
		ground.set_cell(t, SOURCE_ID, T_CRACKED)

	# Sand trails.
	for t: Vector2i in _trail:
		var pick := _trail_tile(t)
		ground.set_cell(t, SOURCE_ID, pick[0], pick[1])

	# Sand plazas under the hab and the launch pad, and a sand square for every build pad.
	_paint_sand_rect(ground, HAB_PLAZA)
	_paint_sand_rect(ground, PAD_PLAZA)
	for pad in build_pad_tiles():
		_paint_sand_rect(ground, Rect2i(pad, Vector2i(PAD_SIZE, PAD_SIZE)))


## A loose 5x5 patch of two ground tiles around `centre`.
func _paint_patch(ground: TileMapLayer, centre: Vector2i, tile_a: Vector2i, tile_b: Vector2i, rng: RandomNumberGenerator) -> void:
	for t in _rect_tiles(Rect2i(centre - Vector2i(2, 2), Vector2i(5, 5))):
		var roll := rng.randf()
		if _is_walk(t) and roll < 0.45:
			ground.set_cell(t, SOURCE_ID, tile_a if roll < 0.25 else tile_b)


## Which path tile fits here, from the trail tiles next to it: [atlas coords, transform].
func _trail_tile(t: Vector2i) -> Array:
	var n := _trail.has(t + Vector2i.UP)
	var e := _trail.has(t + Vector2i.RIGHT)
	var s := _trail.has(t + Vector2i.DOWN)
	var w := _trail.has(t + Vector2i.LEFT)
	var count := int(n) + int(e) + int(s) + int(w)
	if count == 4:
		return [T_PATH_CROSS, 0]
	if count == 3:
		if not n:
			return [T_PATH_T, 0]
		if not s:
			return [T_PATH_T, FLIP_V]
		if not w:
			return [T_PATH_T, TRANSPOSE]
		return [T_PATH_T, TRANSPOSE | FLIP_H]
	if count == 2 and n and s:
		return [T_PATH_V, 0]
	if count == 2 and e and w:
		return [T_PATH_V, TRANSPOSE]
	return [T_SAND_C, 0]                         # corners and ends: plain sand


func _paint_sand_rect(ground: TileMapLayer, rect: Rect2i) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x - 1
	var y1 := rect.end.y - 1
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile := T_SAND_C
			if y == y0:
				tile = T_SAND_TL if x == x0 else (T_SAND_TR if x == x1 else T_SAND_T)
			elif y == y1:
				tile = T_SAND_BL if x == x0 else (T_SAND_BR if x == x1 else T_SAND_B)
			elif x == x0:
				tile = T_SAND_L
			elif x == x1:
				tile = T_SAND_R
			ground.set_cell(Vector2i(x, y), SOURCE_ID, tile)


## Everything that is not walkable is solid rock.
func _paint_walls(walls: TileMapLayer) -> void:
	walls.clear()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			if not _is_walk(Vector2i(x, y)):
				walls.set_cell(Vector2i(x, y), SOURCE_ID, T_WALL_ROCK)


## Cliff faces on every rock edge that looks down onto floor (the art shows a
## cliff seen from the front, with a left and a right end piece).
func _place_cliffs(cliffs: Node) -> void:
	var count := 0
	for y in range(0, MAP_SIZE.y - 1):
		for x in MAP_SIZE.x:
			if not _faces_south(Vector2i(x, y)):
				continue
			# Ends of a cliff run use their own piece, the middle alternates.
			var left_end := not _faces_south(Vector2i(x - 1, y))
			var right_end := not _faces_south(Vector2i(x + 1, y))
			var use_left := left_end or (not right_end and x % 2 == 0)
			var tex: Texture2D = TEX_CLIFF_LEFT if use_left else TEX_CLIFF_RIGHT
			count += 1
			var s := Sprite2D.new()
			s.name = "Cliff%03d" % count
			s.texture = tex
			s.scale = Vector2(TILE, TILE) / tex.get_size()
			s.position = _tile_centre(Vector2i(x, y))
			cliffs.add_child(s)
			s.owner = _scene_owner()


func _faces_south(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < MAP_SIZE.x and not _is_walk(t) and _is_walk(t + Vector2i.DOWN)


# ---------------------------------------------------------------------------
# 4. The base: hab, launch pad, wreck, build pads, cave entrances
# ---------------------------------------------------------------------------

func _build_base(ground_decor: Node) -> void:
	# Move the existing landmarks to their tiles.
	var pad := get_node_or_null("LaunchPad") as Node2D
	if pad != null:
		pad.position = _tile_centre(LAUNCH_PAD_TILE)
		# The launch pad is a build pad too: the only one that takes the Ascent vehicle.
		pad.set_script(BUILD_PAD_SCRIPT)
		pad.set("pad_id", "launch")
		pad.set("pad_type", "launch")
	var hab := get_node_or_null("Entities/Hab") as Node2D
	if hab != null:
		hab.position = _tile_centre(HAB_TILE)
		hab.set_script(null)
	var player := get_node_or_null("Entities/Player") as Node2D
	if player != null:
		player.position = _tile_centre(SPAWN_TILE)

	# Footprints between the hab, the pads and the wreck.
	var i := 0
	for t: Vector2i in FOOTPRINT_TILES:
		i += 1
		_place_sprite(ground_decor, "Footprints%02d" % i, TEX_FOOTPRINTS, Vector2(TILE, TILE) / TEX_FOOTPRINTS.get_size(), _tile_centre(t))

	# Scattered debris around the wreck (no collision, just for the look).
	i = 0
	for offset: Vector2 in [Vector2(-52, -6), Vector2(-44, -30), Vector2(50, -4), Vector2(46, -34), Vector2(-10, -46), Vector2(60, -20)]:
		i += 1
		var debris := _place_sprite(ground_decor, "Debris%02d" % i, TEX_ROCKET_DEBRIS, Vector2.ONE,
			_tile_centre(ROCKET_TILE) + Vector2(0, TILE * 0.5) + offset)
		debris.flip_h = i % 2 == 0
		debris.rotation = (i % 4) * PI / 2

	_build_broken_rocket()


func _place_build_pads(pads: Node) -> void:
	var i := 0
	for tile in build_pad_tiles():
		i += 1
		var size := Vector2(PAD_SIZE, PAD_SIZE) * TILE
		_place_sprite(pads, "Pad%02d" % i, TEX_BUILD_PAD, size / TEX_BUILD_PAD.get_size(),
			Vector2(tile * TILE) + size * 0.5, BUILD_PAD_SCRIPT, {"pad_id": "pad_%02d" % i, "pad_type": "machine"})


## One Area2D per cave: the dark mouth in the cliff, a trigger strip at its foot
## and the marker where the player comes back out.
func _place_entrances(entrances: Node) -> void:
	for e in ENTRANCES:
		var tile: Vector2i = e.tile
		var area := Area2D.new()
		area.set_script(CAVE_ENTRANCE_SCRIPT)
		area.name = "Entrance_%s" % e.cave
		area.set("cave_id", e.cave)
		# Origin: the foot of the cliff, in the middle of the trail.
		area.position = Vector2(tile.x * TILE + TILE * 0.5, tile.y * TILE)
		entrances.add_child(area)
		area.owner = _scene_owner()

		var mouth := Sprite2D.new()
		mouth.name = "Mouth"
		mouth.texture = TEX_CAVE_MOUTH
		mouth.position = Vector2(0, -TEX_CAVE_MOUTH.get_size().y * 0.5)
		area.add_child(mouth)
		mouth.owner = _scene_owner()

		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE * 1.25, TILE * 0.5)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = shape
		collision.position = Vector2(0, TILE * 0.25)      # the top half of the floor tile in front
		area.add_child(collision)
		collision.owner = _scene_owner()

		var exit_marker := Marker2D.new()
		exit_marker.name = "Exit"
		exit_marker.position = Vector2(0, TILE * 1.5)     # one tile further out, clear of the trigger
		area.add_child(exit_marker)
		exit_marker.owner = _scene_owner()


## The crashed rocket: sprite, solid collider, smoke and sparks. Saved into the scene.
func _build_broken_rocket() -> void:
	var entities := get_node("Entities")
	var old := entities.get_node_or_null("BrokenRocket")
	if old != null:
		entities.remove_child(old)
		old.queue_free()

	var rocket := StaticBody2D.new()
	rocket.name = "BrokenRocket"
	rocket.position = _tile_centre(ROCKET_TILE) + Vector2(0, TILE * 0.5)   # its base, for y-sorting
	entities.add_child(rocket)
	rocket.owner = _scene_owner()

	rocket.set_script(SHIP_SCRIPT)
	var ship_scale := SHIP_HEIGHT / TEX_BROKEN_ROCKET.get_size().y
	var size := TEX_BROKEN_ROCKET.get_size() * ship_scale
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = TEX_BROKEN_ROCKET
	sprite.scale = Vector2.ONE * ship_scale
	sprite.position = Vector2(0, -size.y * 0.5)
	rocket.add_child(sprite)
	sprite.owner = _scene_owner()

	# Solid only at its base, so the player can walk behind the tall ship.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x * 0.5, 14)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.position = Vector2(0, -9)
	rocket.add_child(collision)
	collision.owner = _scene_owner()

	# Slow grey smoke from the break in the hull.
	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.position = Vector2(-4, -size.y * 0.75)
	smoke.amount = 14
	smoke.lifetime = 2.6
	smoke.preprocess = 2.6
	smoke.randomness = 0.5
	smoke.lifetime_randomness = 0.3
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 3.0
	smoke.direction = Vector2(0, -1)
	smoke.spread = 14.0
	smoke.gravity = Vector2(5, -6)               # drifts up and a little with the wind
	smoke.initial_velocity_min = 6.0
	smoke.initial_velocity_max = 12.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.30, 0.28, 0.30, 0.0))
	smoke_ramp.set_color(1, Color(0.62, 0.60, 0.62, 0.0))
	smoke_ramp.add_point(0.15, Color(0.36, 0.34, 0.36, 0.8))
	smoke_ramp.add_point(0.6, Color(0.5, 0.48, 0.5, 0.45))
	smoke.color_ramp = smoke_ramp
	rocket.add_child(smoke)
	smoke.owner = _scene_owner()

	# An occasional burst of orange sparks.
	var sparks := CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.position = Vector2(-6, -size.y * 0.6)
	sparks.amount = 6
	sparks.lifetime = 1.8
	sparks.explosiveness = 0.9
	sparks.randomness = 0.6
	sparks.direction = Vector2(0, -1)
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 90)
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 50.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 1.5
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
	spark_ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	spark_ramp.add_point(0.25, Color(1.0, 0.5, 0.15, 0.9))
	spark_ramp.add_point(0.4, Color(1.0, 0.3, 0.1, 0.0))
	sparks.color_ramp = spark_ramp
	rocket.add_child(sparks)
	sparks.owner = _scene_owner()
	_build_ship_slots(rocket, sprite)


## The six repair ports: a dark outline of each module (ship_slot.gd), and a
## pipe in the module's connection colour from its port on the ship.
func _build_ship_slots(rocket: Node2D, ship_sprite: Sprite2D) -> void:
	var entities := get_node("Entities")
	for old in entities.get_children():
		if old.name.begins_with("Slot_"):
			entities.remove_child(old)
			old.queue_free()
	var art_centre := ship_sprite.texture.get_size() * 0.5
	for module_id: String in SHIP_SLOTS:
		var def := Config.machine(module_id)
		var tex: Texture2D = load(def.idle[0])
		var pos := _tile_centre(SHIP_SLOTS[module_id])
		if module_id == "engine":
			pos = rocket.position + Vector2(0, -7)      # on the tail, over the broken nozzle
		var slot := _place_sprite(entities, "Slot_" + module_id, tex, Vector2.ONE * float(def.pixels) / tex.get_size().x,
			pos, SLOT_SCRIPT, {"module_id": module_id})
		if module_id == "engine":
			slot.z_index = 1
		if def.has("port"):
			var port: Vector2 = rocket.position + ship_sprite.position + (def.port - art_centre) * ship_sprite.scale
			var pipe := Line2D.new()
			pipe.name = "Pipe_" + module_id
			pipe.points = PackedVector2Array([port, Vector2(pos.x, port.y), pos])
			pipe.width = 2.0
			pipe.default_color = def.color
			get_node("GroundDecor").add_child(pipe)
			pipe.owner = _scene_owner()


# ---------------------------------------------------------------------------
# 5. Starter deposits and the things that fill the gaps
# ---------------------------------------------------------------------------

func _place_starter_nodes(nodes: Node, decor: Node) -> void:
	var i := 0
	for tile in metal_tiles():
		i += 1
		# Iron Ore: the first thing the player needs (the Ore Refinery is made of it).
		var s := _place_sprite(nodes, "Iron%02d" % i, TEX_IRON, Vector2.ONE * Config.DEPOSIT_PIXELS / TEX_IRON.get_size().x,
			_tile_centre(tile), RESOURCE_NODE_SCRIPT, {"kind": "iron", "charges_left": Config.NODE_CHARGES, "node_id": "surface/Iron%02d" % i})
		s.set_meta("kind", "iron")
	i = 0
	for tile in ice_tiles():
		i += 1
		var s := _place_sprite(nodes, "Ice%02d" % i, TEX_ICE, NODE_SCALE, _tile_centre(tile),
			RESOURCE_NODE_SCRIPT, {"kind": "ice", "charges_left": Config.NODE_CHARGES, "node_id": "surface/Ice%02d" % i})
		s.set_meta("kind", "ice")
	i = 0
	for tile in ICE_CRYSTAL_TILES:
		i += 1
		_place_sprite(decor, "Crystal%02d" % i, TEX_ICE_CRYSTAL, DECOR_SCALE, _tile_centre(tile))


func _place_fillers(ground_decor: Node, decor: Node, rng: RandomNumberGenerator) -> void:
	var rock_i := 0
	var crater_i := 0
	var debris_i := 100                          # after the fixed debris around the wreck
	for f in _fillers:
		var pos := _tile_centre(f.tile)
		match f.type:
			"rock":
				rock_i += 1
				var tex: Texture2D = TEX_ROCKS[rng.randi() % TEX_ROCKS.size()]
				_place_sprite(decor, "Rock%02d" % rock_i, tex, DECOR_SCALE, pos)
			"crater":
				# One tile: costs oxygen if you walk into it, easy to step around.
				crater_i += 1
				_place_sprite(ground_decor, "Crater%02d" % crater_i, TEX_CRATER_SMALL,
					Vector2.ONE * (TILE * 1.1) / TEX_CRATER_SMALL.get_size().x, pos, CRATER_SCRIPT,
					{"hazard_fraction": Vector2(0.7, 0.7)})
			"debris":
				# A small scatter of rocket pieces (no collision).
				for n in 3:
					debris_i += 1
					var piece := _place_sprite(ground_decor, "Debris%03d" % debris_i, TEX_ROCKET_DEBRIS, Vector2.ONE,
						pos + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7)))
					piece.flip_h = rng.randf() < 0.5
					piece.rotation = rng.randi_range(0, 3) * PI / 2


# ---------------------------------------------------------------------------
# Report: what is on the map and whether the rules hold
# ---------------------------------------------------------------------------

func _make_report() -> void:
	# Everything the player must be able to walk to.
	var targets := {"hab": HAB_TILE + Vector2i(0, 3), "launch pad": LAUNCH_PAD_TILE, "wreck": ROCKET_TILE + Vector2i(0, 1)}
	var i := 0
	for pad in build_pad_tiles():
		i += 1
		targets["pad %d" % i] = pad
	for e in ENTRANCES:
		targets["%s cave entrance" % e.cave] = e.tile
	for module_id: String in SHIP_SLOTS:
		if module_id != "engine":
			targets["%s port" % module_id] = SHIP_SLOTS[module_id]
	var unreachable: Array[String] = []
	for key: String in targets:
		if _distance_to(targets[key]) < 0:
			unreachable.append(key)

	var metal := 0
	var ice := 0
	var nodes_near_base := 0
	var unreachable_nodes := 0
	for n in get_node("Entities/Nodes").get_children():
		var t := Vector2i((n as Node2D).position / TILE)
		var d := -1
		for dir in DIRS:                         # a deposit is solid: you stand next to it
			var beside := _distance_to(t + dir)
			if beside >= 0 and (d < 0 or beside < d):
				d = beside
		if d < 0:
			unreachable_nodes += 1
		elif d < Config.STARTER_NODE_MIN_WALK:
			nodes_near_base += 1
		if n.get_meta("kind", "") != "ice":
			metal += 1
		else:
			ice += 1

	var craters := 0
	var craters_near_base := 0
	for c in get_node("GroundDecor").get_children():
		if c.name.begins_with("Crater"):
			craters += 1
			if _chebyshev(Vector2i((c as Node2D).position / TILE), HAB_TILE) < Config.BASE_SAFE_RADIUS:
				craters_near_base += 1

	var walkable := 0
	for v in _walk:
		walkable += v
	last_report = {
		"metal_nodes": metal,
		"ice_nodes": ice,
		"build_pads": get_node("BuildPads").get_child_count(),
		"entrances": get_node("CaveEntrances").get_child_count(),
		"unreachable": unreachable,
		"unreachable_nodes": unreachable_nodes,
		"nodes_near_base": nodes_near_base,
		"craters": craters,
		"craters_near_base": craters_near_base,
		"rocks": get_node("Entities/Decor").get_child_count(),
		"pillars": _pillars,
		"gap_fillers": _fillers.size() + _pillars,
		"walkable_tiles": walkable,
		"max_empty_square": largest_empty_square().size.x,
	}
	print("world_gen seed %d: surface %dx%d, %d build pads, %d cave entrances, %d metal + %d ice starter deposits" % [
		map_seed, MAP_SIZE.x, MAP_SIZE.y, last_report.build_pads, last_report.entrances, metal, ice])
	print("world_gen: %d walkable tiles, %d rock pillars, %d rocks, %d craters, biggest empty patch %dx%d tiles (limit %d)" % [
		walkable, _pillars, last_report.rocks, craters, last_report.max_empty_square, last_report.max_empty_square,
		Config.SURFACE_MAX_EMPTY_SQUARE])
	if not unreachable.is_empty():
		push_warning("world_gen: cannot be reached on foot: %s" % ", ".join(unreachable))
	if unreachable_nodes > 0:
		push_warning("world_gen: %d deposits cannot be reached" % unreachable_nodes)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE) + Vector2(TILE, TILE) * 0.5


## `script` and `props` are applied before the sprite enters the tree, so the
## script's _ready() sees them when the map is generated while the game runs.
func _place_sprite(parent: Node, node_name: String, tex: Texture2D, scl: Vector2, pos: Vector2,
		script: Script = null, props: Dictionary = {}) -> Sprite2D:
	var s := Sprite2D.new()
	if script != null:
		s.set_script(script)
	s.name = node_name
	s.texture = tex
	s.scale = scl
	s.position = pos
	for key: String in props:
		s.set(key, props[key])
	parent.add_child(s)
	s.owner = _scene_owner()
	return s


## A plain Node2D container called `node_name`, placed right after `after` in the
## scene (so it is drawn just above it). Made once, then reused.
func _get_or_make(node_name: String, after: Node) -> Node:
	var container := get_node_or_null(node_name)
	if container == null:
		container = Node2D.new()
		container.name = node_name
		add_child(container)
		move_child(container, after.get_index() + 1)
		container.owner = _scene_owner()
	return container


func _clear_children(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


## Nodes must be owned by the scene root to be saved in World.tscn.
func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree() != null:
		return get_tree().edited_scene_root
	return self


## The camera stays inside the map. On a very wide or tall window it zooms in a
## little more, so the grey outside of the map never shows.
func _setup_camera() -> void:
	var cam := get_node_or_null("Entities/Player/Camera2D") as Camera2D
	if cam == null:
		return
	var map_pixels := Vector2(MAP_SIZE * TILE)
	var view := Vector2(get_viewport().get_visible_rect().size)
	var zoom := maxf(camera_zoom, maxf(view.x / map_pixels.x, view.y / map_pixels.y))
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_pixels.x)
	cam.limit_bottom = int(map_pixels.y)
	cam.zoom = Vector2(zoom, zoom)
	cam.reset_smoothing()                        # no slow pan after arriving somewhere
