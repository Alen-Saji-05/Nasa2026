class_name CaveGen
extends RefCounted
## Makes the layout of ONE cave layer from the numbers in Config.CAVES.
## It only decides where things go; scripts/world/cave.gd paints it.
##
##   var layout := CaveGen.build(Config.cave("ice"), 0)   # first layer of the Ice Cave
##
## How a layer is made:
##   1. A grid of small ROOMS (3-4 tiles wide), separated by thin rock ridges.
##   2. A maze decides which neighbouring rooms are joined by a DOOR (a gap in the
##      ridge). Some doors are as wide as the room, some only 1-2 tiles.
##   3. Rooms with a single door are dead ends. The farthest one gets the ladder
##      down, the next ones get the metal and ice. Empty ones get rocks.
##   4. Guarded rooms and shortcuts have a crater that fills the door (it costs
##      oxygen to pass). Other rooms may have a small crater you can walk around.
##   5. Any empty patch of floor that is still too big gets a rock.
## The same cave and layer always give the same layout. A layout that breaks a
## rule (size, floor share, reachability, ...) is thrown away and built again
## with the next numbered attempt, so the result is still always the same.

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const ATTEMPTS := 300
const NONE := Vector2i(-1, -1)

# Layout tuning (sizes and limits are in config.gd).
const FLOOR_WIDTHS: Array[int] = [3, 4, 4]           # a room is one of these wide
const FLOOR_HEIGHTS: Array[int] = [3, 3, 4]          # ... and one of these tall
const RIDGE_THICKNESS: Array[int] = [1, 1, 1, 1, 2]  # rock between two rooms
const WIDE_DOOR_CHANCE := 0.6                        # a door as wide as the room
const BRANCHINESS := 0.3                             # 0 = one long winding path, 1 = many short dead ends
const MIN_LOOP_STEPS := 4                            # a shortcut must save at least this many rooms

# --- The result ---
var cave_id := ""
var layer := 0                               # 0 = the first layer
var layer_count := 1
var size := Vector2i.ZERO                    # in tiles
var walk := PackedByteArray()                # 1 = floor
## Where the player stands after arriving from outside (layer 0) or from the layer above.
var entry_tile := NONE
## Layer 0 only: the floor tile of the way out. Walking onto it leaves the cave.
var exit_tile := NONE
## Layers below the first: the floor tile at the foot of the ladder up.
var ladder_up_tile := NONE
## All but the last layer: the floor tile with the ladder down.
var ladder_down_tile := NONE
var nodes: Array[Dictionary] = []            # {id, kind, tile, ore (optional: the item id)}
var door_craters: Array[Rect2i] = []         # craters that fill a door (tiles)
var small_craters: Array[Vector2i] = []
var rocks: Array[Vector2i] = []
var chambers: Array[Dictionary] = []         # reward rooms: {rect, kind}
var report: Dictionary = {}
## True when every rule holds.
var ok := false
var attempt := 0

# --- Working data ---
var _rng := RandomNumberGenerator.new()
var _cols := 0
var _rows := 0
var _x0: Array[int] = []                     # first floor column of each grid column
var _fw: Array[int] = []                     # floor width of each grid column
var _y0: Array[int] = []
var _fh: Array[int] = []
var _links: Array[Dictionary] = []           # {a, b, loop, door: Array[Vector2i]}
var _degree := {}                            # cell -> number of doors
var _entry_cell := NONE
var _role := {}                              # cell -> "ladder" / "metal" / "ice" / "guard_metal" / "guard_ice"
var _blocked := {}                           # tile -> true: something solid stands here
var _used := PackedByteArray()               # 1 = wall or a tile with something on it
var _keep := {}                              # tile -> true: must stay free of rocks


## Builds the layer, trying numbered attempts until every rule holds.
static func build(cave: Dictionary, layer_index: int) -> CaveGen:
	var gen: CaveGen = null
	for i in ATTEMPTS:
		gen = CaveGen.new()
		gen.attempt = i
		gen._generate(cave, layer_index)
		if gen.ok:
			return gen
	push_warning("cave_gen: %s layer %d breaks a rule even after %d attempts: %s" % [
		cave.get("id", "?"), layer_index + 1, ATTEMPTS, str(gen.report.get("problems", []))])
	return gen


