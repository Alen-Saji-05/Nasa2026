@tool
extends Node2D
## Builds the Mars map: a base clearing (hab, launch pad, crashed rocket) and a
## network of cliff-lined corridors that lead to far-away reward chambers.
##
## In the editor: select the World node and click "Generate Map" in the Inspector.
##   The result is saved into World.tscn, so you can then touch up tiles by hand.
##   (From a terminal: godot --headless --path . --script res://tools/bake_world.gd)
## When the game runs: if Ground is empty, the map is generated automatically.
## Same seed = same map every time (so balance is testable).
##
## How the layout is made:
##   1. The map is split into a coarse grid of cells. Each cell gets one point.
##   2. A maze is grown over the cells, starting at the hub next to the clearing.
##      It grows as 3 branches of similar size. A few extra links make loops.
##   3. Every maze link becomes a corridor. Every dead end becomes a chamber.
##   4. The far chambers get the ice and metal. The near ones stay empty.
##   5. Craters and rocks are put on the corridors, more on the way to the best rewards.

# ---------------------------------------------------------------------------
# Layout tuning (reward amounts and the crater O2 penalty are in config.gd)
# ---------------------------------------------------------------------------
const TILE := 16
const MAP_SIZE := Vector2i(96, 64)          # in tiles -> 1536 x 1024 pixels
const CELL_SIZE := 8                         # tiles per coarse cell (corridor spacing)
const GRID_SIZE := Vector2i(12, 7)           # cells; GRID_SIZE * CELL_SIZE must fit in MAP_SIZE
const GRID_ORIGIN := Vector2i(0, 4)          # tile of the grid's top-left corner
const CELL_JITTER := 1                       # how far a cell's point may move off-centre (winding)
const CORRIDOR_WIDTH := 3                    # tiles
const CHAMBER_SIZE := 5                      # tiles, dead-end chambers are this big
const BRANCH_RANDOMNESS := 0.15              # 0 = long winding corridors, 1 = many short dead ends
const LOOP_COUNT := 2                        # extra links that create loops (shortcuts)
const MAX_REWARD_CHAMBERS := 9               # only the farthest dead ends hold rewards
const GUARDED_CHAMBERS := 3                  # best chambers get a corridor-wide crater + rock chokepoint
const LAYOUT_ATTEMPTS := 30                  # layouts tried until enough far dead ends exist
const CRATER_DENSITY := 0.45                 # chance of a crater on an ordinary corridor

# The base clearing: hab, spawn, launch pad and crashed rocket. No hazards, no rewards.
const CLEARING := Rect2i(1, 23, 14, 10)     # tiles (x, y, width, height)
const BASE_SAFE_RADIUS := 10                 # tiles around the clearing with no rewards, even behind a wall
const CLEARING_CELLS := Rect2i(0, 2, 2, 2)  # the coarse cells the clearing sits in (no maze there)
const HUB_CELL := Vector2i(2, 3)             # first junction outside the clearing
const HUB_TILE := Vector2i(20, 30)           # the exit corridor runs along this row
const HAB_TILE := Vector2i(4, 29)
const LAUNCH_PAD_TILE := Vector2i(10, 30)
const SPAWN_TILE := Vector2i(6, 27)
const ROCKET_TILE := Vector2i(9, 25)         # bottom-centre of the crashed rocket
const PAD_PLAZA := Rect2i(8, 28, 5, 5)      # sand square under the launch pad
const FOOTPRINT_TILES: Array[Vector2i] = [
	Vector2i(7, 29), Vector2i(6, 31), Vector2i(5, 26), Vector2i(12, 26), Vector2i(13, 28), Vector2i(3, 24)]

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
const TEX_ROCKS := [
	preload("res://art/decor/small_rock.png"),
	preload("res://art/decor/rock_cluster_small.png"),
	preload("res://art/decor/rock_cluster_large.png"),
]
const TEX_CHOKE_ROCK := preload("res://art/decor/rock_cluster_small.png")
const TEX_CRATER_SMALL := preload("res://art/craters/crater_single.png")
const TEX_CRATER_MEDIUM := preload("res://art/craters/crater_2x2.png")
const TEX_CRATER_BIG := preload("res://art/craters/crater_3x3.png")
const TEX_CLIFF_LEFT := preload("res://art/cliffs/cliff_left.png")
const TEX_CLIFF_RIGHT := preload("res://art/cliffs/cliff_right.png")
const TEX_FOOTPRINTS := preload("res://art/overlays/footprints.png")
## PLACEHOLDER art. Swap these files (or these paths) when the real rocket art exists.
const TEX_BROKEN_ROCKET := preload("res://art/placeholders/broken_rocket_placeholder.png")
const TEX_ROCKET_DEBRIS := preload("res://art/placeholders/rocket_debris_placeholder.png")

