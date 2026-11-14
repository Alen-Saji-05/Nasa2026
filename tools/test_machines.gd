extends SceneTree
## Automated check of the machines. Run from the project folder:
##   godot --headless --path . --script res://tools/test_machines.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.
##
## With a screenshot folder it also saves pictures (needs a window, so no --headless):
##   godot --path . --script res://tools/test_machines.gd -- C:/some/folder
##
## Note: class names like Machine or BuildPad are not used here on purpose:
## that would compile those scripts before the autoloads exist.

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


## Steps the game clock by hand (GameState's own _process is switched off).
func _step(seconds: float) -> void:
	for i in int(seconds * 10.0):
		_gs._process(0.1)


## Places a machine through the Builder, like a player who picked a pad.
func _build(machine_id: String, pad_id: String) -> Node2D:
	if not _builder.start_placing(machine_id):
		return null
	return _builder.place_on(_pad(pad_id))


func _run() -> void:
	_check_config()

	_gs.reset()
	_gs.set_process(false)
	_gs.message.connect(func(text: String) -> void: _messages.append(text))
	change_scene_to_file(Config.WORLD_SCENE)
	await _wait(0.5)
	var interactor: Node = _player().get_node("Harvester")

	# --- placing with E ---
	_check("start: 30 metal, no machines, the hab battery is full (%d/%d)" % [_gs.battery_charge, _gs.battery_capacity()],
		_gs.metal == 30 and _gs.machines.is_empty() and is_equal_approx(_gs.battery_charge, Config.HAB_BATTERY_CAPACITY))
	_check("with no placing, a free pad does not take E", interactor.focus() == null or not interactor.focus().is_in_group("build_pads"))
	_check("start placing a Solar Panel", _builder.start_placing("solar"))
	await _wait(0.05)
	var lit := 0
	for p in get_nodes_in_group("build_pads"):
		if p.modulate.is_equal_approx(Color(0.65, 1.0, 0.6)):
			lit += 1
	_check("the %d machine pads light up, the launch pad does not (%d lit)" % [Config.BUILD_PAD_COUNT, lit],
		lit == Config.BUILD_PAD_COUNT and not _pad("launch").modulate.is_equal_approx(Color(0.65, 1.0, 0.6)))
	var pad1 := _pad("pad_01")
	# Beside it on the left: the pads above and below are farther away.
	_player().global_position = pad1.global_position + Vector2(-26, 0)
	await _wait(0.1)
	_check("next to a lit pad, E points at the pad", interactor.focus() == pad1)
	interactor.use()
	await _wait(0.1)
	var solar := _machine_on("pad_01")
	_check("E builds it: metal 30 -> %d, machine on pad_01, placing stops" % _gs.metal,
		solar != null and _gs.metal == 15 and _gs.machines.get("pad_01") == "solar" and _builder.placing == ""
		and pad1.modulate.is_equal_approx(Color.WHITE))
	_check("the first one says '%s'" % (_messages.back() if not _messages.is_empty() else ""),
		not _messages.is_empty() and _messages.back() == "Solar Panel built!")
	_check("the machine is solid (it has a collision box)", solar != null and solar.get_node("CollisionShape2D").shape is RectangleShape2D)

	# --- costs ---
	_messages.clear()
	_check("cannot place an Oxygen Generator with 15 metal", not _builder.start_placing("o2_generator"))
	_check("... and it says why: '%s'" % (_messages.back() if not _messages.is_empty() else ""),
		not _messages.is_empty() and _messages.back() == "Need 25 metal (you have 15)")
	_check("nothing is paid for a failed try (metal %d)" % _gs.metal, _gs.metal == 15 and _builder.placing == "")

	# --- Esc cancels ---
	_builder.start_placing("battery")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(0.1)
	_check("Esc cancels placing and pays nothing", _builder.placing == "" and _gs.metal == 15)

	# --- solar look: sun on = running loop, sun off = idle frame ---
	var solar_sprite: AnimatedSprite2D = solar.get_node("Sprite")
	_check("in the sun the solar panel plays its 4-frame loop", solar_sprite.animation == "running" and solar_sprite.is_playing()
		and solar_sprite.sprite_frames.get_frame_count("running") == 4)
	_step(1.0)
	_check("one panel in full sun makes %.1f power" % _gs.power_made, is_equal_approx(_gs.power_made, Config.SOLAR_OUTPUT))
	_gs.sun = 0.0
	await _wait(0.05)
	_check("without sun it shows the idle frame", solar_sprite.animation == "idle")

	# --- the rest of the machines ---
	_gs.add_metal(200)
	var battery := _build("battery", "pad_02")
	var o2gen := _build("o2_generator", "pad_03")
	_check("Battery and Oxygen Generator built (metal %d)" % _gs.metal, battery != null and o2gen != null and _gs.metal == 15 + 200 - 10 - 25)
	_check("a battery adds %d storage (now %d)" % [Config.BATTERY_CAPACITY_BONUS, _gs.battery_capacity()],
		is_equal_approx(_gs.battery_capacity(), Config.HAB_BATTERY_CAPACITY + Config.BATTERY_CAPACITY_BONUS))
	var battery_sprite: AnimatedSprite2D = battery.get_node("Sprite")
	_gs.battery_charge = _gs.battery_capacity()
	await _wait(0.05)
	var full_frame := battery_sprite.frame
	_gs.battery_charge = 0.0
	await _wait(0.05)
	var empty_frame := battery_sprite.frame
	_gs.battery_charge = _gs.battery_capacity() * 0.4
	await _wait(0.05)
	_check("the battery picture follows the charge (full %d, empty %d, 40%% -> %d)" % [full_frame, empty_frame, battery_sprite.frame],
		full_frame == 3 and empty_frame == 0 and battery_sprite.frame == 2)

	# --- O2 generator: runs with power, stops without, warning icon ---
	_gs.consume_oxygen(20.0)                      # below 95: it wants to run
	_gs.battery_charge = 10.0
	_step(0.5)
	await _wait(0.05)
	var o2_sprite: AnimatedSprite2D = o2gen.get_node("Sprite")
	_check("O2 below 95 at night: the generator runs on the battery (%.1f left)" % _gs.battery_charge,
		_gs.o2_generator_working() and o2_sprite.animation == "running" and _gs.battery_charge < 10.0)
	_gs.battery_charge = 0.0
	_step(0.2)
	await _wait(0.05)
	_check("battery empty and no sun: it stops ('%s') and shows the warning icon" % _gs.o2_generator_problem(),
		not _gs.o2_generator_working() and _gs.o2_generator_problem() == "no power"
		and o2gen.get_node("Warning").visible and o2_sprite.animation == "idle")
	var o2_before: float = _gs.oxygen
	_step(1.0)
	_check("... and oxygen only goes down (%.2f -> %.2f)" % [o2_before, _gs.oxygen], _gs.oxygen < o2_before)
	_messages.clear()
	_player().global_position = o2gen.global_position + Vector2(0, 16)
	await _wait(0.1)
	interactor.use()
	_check("E on the machine tells what it does: '%s'" % (_messages.back() if not _messages.is_empty() else ""),
		not _messages.is_empty() and _messages.back() == "Oxygen Generator: stopped, no power")

	var backup := _build("backup_power", "pad_04")
	_step(1.0)
	await _wait(0.05)
	_check("Backup Power keeps it running at night (made %.1f, used %.1f)" % [_gs.power_made, _gs.power_used],
		backup != null and _gs.o2_generator_working() and is_equal_approx(_gs.power_made, Config.BACKUP_OUTPUT)
		and is_equal_approx(_gs.power_used, Config.O2_GEN_POWER_USE) and not o2gen.get_node("Warning").visible)
	_check("backup power always plays its running loop", (backup.get_node("Sprite") as AnimatedSprite2D).animation == "running")

	var tank := _build("water_tank", "pad_05")
	_check("a Water Tank raises the water limit to %d" % _gs.water_limit,
		tank != null and is_equal_approx(_gs.water_limit, Config.WATER_BASE_LIMIT + Config.WATER_TANK_LIMIT_BONUS))
	var tank_sprite: AnimatedSprite2D = tank.get_node("Sprite")
	await _wait(0.05)
	_check("the tank picture shows how full the water is (frame %d)" % tank_sprite.frame, tank_sprite.animation == "levels")

	# --- the ascent vehicle only fits the launch pad ---
	_gs.sun = 1.0
	await _wait(0.4)
	await _shot("base_with_machines.png")
	_check("the Ascent Vehicle fits the launch pad and no machine pad",
		_pad("launch").fits("ascent") and not _pad("pad_06").fits("ascent") and not _pad("launch").fits("solar"))

	# --- back from a cave: everything is still there, nothing is applied twice ---
	var count_before: int = get_nodes_in_group("machines").size()
	_gs.set_process(true)
	_travel.enter_cave("ice")
	var in_cave := await _until(func() -> bool: return current_scene.scene_file_path == Config.CAVE_SCENE)
	_check("can still go into a cave", in_cave)
	_messages.clear()
	_check("no building in a cave: '%s'" % _builder.build_problem("solar"), _builder.build_problem("solar") == "Machines are built at the base")
	_travel.exit_cave()
	var back := await _until(func() -> bool: return current_scene.scene_file_path == Config.WORLD_SCENE)
	await _wait(0.3)
	_gs.set_process(false)
	_check("back on the surface all %d machines stand on their pads again" % count_before,
		back and get_nodes_in_group("machines").size() == count_before and _machine_on("pad_05") != null
		and not _pad("pad_05").is_free())
	_check("the water limit is still %d (the tank did not count twice)" % _gs.water_limit,
		is_equal_approx(_gs.water_limit, Config.WATER_BASE_LIMIT + Config.WATER_TANK_LIMIT_BONUS))

	# --- launch ---
	_gs.add_metal(100)
	_gs.add_water(60.0)
	var rocket := _build("ascent", "launch")
	_check("Ascent Vehicle built on the launch pad: the countdown starts", rocket != null and paused)
	var start_y := rocket.position.y if rocket != null else 0.0
	await _wait(3.6)
	await _shot("launch.png")
	var won := await _until(func() -> bool: return _gs.game_won, 6.0)
	_check("after the countdown the rocket climbs (%.0f px) and the game is won" % (start_y - rocket.position.y),
		won and _gs.game_over and start_y - rocket.position.y > 200.0)
	var panel := current_scene.get_node("UI/HUD/GameOver") as Control
	_check("the end panel says '%s'" % (panel.get_node("Label") as Label).text.get_slice("\n", 0),
		panel.visible and (panel.get_node("Label") as Label).text.begins_with("Launch successful"))
	await _wait(0.2)
	await _shot("won.png")

	# --- a new game has no machines ---
	_gs.reset()
	paused = false
	_check("a new game has no machines, an empty water tank bonus and a full hab battery",
		_gs.machines.is_empty() and is_equal_approx(_gs.water_limit, Config.WATER_BASE_LIMIT)
		and is_equal_approx(_gs.battery_capacity(), Config.HAB_BATTERY_CAPACITY) and not _gs.game_won)

	_gs.set_process(true)
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check_config() -> void:
	var expected := {"solar": [15, 0], "battery": [10, 0], "o2_generator": [25, 0], "backup_power": [60, 0],
		"water_tank": [20, 0], "ascent": [80, 40]}
	var costs_ok := true
	var art_ok := true
	var text_ok := true
	for id: String in Config.MACHINE_ORDER:
		var def := Config.machine(id)
		if def.is_empty() or [def.metal, def.water] != expected.get(id, []):
			costs_ok = false
			continue
		for anim: String in ["idle", "running", "levels"]:
			for path: String in def.get(anim, []):
				if not ResourceLoader.exists(path):
					art_ok = false
		for key: String in ["name", "description", "how", "nasa"]:
			if str(def.get(key, "")) == "":
				text_ok = false
	_check("6 machines with the GAME_FLOW costs %s" % str(Config.MACHINE_ORDER),
		Config.MACHINE_ORDER.size() == 6 and costs_ok)
	_check("every machine's art exists", art_ok)
	_check("every machine has a name, description, how-it-works and NASA text", text_ok)
