extends SceneTree
## Automated check of the Build Book, the progression and the ship repair. Run:
##   godot --headless --path . --script res://tools/test_book.gd   [-- C:/screenshot/folder]
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## Dependency map (what makes what). The book must list things in an order where
## everything a page needs is either found in the world or made on an EARLIER page:
##   found:  iron, aluminum, sulfur, electronics (caves/surface), water (ice), potato (wreck)
##   Ore Refinery -> iron_ingot, aluminum_ingot, sulfur_compound
##   Wire -> wire,  CO2 Capture -> co2,  Oxygen Capsule -> oxygen,  Methane Capsule -> methane

const FOUND := ["iron", "aluminum", "sulfur", "electronics", "water", "potato"]
const MADE_BY := {"iron_ingot": "ore_refinery", "aluminum_ingot": "ore_refinery", "sulfur_compound": "ore_refinery",
	"wire": "wire", "co2": "co2_capture", "oxygen": "oxygen", "methane": "methane"}
## The recipes as specified (the 11 from the Build Book brief, plus Wire).
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
	"wire": {"iron_ingot": 1},
}

var _failed := 0
var _gs: Node
var _builder: Node
var _dialogue: Node
var _shots := ""
var _unlock_events := 0


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_builder = root.get_node("Builder")
	_dialogue = root.get_node("Dialogue")
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


func _check_data() -> void:
	var order: Array = Config.BOOK_ORDER
	var exact := true
	for id: String in RECIPES:
		if Config.machine(id).get("cost", {}) != RECIPES[id]:
			exact = false
			print("   recipe differs: ", id)
	_check("the 11 specified recipes and Wire (1 Iron Ingot = 1 Wire) are exact", exact)
	var art_ok := true
	var pictures := {}
	for id: String in order:
		var def := Config.machine(id)
		var path: String = (def.get("idle", def.get("levels", [""])) as Array)[0]
		art_ok = art_ok and ResourceLoader.exists(path) and str(def.get("description", "")) != ""
		pictures[path] = true
		for item_id: String in def.cost:
			art_ok = art_ok and not Config.item(item_id).is_empty() and ResourceLoader.exists(Config.item(item_id).icon)
	_check("%d pages, each with art, a description and known materials (%d different pictures)" % [order.size(), pictures.size()],
		order.size() == 18 and art_ok and pictures.size() >= 17)
	# The order follows the dependencies: nothing needs something from a later page.
	var bad: Array[String] = []
	for i in order.size():
		var def := Config.machine(order[i])
		for item_id: String in def.cost:
			if not FOUND.has(item_id) and order.find(MADE_BY.get(item_id, "?")) >= i:
				bad.append("%s needs %s" % [order[i], item_id])
		if def.has("requires") and order.find(def.requires) >= i:
			bad.append("%s requires %s" % [order[i], def.requires])
	_check("every page only needs found materials or things made on earlier pages %s" % str(bad), bad.is_empty())
	_check("the Ore Refinery is first, the Oxygen Generator early (page %d), the six ship modules last" % (order.find("oxygen_gen") + 1),
		order[0] == "ore_refinery" and order.find("oxygen_gen") < 6
		and order.slice(order.size() - 6) == Config.REPAIR_ORDER)