## The stable id of a deposit, for example "ice/L2/Ice01".
static func node_id(cave: String, layer_index: int, kind: String, number: int) -> String:
	return "%s/L%d/%s%02d" % [cave, layer_index + 1, kind.capitalize(), number]


func is_walk(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and walk[t.y * size.x + t.x] == 1


## Where the player appears. `arrival` is how they got here:
## "ladder_up" = climbed up from the layer below, anything else = came in from above/outside.
func spawn_tile(arrival: String) -> Vector2i:
	if arrival == "ladder_up" and ladder_down_tile != NONE:
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var t: Vector2i = ladder_down_tile + d
			if is_walk(t) and not _blocked.has(t):
				return t
		return ladder_down_tile
	return entry_tile


# ---------------------------------------------------------------------------

func _generate(cave: Dictionary, layer_index: int) -> void:
	cave_id = cave.id
	layer = layer_index
	layer_count = cave.layers.size()
	var spec: Dictionary = cave.layers[layer_index]
	_rng.seed = hash([cave.seed, layer_index, attempt])
	_cols = spec.cols
	_rows = spec.rows

	_make_grid()
	if size.x < Config.CAVE_SIZE_MIN.x or size.y < Config.CAVE_SIZE_MIN.y or size.x > Config.CAVE_SIZE_MAX.x or size.y > Config.CAVE_SIZE_MAX.y:
		report = {"problems": ["size %dx%d" % [size.x, size.y]]}
		return
	_make_maze(spec.get("loops", 0))
	if not _choose_roles(spec):
		report = {"problems": ["not enough dead-end rooms for the ladder and the deposits"]}
		return
	_carve()
	_place_entry_and_ladders()
	_place_nodes(spec)
	_place_craters(spec.get("crater_chance", 0.0))
	_place_rocks()
	_make_report(spec)


func _index(t: Vector2i) -> int:
	return t.y * size.x + t.x


func _pick(options: Array[int]) -> int:
	return options[_rng.randi_range(0, options.size() - 1)]


## 1. Room sizes and positions. One tile of rock all around the layer.
func _make_grid() -> void:
	var x := 1
	for c in _cols:
		_x0.append(x)
		_fw.append(_pick(FLOOR_WIDTHS))
		x += _fw[c] + (_pick(RIDGE_THICKNESS) if c < _cols - 1 else 0)
	var y := 1
	for r in _rows:
		_y0.append(y)
		_fh.append(_pick(FLOOR_HEIGHTS))
		y += _fh[r] + (_pick(RIDGE_THICKNESS) if r < _rows - 1 else 0)
	size = Vector2i(x + 1, y + 1)


func _cell_rect(cell: Vector2i) -> Rect2i:
	return Rect2i(_x0[cell.x], _y0[cell.y], _fw[cell.x], _fh[cell.y])


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _cols and cell.y < _rows


## 2. Which rooms are joined. Starts at the entry room and grows like a tree.
func _make_maze(loops: int) -> void:
	for cx in _cols:
		for cy in _rows:
			_degree[Vector2i(cx, cy)] = 0
	# You come in at the bottom on the first layer (from the surface), and at the
	# top on deeper layers (down a ladder that leans on the north wall).
	var column := _rng.randi_range(1, _cols - 2)
	_entry_cell = Vector2i(column, _rows - 1 if layer == 0 else 0)

	var in_maze := {_entry_cell: true}
	var active: Array[Vector2i] = [_entry_cell]
	while not active.is_empty():
		var idx := active.size() - 1
		if _rng.randf() < BRANCHINESS:
			idx = _rng.randi_range(0, active.size() - 1)
		var cell := active[idx]
		var options: Array[Vector2i] = []
		for d in DIRS:
			var n := cell + d
			if _in_grid(n) and not in_maze.has(n):
				options.append(n)
		if options.is_empty():
			active.remove_at(idx)
			continue
		var next := options[_rng.randi_range(0, options.size() - 1)]
		_link(cell, next, false)
		in_maze[next] = true
		active.append(next)

	# Shortcuts: an extra door between two rooms that are far apart by path.
	var candidates: Array = []                   # [score, a, b]
	for cx in _cols:
		for cy in _rows:
			var a := Vector2i(cx, cy)
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var b := a + d
				if not _in_grid(b) or _linked(a, b):
					continue
				# Dead ends stay dead ends.
				if _degree[a] < 2 or _degree[b] < 2:
					continue
				var steps := _maze_steps(a, b)
				if steps >= MIN_LOOP_STEPS:
					candidates.append([steps * 1000 + _rng.randi_range(0, 999), a, b])
	candidates.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0])
	var touched := {}
	var added := 0
	for c in candidates:
		if added >= loops:
			break
		if touched.has(c[1]) or touched.has(c[2]):
			continue
		_link(c[1], c[2], true)
		touched[c[1]] = true
		touched[c[2]] = true
		added += 1


