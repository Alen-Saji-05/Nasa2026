extends SceneTree
## End-to-end check of health and food hints, radiation events, dust storms and
## the walk-in Emergency Shelter. Run:
##   godot --headless --path . --script res://tools/test_hazards.gd   [-- C:/screenshot/folder]
## Prints PASS / FAIL lines and exits with code 1 if anything failed.

var _failed := 0
var _gs: Node
var _hz: Node
var _guide: Node
var _builder: Node
var _travel: Node
var _dialogue: Node
var _shots := ""
var _messages: Array[String] = []
var _highlights: Array[String] = []


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_hz = root.get_node("Hazards")
	_guide = root.get_node("Guide")
	_builder = root.get_node("Builder")
	_travel = root.get_node("Travel")
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


func _until(condition: Callable, seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not _travel.busy and condition.call():
			return true
	return false


func _shot(file_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(file_name))


## Game time passes: GameState (hunger, day/night) and the hazards.
func _step(seconds: float, hazards_only := false) -> void:
	for i in roundi(seconds * 10.0):
		if not hazards_only:
			_gs._process(0.1)
		_hz._process(0.1)


func _player() -> CharacterBody2D:
	return current_scene.get_node("Entities/Player")


func _hand() -> Node:
	return _player().get_node("Harvester")


func _in_scene(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


func _heard(text: String) -> bool:
	return _messages.any(func(m: String) -> bool: return m.begins_with(text))


func _walk(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


func _run() -> void:
	_gs.reset()
	for n in [_gs, _hz, _guide]:
		n.set_process(false)
	_gs.message.connect(func(text: String) -> void: _messages.append(text))
	_gs.highlight.connect(func(target: String) -> void: _highlights.append(target))
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	_dialogue.clear()
	var hud: Control = current_scene.get_node("UI/HUD")
	_check("the HUD shows a health bar and no metal counter", hud.has_node("Bars/HealthRow") and not hud.has_node("Bars/MetalRow"))

	# --- ice: used-up deposits refill a little, fresh ones appear elsewhere ---
	var spots: Array = _gs.ice_spawn_spots
	_check("the world lists %d open spots for fresh ice" % spots.size(), spots.size() > 50)
	var fixed: Node = null
	for n in get_nodes_in_group("resource_nodes"):
		if str(n.get("node_id")).begins_with("surface/Ice"):
			fixed = n
	_gs.water = 0.0
	for i in Config.NODE_CHARGES:
		fixed.harvest()
	_check("a surface ice deposit can be used up", fixed.is_empty())
	_gs.sol_elapsed_seconds = 0.0
	_gs.water = Config.WATER_START
	_step(Config.ICE_REGEN_SECONDS - 1.0)
	var still_empty: bool = fixed.is_empty()
	_step(2.0)
	_check("%d s later it refills with a smaller amount (%d uses)" % [Config.ICE_REGEN_SECONDS, fixed.get("charges_left")],
		still_empty and fixed.get("charges_left") == Config.ICE_REGEN_CHARGES)
	var ids: Array[String] = []
	for i in Config.ICE_SPAWN_MAX + 1:
		ids.append(_gs.spawn_ice())
	await _wait(0.7)
	var fresh: Node = current_scene.get_node_or_null("Entities/Nodes/" + ids[0].get_file())
	_check("fresh ice appears at %d different open spots, full, at most %d at once" % [Config.ICE_SPAWN_MAX, Config.ICE_SPAWN_MAX],
		fresh != null and fresh.get("charges_left") == Config.NODE_CHARGES and ids[Config.ICE_SPAWN_MAX] == ""
		and _gs.ice_spawns.size() == Config.ICE_SPAWN_MAX and spots.has(_gs.ice_spawns[ids[1]]))
	_gs.water = 0.0
	for i in Config.NODE_CHARGES:
		fresh.harvest()
	await _wait(1.5)
	_check("used up, a fresh deposit melts away and makes room for a new one somewhere else",
		not is_instance_valid(fresh) and not _gs.ice_spawns.has(ids[0]) and _gs.spawn_ice() != "")
	_gs.water = Config.WATER_START
	_gs.sol_elapsed_seconds = 0.0
	_dialogue.clear()

	# --- hunger and the food hints ---
	_gs.sol_elapsed_seconds = 10.0
	_gs.health = Config.HUNGER_HINT_1 + 1.0
	_step(4.0)
	_check("hunger lowers health slowly (%.1f)" % _gs.health, _gs.health < Config.HUNGER_HINT_1 + 1.0 and _gs.health > Config.HUNGER_HINT_1 - 1.0)
	_step(3.0)
	_check("below %d: 'I need to keep this in check... hungry' and the health bar is highlighted" % Config.HUNGER_HINT_1,
		_guide.check() == "hunger_1" and _highlights.has("health"))
	_dialogue.clear()
	_check("next hint: potatoes in the wreck, the ship gets an arrow", _guide.check() == "food_wreck" and _highlights.has("wreck"))
	_dialogue.clear()
	current_scene.get_node("Entities/BrokenRocket").interact(_player())
	_dialogue.clear()
	_check("after salvaging: 'press F to eat'", _guide.check() == "food_eat")
	var before: float = _gs.health
	_check("F eats a potato: +%d health" % Config.POTATO_HEALTH, _gs.eat_potato() and is_equal_approx(_gs.health, before + Config.POTATO_HEALTH)
		and _gs.item_count("potato") == Config.WRECK_POTATOES - 1)
	_dialogue.clear()
	_gs.health = Config.HUNGER_HINT_2 - 1.0
	_check("health dropping again: 'uh oh... I need a way to harvest food'", _guide.check() == "hunger_2")
	_dialogue.clear()
	_check("then the Greenhouse is highlighted in the Build Book (page %d)" % hud.get_node("BuildBook").page,
		_guide.check() == "food_grow" and _highlights.has("book:greenhouse")
		and hud.get_node("BuildBook").page_id() == "greenhouse")
	for id: String in ["iron_ingot", "aluminum_ingot", "sulfur_compound"]:
		_gs.add_item(id, 40)
	_builder.start_placing("greenhouse")
	var greenhouse: Node2D = _builder.place_on(_pad_free())
	_step(Config.GREENHOUSE_SECONDS + 0.5)
	var potatoes: int = _gs.item_count("potato")
	greenhouse.interact(_player())
	_check("the Greenhouse (2 seed potatoes) grows a potato every %d s; E harvests it" % Config.GREENHOUSE_SECONDS,
		potatoes == Config.WRECK_POTATOES - 3 and _gs.item_count("potato") == potatoes + 1)
	_dialogue.clear()

	# --- radiation: starts by itself on the timer ---
	_gs.health = Config.HEALTH_MAX
	_hz.next_storm = 999.0
	_check("calm at first, the first radiation warning is due at %d s" % Config.RADIATION_FIRST,
		_hz.radiation == "" and _hz.storm == "" and _hz.next_radiation > 0.0 and _hz.next_radiation <= Config.RADIATION_FIRST)
	_step(_hz.next_radiation + 0.2, true)
	_check("the radiation warning starts on its own: '%s'" % _messages.back(),
		_hz.radiation == "warning" and _heard("RADIATION WARNING! Seek Emergency Shelter immediately!"))
	_check("the first event unlocks the Emergency Shelter recipe", _gs.radiation_seen and _gs.recipe_unlocked("shelter")
		and Config.machine("shelter").name == "Emergency Shelter")
	_check("a second trigger does not start a duplicate event", _start_twice())
	await _wait(0.1)
	_step(Config.RADIATION_WARNING, true)
	_check("then it is active", _hz.radiation == "active" and _heard("Radiation event active!"))
	before = _gs.health
	_step(1.0, true)
	var after_one: float = _gs.health
	_step(1.1, true)
	_check("outside it hurts every %d s, not every frame (%.0f -> %.0f -> %.0f)" % [Config.HAZARD_DAMAGE_EVERY, before, after_one, _gs.health],
		is_equal_approx(after_one, before) and is_equal_approx(_gs.health, before - Config.RADIATION_DAMAGE))
	await _wait(0.2)
	await _shot("radiation_outside.png")

	# --- build the Emergency Shelter and walk in ---
	_builder.start_placing("shelter")
	var shelter: Node2D = _builder.place_on(_pad_free())
	_check("the Emergency Shelter is built with its own art", shelter != null
		and (shelter.get_node("Sprite") as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0).resource_path.ends_with("radioactive_protection_shelter.png"))
	_player().global_position = shelter.global_position + Vector2(0, 12)
	await _wait(0.3)
	var prompt: Label = _hand().get("_prompt")
	_check("at the door: '%s'" % prompt.text, _hand().focus() == shelter and prompt.text == "Press E to Enter Emergency Shelter" and prompt.visible)
	var bag: Dictionary = _gs.inventory.duplicate()
	var health_in: float = _gs.health
	_hand().use()
	_check("E really goes inside: the shelter interior scene loads",
		await _until(func() -> bool: return _in_scene(Config.SHELTER_SCENE)) and _gs.in_shelter
		and _gs.location_name() == "Emergency Shelter")
	await _wait(0.2)
	var cam := _player().get_node("Camera2D") as Camera2D
	prompt = _hand().get("_prompt")
	_check("the player stands in the room, the camera follows, inventory and health kept",
		Rect2(0, 0, 240, 150).has_point(_player().position) and cam.is_current() and _gs.inventory == bag and absf(_gs.health - health_in) < 1.0)
	var start := _player().position
	await _walk("ui_left", 0.4)
	var moved := _player().position.x < start.x - 10
	await _walk("ui_down", 1.0)
	_check("the player can walk inside but not through the front wall (y %.0f)" % _player().position.y, moved and _player().position.y < 120.0)
	await _shot("shelter_inside.png")
	before = _gs.health
	var rad_left: float = _hz.rad_left
	_step(6.0, true)
	_check("inside: no radiation damage, but the event keeps running outside (%.0f s -> %.0f s left)" % [rad_left, _hz.rad_left],
		is_equal_approx(_gs.health, before) and _hz.rad_left < rad_left and _hz.radiation == "active")
	var door: Node2D = current_scene.get_node("Entities/Door")
	_player().position = door.position + Vector2(0, -22)
	await _wait(0.6)
	_messages.clear()
	_hand().use()
	await _wait(0.3)
	_check("the exit is locked while radiation is active: '%s'" % (_messages.back() if not _messages.is_empty() else ""),
		_hand().focus() == door and prompt.text == "Exit locked: hazard outside" and _in_scene(Config.SHELTER_SCENE)
		and _heard("Not safe outside: radiation active"))
	_step(_hz.rad_left + 0.2, true)
	_check("when it ends: 'Environmental conditions are safe. You may exit the Emergency Shelter.'",
		_hz.radiation == "" and _heard("Environmental conditions are safe. You may exit the Emergency Shelter."))
	await _wait(0.6)
	_check("the door now says '%s'" % prompt.text, prompt.text == "Press E to Exit Emergency Shelter")
	_hand().use()
	_check("E goes back out to the surface", await _until(func() -> bool: return _in_scene(Config.WORLD_SCENE)) and not _gs.in_shelter)
	await _wait(0.2)
	prompt = _hand().get("_prompt")
	shelter = _shelter()
	var out_pos := _player().global_position
	_check("the player stands in front of the shelter door, not inside anything",
		out_pos.distance_to(shelter.global_position) < 20.0 and not _player().test_move(_player().global_transform, Vector2(0, 2))
		and _gs.inventory == bag)

	# --- dust storm: warning, approaching, active, clearing, over ---
	_messages.clear()
	_hz.next_storm = 0.05
	_step(0.1, true)
	_check("the dust storm warning: '%s'" % _messages.front(), _hz.storm == "warning" and _heard("A dust storm is approaching! Find shelter!"))
	_step(Config.STORM_WARNING + Config.STORM_APPROACH * 0.5, true)
	await _wait(0.05)
	_check("approaching: the dust builds up (intensity %.2f), the wind pushes and slows the player" % _hz.intensity,
		_hz.storm == "approaching" and _hz.intensity > 0.3 and _hz.intensity < 0.7 and _hz.wind().x > 0.0 and _hz.speed_factor() < 1.0
		and _heard("Dust storm intensity increasing!"))
	_step(Config.STORM_APPROACH * 0.5 + 0.2, true)
	await _wait(0.1)
	var dust: CPUParticles2D = _hz.get("_dust")
	_check("active: full strength, dust blowing, solar power cut to %d%%" % roundi(_hz.solar_factor() * 100),
		_hz.storm == "active" and is_equal_approx(_hz.intensity, 1.0) and dust.emitting and _hz.solar_factor() < 0.5
		and _heard("Severe dust storm conditions! Stay indoors!"))
	await _wait(0.3)
	await _shot("dust_storm.png")
	before = _gs.health
	_step(Config.HAZARD_DAMAGE_EVERY + 0.05, true)
	_check("outside in the storm the suit takes damage (%.0f -> %.0f)" % [before, _gs.health], _gs.health < before)

	# --- both at once: shelter, and only out when both are over ---
	_hz.trigger("radiation")
	_step(_hz.rad_left + 0.1, true)
	_check("radiation and the storm can be active together", _hz.radiation == "active" and _hz.storm == "active")
	_player().global_position = shelter.global_position + Vector2(0, 12)
	await _wait(0.6)
	_hand().use()
	await _until(func() -> bool: return _in_scene(Config.SHELTER_SCENE))
	await _wait(0.2)
	before = _gs.health
	_step(4.0, true)
	_check("inside, both are blocked out (health %.0f) and no dust is drawn" % _gs.health,
		is_equal_approx(_gs.health, before) and not (_hz.get("_dust") as CPUParticles2D).emitting)
	_hz.rad_left = _hz.storm_left + Config.STORM_CLEAR       # radiation lasts longer than the storm here
	_step(_hz.storm_left + Config.STORM_CLEAR * 0.5, true)
	_check("the storm clears while radiation is still active: still locked ('%s')" % _hz.danger_text(),
		_hz.storm == "clearing" and _hz.radiation == "active" and not _hz.is_safe())
	_step(_hz.rad_left + 0.2, true)
	_check("both over: safe to exit", _hz.is_safe() and _heard("Environmental conditions are safe."))
	_step(Config.STORM_CLEAR, true)
	_check("the storm settles completely: 'The dust storm has passed.'", _hz.storm == "" and _hz.intensity == 0.0
		and _heard("The dust storm has passed."))
	_player().position = (current_scene.get_node("Entities/Door") as Node2D).position + Vector2(0, -22)
	await _wait(0.6)
	_hand().use()
	_check("and out again", await _until(func() -> bool: return _in_scene(Config.WORLD_SCENE)))

	# --- deaths: each cause has its own reason and ending animation ---
	_gs.set_process(true)
	_gs.damage(_gs.health, true, "radiation")
	await process_frame
	var endings: Node = current_scene.get_node("UI/HUD/Endings")
	var panel: Control = current_scene.get_node("UI/HUD/GameOver")
	_check("killed by radiation: '%s', the radiation ending plays first, no panel yet" % _gs.game_over_reason,
		_gs.game_over and _gs.death_cause == "radiation" and _gs.game_over_reason == "Killed by radiation" and not panel.visible)
	await _until(func() -> bool: return endings.finished, 10.0)
	await _shot("death_radiation.png")
	_check("after the animation the game-over panel shows", panel.visible and _player().modulate.a < 0.1)
	var reasons := {"hunger": "Starved - you ran out of food", "storm": "Lost in the dust storm"}
	var ok := true
	for cause: String in reasons:
		_gs.reset()
		_gs.damage(_gs.health, true, cause)
		ok = ok and _gs.death_cause == cause and _gs.game_over_reason == reasons[cause]
	_check("starving and the dust storm have their own reasons and endings", ok)
	_gs.set_process(false)
	_hz.trigger("storm")
	_gs.reset()
	paused = false
	_check("a new game: calm weather, fresh timers, not in the shelter, full health",
		_hz.radiation == "" and _hz.storm == "" and _hz.intensity == 0.0 and is_equal_approx(_hz.next_radiation, Config.RADIATION_FIRST)
		and is_equal_approx(_hz.next_storm, Config.STORM_FIRST) and not _gs.in_shelter and is_equal_approx(_gs.health, Config.HEALTH_MAX)
		and _gs.meals == 0)
	for n in [_gs, _hz, _guide]:
		n.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _start_twice() -> bool:
	var left: float = _hz.rad_left
	_hz.trigger("radiation")
	return _hz.radiation == "warning" and is_equal_approx(_hz.rad_left, left)


## The first build pad without a machine.
func _pad_free() -> Node2D:
	for p in get_nodes_in_group("build_pads"):
		if not _gs.machines.has(p.get("pad_id")):
			return p
	return null


func _shelter() -> Node2D:
	for m in get_nodes_in_group("machines"):
		if m.get("machine_id") == "shelter":
			return m
	return null