func _run() -> void:
	_check_data()
	_gs.reset()
	_gs.set_process(false)
	_gs.recipes_unlocked.connect(func(_ids: Array) -> void: _unlock_events += 1)
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	var book: Control = current_scene.get_node("UI/HUD/BuildBook")
	var icon: TextureButton = book.get_node("Icon")
	var player: CharacterBody2D = current_scene.get_node("Entities/Player")
	_check("the story starts with Mission Control: '%s...'" % _dialogue.current_text().left(30),
		_dialogue.is_showing() and _gs.story_seen.has("intro"))
	var icon_tex := icon.texture_normal as AtlasTexture
	_check("the book icon is the small open book from the sheet, on the right of the HUD",
		icon.global_position.x > root.get_visible_rect().size.x * 0.75 and icon_tex.region == Rect2(470, 582, 214, 218))

	# --- discovery follows the progression ---
	_check("at the start no recipe is discovered", _gs.unlocked_recipes().is_empty())
	_gs.add_item("iron", 4)
	_check("Iron Ore discovers the Ore Refinery (%s) and says so once" % str(_gs.unlocked_recipes()),
		_gs.unlocked_recipes() == ["ore_refinery"] and _gs.story_seen.has("found_iron") and _unlock_events == 1)
	_gs.add_item("iron", 4)
	_check("more iron says nothing new", _unlock_events == 1)
	_gs.add_item("aluminum", 4)
	_gs.add_item("sulfur", 2)

	# --- build the refinery from the book ---
	icon.pressed.emit()
	await _wait(0.4)
	var overlay: Control = book.get_node("Overlay")
	var build: Button = overlay.find_child("Build", true, false)
	_check("the book opens on the Ore Refinery and it can be built", overlay.visible and paused and book.page_id() == "ore_refinery" and not build.disabled)
	await _shot("book_refinery.png")
	build.pressed.emit()
	await _wait(0.1)
	_builder.place_on(_pad("pad_01"))
	await _wait(0.1)
	var refinery: Node = null
	for m in get_nodes_in_group("machines"):
		if m.get("machine_id") == "ore_refinery":
			refinery = m
	_check("the refinery stands on pad_01 with its own sprite and took 4 iron + 4 aluminum ore",
		refinery != null and (refinery.get_node("Sprite") as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0).resource_path.ends_with("ore_refinery.png")
		and _gs.item_count("iron") == 4 and _gs.item_count("aluminum") == 0)
	refinery.interact(player)
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 0.2
	for i in 160:
		_gs._process(0.1)
	refinery.interact(player)
	_check("E loads the ore; it refines over time on hab power; E collects: %d iron ingots, %d sulfur compounds" % [
		_gs.item_count("iron_ingot"), _gs.item_count("sulfur_compound")],
		_gs.item_count("iron_ingot") == 4 and _gs.item_count("sulfur_compound") == 2 and _gs.item_count("iron") == 0)
	_check("ingots unlock the next pages (%d discovered)" % _gs.unlocked_recipes().size(),
		_gs.recipe_unlocked("wire") and _gs.recipe_unlocked("oxygen_gen") and _gs.recipe_unlocked("power_station")
		and not _gs.recipe_unlocked("shelter") and not _gs.recipe_unlocked("methane"))

	# --- craft Wire in the book ---
	book.open()
	await _wait(0.3)
	book.show_page(Config.BOOK_ORDER.find("wire"))
	build.pressed.emit()
	await _wait(0.05)
	_check("CRAFT on the Wire page: 1 iron ingot -> 1 wire, and the book stays open",
		build.text == "CRAFT" and _gs.item_count("wire") == 1 and _gs.item_count("iron_ingot") == 3 and overlay.visible)
	book.show_page(Config.BOOK_ORDER.find("oxygen"))
	_check("the Oxygen Capsule says it needs the Oxygen Generator first", build.disabled
		or overlay.find_child("Problem", true, false).text == "Needs a Oxygen Generator first")
	var names_ok := true
	for i in Config.BOOK_ORDER.size():
		var want: String = Config.machine(book.page_id()).name if _gs.recipe_unlocked(book.page_id()) else "???"
		names_ok = names_ok and (overlay.find_child("Title", true, false) as Label).text == want
		await book.flip(1)
	_check("flipping through all %d pages shows the right names" % Config.BOOK_ORDER.size(), names_ok)

	# --- ship repair: build a module in the book, install it at its port ---
	for id: String in ["iron_ingot", "aluminum_ingot", "sulfur_compound", "electronics", "methane", "oxygen"]:
		_gs.add_item(id, 30)
	_gs.add_water(20.0)
	book.show_page(Config.BOOK_ORDER.find("engine"))
	await _shot("book_engine.png")
	build.pressed.emit()
	_check("BUILD on the Engine page makes the module (ready to install), it is not placed on a pad",
		_gs.modules_ready.has("engine") and _builder.placing == "" and overlay.visible)
	book.close()
	var slot: Node2D = current_scene.get_node("Entities/Slot_engine")
	player.global_position = slot.global_position + Vector2(0, 14)
	await _wait(0.15)
	var hand: Node = player.get_node("Harvester")
	_check("next to the ship's tail, E points at the engine port", hand.focus() == slot)
	hand.use()
	await _wait(0.6)
	_check("E installs it: the port shows the real engine, progress 1/6, and the story says so",
		_gs.installed == ["engine"] and slot.modulate.is_equal_approx(Color.WHITE) and _gs.story_seen.has("installed_engine"))
	await _shot("engine_installed.png")
	_check("a second engine cannot be built: '%s'" % _builder.build_problem("engine"), _builder.build_problem("engine") == "Already built")
	var ship_sprite := current_scene.get_node("Entities/BrokenRocket/Sprite2D") as Sprite2D
	for id: String in Config.REPAIR_ORDER:
		if id == "engine":
			continue
		_check("not repaired before every module is in (%d/6)" % _gs.installed.size(), not _gs.game_won and ship_sprite.texture.resource_path.contains("Crashed"))
		_builder.craft(id)
		(current_scene.get_node("Entities/Slot_" + id)).interact(player)
	await _wait(0.2)
	_check("all six installed: the ship shows its repaired sprite and the game is won ('%s')" % _gs.game_over_reason,
		_gs.game_won and _gs.ship_repaired() and ship_sprite.texture.resource_path.ends_with("Repaired_Spaceship.png"))
	await _shot("repaired.png")

	_gs.reset()
	paused = false
	_check("a new game forgets discoveries, modules and story", _gs.unlocked_recipes().is_empty() and _gs.installed.is_empty()
		and _gs.story_seen.is_empty() and not _dialogue.is_showing())
	_gs.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
