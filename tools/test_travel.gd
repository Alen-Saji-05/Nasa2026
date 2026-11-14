extends SceneTree
## Automated play-through of every cave. Run from the project folder:
##   godot --headless --path . --script res://tools/test_travel.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## For every cave it walks in through the surface entrance, takes every ladder
## down and back up, harvests a deposit, and walks out again.
##
## With a screenshot folder it also saves pictures (needs a window, so no --headless):
##   godot --path . --script res://tools/test_travel.gd -- C:/some/folder

var _failed := 0
var _gs: Node
var _travel: Node
var _shots := ""


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_travel = root.get_node("Travel")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_shots = args[0]
	_run()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Waits until `condition` is true and no move is in progress. False = timed out.
func _until(condition: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not _travel.busy and condition.call():
			return true
	return false


## Waits until a move (fade) has started. False = timed out.
func _until_moving(seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if _travel.busy:
			return true
	return false


func _shot(file_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(file_name))


func _player() -> CharacterBody2D:
	return current_scene.get_node("Entities/Player")


func _feet_offset() -> Vector2:
	var p := _player()
	return (p.get_node("CollisionShape2D") as Node2D).position * p.scale


func _feet_tile() -> Vector2i:
	return Vector2i((_player().position + _feet_offset()) / 16.0)


## Stands the player with the feet on the middle of a tile.
func _stand_on(tile: Vector2i) -> void:
	_player().position = Vector2(tile * 16) + Vector2(8, 8) - _feet_offset()


func _in_cave(cave_id: String, layer: int) -> bool:
	return current_scene != null and current_scene.scene_file_path == Config.CAVE_SCENE and _gs.cave_id == cave_id and _gs.cave_layer == layer


func _on_surface() -> bool:
	return current_scene != null and current_scene.scene_file_path == Config.WORLD_SCENE and _gs.cave_id == ""


func _location_label() -> String:
	var label := current_scene.get_node_or_null("UI/HUD/Location") as Label
	return label.text if label != null else "<no label>"


## A free floor tile next to `tile`, the one below it first.
func _beside(layout: CaveGen, tile: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if layout.is_walk(tile + d):
			return tile + d
	return tile


func _run() -> void:
	_gs.reset()
	_gs.set_process(false)               # no oxygen drain while we test
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.4)
	_check("starts on the surface, label says '%s'" % _location_label(), _on_surface() and _location_label() == "Surface")

	var harvested_id := ""
	for cave in Config.CAVES:
		var cave_id: String = cave.id
		var cave_name: String = cave.name
		var layer_count: int = cave.layers.size()

		if not _on_surface():
			_check("%s: cannot start, the player is not on the surface" % cave_name, false)
			break

		# --- walk into the entrance ---
		var entrance := current_scene.get_node("CaveEntrances/Entrance_%s" % cave_id) as Area2D
		_player().global_position = entrance.exit_position()
		await _wait(0.15)
		_check("%s: standing in front of the entrance does not start a move" % cave_name, _on_surface() and not _travel.busy)
		Input.action_press("ui_up")
		await _until_moving()
		Input.action_release("ui_up")            # let go as soon as the fade starts
		var entered := await _until(func() -> bool: return _in_cave(cave_id, 0))
		_check("%s: walking into the mouth enters the cave" % cave_name, entered)
		if not entered:
			continue
		await _wait(0.2)
		var layout: CaveGen = current_scene.layout
		_check("%s L1: the label says '%s'" % [cave_name, _location_label()], _location_label() == "%s L1" % cave_name)
		_check("%s L1: the player stands at the way in, one tile above the way out" % cave_name,
			_feet_tile() == layout.entry_tile and layout.entry_tile == layout.exit_tile + Vector2i.UP)
		var dark: Color = (current_scene.get_node("Darkness") as CanvasModulate).color
		_check("%s L1: the cave is dark (%.2f) and the player carries a light" % [cave_name, dark.get_luminance()],
			dark.get_luminance() < 0.6 and current_scene.get_node_or_null("SuitLight") is PointLight2D)
		_check("%s L1: it is the layout the generator makes for it" % cave_name,
			layout.ok and layout.walk == CaveGen.build(cave, 0).walk)
		var cam := _player().get_node("Camera2D") as Camera2D
		var view := Vector2(root.get_visible_rect().size) / cam.zoom
		_check("%s L1: the camera never shows outside the layer" % cave_name,
			view.x <= layout.size.x * 16 + 0.5 and view.y <= layout.size.y * 16 + 0.5)
		await _wait(0.4)
		await _shot("%s_L1_arrive.png" % cave_id)

		# --- down every ladder ---
		for layer in range(1, layer_count):
			layout = current_scene.layout
			_stand_on(_beside(layout, layout.ladder_down_tile))
			await _wait(0.15)
			var interactor := _player().get_node("Harvester")
			var ladder := current_scene.get_node("Doors/LadderDown")
			var prompt := interactor.get_node("PromptLayer/Prompt") as Label
			_check("%s L%d: next to the ladder down, E points at it and the E tag shows" % [cave_name, layer],
				interactor.focus() == ladder and prompt.visible)
			if layer == 1:
				await _shot("%s_L1_ladder.png" % cave_id)
				# The real key, once: E.
				var key := InputEventKey.new()
				key.physical_keycode = KEY_E
				key.keycode = KEY_E
				key.pressed = true
				Input.parse_input_event(key)
			else:
				interactor.use()
			var went_down := await _until(func() -> bool: return _in_cave(cave_id, layer))
			_check("%s: E on the ladder goes down to L%d" % [cave_name, layer + 1], went_down)
			if not went_down:
				break
			await _wait(0.2)
			layout = current_scene.layout
			_check("%s L%d: arrives at the foot of the ladder up, label '%s'" % [cave_name, layer + 1, _location_label()],
				_feet_tile() == layout.entry_tile and layout.entry_tile == layout.ladder_up_tile + Vector2i.DOWN
				and _location_label() == "%s L%d" % [cave_name, layer + 1])
			await _wait(0.3)
			await _shot("%s_L%d_arrive.png" % [cave_id, layer + 1])
		if not _in_cave(cave_id, layer_count - 1):
			continue

		# --- harvest on the deepest layer; the deposit remembers it ---
		var deposits := get_nodes_in_group("resource_nodes")
		_check("%s L%d: %d deposits, as in Config" % [cave_name, layer_count, deposits.size()],
			deposits.size() == cave.layers[layer_count - 1].metal + cave.layers[layer_count - 1].ice)
		# Untyped on purpose: naming the ResourceNode class here would compile that
		# script before the autoloads exist.
		var deposit: Node2D = deposits[0]
		harvested_id = deposit.get("node_id")
		layout = current_scene.layout
		_stand_on(_beside(layout, Vector2i(deposit.position / 16.0)))
		await _wait(0.15)
		var metal_before: int = _gs.metal
		var water_before: float = _gs.water
		var reach := _player().get_node("Harvester")
		_check("%s: next to a deposit, E points at the deposit" % cave_name, reach.focus() == deposit)
		reach.use()
		await _wait(0.5)
		reach.use()
		await _wait(0.1)
		_check("%s: two harvests leave %d of %d uses and give resources" % [cave_name, deposit.get("charges_left"), Config.NODE_CHARGES],
			deposit.get("charges_left") == Config.NODE_CHARGES - 2 and (_gs.metal > metal_before or _gs.water > water_before or not _gs.inventory.is_empty()))
		await _shot("%s_L%d_deposit.png" % [cave_id, layer_count])

		# --- up every ladder ---
		for layer in range(layer_count - 2, -1, -1):
			layout = current_scene.layout
			_stand_on(layout.entry_tile)
			await _wait(Config.HARVEST_COOLDOWN + 0.15)   # E has a short cooldown after each use
			var hand := _player().get_node("Harvester")
			_check("%s L%d: at the ladder up, E points at it" % [cave_name, layer + 2],
				hand.focus() == current_scene.get_node("Doors/LadderUp"))
			hand.use()
			var went_up := await _until(func() -> bool: return _in_cave(cave_id, layer))
			_check("%s: E on the ladder goes up to L%d" % [cave_name, layer + 1], went_up)
			if not went_up:
				break
			await _wait(0.2)
			layout = current_scene.layout
			var feet := _feet_tile()
			_check("%s L%d: arrives right next to the ladder down" % [cave_name, layer + 1],
				absi(feet.x - layout.ladder_down_tile.x) + absi(feet.y - layout.ladder_down_tile.y) == 1)

		# --- going back down: the deposit is still used up ---
		if layer_count >= 2 and _in_cave(cave_id, 0):
			for layer in range(1, layer_count):
				_stand_on(_beside(current_scene.layout, current_scene.layout.ladder_down_tile))
				await _wait(Config.HARVEST_COOLDOWN + 0.15)
				_player().get_node("Harvester").use()
				await _until(func() -> bool: return _in_cave(cave_id, layer))
				await _wait(0.1)
			var same: Node = null
			for n in get_nodes_in_group("resource_nodes"):
				if n.get("node_id") == harvested_id:
					same = n
			_check("%s: after leaving the layer and coming back, the deposit still has %d uses" % [cave_name, Config.NODE_CHARGES - 2],
				same != null and same.get("charges_left") == Config.NODE_CHARGES - 2)
			for layer in range(layer_count - 2, -1, -1):
				_stand_on(current_scene.layout.entry_tile)
				await _wait(Config.HARVEST_COOLDOWN + 0.15)
				_player().get_node("Harvester").use()
				await _until(func() -> bool: return _in_cave(cave_id, layer))
				await _wait(0.1)

		# --- walk out ---
		if not _in_cave(cave_id, 0):
			continue
		_stand_on(current_scene.layout.entry_tile)
		await _wait(0.15)
		Input.action_press("ui_down")
		await _until_moving()
		Input.action_release("ui_down")
		var left := await _until(_on_surface)
		_check("%s: walking into the way out returns to the surface" % cave_name, left)
		if not left:
			continue
		await _wait(0.2)
		var back := current_scene.get_node("CaveEntrances/Entrance_%s" % cave_id) as Area2D
		_check("%s: the player stands in front of this cave's entrance, label '%s'" % [cave_name, _location_label()],
			_player().global_position.distance_to(back.exit_position()) < 4.0 and _location_label() == "Surface")
		await _wait(0.3)
		await _shot("%s_back_on_surface.png" % cave_id)

	# --- a new game forgets everything ---
	_check("harvested deposits are remembered (%d)" % _gs.node_charges.size(), _gs.node_charges.size() == Config.CAVES.size())
	_gs.reset()
	_check("a new game makes every deposit full again and puts the player on the surface",
		_gs.node_charges.is_empty() and _gs.cave_id == "" and _gs.arrival == "")

	_gs.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
