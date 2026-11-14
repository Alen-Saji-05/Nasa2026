extends SceneTree
## Automated check of the Build Book. Run from the project folder:
##   godot --headless --path . --script res://tools/test_book.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
## With a screenshot folder it also saves pictures (needs a window, so no --headless):
##   godot --path . --script res://tools/test_book.gd -- C:/some/folder

## The recipes exactly as specified: iron ingots, aluminum ingots, then the rest.
const RECIPES := {
	"power_station": {"iron_ingot": 3, "aluminum_ingot": 5, "sulfur_compound": 2},
	"propellant": {"iron_ingot": 3, "aluminum_ingot": 4, "methane": 3, "oxygen": 3},
	"engine": {"iron_ingot": 6, "aluminum_ingot": 4, "sulfur_compound": 2},
	"avionics": {"iron_ingot": 2, "aluminum_ingot": 4, "sulfur_compound": 2, "electronics": 1},
	"thermal": {"iron_ingot": 2, "aluminum_ingot": 5, "sulfur_compound": 2},
	"life_support": {"iron_ingot": 2, "aluminum_ingot": 3, "oxygen": 4, "water": 3},
	"greenhouse": {"iron_ingot": 3, "aluminum_ingot": 5, "sulfur_compound": 2, "potato": 2},
	"reservoir": {"iron_ingot": 3, "aluminum_ingot": 4, "sulfur_compound": 2},
	"oxygen_gen": {"iron_ingot": 3, "aluminum_ingot": 4, "electronics": 1},
	"radiation_sensor": {"iron_ingot": 2, "aluminum_ingot": 2, "electronics": 1},
	"shelter": {"iron_ingot": 6, "aluminum_ingot": 5, "sulfur_compound": 3},
}

var _failed := 0
var _gs: Node
var _builder: Node
var _shots := ""
var _messages: Array[String] = []
var _unlock_events := 0


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_builder = root.get_node("Builder")
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


func _pad(pad_id: String) -> Node:
	for p in get_nodes_in_group("build_pads"):
		if p.get("pad_id") == pad_id:
			return p
	return null