const RESOURCE_NODE_SCRIPT := preload("res://scripts/resource_node.gd")
const CRATER_SCRIPT := preload("res://scripts/crater_hazard.gd")

const DECOR_SCALE := Vector2(0.25, 0.25)    # rock art is drawn ~4x larger than tiles
const NODE_SCALE := Vector2(2.0, 2.0)       # metal / ice deposits (16 px art)
const ROCKET_SCALE := Vector2(1.5, 1.5)
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

@export var map_seed: int = 1337
@export var camera_zoom: float = 2.0
@export_tool_button("Generate Map", "TileMapLayer") var generate_button: Callable = generate

## Numbers from the last generate(): path lengths and the oxygen cost of a trip.
var last_report: Dictionary = {}

# Working data, only valid while generate() runs.
var _walk := PackedByteArray()              # 1 = walkable tile
var _dist := PackedInt32Array()             # walking distance from the spawn, in tiles
var _centres := {}                          # cell -> its point (tile)
var _branch := {}                           # cell -> which of the 3 main branches
var _degree := {}                           # cell -> number of corridors
var _edges: Array[Dictionary] = []          # {a, b, line, shortcut}
var _trail := {}                            # tile -> true, the sand path down each corridor
var _chambers := {}                         # cell -> Rect2i


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if (get_node("Ground") as TileMapLayer).get_used_cells().is_empty():
		generate()
	_setup_camera()


func generate() -> void:
	var ground := get_node("Ground") as TileMapLayer
	var walls := get_node("Walls") as TileMapLayer
	var nodes := get_node("Entities/Nodes")
	var decor := get_node("Entities/Decor")
	var ground_decor := get_node("GroundDecor")
	var cliffs := _get_or_make_cliffs(walls)
	for container in [nodes, decor, ground_decor, cliffs]:
		_clear_children(container)

	var rng := RandomNumberGenerator.new()
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.08

	# 1. Layout: which tiles can be walked on.
	# 2. Rewards: only in far dead-end chambers, checked by real walking distance.
	# A layout without enough far dead ends is thrown away and built again. The
	# retries are numbered, so one seed still always gives the same map.
	var rewards: Array[Dictionary] = []
	for attempt in LAYOUT_ATTEMPTS:
		rng.seed = map_seed if attempt == 0 else hash([map_seed, attempt])
		_build_maze(rng)
		_carve_everything()
		_dist = _flood_from(SPAWN_TILE)
		var last_try := attempt == LAYOUT_ATTEMPTS - 1
		rewards = _choose_reward_chambers(last_try)
		if not rewards.is_empty():
			break
	_ensure_reachable(rewards)

	# 3. Paint and fill.
	_paint_ground(ground, noise, rng, rewards)
	_paint_walls(walls)
	_place_cliffs(cliffs)
	_build_base(ground_decor)
	_place_rewards(nodes, decor, rewards, rng)
	_place_hazards(ground_decor, decor, rewards, rng)

	_make_report(rewards)


# ---------------------------------------------------------------------------
# 1. Layout
# ---------------------------------------------------------------------------