func _link(a: Vector2i, b: Vector2i, loop: bool) -> void:
	# Stored left-to-right or top-to-bottom.
	var first := a if (a.x < b.x or a.y < b.y) else b
	var second := b if first == a else a
	_links.append({"a": first, "b": second, "loop": loop, "door": [] as Array[Vector2i]})
	_degree[a] += 1
	_degree[b] += 1


func _linked(a: Vector2i, b: Vector2i) -> bool:
	for l in _links:
		if (l.a == a and l.b == b) or (l.a == b and l.b == a):
			return true
	return false


## Number of doors you walk through from room a to room b.
func _maze_steps(a: Vector2i, b: Vector2i) -> int:
	var steps := {a: 0}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == b:
			return steps[cur]
		for l in _links:
			var other := NONE
			if l.a == cur:
				other = l.b
			elif l.b == cur:
				other = l.a
			if other != NONE and not steps.has(other):
				steps[other] = steps[cur] + 1
				queue.append(other)
	return 0


## 3. What each dead-end room is for. Returns false if there are too few of them.
func _choose_roles(spec: Dictionary) -> bool:
	var dead_ends: Array[Vector2i] = []
	for cell: Vector2i in _degree:
		# A room right next to the entry is no reward: it is too easy to reach.
		if _degree[cell] == 1 and cell != _entry_cell and _maze_steps(_entry_cell, cell) >= 2:
			dead_ends.append(cell)
	var steps := {}
	for cell in dead_ends:
		steps[cell] = _maze_steps(_entry_cell, cell)
	dead_ends.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		if steps[p] != steps[q]:
			return steps[p] > steps[q]
		return p.x * 100 + p.y < q.x * 100 + q.y)

	# The ladder down takes the farthest dead end: the whole layer is in the way.
	if layer < layer_count - 1:
		if dead_ends.is_empty():
			return false
		_role[dead_ends.pop_front()] = "ladder"

	# Then the deposits, the bigger group first (so it gets the farther rooms).
	# Metal and ice never share a room.
	var kinds: Array[String] = ["metal", "ice"]
	if spec.ice > spec.metal:
		kinds = ["ice", "metal"]
	var reward_rooms: Array[Vector2i] = []
	for kind in kinds:
		var left: int = spec[kind]
		while left > 0:
			if dead_ends.is_empty():
				return false
			var cell: Vector2i = dead_ends.pop_front()
			_role[cell] = kind
			reward_rooms.append(cell)
			left -= _room_capacity(cell)

	# The first rooms (farthest, fullest) are the guarded ones.
	for i in mini(spec.get("guarded", 0), reward_rooms.size()):
		_role[reward_rooms[i]] = "guard_" + _role[reward_rooms[i]]
	return true


## How many deposits fit in a room and still leave space to walk.
func _room_capacity(cell: Vector2i) -> int:
	var rect := _cell_rect(cell)
	return clampi(rect.size.x * rect.size.y / 4, 1, Config.MAX_NODES_PER_CHAMBER)


func _room_kind(cell: Vector2i) -> String:
	return str(_role.get(cell, "")).trim_prefix("guard_")


