extends SceneTree
## Automated check of the base machines, power and production. Run:
##   godot --headless --path . --script res://tools/test_machines.gd   [-- C:/screenshot/folder]
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
## (Class names like Machine are not used here: that would compile those scripts
## before the autoloads exist.)

var _failed := 0
var _gs: Node
var _builder: Node
var _travel: Node
var _shots := ""
var _messages: Array[String] = []


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_builder = root.get_node("Builder")
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


func _pad(pad_id: String) -> Node2D:
	for p in get_nodes_in_group("build_pads"):
		if p.get("pad_id") == pad_id:
			return p
	return null


func _machine_on(pad_id: String) -> Node2D:
	for m in get_nodes_in_group("machines"):
		if m.get("pad_id") == pad_id:
			return m
	return null


func _player() -> CharacterBody2D:
	return current_scene.get_node("Entities/Player")


func _step(seconds: float) -> void:
	for i in int(seconds * 10.0):
		_gs._process(0.1)


func _set_time(night: bool) -> void:
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * (0.75 if night else 0.2)
	_gs._process(0.0)


func _build(machine_id: String, pad_id: String) -> Node2D:
	if not _builder.start_placing(machine_id):
		return null
	return _builder.place_on(_pad(pad_id))


func _last() -> String:
	return _messages.back() if not _messages.is_empty() else ""