## Grows the maze over the coarse grid. Fills _centres, _branch, _degree, _edges.
func _build_maze(rng: RandomNumberGenerator) -> void:
	_centres.clear()
	_branch.clear()
	_degree.clear()
	_edges.clear()

	for cx in GRID_SIZE.x:
		for cy in GRID_SIZE.y:
			var cell := Vector2i(cx, cy)
			if CLEARING_CELLS.has_point(cell):
				continue
			var jitter := Vector2i(rng.randi_range(-CELL_JITTER, CELL_JITTER), rng.randi_range(-CELL_JITTER, CELL_JITTER))
			var centre := GRID_ORIGIN + cell * CELL_SIZE + Vector2i(CELL_SIZE, CELL_SIZE) / 2 + jitter
			# Keep a whole chamber inside the map, also for cells at the edge.
			var before := CHAMBER_SIZE / 2 + 1
			var after := CHAMBER_SIZE - CHAMBER_SIZE / 2
			_centres[cell] = centre.clamp(Vector2i(before, before), MAP_SIZE - Vector2i(after + 1, after + 1))
			_degree[cell] = 0
	_centres[HUB_CELL] = HUB_TILE

	# The hub starts one branch towards each free neighbour (2-3 branches).
	var in_maze := {HUB_CELL: true}
	var active: Array = []                   # one list of growable cells per branch
	var sizes: Array[int] = []
	for d in DIRS:
		var n := HUB_CELL + d
		if _centres.has(n):
			_link(HUB_CELL, n, false)
			in_maze[n] = true
			_branch[n] = active.size()
			active.append([n])
			sizes.append(1)

	# Always grow the smallest branch, so the three branches end up similar in size.
	while true:
		var b := -1
		for i in active.size():
			if not active[i].is_empty() and (b == -1 or sizes[i] < sizes[b]):
				b = i
		if b == -1:
			break
		var list: Array = active[b]
		var idx := list.size() - 1
		if rng.randf() < BRANCH_RANDOMNESS:
			idx = rng.randi_range(0, list.size() - 1)
		var cell: Vector2i = list[idx]
		var options: Array[Vector2i] = []
		for d in DIRS:
			var n := cell + d
			if _centres.has(n) and not in_maze.has(n):
				options.append(n)
		if options.is_empty():
			list.remove_at(idx)
			continue
		var next := options[rng.randi_range(0, options.size() - 1)]
		_link(cell, next, false)
		in_maze[next] = true
		_branch[next] = b
		list.append(next)
		sizes[b] += 1

	_add_loops(rng)


## Extra links between corridors that are far apart by path: these are the shortcuts.
func _add_loops(rng: RandomNumberGenerator) -> void:
	var candidates: Array = []               # [score, a, b]
	for a: Vector2i in _centres:
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var b := a + d
			if not _centres.has(b) or _linked(a, b):
				continue
			# Dead ends stay dead ends, and the hub keeps exactly its branches.
			if _degree[a] < 2 or _degree[b] < 2 or a == HUB_CELL or b == HUB_CELL:
				continue
			var steps := _maze_steps(a, b)
			if steps >= 5:
				candidates.append([steps * 1000 + rng.randi_range(0, 999), a, b])
	candidates.sort_custom(func(x, y): return x[0] > y[0])
	var used := {}
	var added := 0
	for c in candidates:
		if added >= LOOP_COUNT:
			break
		if used.has(c[1]) or used.has(c[2]):
			continue
		_link(c[1], c[2], true)
		used[c[1]] = true
		used[c[2]] = true
		added += 1


func _link(a: Vector2i, b: Vector2i, shortcut: bool) -> void:
	_edges.append({"a": a, "b": b, "line": [], "shortcut": shortcut})
	_degree[a] += 1
	_degree[b] += 1


func _linked(a: Vector2i, b: Vector2i) -> bool:
	for e in _edges:
		if (e.a == a and e.b == b) or (e.a == b and e.b == a):
			return true
	return false


## Number of corridors you walk from cell a to cell b.
func _maze_steps(a: Vector2i, b: Vector2i) -> int:
	var steps := {a: 0}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == b:
			return steps[cur]
		for e in _edges:
			var other: Variant = null
			if e.a == cur:
				other = e.b
			elif e.b == cur:
				other = e.a
			if other != null and not steps.has(other):
				steps[other] = steps[cur] + 1
				queue.append(other)
	return 0


## Turns the maze into walkable tiles: clearing, corridors, chambers.
func _carve_everything() -> void:
	_walk.resize(MAP_SIZE.x * MAP_SIZE.y)
	_walk.fill(0)
	_trail.clear()
	_chambers.clear()

	_carve_rect(CLEARING)
	# Exit of the clearing: one corridor east to the hub.
	var exit_line: Array[Vector2i] = []
	for x in range(PAD_PLAZA.end.x, HUB_TILE.x + 1):
		exit_line.append(Vector2i(x, HUB_TILE.y))
	_carve_line(exit_line)

	for e in _edges:
		var a: Vector2i = _centres[e.a]
		var b: Vector2i = _centres[e.b]
		# Side-by-side cells: walk across first, then up/down. Stacked cells: the other way.
		var line := _corner_line(a, b, e.a.y == e.b.y)
		e.line = line
		_carve_line(line)

	# Dead ends become chambers.
	for cell: Vector2i in _centres:
		if cell != HUB_CELL and _degree[cell] == 1:
			var half := CHAMBER_SIZE / 2
			var rect := Rect2i(_centres[cell] - Vector2i(half, half), Vector2i(CHAMBER_SIZE, CHAMBER_SIZE))
			_chambers[cell] = rect
			_carve_rect(rect)
	# The sand path stops at the chamber door.
	for rect: Rect2i in _chambers.values():
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				_trail.erase(Vector2i(x, y))


