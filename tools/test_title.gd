extends SceneTree
## Automated check of the title screen. Run from the project folder:
##   godot --headless --path . --script res://tools/test_title.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## With a screenshot folder it also saves pictures (needs a window, so no --headless):
##   godot --path . --script res://tools/test_title.gd -- C:/some/folder

const TITLE := "res://scenes/TitleScreen.tscn"
const WORLD := "res://scenes/World.tscn"

var _failed := 0
var _gs: Node
var _shots := ""


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


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_for_scene(path: String, seconds: float) -> bool:
	# Real time, not frames: headless frames run much faster than 60 per second.
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return true
	return false


func _shot(file_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(file_name))


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame


func _run() -> void:
	_check("the project starts on the title screen",
		ProjectSettings.get_setting("application/run/main_scene") == TITLE)

	# --- layout: the invisible button sits on the painted one, at any window size ---
	change_scene_to_file(TITLE)
	_check("title scene loads", await _wait_for_scene(TITLE, 2.0))
	var title := current_scene as Control
	var button: Button = title.get_node("PlayButton")
	var image_size: Vector2 = (title.get_node("Art") as TextureRect).texture.get_size()
	for window_size in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(800, 800), Vector2i(1600, 500)]:
		root.size = window_size
		await _frames(3)
		var picture: Rect2 = title.picture_rect()
		var fit := picture.size.x / image_size.x
		var want := Rect2(picture.position + title.play_rect.position * fit, title.play_rect.size * fit)
		var same_shape := absf(picture.size.x / picture.size.y - image_size.x / image_size.y) < 0.01
		var inside := Rect2(Vector2.ZERO, title.size).grow(0.5).encloses(picture)
		var on_top := button.position.distance_to(want.position) < 0.5 and button.size.distance_to(want.size) < 0.5
		_check("window %dx%d: picture keeps its shape, fits, button on the painted Play" % [window_size.x, window_size.y],
			same_shape and inside and on_top)
	root.size = Vector2i(1152, 648)
	await create_timer(0.6).timeout      # let the fade-in finish
	await _shot("title.png")

	# --- Play (button) starts a fresh game ---
	_gs.consume_oxygen(40)
	_gs.add_metal(50)
	button.pressed.emit()
	_check("Play opens the world", await _wait_for_scene(WORLD, 3.0))
	_check("Play starts a fresh game (O2 %.0f, metal %d)" % [_gs.oxygen, _gs.metal],
		_gs.oxygen > 99.0 and _gs.metal == Config.METAL_START and not _gs.game_over)
	await _frames(20)
	await _shot("world_after_play.png")

	# --- game over, then R goes back to the title ---
	_gs.consume_oxygen(1000)
	for i in int(Config.O2_ZERO_GRACE * 10.0) + 2:   # step the game clock by hand
		_gs._process(0.1)
	await _frames(2)
	_check("out of oxygen ends the game and pauses it", _gs.game_over and paused)
	await _shot("game_over.png")
	await _press_key(KEY_R)
	_check("R on the game-over screen goes back to the title", await _wait_for_scene(TITLE, 3.0))
	_check("back on the title the game is not paused", not paused)

	# --- Enter starts the game too ---
	await _frames(5)
	await _press_key(KEY_ENTER)
	_check("Enter starts the game", await _wait_for_scene(WORLD, 3.0))
	_check("the new game is fresh after a game over (O2 %.0f)" % _gs.oxygen,
		_gs.oxygen > 99.0 and not _gs.game_over)

	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