func _is_guarded(cell: Vector2i) -> bool:
	return str(_role.get(cell, "")).begins_with("guard_")


## 4. Floor tiles: every room, plus a door for every link.
func _carve() -> void:
	walk.resize(size.x * size.y)
	walk.fill(0)
	for cx in _cols:
		for cy in _rows:
			var rect := _cell_rect(Vector2i(cx, cy))
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					walk[_index(Vector2i(x, y))] = 1

	for l in _links:
		var a: Vector2i = l.a
		var b: Vector2i = l.b
		var ra := _cell_rect(a)
		var rb := _cell_rect(b)
		var side_by_side := a.y == b.y
		# The door runs along `span` tiles and is as thick as the ridge.
		var span := ra.size.y if side_by_side else ra.size.x
		var kind_a := str(_role.get(a, ""))
		var kind_b := str(_role.get(b, ""))
		var reward := kind_a if kind_a != "" and kind_a != "ladder" else (kind_b if kind_b != "ladder" else "")
		var width := span
		if l.loop or reward.begins_with("guard_"):
			width = mini(2, span)                # a crater will fill it
		elif reward != "":
			width = 1                            # a squeeze: one tile wide
		elif _rng.randf() >= WIDE_DOOR_CHANCE:
			width = _rng.randi_range(1, mini(2, span))
		var offset := _rng.randi_range(0, span - width)

		var door: Array[Vector2i] = []
		if side_by_side:
			for x in range(ra.end.x, rb.position.x):
				for y in range(ra.position.y + offset, ra.position.y + offset + width):
					door.append(Vector2i(x, y))
		else:
			for y in range(ra.end.y, rb.position.y):
				for x in range(ra.position.x + offset, ra.position.x + offset + width):
					door.append(Vector2i(x, y))
		l.door = door
		for t in door:
			walk[_index(t)] = 1
			_keep[t] = true
		# Keep the floor right in front of a door clear, on both sides.
		var step := Vector2i.RIGHT if side_by_side else Vector2i.DOWN
		for t in door:
			_keep[t + step] = true
			_keep[t - step] = true

		if l.loop or reward.begins_with("guard_"):
			var first: Vector2i = door[0]
			var last: Vector2i = door[door.size() - 1]
			door_craters.append(Rect2i(first, last - first + Vector2i.ONE))


## The way in, the way out and the ladders.
func _place_entry_and_ladders() -> void:
	var rect := _cell_rect(_entry_cell)
	var x := rect.position.x + rect.size.x / 2
	if layer == 0:
		# A notch in the south wall: the way out to the surface.
		exit_tile = Vector2i(x, rect.end.y)
		walk[_index(exit_tile)] = 1
		entry_tile = exit_tile + Vector2i.UP
		_keep[exit_tile] = true
	else:
		# The ladder up leans on the north wall of the entry room.
		ladder_up_tile = Vector2i(x, rect.position.y)
		entry_tile = ladder_up_tile + Vector2i.DOWN
		_keep[ladder_up_tile] = true
	_keep[entry_tile] = true

	for cell: Vector2i in _role:
		if _role[cell] == "ladder":
			var r := _cell_rect(cell)
			ladder_down_tile = r.position + r.size / 2
			_keep[ladder_down_tile] = true
			for d in DIRS:
				_keep[ladder_down_tile + d] = true


## The single door of a dead-end room.
func _door_of(cell: Vector2i) -> Array[Vector2i]:
	for l in _links:
		if l.a == cell or l.b == cell:
			return l.door
	return []


## Floor tiles of a room, the ones farthest from its door first.
func _tiles_far_from_door(cell: Vector2i) -> Array[Vector2i]:
	var door := _door_of(cell)
	var rect := _cell_rect(cell)
	var scored: Array = []                       # [distance, tile]
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var t := Vector2i(x, y)
			var nearest := 999.0
			for d in door:
				nearest = minf(nearest, Vector2(t - d).length())
			scored.append([nearest, t])
	scored.sort_custom(func(p: Array, q: Array) -> bool:
		if p[0] != q[0]:
			return p[0] > q[0]
		return p[1].x * 100 + p[1].y < q[1].x * 100 + q[1].y)
	var tiles: Array[Vector2i] = []
	for s in scored:
		tiles.append(s[1])
	return tiles


