extends SceneTree
## Automated check of the map generator. Run from the project folder:
##   godot --headless --path . --script res://tools/test_world.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.

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
	_check("another seed gives another map", _signature(b) != sig_a)

	_check_map(a, "seed %d" % a.map_seed)
	_check_base(a)

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

	_check("%s: %d metal and %d ice nodes" % [label, r.metal_nodes, r.ice_nodes],
		r.metal_nodes == Config.METAL_NODE_COUNT and r.ice_nodes == Config.ICE_NODE_COUNT)
	_check("%s: every node can be reached on foot from the spawn" % label, r.unreachable_nodes == 0)
	_check("%s: no node near the base" % label, r.nodes_near_base == 0)
	_check("%s: nearest deposit is %d%% of the farthest walk (need >= %d%%)" % [
		label, roundi(r.nearest_share * 100.0), roundi(Config.MIN_REWARD_DISTANCE * 100.0)],
		r.nearest_share >= Config.MIN_REWARD_DISTANCE)

	var border_ok := true
	for x in size.x:
		if walls.get_cell_source_id(Vector2i(x, 0)) == -1 or walls.get_cell_source_id(Vector2i(x, size.y - 1)) == -1:
			border_ok = false
	for y in size.y:
		if walls.get_cell_source_id(Vector2i(0, y)) == -1 or walls.get_cell_source_id(Vector2i(size.x - 1, y)) == -1:
			border_ok = false
	_check("%s: solid wall all around the map" % label, border_ok)

	# Metal and ice live in different chambers.
	var kinds_per_chamber := {}
	var mixed := false
	for n in world.get_node("Entities/Nodes").get_children():
		var tile_pos := Vector2i((n as Node2D).position / world.TILE) - (world.GRID_ORIGIN as Vector2i)
		var key := tile_pos / (world.CELL_SIZE as int)
		var kind: String = n.get_meta("kind", "")
		if kinds_per_chamber.get(key, kind) != kind:
			mixed = true
		kinds_per_chamber[key] = kind
	_check("%s: metal and ice are in separate chambers (%d chambers)" % [label, r.reward_chambers], not mixed)


func _check_base(world: Node) -> void:
	var clearing: Rect2i = world.CLEARING
	var tile: int = world.TILE
	var area := Rect2(clearing.position * tile, clearing.size * tile)
	var rocket := world.get_node_or_null("Entities/BrokenRocket") as Node2D
	var pad := world.get_node_or_null("LaunchPad") as Node2D
	var hab := world.get_node_or_null("Entities/Hab") as Node2D
	var player := world.get_node_or_null("Entities/Player") as Node2D
	_check("base: hab, launch pad, broken rocket and player are all in the clearing",
		rocket != null and pad != null and hab != null and player != null
		and area.has_point(rocket.position - Vector2(0, 4)) and area.has_point(pad.position)
		and area.has_point(hab.position) and area.has_point(player.position))
	_check("base: the rocket has smoke and spark particles and a collider",
		rocket != null and rocket.get_node_or_null("Smoke") is CPUParticles2D
		and rocket.get_node_or_null("Sparks") is CPUParticles2D
		and rocket.get_node_or_null("CollisionShape2D") is CollisionShape2D)
	var hazards_in_base := 0
	for c in world.get_node("GroundDecor").get_children():
		if c.name.begins_with("Crater") and area.grow(tile * 4).has_point((c as Node2D).position):
			hazards_in_base += 1
	_check("base: no craters in or next to the clearing", hazards_in_base == 0)


## Everything that defines the map, as one comparable value.
func _signature(world: Node) -> int:
	var parts: Array = []
	for layer_name: String in ["Ground", "Walls"]:
		var layer: TileMapLayer = world.get_node(layer_name)
		var cells := layer.get_used_cells()
		cells.sort()
		for c in cells:
			parts.append([c, layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c)])
	for path: String in ["Entities/Nodes", "Entities/Decor", "GroundDecor", "Cliffs"]:
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
