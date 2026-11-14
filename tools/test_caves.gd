extends SceneTree
## Automated check of the cave layouts. Run from the project folder:
##   godot --headless --path . --script res://tools/test_caves.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
## Add "-- map" to also print a text picture of every layer:
##   # rock   . floor   M metal   I ice   o small crater   O door crater
##   r rock (decor)   E way out   U ladder up   D ladder down   @ arrival point

const WORLD := "res://scenes/World.tscn"
const EXTRA_SEEDS := [1, 7, 42, 99, 2026, 31337]

var _failed := 0


func _initialize() -> void:
	_run(OS.get_cmdline_user_args().has("map"))
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _run(show_maps: bool) -> void:
	var metal := 0
	var ice := 0
	var ids := {}
	var layouts := {}

	_check("there are at least 3 caves", Config.CAVES.size() >= 3)
	for cave in Config.CAVES:
		var layer_count: int = cave.layers.size()
		_check("%s has %d layers (2 or 3)" % [cave.name, layer_count], layer_count >= 2 and layer_count <= 3)
		for layer in layer_count:
			var gen := CaveGen.build(cave, layer)
			var label := "%s L%d" % [cave.name, layer + 1]
			layouts[label] = _signature(gen)
			_check_layer(gen, cave, layer, label)
			if show_maps:
				print(_picture(gen))
			metal += gen.report.get("metal_nodes", 0)
			ice += gen.report.get("ice_nodes", 0)
			for n in gen.nodes:
				ids[n.id] = true

			# Same cave and layer = same layout, every time.
			_check("%s: building it again gives the same layout" % label, _signature(CaveGen.build(cave, layer)) == layouts[label])

	# --- every cave and layer is different ---
	var unique := {}
	for label: String in layouts:
		unique[layouts[label]] = true
	_check("all %d layers are different from each other" % layouts.size(), unique.size() == layouts.size())

	# --- the loot of the whole game adds up ---
	var surface := (load(WORLD) as PackedScene).instantiate()
	for n in surface.get_node("Entities/Nodes").get_children():
		ids[n.get("node_id")] = true
	surface.free()
	_check("deposits in the whole game: %d metal (caves %d + surface %d) and %d ice (caves %d + surface %d)" % [
		metal + Config.SURFACE_METAL_NODES, metal, Config.SURFACE_METAL_NODES,
		ice + Config.SURFACE_ICE_NODES, ice, Config.SURFACE_ICE_NODES],
		metal + Config.SURFACE_METAL_NODES == Config.METAL_NODE_COUNT and ice + Config.SURFACE_ICE_NODES == Config.ICE_NODE_COUNT)
	_check("every deposit in the game has its own id (%d ids)" % ids.size(),
		ids.size() == Config.METAL_NODE_COUNT + Config.ICE_NODE_COUNT and not ids.has("") and not ids.has(null))

	# --- the rules hold for other seeds too ---
	var bad: Array[String] = []
	var tried := 0
	for s: int in EXTRA_SEEDS:
		for cave in Config.CAVES:
			var other: Dictionary = cave.duplicate(true)
			other.seed = s * 1000 + int(cave.seed)
			for layer in other.layers.size():
				tried += 1
				var gen := CaveGen.build(other, layer)
				if not gen.ok:
					bad.append("%s L%d seed %d: %s" % [cave.id, layer + 1, other.seed, str(gen.report.get("problems"))])
	_check("%d layers with other seeds all keep the rules %s" % [tried, str(bad)], bad.is_empty())


