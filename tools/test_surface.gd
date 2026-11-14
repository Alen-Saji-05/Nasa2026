extends SceneTree
## Automated check of the surface while the game runs. Run from the project folder:
##   godot --headless --path . --script res://tools/test_surface.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## With a screenshot folder it also saves pictures (needs a window, so no --headless):
##   godot --path . --script res://tools/test_surface.gd -- C:/some/folder

const WORLD := "res://scenes/World.tscn"

var _failed := 0
var _gs: Node
var _shots := ""
var _messages: Array[String] = []


func _initialize() -> void:
	_gs = root.get_node("GameState")
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


func _shot(file_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(file_name))


func _run() -> void:
	_gs.reset()
	_gs.set_process(false)               # no oxygen drain while we test
	_gs.message.connect(func(text: String) -> void: _messages.append(text))
	change_scene_to_file(WORLD)
	await _wait(0.3)
	var world := current_scene
	_check("the world scene loads", world != null and world.scene_file_path == WORLD)
	var player: CharacterBody2D = world.get_node("Entities/Player")
	var camera: Camera2D = player.get_node("Camera2D")
	await _wait(0.5)
	await _shot("spawn.png")

	# --- everything registered itself ---
	var pads := get_nodes_in_group("build_pads")
	var launch_pads := pads.filter(func(p: Node) -> bool: return p.get("pad_type") == "launch")
	_check("%d build pads are ready, one of them the launch pad" % pads.size(),
		pads.size() == Config.BUILD_PAD_COUNT + 1 and launch_pads.size() == 1
		and pads.all(func(p: Node) -> bool: return p.is_free()))
	var entrances := get_nodes_in_group("cave_entrances")
	_check("%d cave entrances are ready" % entrances.size(), entrances.size() == Config.CAVES.size())
	_check("%d starter deposits are ready" % get_nodes_in_group("resource_nodes").size(),
		get_nodes_in_group("resource_nodes").size() == Config.SURFACE_METAL_NODES + Config.SURFACE_ICE_NODES)

	# --- the entrances wait for the player (walking in is covered by test_travel.gd) ---
	var travel := root.get_node("Travel")
	for e in entrances:
		var entrance := e as Area2D
		player.global_position = entrance.exit_position()
		await _wait(0.2)
		_check("%s: standing at the exit marker does not enter the cave" % Config.cave_name(entrance.get("cave_id")),
			not travel.busy and current_scene == world)
	await _shot("at_entrance.png")

	# --- the sol counter and the night ---
	var sol_label := world.get_node("UI/HUD/Sol") as Label
	var tint := world.get_node("DayNight") as CanvasModulate
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 4.2
	_gs._process(0.0)
	await _wait(0.05)
	var day_brightness := tint.color.get_luminance()
	_check("by day the HUD says '%s' and the surface is bright (%.2f)" % [sol_label.text, day_brightness],
		sol_label.text == "SOL 05 / 30" and day_brightness > 0.95)
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 4.8
	_gs._process(0.0)
	await _wait(0.05)
	_check("at night the surface is darker (%.2f) but still readable" % tint.color.get_luminance(),
		tint.color.get_luminance() < 0.6 and tint.color.get_luminance() > 0.3)
	var lamp := player.get_node("Lamp") as PointLight2D
	_check("at night the lamp glows around the player, and its story was told",
		lamp.energy > 0.5 and _gs.lamp_found and _gs.story_seen.has("lamp"))
	player.global_position = world.get_node("Entities/Hab").global_position + Vector2(0, 50)

	# --- the inventory on the HUD ---
	_gs.add_item("iron", 3)
	_gs.add_item("sulfur", 2)
	_gs.add_item("iron", 3)
	await _wait(0.1)
	var iron_row := world.get_node_or_null("UI/HUD/Bars/Item_iron")
	_check("carried items show on the HUD: '%s'" % (iron_row.get_child(1).text if iron_row != null else ""),
		iron_row != null and iron_row.get_child(1).text == "Iron Ore  6" and world.get_node_or_null("UI/HUD/Bars/Item_sulfur") != null
		and world.get_node_or_null("UI/HUD/Bars/Item_aluminum") == null)
	await _wait(0.3)
	await _shot("night.png")
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 0.2
	_gs._process(0.0)
	_check("by day the lamp is off", lamp.energy < 0.05)

	# --- the camera never shows the outside of the map ---
	var map_pixels := Vector2(world.MAP_SIZE * world.TILE)
	for window_size in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(900, 1200)]:
		root.size = window_size
		await _wait(0.15)
		var view := Vector2(root.get_visible_rect().size) / camera.zoom
		_check("window %dx%d: the view (%d x %d px of map) fits inside the map (%d x %d)" % [
			window_size.x, window_size.y, roundi(view.x), roundi(view.y), roundi(map_pixels.x), roundi(map_pixels.y)],
			view.x <= map_pixels.x + 0.5 and view.y <= map_pixels.y + 0.5
			and camera.limit_right == roundi(map_pixels.x) and camera.limit_bottom == roundi(map_pixels.y))
	root.size = Vector2i(1152, 648)

	_gs.set_process(true)
	_gs.reset()
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