func _run() -> void:
	_gs.reset()
	_gs.set_process(false)
	_gs.message.connect(func(text: String) -> void: _messages.append(text))
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	var hand: Node = _player().get_node("Harvester")

	# --- the wreck ---
	var ship: Node2D = current_scene.get_node("Entities/BrokenRocket")
	_player().global_position = ship.global_position + Vector2(0, 14)
	await _wait(0.15)
	_check("next to the wreck, E points at it", hand.focus() == ship)
	hand.use()
	_check("E on the wreck salvages the power cell (storage %d, full) and %d potatoes" % [_gs.battery_capacity(), _gs.item_count("potato")],
		is_equal_approx(_gs.battery_capacity(), Config.HAB_BATTERY_CAPACITY + Config.POWER_CELL_BONUS)
		and is_equal_approx(_gs.battery_charge, _gs.battery_capacity()) and _gs.item_count("potato") == Config.WRECK_POTATOES)
	await _wait(0.5)
	hand.use()
	_check("only once: after that it shows the repair progress ('%s')" % _last(), _last() == "Ship repair: 0 / 6 systems installed"
		and _gs.item_count("potato") == Config.WRECK_POTATOES)

	# --- the Ore Refinery: built from raw ore, placed with E ---
	_check("the refinery cannot be placed without ore: '%s'" % _builder.build_problem("ore_refinery"),
		_builder.build_problem("ore_refinery") == "Need 4 Iron Ore (you have 0), 4 Aluminum Ore (you have 0)")
	_gs.add_item("iron", 6)
	_gs.add_item("aluminum", 4)
	_check("start placing the refinery", _builder.start_placing("ore_refinery"))
	_player().global_position = _pad("pad_01").global_position + Vector2(-26, 0)
	await _wait(0.6)
	_check("next to a lit pad, E points at the pad", hand.focus() == _pad("pad_01"))
	hand.use()
	await _wait(0.1)
	var refinery := _machine_on("pad_01")
	_check("E builds it and takes exactly 4 iron + 4 aluminum ore", refinery != null and _gs.item_count("iron") == 2 and _gs.item_count("aluminum") == 0)
	_check("only one refinery: '%s'" % _builder.build_problem("ore_refinery"), _builder.build_problem("ore_refinery") == "Already built")

	_gs.add_item("sulfur", 2)
	_player().global_position = refinery.global_position + Vector2(0, 16)
	await _wait(0.6)
	hand.use()
	var panel: Control = current_scene.get_node("UI/HUD/RefineryPanel")
	_check("E opens the refinery panel, every carried ore ticked with all of it", panel.visible
		and panel.selection() == {"iron": 2, "sulfur": 2})
	panel.set_picked("sulfur", false)
	panel.change("iron", -1)
	_check("untick an ore and use - / +: %s" % panel.selection(), panel.selection() == {"iron": 1})
	var typed: LineEdit = panel.get_node("Panel").find_child("Amount", true, false)
	typed.text = "7"
	typed.text_changed.emit("7")
	_check("the amount can be typed in too, and is kept to what you carry: '%s'" % typed.text,
		typed.text == "2" and panel.selection().get("iron", 0) == 2)
	typed.text = "1"
	typed.text_changed.emit("1")
	panel.change("iron", 5)
	panel.change("sulfur", 1)
	_check("+ never goes above what you carry, and ticks the ore: %s" % panel.selection(),
		panel.selection() == {"iron": 2, "sulfur": 2})
	panel.start()
	await _wait(0.05)
	var clock_label: Label = refinery.get_node("Clock/Time")
	_check("START loads only the choice; the clock counts down from %s" % clock_label.text,
		_gs.refinery_left() == 4 and _gs.item_count("iron") == 0 and _gs.item_count("sulfur") == 0
		and _gs.refinery_seconds_left() > Config.REFINE_SECONDS * 4.0 - 0.5 and clock_label.text == "0:08"
		and refinery.get_node("Clock").visible)
	panel.close()
	_set_time(true)
	_gs.battery_charge = 0.0
	_step(3.0)
	_check("at night with no power it waits", not _gs.refinery_working() and _gs.refinery_left() == 4)
	_set_time(false)
	_gs.battery_charge = 30.0
	_step(Config.REFINE_SECONDS * 4.0 + 0.2)
	await _wait(0.05)
	_check("with power it refines one ore every %.0f s" % Config.REFINE_SECONDS,
		_gs.refinery_left() == 0 and _gs.machine_output.get("iron_ingot", 0) == 2 and _gs.machine_output.get("sulfur_compound", 0) == 2)
	_check("when done: READY! above it, sparkles, '%s'" % _last(), clock_label.text == "READY!" and _gs.refinery_ready()
		and (refinery.get_node("Sparks") as CPUParticles2D).emitting and _last().contains("ready"))
	await _wait(0.5)
	hand.use()
	await _wait(0.05)
	await _shot("refinery_panel.png")
	panel.collect()
	_check("E + COLLECT takes the ingots: '%s'" % _last(), _gs.item_count("iron_ingot") == 2 and _gs.item_count("sulfur_compound") == 2
		and not _gs.refinery_ready())
	panel.close()

	# --- power: solar and battery ---
	for id: String in ["iron_ingot", "aluminum_ingot", "sulfur_compound", "electronics", "wire"]:
		_gs.add_item(id, 20)
	var solar := _build("solar", "pad_02")
	_set_time(false)
	_step(1.0)
	await _wait(0.05)
	var solar_sprite: AnimatedSprite2D = solar.get_node("Sprite")
	_check("a Solar Panel makes %.1f power in the sun and plays its loop" % _gs.power_made,
		is_equal_approx(_gs.power_made, Config.SOLAR_OUTPUT) and solar_sprite.animation == "running")
	_set_time(true)
	await _wait(0.05)
	_check("at night it shows the idle frame", solar_sprite.animation == "idle")
	var cap: float = _gs.battery_capacity()
	var battery := _build("battery", "pad_03")
	_check("a Battery uses a Wire and adds %d storage" % Config.BATTERY_CAPACITY_BONUS,
		battery != null and is_equal_approx(_gs.battery_capacity(), cap + Config.BATTERY_CAPACITY_BONUS) and _gs.item_count("wire") == 19)
	_gs.battery_charge = 0.0
	await _wait(0.05)
	_check("the battery picture follows the charge (empty frame %d)" % (battery.get_node("Sprite") as AnimatedSprite2D).frame,
		(battery.get_node("Sprite") as AnimatedSprite2D).frame == 0)

	# --- oxygen generator ---
	var o2gen := _build("oxygen_gen", "pad_04")
	_gs.consume_oxygen(20.0)
	_gs.battery_charge = 10.0
	_step(0.5)
	await _wait(0.05)
	_check("the Oxygen Generator runs on the battery at night", _gs.o2_generator_working())
	_gs.battery_charge = 0.0
	_step(0.2)
	await _wait(0.05)
	_check("no power: it stops and shows the warning icon", not _gs.o2_generator_working() and o2gen.get_node("Warning").visible)
	_check("now Oxygen Capsules can be crafted: 2 water -> 1 oxygen",
		_builder.build_problem("oxygen") == "" and _builder.craft("oxygen") and _gs.item_count("oxygen") == 1)

	# --- reservoir and CO2 capture ---
	var limit: float = _gs.water_limit
	_build("reservoir", "pad_05")
	_check("the Water Reservoir raises the water limit by %d" % Config.WATER_TANK_LIMIT_BONUS,
		is_equal_approx(_gs.water_limit - limit, Config.WATER_TANK_LIMIT_BONUS))
	_check("Methane needs the CO2 Capture Machine first: '%s'" % _builder.build_problem("methane"),
		_builder.build_problem("methane") == "Needs a CO2 Capture Machine first")
	var co2 := _build("co2_capture", "pad_06")
	_set_time(false)
	_gs.battery_charge = 30.0
	_step(Config.CO2_CAPTURE_SECONDS + 0.5)
	_player().global_position = co2.global_position + Vector2(0, 16)
	await _wait(0.6)
	hand.use()
	_check("the CO2 Capture Machine captures 1 capsule in %d s; E collects it" % Config.CO2_CAPTURE_SECONDS, _gs.item_count("co2") == 1)
	_gs.add_water(10.0)
	_check("Methane: 1 CO2 + 2 water -> 1 methane", _builder.craft("methane") and _gs.item_count("methane") == 1 and _gs.item_count("co2") == 0)
	await _wait(0.4)
	await _shot("base_with_machines.png")

	# --- everything survives a cave trip ---
	var count: int = get_nodes_in_group("machines").size()
	_gs.set_process(true)
	_travel.enter_cave("ice")
	await _until(func() -> bool: return current_scene.scene_file_path == Config.CAVE_SCENE)
	_check("no machines in a cave: '%s'" % _builder.build_problem("solar"), _builder.build_problem("solar") == "Machines are built at the base")
	_travel.exit_cave()
	await _until(func() -> bool: return current_scene.scene_file_path == Config.WORLD_SCENE)
	await _wait(0.3)
	_gs.set_process(false)
	_check("back on the surface all %d machines are there and nothing counted twice" % count,
		get_nodes_in_group("machines").size() == count and is_equal_approx(_gs.water_limit - limit, Config.WATER_TANK_LIMIT_BONUS))

	_gs.reset()
	_check("a new game has no machines, outputs or salvage", _gs.machines.is_empty() and _gs.machine_output.is_empty()
		and not _gs.wreck_salvaged and is_equal_approx(_gs.battery_capacity(), Config.HAB_BATTERY_CAPACITY))
	_gs.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