func _check_layer(gen: CaveGen, cave: Dictionary, layer: int, label: String) -> void:
	var r: Dictionary = gen.report
	var spec: Dictionary = cave.layers[layer]
	var last: bool = layer == cave.layers.size() - 1
	_check("%s: all rules hold (attempt %d) %s" % [label, gen.attempt, str(r.get("problems", []))], gen.ok)
	if not gen.ok:
		return
	var size: Vector2i = gen.size
	_check("%s: %dx%d tiles (allowed %dx%d to %dx%d)" % [label, size.x, size.y,
		Config.CAVE_SIZE_MIN.x, Config.CAVE_SIZE_MIN.y, Config.CAVE_SIZE_MAX.x, Config.CAVE_SIZE_MAX.y],
		size.x >= Config.CAVE_SIZE_MIN.x and size.y >= Config.CAVE_SIZE_MIN.y and size.x <= Config.CAVE_SIZE_MAX.x and size.y <= Config.CAVE_SIZE_MAX.y)
	_check("%s: %d%% of the layer is floor (need %d%%), biggest empty patch %dx%d (limit %d)" % [label,
		roundi(r.floor_share * 100.0), roundi(Config.CAVE_MIN_FLOOR_SHARE * 100.0), r.max_empty_square, r.max_empty_square, Config.CAVE_MAX_EMPTY_SQUARE],
		r.floor_share >= Config.CAVE_MIN_FLOOR_SHARE and r.max_empty_square <= Config.CAVE_MAX_EMPTY_SQUARE)
	_check("%s: %d metal + %d ice, as in Config" % [label, r.metal_nodes, r.ice_nodes],
		r.metal_nodes == spec.metal and r.ice_nodes == spec.ice)
	if not gen.nodes.is_empty():
		_check("%s: nearest deposit is %d%% of the longest walk (need %d%%)" % [label,
			roundi(r.nearest_share * 100.0), roundi(Config.MIN_REWARD_DISTANCE * 100.0)], r.nearest_share >= Config.MIN_REWARD_DISTANCE)

	# Solid rock all around, except the one way out on the first layer.
	var holes: Array[Vector2i] = []
	for x in size.x:
		for y in [0, size.y - 1]:
			if gen.is_walk(Vector2i(x, y)):
				holes.append(Vector2i(x, y))
	for y in size.y:
		for x in [0, size.x - 1]:
			if gen.is_walk(Vector2i(x, y)):
				holes.append(Vector2i(x, y))
	_check("%s: solid rock all around%s" % [label, ", except the way out" if layer == 0 else ""],
		holes == ([gen.exit_tile] if layer == 0 else []))

	# The right doors and ladders for this layer.
	var has_exit: bool = gen.exit_tile != CaveGen.NONE
	var has_up: bool = gen.ladder_up_tile != CaveGen.NONE
	var has_down: bool = gen.ladder_down_tile != CaveGen.NONE
	_check("%s: way out %s, ladder up %s, ladder down %s" % [label, has_exit, has_up, has_down],
		has_exit == (layer == 0) and has_up == (layer > 0) and has_down == (not last))
	if has_up:
		_check("%s: the ladder up leans on a rock wall" % label, not gen.is_walk(gen.ladder_up_tile + Vector2i.UP))
	if has_down:
		_check("%s: the ladder down is the far end of the layer (%d of %d tiles)" % [label, r.ladder_down_tiles, r.farthest_tiles],
			r.ladder_down_tiles >= r.farthest_tiles * Config.MIN_REWARD_DISTANCE)
	_check("%s: both arrival points are on open floor" % label,
		gen.is_walk(gen.spawn_tile("")) and gen.is_walk(gen.spawn_tile("ladder_up")))

	# Metal and ice never share a room.
	var mixed := false
	for chamber in gen.chambers:
		for n in gen.nodes:
			if (chamber.rect as Rect2i).has_point(n.tile) and n.kind != chamber.kind:
				mixed = true
	_check("%s: metal and ice are in separate rooms (%d reward rooms)" % [label, gen.chambers.size()], not mixed)


func _signature(gen: CaveGen) -> int:
	return hash([gen.size, gen.walk, gen.entry_tile, gen.exit_tile, gen.ladder_up_tile, gen.ladder_down_tile,
		gen.nodes, gen.door_craters, gen.small_craters, gen.rocks])


func _picture(gen: CaveGen) -> String:
	var marks := {}
	for t in gen.rocks:
		marks[t] = "r"
	for t in gen.small_craters:
		marks[t] = "o"
	for crater in gen.door_craters:
		for x in range(crater.position.x, crater.end.x):
			for y in range(crater.position.y, crater.end.y):
				marks[Vector2i(x, y)] = "O"
	for n in gen.nodes:
		marks[n.tile] = "M" if n.kind == "metal" else "I"
	marks[gen.entry_tile] = "@"
	if gen.exit_tile != CaveGen.NONE:
		marks[gen.exit_tile] = "E"
	if gen.ladder_up_tile != CaveGen.NONE:
		marks[gen.ladder_up_tile] = "U"
	if gen.ladder_down_tile != CaveGen.NONE:
		marks[gen.ladder_down_tile] = "D"
	var lines: Array[String] = []
	for y in gen.size.y:
		var line := ""
		for x in gen.size.x:
			var t := Vector2i(x, y)
			line += marks.get(t, "." if gen.is_walk(t) else "#")
		lines.append(line)
	return "\n".join(lines) + "\n"
