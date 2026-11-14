extends SceneTree
## Automated check of the surface map generator. Run from the project folder:
##   godot --headless --path . --script res://tools/test_world.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## The surface is the base area: hab, build pads, launch pad, wreck, cave
## entrances and a few starter deposits. (The caves have their own test.)

const SCENE := "res://scenes/World.tscn"
const SEEDS_TO_TRY := [1, 2, 3, 7, 42, 99, 2026, 31337, 5, 11, 123, 777, 4242, 9001]

var _failed := 0


func _initialize() -> void:
	_run()
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var packed: PackedScene = load(SCENE)

	# --- the saved scene is the generated map (nobody forgot to bake) ---
	var saved := packed.instantiate()
	var saved_sig := _signature(saved)
	var a := packed.instantiate()
	a.generate()
	var sig_a := _signature(a)
	_check("World.tscn holds the map for its seed (%d)" % a.map_seed, saved_sig == sig_a)

	# --- same seed = same map ---
	var b := packed.instantiate()
	b.generate()
	_check("same seed gives the same map", _signature(b) == sig_a)
	b.map_seed = a.map_seed + 1
	b.generate()
	_check("another seed gives another map (different decoration)", _signature(b) != sig_a)

	_check_map(a, "seed %d" % a.map_seed)
	_check_base(a)
	_check_entrances(a)
	_check_pads(a)

	# --- the rules hold for other seeds too ---
	for s: int in SEEDS_TO_TRY:
		b.map_seed = s
		b.generate()
		_check_map(b, "seed %d" % s)

	saved.free()
	a.free()
	b.free()


func _check_map(world: Node, label: String) -> void:
	var r: Dictionary = world.last_report
	var size: Vector2i = world.MAP_SIZE
	var walls: TileMapLayer = world.get_node("Walls")

	_check("%s: %d build pads and %d cave entrances" % [label, r.build_pads, r.entrances],
		r.build_pads == Config.BUILD_PAD_COUNT and r.entrances == Config.CAVES.size())
	_check("%s: %d metal and %d ice starter deposits" % [label, r.metal_nodes, r.ice_nodes],
		r.metal_nodes == Config.SURFACE_METAL_NODES and r.ice_nodes == Config.SURFACE_ICE_NODES)
	_check("%s: hab, pads, launch pad, wreck, entrances and deposits can all be reached on foot %s" % [label, str(r.unreachable)],
		r.unreachable.is_empty() and r.unreachable_nodes == 0)
	_check("%s: no deposit near the base" % label, r.nodes_near_base == 0)
	_check("%s: no craters near the hab" % label, r.craters_near_base == 0)
	_check("%s: no dead space, biggest empty patch is %dx%d (limit %d)" % [
		label, r.max_empty_square, r.max_empty_square, Config.SURFACE_MAX_EMPTY_SQUARE],
		r.max_empty_square <= Config.SURFACE_MAX_EMPTY_SQUARE)

	var border_ok := true
	for x in size.x:
		if walls.get_cell_source_id(Vector2i(x, 0)) == -1 or walls.get_cell_source_id(Vector2i(x, size.y - 1)) == -1:
			border_ok = false
	for y in size.y:
		if walls.get_cell_source_id(Vector2i(0, y)) == -1 or walls.get_cell_source_id(Vector2i(size.x - 1, y)) == -1:
			border_ok = false
	_check("%s: solid wall all around the map" % label, border_ok)


func _check_base(world: Node) -> void:
	var floor_rect: Rect2i = world.FLOOR
	var tile: int = world.TILE
	var area := Rect2(floor_rect.position * tile, floor_rect.size * tile)
	var rocket := world.get_node_or_null("Entities/BrokenRocket") as Node2D
	var pad := world.get_node_or_null("LaunchPad") as Node2D
	var hab := world.get_node_or_null("Entities/Hab") as Node2D
	var player := world.get_node_or_null("Entities/Player") as Node2D
	_check("base: hab, launch pad, broken rocket and player are all on the map floor",
		rocket != null and pad != null and hab != null and player != null
		and area.has_point(rocket.position - Vector2(0, 4)) and area.has_point(pad.position)
		and area.has_point(hab.position) and area.has_point(player.position))
	_check("base: the rocket has smoke and spark particles and a collider",
		rocket != null and rocket.get_node_or_null("Smoke") is CPUParticles2D
		and rocket.get_node_or_null("Sparks") is CPUParticles2D
		and rocket.get_node_or_null("CollisionShape2D") is CollisionShape2D)
	_check("base: the launch pad is the build pad for the Ascent vehicle",
		pad != null and pad.get("pad_type") == "launch" and pad.get("pad_id") == "launch")


