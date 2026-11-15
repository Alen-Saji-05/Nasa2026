extends SceneTree
## Checks the Mars fact papers, the low-battery warning, the shelter furniture and
## the death screens. Run:
##   godot --headless --path . --script res://tools/test_extras.gd   [-- C:/screenshot/folder]

var _failed := 0
var _gs: Node
var _guide: Node
var _dialogue: Node
var _shots := ""


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_guide = root.get_node("Guide")
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
	await create_timer(seconds, true).timeout


func _shot(file_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(file_name))


func _papers() -> Array:
	return current_scene.find_children("FactPaper*", "", true, false)


func _run() -> void:
	_gs.reset()
	_gs.set_process(false)
	_guide.set_process(false)
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	_dialogue.clear()

	# --- fact papers on the surface ---
	var surface_count := Config.FACTS.filter(func(f: Dictionary) -> bool: return f.where == "surface").size()
	var papers := _papers()
	var apart := true
	for p: Node2D in papers:
		for q: Node2D in papers:
			apart = apart and (p == q or p.position.distance_to(q.position) > 100.0)
	_check("%d of the %d fact papers lie on the surface, spread out" % [papers.size(), Config.FACTS.size()],
		papers.size() == surface_count and apart)
	_check("fresh ice never appears on a paper", _gs.ice_spawn_spots.all(func(s: Vector2) -> bool:
		return papers.all(func(p: Node2D) -> bool: return p.position.distance_to(s) > 20.0)))
	var paper: Node2D = papers[0]
	var player: Node2D = current_scene.get_node("Entities/Player")
	player.global_position = paper.global_position + Vector2(0, 10)
	await _wait(0.4)
	var hand: Node = player.get_node("Harvester")
	_check("next to a paper, E points at it: '%s'" % paper.prompt_text(), hand.focus() == paper)
	hand.use()
	await _wait(0.8)
	var viewer: Control = current_scene.get_node("UI/HUD/FactViewer")
	var body: Label = viewer.get_node("Body")
	var f: Dictionary = Config.FACTS[paper.get("fact")]
	await _shot("fact_paper.png")
	_check("E opens it full screen and pauses the game: '%s'" % viewer.get_node("Title").text,
		viewer.visible and paper_ok(viewer, f) and paused and _gs.facts_read.has(paper.get("fact")))
	var fs: int = body.get_theme_font_size("font_size")
	_check("the fact fills the page in a big readable size (%d px)" % fs, fs >= 20
		and viewer.get_node("Paper").size.y > root.get_visible_rect().size.y * 0.9)
	var biggest := 99
	for i in Config.FACTS.size():
		body.text = Config.FACTS[i].text
		viewer.call("_fit_text")
		biggest = mini(biggest, body.get_theme_font_size("font_size"))
	_check("every fact fits its page at %d px or more" % biggest, biggest >= 18)
	viewer.close()
	await _wait(0.5)
	_check("E closes it and the game goes on; read papers stop shining", not viewer.visible and not paused
		and paper.prompt_text() == "E: read again")

	# --- fact papers in the caves ---
	var found := 0
	for i in Config.FACTS.size():
		var where: String = Config.FACTS[i].where
		if where == "surface":
			continue
		_gs.set_location(where.get_slice("/", 0), int(where.get_slice("/", 1)), "from_surface")
		change_scene_to_file(Config.CAVE_SCENE)
		await _wait(0.4)
		var here := _papers()
		if here.size() == 1 and here[0].get("fact") == i:
			found += 1
		if i == 3:
			await _shot("fact_paper_cave.png")
	_check("the other %d papers are in the caves, one per chosen layer" % found, found == Config.FACTS.size() - surface_count)
	_gs.set_location("", 0, "from_cave")
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	_dialogue.clear()

	# --- low battery: Mission Control says build a Solar Panel ---
	var highlights: Array[String] = []
	_gs.highlight.connect(func(t: String) -> void: highlights.append(t))
	_gs.battery_charge = 16.0
	var early: String = _guide.check()
	_gs.battery_charge = Config.POWER_LOW_HINT
	_gs.power_changed.emit()
	var key: String = _guide.check()
	await _wait(0.3)
	await _shot("power_low.png")
	_check("battery 16: no warning yet; at %d: '%s', the power line and the Solar Panel page are highlighted"
		% [Config.POWER_LOW_HINT, key], early != "power_low" and key == "power_low"
		and highlights.has("power") and highlights.has("book:solar"))

	# --- the shelter furniture ---
	_gs.set_location("", 0, "shelter")
	change_scene_to_file(Config.SHELTER_SCENE)
	await _wait(0.6)
	_dialogue.clear()
	var ok := true
	for n in ["Bed", "Desk", "O2Tanks", "Shelf", "Door/Art"]:
		ok = ok and current_scene.has_node("Entities/" + n)
	await _wait(0.2)
	await _shot("shelter_furniture.png")
	_check("the shelter has the new bed, desk, O2 tanks, shelf and door art", ok)
	_gs.set_location("", 0, "shelter_exit")

	# --- every death has its own death screen, then "Press R to restart" ---
	var cards := 0
	for cause: String in ["oxygen", "water", "hunger", "radiation", "storm", "time"]:
		_gs.reset()
		paused = false
		change_scene_to_file(Config.WORLD_SCENE)
		await _wait(0.4)
		_dialogue.clear()
		_gs.death_cause = cause
		_gs._end_game("test")
		var endings: Node = null
		var deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			endings = current_scene.get_node_or_null("UI/HUD/Endings")
			if endings != null and endings.finished:
				break
		await _wait(1.0)
		var card := endings.get_node_or_null("Card") as TextureRect if endings != null else null
		var label: Label = current_scene.get_node("UI/HUD/GameOver/Label")
		if card != null and card.texture.resource_path == endings.CARDS[cause] and label.text == "Press R to restart" \
				and current_scene.get_node("UI/HUD/GameOver").visible:
			cards += 1
		await _shot("death_%s.png" % cause)
	_check("all 6 deaths end on their own death screen with 'Press R to restart' (%d)" % cards, cards == 6)

	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func paper_ok(viewer: Control, f: Dictionary) -> bool:
	return viewer.get_node("Title").text == f.title and viewer.get_node("Body").text == f.text