## Tiles from a to b with one 90-degree corner.
func _corner_line(a: Vector2i, b: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var line: Array[Vector2i] = [a]
	var p := a
	for step in 2:
		var along_x := (step == 0) == horizontal_first
		if along_x:
			while p.x != b.x:
				p.x += signi(b.x - p.x)
				line.append(p)
		else:
			while p.y != b.y:
				p.y += signi(b.y - p.y)
				line.append(p)
	return line


func _carve_line(line: Array[Vector2i]) -> void:
	var lo := -(CORRIDOR_WIDTH - 1) / 2
	var hi := CORRIDOR_WIDTH / 2
	for t in line:
		_trail[t] = true
		for dx in range(lo, hi + 1):
			for dy in range(lo, hi + 1):
				_carve(t + Vector2i(dx, dy))


func _carve_rect(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_carve(Vector2i(x, y))


## Marks a tile walkable. The outer ring of the map always stays wall.
func _carve(t: Vector2i) -> void:
	if t.x >= 1 and t.y >= 1 and t.x <= MAP_SIZE.x - 2 and t.y <= MAP_SIZE.y - 2:
		_walk[t.y * MAP_SIZE.x + t.x] = 1


func _is_walk(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= MAP_SIZE.x or t.y >= MAP_SIZE.y:
		return false
	return _walk[t.y * MAP_SIZE.x + t.x] == 1


## Walking distance (in tiles) from `start` to every tile. -1 = cannot be reached.
func _flood_from(start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(MAP_SIZE.x * MAP_SIZE.y)
	dist.fill(-1)
	dist[start.y * MAP_SIZE.x + start.x] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var d := dist[cur.y * MAP_SIZE.x + cur.x]
		for dir in DIRS:
			var n := cur + dir
			if _is_walk(n) and dist[n.y * MAP_SIZE.x + n.x] == -1:
				dist[n.y * MAP_SIZE.x + n.x] = d + 1
				queue.append(n)
	return dist


func _distance_to(t: Vector2i) -> int:
	return _dist[t.y * MAP_SIZE.x + t.x]


# ---------------------------------------------------------------------------
# 2. Rewards
# ---------------------------------------------------------------------------

## Picks the far dead-end chambers and decides how many metal / ice nodes each gets.
## Returns a list of {cell, kind, count, guarded}, farthest first.
## Returns nothing if there are too few far dead ends, unless `allow_near` is set.
func _choose_reward_chambers(allow_near: bool) -> Array[Dictionary]:
	var leaves: Array = _chambers.keys()
	leaves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := _distance_to(_centres[a])
		var db := _distance_to(_centres[b])
		if da != db:
			return da > db
		return a.x * 100 + a.y < b.x * 100 + b.y)

	var metal_min := ceili(float(Config.METAL_NODE_COUNT) / Config.MAX_NODES_PER_CHAMBER)
	var ice_min := ceili(float(Config.ICE_NODE_COUNT) / Config.MAX_NODES_PER_CHAMBER)
	if leaves.is_empty():
		if allow_near:
			push_warning("world_gen: the maze has no dead ends, so no rewards were placed")
		return []

	# Far enough = at least MIN_REWARD_DISTANCE of the longest walk on the map.
	var farthest := _distance_to(_centres[leaves[0]])
	var chosen: Array = []
	var safe_zone := CLEARING.grow(BASE_SAFE_RADIUS)
	for cell: Vector2i in leaves:
		if safe_zone.has_point(_centres[cell]):
			continue                              # far to walk, but right behind the base wall
		if _distance_to(_centres[cell]) >= farthest * Config.MIN_REWARD_DISTANCE and chosen.size() < MAX_REWARD_CHAMBERS:
			chosen.append(cell)
	if chosen.size() < metal_min + ice_min:
		if not allow_near:
			return []
		push_warning("world_gen: only %d far dead ends, using nearer ones as well" % chosen.size())
		chosen = leaves.slice(0, mini(leaves.size(), metal_min + ice_min))

	# Ice goes to one branch (region) of the map, metal to the others.
	var ice_chambers := clampi(roundi(chosen.size() * float(Config.ICE_NODE_COUNT) / (Config.ICE_NODE_COUNT + Config.METAL_NODE_COUNT)),
		ice_min, maxi(ice_min, chosen.size() - metal_min))
	ice_chambers = mini(ice_chambers, chosen.size() - 1)
	var per_branch := {}
	for cell: Vector2i in chosen:
		if not per_branch.has(_branch[cell]):
			per_branch[_branch[cell]] = []
		per_branch[_branch[cell]].append(cell)
	var ice_cells: Array = []
	var best_branch := -1
	for b: int in per_branch:
		var n: int = per_branch[b].size()
		if n >= ice_chambers and n < chosen.size() and (best_branch == -1 or n < per_branch[best_branch].size()):
			best_branch = b
	if best_branch != -1:
		ice_cells = per_branch[best_branch].slice(0, ice_chambers)
	else:
		# No single branch has enough: use the northern chambers as the ice region.
		var by_north := chosen.duplicate()
		by_north.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _centres[a].y * 1000 + _centres[a].x < _centres[b].y * 1000 + _centres[b].x)
		ice_cells = by_north.slice(0, ice_chambers)

	var metal_cells: Array = chosen.filter(func(c: Vector2i) -> bool: return not ice_cells.has(c))
	var ice_counts := _spread(Config.ICE_NODE_COUNT, ice_cells.size())
	var metal_counts := _spread(Config.METAL_NODE_COUNT, metal_cells.size())

	var rewards: Array[Dictionary] = []
	for cell: Vector2i in chosen:              # still farthest first
		var is_ice := ice_cells.has(cell)
		var count: int = ice_counts[ice_cells.find(cell)] if is_ice else metal_counts[metal_cells.find(cell)]
		if count > 0:
			rewards.append({"cell": cell, "kind": "ice" if is_ice else "metal", "count": count, "guarded": false})

	# The richest (then farthest) chambers are the guarded ones.
	var by_value := rewards.duplicate()
	by_value.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.count != b.count:
			return a.count > b.count
		return _distance_to(_centres[a.cell]) > _distance_to(_centres[b.cell]))
	for i in mini(GUARDED_CHAMBERS, by_value.size()):
		by_value[i].guarded = true
	return rewards


## Shares `total` nodes over `chambers` chambers. The first (farthest) get the most.
func _spread(total: int, chambers: int) -> Array[int]:
	var counts: Array[int] = []
	if chambers <= 0:
		return counts
	counts.resize(chambers)
	counts.fill(0)
	var cap := maxi(Config.MAX_NODES_PER_CHAMBER, ceili(float(total) / chambers))
	var left := total
	while left > 0:
		var gave := false
		for i in chambers:
			if left > 0 and counts[i] < cap:
				counts[i] += 1
				left -= 1
				gave = true
		if not gave:
			break
	return counts


## Every reward chamber must be reachable on foot from the spawn. The maze makes
## that true by design; this is the safety net (it digs a corridor to the hub).
func _ensure_reachable(rewards: Array[Dictionary]) -> void:
	var fixed := false
	for r in rewards:
		var c: Vector2i = _centres[r.cell]
		if _distance_to(c) < 0:
			push_warning("world_gen: chamber %s was cut off, digging a corridor to the hub" % str(r.cell))
			_carve_line(_corner_line(c, HUB_TILE, true))
			fixed = true
	if fixed:
		_dist = _flood_from(SPAWN_TILE)
		for r in rewards:
			if _distance_to(_centres[r.cell]) < 0:
				push_warning("world_gen: chamber %s is still unreachable" % str(r.cell))


# ---------------------------------------------------------------------------
# 3. Painting
# ---------------------------------------------------------------------------

func _paint_ground(ground: TileMapLayer, noise: FastNoiseLite, rng: RandomNumberGenerator, rewards: Array[Dictionary]) -> void:
	ground.clear()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			var t := Vector2i(x, y)
			var tile := T_REGOLITH
			var n := noise.get_noise_2d(x, y)
			var r := rng.randf()                 # always drawn, so the map stays the same per seed
			if CLEARING.has_point(t):
				tile = T_REGOLITH                # the base is flat, clean ground
			elif n > 0.38:
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

	# Chamber floors hint at what is inside: icy ground or rocky ground.
	for reward in rewards:
		var rect: Rect2i = _chambers[reward.cell]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var roll := rng.randf()
				if reward.kind == "ice" and roll < 0.4:
					ground.set_cell(Vector2i(x, y), SOURCE_ID, T_ICE)
				elif reward.kind == "metal" and roll < 0.3:
					ground.set_cell(Vector2i(x, y), SOURCE_ID, T_ROCKY if roll < 0.15 else T_ROCKS)

	# The sand trail down the middle of every corridor.
	for t: Vector2i in _trail:
		var pick := _trail_tile(t)
		ground.set_cell(t, SOURCE_ID, pick[0], pick[1])

	# Base: a sand plaza under the launch pad, and scorched ground under the wreck.
	_paint_sand_rect(ground, PAD_PLAZA)
	for x in range(ROCKET_TILE.x - 2, ROCKET_TILE.x + 3):
		for y in range(ROCKET_TILE.y - 2, ROCKET_TILE.y + 1):
			if CLEARING.has_point(Vector2i(x, y)):
				ground.set_cell(Vector2i(x, y), SOURCE_ID, T_CRACKED)


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


## Cliff faces on every rock edge that looks down onto a path (the art shows a
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
			s.position = Vector2(Vector2i(x, y) * TILE) + Vector2(TILE, TILE) * 0.5
			cliffs.add_child(s)
			s.owner = _scene_owner()


func _faces_south(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < MAP_SIZE.x and not _is_walk(t) and _is_walk(t + Vector2i.DOWN)


# ---------------------------------------------------------------------------
# 4. The base clearing
# ---------------------------------------------------------------------------

func _build_base(ground_decor: Node) -> void:
	# Move the existing landmarks to their tiles.
	var pad := get_node_or_null("LaunchPad") as Node2D
	if pad != null:
		pad.position = _tile_centre(LAUNCH_PAD_TILE)
	var hab := get_node_or_null("Entities/Hab") as Node2D
	if hab != null:
		hab.position = _tile_centre(HAB_TILE)
	var player := get_node_or_null("Entities/Player") as Node2D
	if player != null:
		player.position = _tile_centre(SPAWN_TILE)

	# Footprints between the hab, the pad and the wreck.
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

	var size := TEX_BROKEN_ROCKET.get_size() * ROCKET_SCALE
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = TEX_BROKEN_ROCKET
	sprite.scale = ROCKET_SCALE
	sprite.position = Vector2(0, -size.y * 0.5)
	rocket.add_child(sprite)
	sprite.owner = _scene_owner()

	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x * 0.9, size.y * 0.5)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	collision.position = Vector2(0, -size.y * 0.3)
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


# ---------------------------------------------------------------------------
# 5. Rewards and hazards
# ---------------------------------------------------------------------------

func _place_rewards(nodes: Node, decor: Node, rewards: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Spots inside a chamber, away from the door lines: the corners first.
	var lo := -(CHAMBER_SIZE / 2)
	var hi := CHAMBER_SIZE - CHAMBER_SIZE / 2 - 1
	var corner_spots: Array[Vector2i] = [Vector2i(lo, lo), Vector2i(hi, lo), Vector2i(lo, hi), Vector2i(hi, hi)]
	var extra_spots: Array[Vector2i] = [Vector2i(lo + 1, lo), Vector2i(hi - 1, hi), Vector2i(lo, hi - 1), Vector2i(hi, lo + 1)]
	var reward_by_cell := {}
	for r in rewards:
		reward_by_cell[r.cell] = r

	var metal_i := 0
	var ice_i := 0
	var rock_i := 0
	for cell: Vector2i in _chambers:
		var spots := corner_spots.duplicate()
		_shuffle(spots, rng)
		spots.append_array(extra_spots)
		var centre: Vector2i = _centres[cell]
		var used := 0
		if reward_by_cell.has(cell):
			var r: Dictionary = reward_by_cell[cell]
			for i in r.count:
				# Only on floor the player can really reach.
				while used < spots.size() and _distance_to(centre + spots[used]) < 0:
					used += 1
				if used >= spots.size():
					push_warning("world_gen: chamber %s has no room for all its nodes" % str(cell))
					break
				var node_name := ""
				if r.kind == "metal":
					metal_i += 1
					node_name = "Metal%02d" % metal_i
				else:
					ice_i += 1
					node_name = "Ice%02d" % ice_i
				var s := _place_sprite(nodes, node_name, TEX_METAL if r.kind == "metal" else TEX_ICE, NODE_SCALE,
					_tile_centre(centre + spots[used]), RESOURCE_NODE_SCRIPT, {"kind": r.kind, "charges_left": Config.NODE_CHARGES})
				s.set_meta("kind", r.kind)
				used += 1
		# Rocks fill some of the free spots. Empty dead ends get more of them.
		var rocks := 1 if reward_by_cell.has(cell) else rng.randi_range(2, 3)
		for i in rocks:
			if used >= corner_spots.size():
				break
			rock_i += 1
			var tex: Texture2D = TEX_ROCKS[rng.randi() % TEX_ROCKS.size()]
			_place_sprite(decor, "Rock%02d" % rock_i, tex, DECOR_SCALE, _tile_centre(centre + spots[used]))
			used += 1


func _place_hazards(ground_decor: Node, decor: Node, rewards: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var reward_by_cell := {}
	for r in rewards:
		reward_by_cell[r.cell] = r
	var crater_i := 0
	var choke_i := 0

	for e in _edges:
		if e.a == HUB_CELL or e.b == HUB_CELL:
			continue                              # the first corridors out of the base are safe
		var line: Array[Vector2i] = e.line
		var slots := _obstacle_slots(line)
		var used: Array[int] = []

		var reward: Dictionary = reward_by_cell.get(e.b, reward_by_cell.get(e.a, {}))
		var leads_to_chamber: bool = _chambers.has(e.a) or _chambers.has(e.b)
		var plan: Array[String] = []              # what to put on this corridor
		if e.shortcut:
			plan = ["big", "big"]                 # shortcuts always cost oxygen
		elif leads_to_chamber and not reward.is_empty() and reward.guarded:
			plan = ["big", "choke"]
		elif leads_to_chamber and not reward.is_empty():
			plan = ["medium"]
		elif rng.randf() < CRATER_DENSITY:
			plan = ["small" if rng.randf() < 0.6 else "medium"]

		for what in plan:
			var i := _take_slot(slots, used, rng)
			if i == -1:
				break
			var along := line[i + 1] - line[i]
			var across := Vector2(-along.y, along.x)
			var horizontal := along.x != 0
			var pos := _tile_centre(line[i])
			if what == "choke":
				# Two rocks squeeze the corridor down to one tile.
				for side: float in [-1.0, 1.0]:
					choke_i += 1
					_place_sprite(decor, "ChokeRock%02d" % choke_i, TEX_CHOKE_ROCK, DECOR_SCALE, pos + across * side * TILE)
				continue
			crater_i += 1
			var crater_name := "Crater%02d" % crater_i
			if what == "big":
				# Fills the whole corridor: cannot be walked around.
				_place_sprite(ground_decor, crater_name, TEX_CRATER_BIG,
					Vector2.ONE * (CORRIDOR_WIDTH * TILE) / TEX_CRATER_BIG.get_size().x, pos, CRATER_SCRIPT,
					{"hazard_fraction": Vector2(0.8, 1.15) if horizontal else Vector2(1.15, 0.8)})
			elif what == "medium":
				# Two tiles wide against one wall: one tile is left to squeeze past.
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				_place_sprite(ground_decor, crater_name, TEX_CRATER_MEDIUM,
					Vector2.ONE * (TILE * 1.9) / TEX_CRATER_MEDIUM.get_size().x, pos + across * side * TILE * 0.55, CRATER_SCRIPT,
					{"hazard_fraction": Vector2(0.75, 0.75), "rotation": PI / 2 if horizontal else 0.0})
			else:
				# One tile: easy to step around if you watch where you walk.
				var lane := float(rng.randi_range(-1, 1))
				_place_sprite(ground_decor, crater_name, TEX_CRATER_SMALL,
					Vector2.ONE * (TILE * 1.1) / TEX_CRATER_SMALL.get_size().x, pos + across * lane * TILE, CRATER_SCRIPT,
					{"hazard_fraction": Vector2(0.7, 0.7)})


## Places on a corridor where an obstacle fits: straight, plain corridor, well
## away from junctions, corners, chambers and the base.
func _obstacle_slots(line: Array[Vector2i]) -> Array[int]:
	var slots: Array[int] = []
	var reach := CORRIDOR_WIDTH / 2 + 1          # first tile beyond the corridor wall
	for i in range(2, line.size() - 2):
		var along := line[i + 1] - line[i]
		if line[i] - line[i - 1] != along or line[i + 2] - line[i + 1] != along:
			continue                              # too close to the corner
		var across := Vector2i(-along.y, along.x)
		var plain := true
		for j in [i - 1, i, i + 1]:
			if _is_walk(line[j] + across * reach) or _is_walk(line[j] - across * reach):
				plain = false                     # something opens up next to the corridor here
				break
		if plain:
			slots.append(i)
	return slots


## Picks a free slot at least 3 tiles from the ones already used. -1 = none left.
func _take_slot(slots: Array[int], used: Array[int], rng: RandomNumberGenerator) -> int:
	var free: Array[int] = []
	for s in slots:
		var ok := true
		for u in used:
			if absi(s - u) < 3:
				ok = false
				break
		if ok:
			free.append(s)
	if free.is_empty():
		return -1
	var pick := free[rng.randi_range(0, free.size() - 1)]
	used.append(pick)
	return pick


# ---------------------------------------------------------------------------
# Report: path lengths and the oxygen budget
# ---------------------------------------------------------------------------

func _make_report(rewards: Array[Dictionary]) -> void:
	last_report = {}
	if rewards.is_empty():
		return
	var player := get_node_or_null("Entities/Player")
	var speed := 250.0
	if player != null and player.get("speed") != null:
		speed = float(player.get("speed"))

	var nearest := 1 << 30
	var farthest := 0
	var unreachable := 0
	var in_base := 0
	var metal := 0
	var ice := 0
	for n in get_node("Entities/Nodes").get_children():
		var t := Vector2i((n as Node2D).position / TILE)
		var d := _distance_to(t)
		if d < 0:
			unreachable += 1
			continue
		nearest = mini(nearest, d)
		farthest = maxi(farthest, d)
		if CLEARING.grow(BASE_SAFE_RADIUS - CHAMBER_SIZE).has_point(t):
			in_base += 1
		if n.get_meta("kind", "") == "metal":
			metal += 1
		else:
			ice += 1

	var near_s := nearest * TILE / speed
	var far_s := farthest * TILE / speed
	last_report = {
		"metal_nodes": metal,
		"ice_nodes": ice,
		"reward_chambers": rewards.size(),
		"dead_ends": _chambers.size(),
		"unreachable_nodes": unreachable,
		"nodes_near_base": in_base,
		"nearest_tiles": nearest,
		"farthest_tiles": farthest,
		"nearest_seconds": near_s,
		"farthest_seconds": far_s,
		"nearest_share": float(nearest) / maxf(1.0, farthest),
		# Walking there and back, without craters or harvesting:
		"nearest_round_trip_o2": 2.0 * near_s * Config.O2_DRAIN_PER_SEC,
		"farthest_round_trip_o2": 2.0 * far_s * Config.O2_DRAIN_PER_SEC,
		"craters": get_node("GroundDecor").get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Crater")).size(),
	}
	print("world_gen seed %d: %d metal + %d ice nodes in %d chambers (%d dead ends), %d craters" % [
		map_seed, metal, ice, rewards.size(), _chambers.size(), last_report.craters])
	print("world_gen: nearest deposit %d tiles (%.1f s one way), farthest %d tiles (%.1f s one way), nearest = %d%% of farthest" % [
		nearest, near_s, farthest, far_s, roundi(last_report.nearest_share * 100.0)])
	print("world_gen: walking O2 for a round trip: nearest %.1f, farthest %.1f (+%d per crater, +%d per harvest)" % [
		last_report.nearest_round_trip_o2, last_report.farthest_round_trip_o2,
		roundi(Config.CRATER_O2_PENALTY), roundi(Config.O2_HARVEST_COST)])
	if unreachable > 0:
		push_warning("world_gen: %d resource nodes cannot be reached" % unreachable)
	if in_base > 0:
		push_warning("world_gen: %d resource nodes are next to the base" % in_base)


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


func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


## The node that holds the cliff sprites, drawn right above the Walls layer.
func _get_or_make_cliffs(walls: Node) -> Node:
	var cliffs := get_node_or_null("Cliffs")
	if cliffs == null:
		cliffs = Node2D.new()
		cliffs.name = "Cliffs"
		add_child(cliffs)
		move_child(cliffs, walls.get_index() + 1)
		cliffs.owner = _scene_owner()
	return cliffs


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