## 5. Deposits in the reward rooms, far from the door and not side by side.
func _place_nodes(spec: Dictionary) -> void:
	var left := {"metal": spec.metal, "ice": spec.ice}
	var number := {"metal": 0, "ice": 0}
	# Farthest rooms first, in the order the roles were given.
	for cell: Vector2i in _role:
		var kind := _room_kind(cell)
		if kind != "metal" and kind != "ice":
			continue
		chambers.append({"rect": _cell_rect(cell), "kind": kind})
		var placed: Array[Vector2i] = []
		for t in _tiles_far_from_door(cell):
			if placed.size() >= _room_capacity(cell) or left[kind] <= 0:
				break
			if _keep.has(t):
				continue
			if placed.any(func(p: Vector2i) -> bool: return maxi(absi(p.x - t.x), absi(p.y - t.y)) < 2):
				continue
			placed.append(t)
			left[kind] -= 1
			number[kind] += 1
			var node := {"id": node_id(cave_id, layer, kind, number[kind]), "kind": kind, "tile": t}
			# A "metal" deposit is really one of the ores, if the layer names them.
			var ores: Array = spec.get("ores", [])
			if kind == "metal" and number[kind] <= ores.size():
				node["ore"] = ores[number[kind] - 1]
			nodes.append(node)
			_blocked[t] = true
			_keep[t] = true


func _place_craters(chance: float) -> void:
	# Ordinary rooms you pass through: sometimes a small crater to step around.
	for cx in _cols:
		for cy in _rows:
			var cell := Vector2i(cx, cy)
			var roll := _rng.randf()             # always drawn, so layouts stay stable
			if _degree[cell] < 2 or cell == _entry_cell or roll >= chance:
				continue
			var rect := _cell_rect(cell)
			var options: Array[Vector2i] = []
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					if not _keep.has(Vector2i(x, y)):
						options.append(Vector2i(x, y))
			if not options.is_empty():
				var t := options[_rng.randi_range(0, options.size() - 1)]
				small_craters.append(t)
				_keep[t] = true


func _place_rocks() -> void:
	_used.resize(size.x * size.y)
	for i in walk.size():
		_used[i] = 1 - walk[i]
	var taken: Array[Vector2i] = [entry_tile]
	taken.append_array(small_craters)
	for n in nodes:
		taken.append(n.tile)
	for crater in door_craters:
		for x in range(crater.position.x, crater.end.x):
			for y in range(crater.position.y, crater.end.y):
				taken.append(Vector2i(x, y))
	for t: Vector2i in [exit_tile, ladder_up_tile, ladder_down_tile]:
		if t != NONE:
			taken.append(t)
	for t in taken:
		_used[_index(t)] = 1

	# Empty dead ends are not left bare: a rock or two in the far corners.
	for cell: Vector2i in _degree:
		if _degree[cell] != 1 or cell == _entry_cell or _role.has(cell):
			continue
		var wanted := _rng.randi_range(1, 2)
		for t in _tiles_far_from_door(cell):
			if wanted <= 0:
				break
			if _try_rock(t):
				wanted -= 1

	# No dead space: a rock in every plain patch that is still too big.
	for guard in 200:
		var gap := _largest_empty_square()
		var side := gap.size.x
		if side <= Config.CAVE_MAX_EMPTY_SQUARE:
			return
		var centre := gap.position + Vector2i(side, side) / 2
		var options: Array = []                  # [score, tile]
		for x in range(gap.position.x, gap.end.x):
			for y in range(gap.position.y, gap.end.y):
				options.append([Vector2(Vector2i(x, y) - centre).length() + _rng.randf() * 0.9, Vector2i(x, y)])
		options.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var done := false
		for o in options:
			if _try_rock(o[1]):
				done = true
				break
		if not done:
			_used[_index(centre)] = 1            # nothing may stand here: leave it open