func _run() -> void:
	# --- the data ---
	var costs_ok := Config.BOOK_ORDER.size() == 11
	var art := {}
	for id: String in Config.BOOK_ORDER:
		var def := Config.machine(id)
		if def.get("cost", {}) != RECIPES.get(id, {}) or str(def.get("description", "")) == "":
			costs_ok = false
		var path: String = def.idle[0]
		if ResourceLoader.exists(path):
			art[path] = true
		for item_id: String in def.cost:
			if Config.item(item_id).is_empty() or not ResourceLoader.exists(Config.item(item_id).icon):
				costs_ok = false
	_check("11 recipes with exactly the specified materials and a description", costs_ok)
	_check("every recipe has its own machine picture (%d different)" % art.size(), art.size() == 11)

	_gs.reset()
	_gs.set_process(false)
	_gs.message.connect(func(text: String) -> void: _messages.append(text))
	_gs.recipes_unlocked.connect(func(_ids: Array) -> void: _unlock_events += 1)
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	var book: Control = current_scene.get_node("UI/HUD/BuildBook")
	var icon: TextureButton = book.get_node("Icon")
	var player: CharacterBody2D = current_scene.get_node("Entities/Player")

	# --- the HUD icon ---
	var icon_tex := icon.texture_normal as AtlasTexture
	_check("the book icon is on the right side of the HUD and is the small open book from the sheet",
		icon.visible and icon.global_position.x > root.get_visible_rect().size.x * 0.75
		and icon_tex != null and icon_tex.atlas.resource_path == "res://art/new_sprites/book_sprite.png"
		and icon_tex.region == Rect2(470, 582, 214, 218))

	# --- discovery ---
	_check("at the start no recipe is discovered", _gs.unlocked_recipes().is_empty())
	_gs.add_item("sulfur", 2)
	_check("raw sulfur ore discovers nothing yet", _gs.unlocked_recipes().is_empty() and _unlock_events == 0)
	current_scene.get_node("Entities/Hab").interact(player)
	var with_sulfur: Array = Config.BOOK_ORDER.filter(func(id: String) -> bool:
		return RECIPES[id].has("sulfur_compound") and id != "shelter")
	_check("refining it at the hab gives 2 Sulfur Compounds and discovers all %d recipes that use them together: %s" % [with_sulfur.size(), str(_gs.unlocked_recipes())],
		_gs.item_count("sulfur_compound") == 2 and _gs.item_count("sulfur") == 0 and _gs.unlocked_recipes() == with_sulfur)
	_check("one 'NEW RECIPES DISCOVERED!' message, shown once", _unlock_events == 1 and _messages.count("NEW RECIPES DISCOVERED!") == 1)
	_gs.spend_items({"sulfur_compound": 2})
	_gs.add_item("sulfur_compound", 1)
	_check("spending the material does not lock them again, and finding more does not announce again",
		_gs.unlocked_recipes() == with_sulfur or _gs.unlocked_recipes().size() >= with_sulfur.size() and _unlock_events == 1)
	_check("the shelter uses sulfur too but stays locked until the first radiation event", not _gs.recipe_unlocked("shelter"))
	_gs.see_radiation()
	_check("after the first radiation event the shelter is discovered; the sensor still needs one of its materials",
		_gs.recipe_unlocked("shelter") and not _gs.recipe_unlocked("radiation_sensor") and _unlock_events == 2)

	# --- opening, pages, closing ---
	icon.pressed.emit()
	await _wait(0.4)
	var overlay: Control = book.get_node("Overlay")
	var start: Vector2 = player.global_position
	Input.action_press("ui_down")
	await _wait(0.3)
	Input.action_release("ui_down")
	_check("clicking the icon opens the book; the game is paused and the player cannot move",
		overlay.visible and paused and player.global_position.distance_to(start) < 0.5)
	var title: Label = overlay.get_node("Book/Content").get_child(0).get_node("Title")
	var build: Button = overlay.find_child("Build", true, false)
	var seen: Array = []
	var names_ok := true
	for i in Config.BOOK_ORDER.size():
		seen.append(book.page_id())
		var want: String = Config.machine(book.page_id()).name if _gs.recipe_unlocked(book.page_id()) else "???"
		if title.text != want:
			names_ok = false
		if i == 0:
			await _shot("book_page.png")
		await book.flip(1)
	_check("turning the page 11 times shows every recipe once, in order, and comes back to the first",
		seen == Config.BOOK_ORDER and book.page_id() == Config.BOOK_ORDER[0])
	_check("discovered pages show the machine's name, locked pages show '???'", names_ok)
	book.show_page(Config.BOOK_ORDER.find("radiation_sensor"))
	await _shot("book_locked.png")
	_check("a locked recipe cannot be built", build.disabled)

	# --- building from the book ---
	book.show_page(Config.BOOK_ORDER.find("reservoir"))
	_check("discovered but not affordable: Build is off and it says why ('%s')" % overlay.find_child("Problem", true, false).text,
		build.disabled and overlay.find_child("Problem", true, false).text.begins_with("Need 3 Iron Ingots"))
	_gs.add_item("iron_ingot", 3)
	_gs.add_item("aluminum_ingot", 4)
	_gs.add_item("sulfur_compound", 1)
	var rows: Node = overlay.find_child("Materials", true, false)
	await _wait(0.05)
	_check("the page shows live amounts (%s) and Build turns on" % rows.get_child(0).get_child(2).text,
		rows.get_child_count() == 3 and rows.get_child(0).get_child(2).text == "3 / 3" and not build.disabled)
	var limit: float = _gs.water_limit
	build.pressed.emit()
	await _wait(0.1)
	_check("Build closes the book, un-pauses and starts placing the machine",
		not overlay.visible and not paused and _builder.placing == "reservoir")
	_builder.place_on(_pad("pad_02"))
	await _wait(0.1)
	_check("placing it takes exactly the materials (iron %d, aluminum %d, sulfur compounds %d) and the tank works (+%d water limit)" % [
		_gs.item_count("iron_ingot"), _gs.item_count("aluminum_ingot"), _gs.item_count("sulfur_compound"), _gs.water_limit - limit],
		_gs.item_count("iron_ingot") == 0 and _gs.item_count("aluminum_ingot") == 0 and _gs.item_count("sulfur_compound") == 0
		and _gs.machines.get("pad_02") == "reservoir" and is_equal_approx(_gs.water_limit - limit, Config.WATER_TANK_LIMIT_BONUS))
	await _wait(0.3)
	await _shot("built.png")
	for id: String in ["iron_ingot", "aluminum_ingot", "sulfur_compound"]:
		_gs.add_item(id, 40)
	_check("a second one cannot be built: '%s'" % _builder.build_problem("reservoir"), _builder.build_problem("reservoir") == "Already built")
	_check("the engine goes on the launch pad only", _pad("launch").fits("engine") and not _pad("pad_03").fits("engine"))

	# --- B and Esc ---
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(0.3)
	var opened_by_key := overlay.visible
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(0.1)
	_check("B opens the book and Esc closes it", opened_by_key and not overlay.visible and not paused)

	# --- the six repairs win the game ---
	for id: String in ["methane", "oxygen", "electronics"]:
		_gs.add_item(id, 10)
	var pads := ["pad_03", "pad_04", "launch", "pad_05", "pad_06", "pad_07"]
	for i in Config.REPAIR_ORDER.size():
		_check("five repairs are not enough to win", not _gs.game_won)
		_builder.start_placing(Config.REPAIR_ORDER[i])
		_builder.place_on(_pad(pads[i]))
		await _wait(0.05)
	_check("all six ship systems built: the game is won ('%s')" % _gs.game_over_reason, _gs.game_won and _gs.ship_repaired())
	await _wait(0.2)
	await _shot("repaired.png")

	_gs.reset()
	paused = false
	_check("a new game forgets every discovery", _gs.unlocked_recipes().is_empty() and not _gs.radiation_seen and _gs.new_recipes.is_empty())
	_gs.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