func _check_entrances(world: Node) -> void:
	var tile: int = world.TILE
	var walls: TileMapLayer = world.get_node("Walls")
	var wanted: Array = Config.CAVES.map(func(c: Dictionary) -> String: return c.id)
	var found: Array = []
	var parts_ok := true
	var placed_ok := true
	for e in world.get_node("CaveEntrances").get_children():
		found.append(e.get("cave_id"))
		var exit_marker := e.get_node_or_null("Exit") as Node2D
		if not (e is Area2D) or e.get_node_or_null("Mouth") == null or e.get_node_or_null("CollisionShape2D") == null or exit_marker == null:
			parts_ok = false
			continue
		# The mouth is in solid rock, the exit marker and the tile in front are open floor.
		var front := Vector2i(((e as Node2D).position + Vector2(0, tile * 0.5)) / tile)
		var exit_tile := Vector2i(((e as Node2D).position + exit_marker.position) / tile)
		if walls.get_cell_source_id(front + Vector2i.UP) == -1 or walls.get_cell_source_id(front) != -1 or walls.get_cell_source_id(exit_tile) != -1:
			placed_ok = false
	found.sort()
	wanted.sort()
	_check("entrances: one for each cave in Config.CAVES %s" % str(found), found == wanted)
	_check("entrances: each has a mouth, a trigger and an exit marker", parts_ok)
	_check("entrances: mouth in the cliff, open floor in front, exit marker on open floor", placed_ok)


func _check_pads(world: Node) -> void:
	var tile: int = world.TILE
	var walls: TileMapLayer = world.get_node("Walls")
	var ids := {}
	var rects: Array[Rect2] = []
	var clear := true
	for p in world.get_node("BuildPads").get_children():
		ids[p.get("pad_id")] = true
		var size := Vector2(world.PAD_SIZE, world.PAD_SIZE) * tile
		var rect := Rect2((p as Node2D).position - size * 0.5, size)
		for other in rects:
			if rect.intersects(other):
				clear = false
		rects.append(rect)
		# No rock under a pad, and nothing standing on it.
		for x in world.PAD_SIZE:
			for y in world.PAD_SIZE:
				if walls.get_cell_source_id(Vector2i(rect.position / tile) + Vector2i(x, y)) != -1:
					clear = false
		for path: String in ["Entities/Decor", "Entities/Nodes", "GroundDecor"]:
			for n in world.get_node(path).get_children():
				if n.name.begins_with("Footprints"):
					continue
				if rect.grow(tile * 0.5).has_point((n as Node2D).position):
					clear = false
	_check("pads: every pad has its own id (%d ids)" % ids.size(), ids.size() == Config.BUILD_PAD_COUNT)
	_check("pads: no rock, deposit or crater on or right next to a pad, and no pads overlap", clear)


## Everything that defines the map, as one comparable value.
func _signature(world: Node) -> int:
	var parts: Array = []
	for layer_name: String in ["Ground", "Walls"]:
		var layer: TileMapLayer = world.get_node(layer_name)
		var cells := layer.get_used_cells()
		cells.sort()
		for c in cells:
			parts.append([c, layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c)])
	for path: String in ["Entities/Nodes", "Entities/Decor", "GroundDecor", "Cliffs", "BuildPads", "CaveEntrances"]:
		var container := world.get_node_or_null(path)
		if container == null:
			parts.append(path + " missing")
			continue
		for n in container.get_children():
			parts.append([n.name, (n as Node2D).position.round(), (n as Node2D).rotation])
	for path: String in ["LaunchPad", "Entities/Hab", "Entities/Player", "Entities/BrokenRocket"]:
		var n := world.get_node_or_null(path) as Node2D
		parts.append([path, n.position.round() if n != null else Vector2.INF])
	return hash(parts)