## Puts a rock on a tile if that is allowed and nothing gets cut off by it.
func _try_rock(t: Vector2i) -> bool:
	if _keep.has(t) or _blocked.has(t) or _used[_index(t)] == 1:
		return false
	_blocked[t] = true
	if not _everything_reachable():
		_blocked.erase(t)
		return false
	rocks.append(t)
	_used[_index(t)] = 1
	return true


func _largest_empty_square() -> Rect2i:
	var w := size.x
	var sizes := PackedInt32Array()
	sizes.resize(w * size.y)
	var best := 0
	var best_pos := Vector2i.ZERO
	for y in size.y:
		for x in w:
			var i := y * w + x
			if _used[i] == 1:
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


## Walking distance from the entry to every tile, around rocks and deposits. -1 = cut off.
func _flood() -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(size.x * size.y)
	dist.fill(-1)
	dist[_index(entry_tile)] = 0
	var queue: Array[Vector2i] = [entry_tile]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for d in DIRS:
			var n := cur + d
			if is_walk(n) and not _blocked.has(n) and dist[_index(n)] == -1:
				dist[_index(n)] = dist[_index(cur)] + 1
				queue.append(n)
	return dist


## Distance to a tile, or to the nearest free tile beside it when it is solid.
func _reach(dist: PackedInt32Array, t: Vector2i) -> int:
	if not _blocked.has(t):
		return dist[_index(t)]
	var best := -1
	for d in DIRS:
		var n := t + d
		if is_walk(n) and dist[_index(n)] >= 0 and (best < 0 or dist[_index(n)] < best):
			best = dist[_index(n)]
	return best


## Every floor tile, every deposit, the ladders and the exit can be walked to.
func _everything_reachable() -> bool:
	var dist := _flood()
	for i in walk.size():
		if walk[i] == 1 and dist[i] < 0:
			var t := Vector2i(i % size.x, i / size.x)
			if not _blocked.has(t) or _reach(dist, t) < 0:
				return false
	return true


## 6. Checks every rule and fills `report` and `ok`.
func _make_report(spec: Dictionary) -> void:
	var dist := _flood()
	var problems: Array[String] = []

	var floor_tiles := 0
	for v in walk:
		floor_tiles += v
	var floor_share := float(floor_tiles) / float(size.x * size.y)
	if floor_share < Config.CAVE_MIN_FLOOR_SHARE:
		problems.append("only %d%% floor" % roundi(floor_share * 100.0))

	var empty := _largest_empty_square().size.x
	if empty > Config.CAVE_MAX_EMPTY_SQUARE:
		problems.append("empty patch %dx%d" % [empty, empty])

	if not _everything_reachable():
		problems.append("something cannot be reached")

	var metal := 0
	var ice := 0
	var nearest := 1 << 30
	for n in nodes:
		if n.kind == "metal":
			metal += 1
		else:
			ice += 1
		nearest = mini(nearest, maxi(0, _reach(dist, n.tile)))
	if metal != spec.metal or ice != spec.ice:
		problems.append("%d metal + %d ice placed, wanted %d + %d" % [metal, ice, spec.metal, spec.ice])

	var farthest := 0
	for d in dist:
		farthest = maxi(farthest, d)
	var nearest_share := 1.0
	if not nodes.is_empty():
		nearest_share = float(nearest) / maxf(1.0, farthest)
		if nearest_share < Config.MIN_REWARD_DISTANCE:
			problems.append("a deposit is only %d%% of the longest walk away" % roundi(nearest_share * 100.0))

	var ladder_walk := -1
	if ladder_down_tile != NONE:
		ladder_walk = dist[_index(ladder_down_tile)]

	report = {
		"size": size,
		"rooms": _cols * _rows,
		"floor_share": floor_share,
		"max_empty_square": empty,
		"metal_nodes": metal,
		"ice_nodes": ice,
		"door_craters": door_craters.size(),
		"small_craters": small_craters.size(),
		"rocks": rocks.size(),
		"nearest_tiles": nearest if not nodes.is_empty() else 0,
		"farthest_tiles": farthest,
		"nearest_share": nearest_share,
		"ladder_down_tiles": ladder_walk,
		"attempt": attempt,
		"problems": problems,
	}
	ok = problems.is_empty()
