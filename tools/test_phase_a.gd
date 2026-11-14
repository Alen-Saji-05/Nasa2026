extends SceneTree
## Automated check of the resource rules. Run from the project folder:
##   godot --headless --path . --script res://tools/test_phase_a.gd
## Prints PASS / FAIL lines and exits with code 1 if anything failed.

var _failed := 0
var _gs: Node
# Loaded at run time: scripts that use the GameState autoload cannot be compiled
# before the autoloads exist, and this script is compiled first.
var _node_script: GDScript


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_gs.set_process(false)          # we step time by hand
	_node_script = load("res://scripts/resource_node.gd")
	_run()
	print("RESULT: %s" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _run() -> void:
	# --- start values ---
	_check("start O2 100, water 50/60, metal 30",
		_near(_gs.oxygen, 100) and _near(_gs.water, 50) and _near(_gs.water_limit, 60) and _gs.metal == 30)

	# --- drain: one sol (15 s) costs 6 O2 and 6 water ---
	for i in 150:
		_gs._process(0.1)
	_check("one sol drains 6 O2 (now %.2f)" % _gs.oxygen, _near(_gs.oxygen, 94))
	_check("one sol drains 6 water (now %.2f)" % _gs.water, _near(_gs.water, 44))

	# --- metal node ---
	_gs.reset()
	var metal_node: Sprite2D = _node_script.new()
	metal_node.kind = "metal"
	root.add_child(metal_node)
	var text: String = metal_node.harvest()
	_check("metal harvest: +8 metal, -1 O2, text '%s'" % text,
		_gs.metal == 38 and _near(_gs.oxygen, 99) and text == "+8 metal" and metal_node.charges_left == 4)
	for i in 4:
		metal_node.harvest()
	_check("metal node empty after 5 uses, shows depleted art",
		metal_node.is_empty() and metal_node.texture == _node_script.TEX_DEPLETED["metal"])
	var before: int = _gs.metal
	_check("empty node gives nothing", metal_node.harvest() == "" and _gs.metal == before)

	# --- ice node ---
	_gs.reset()
	var ice: Sprite2D = _node_script.new()
	ice.kind = "ice"
	root.add_child(ice)
	text = ice.harvest()
	_check("ice harvest: +6 water, -1 O2, text '%s'" % text,
		_near(_gs.water, 56) and _near(_gs.oxygen, 99) and text == "+6 water")
	text = ice.harvest()
	_check("nearly full: only the free space is added (text '%s')" % text,
		_near(_gs.water, 60) and text == "+4 water" and ice.charges_left == 3)
	var o2_before: float = _gs.oxygen
	var messages: Array = []
	_gs.message.connect(func(t): messages.append(t))
	text = ice.harvest()
	_check("full: blocked, no O2 spent, charge kept, message '%s'" % str(messages),
		text == "" and _near(_gs.oxygen, o2_before) and ice.charges_left == 3
		and messages == ["Water full, build a tank"])
	_gs.add_water_limit(Config.WATER_TANK_LIMIT_BONUS)
	_check("water tank raises the limit to 100", _near(_gs.water_limit, 100) and ice.harvest() == "+6 water")

	# --- low oxygen blocks harvesting ---
	_gs.reset()
	_gs.consume_oxygen(99.5)
	var fresh: Sprite2D = _node_script.new()
	root.add_child(fresh)
	_check("O2 below 1 blocks harvest", fresh.harvest() == "" and fresh.charges_left == 5)

	# --- metal spending and limit ---
	_gs.reset()
	_check("cannot spend more metal than you have", not _gs.spend_metal(31) and _gs.metal == 30)
	_check("spend works", _gs.spend_metal(20) and _gs.metal == 10)
	_gs.add_metal(5000)
	_check("metal capped at 999", _gs.metal == 999)

	# --- lose timers ---
	_gs.reset()
	var reasons: Array = []
	_gs.game_ended.connect(func(r): reasons.append(r))
	_gs.consume_oxygen(100)
	for i in 30:
		_gs._process(0.1)           # 3 s at zero
	_gs.add_oxygen(5)
	_gs._process(0.1)
	_check("O2 timer resets when oxygen comes back", _near(_gs.zero_oxygen_time, 0) and not _gs.game_over)
	_gs.consume_oxygen(100)
	for i in 59:
		_gs._process(0.1)
	_check("still alive at 5.9 s without oxygen", not _gs.game_over)
	for i in 2:
		_gs._process(0.1)
	_check("game over after 6 s: %s" % str(reasons), _gs.game_over and reasons == ["Out of oxygen"])

	_gs.reset()
	reasons.clear()
	_gs.consume_water(100)
	for i in 61:
		_gs._process(0.1)
	_check("water at 0 for 6 s: %s" % str(reasons), _gs.game_over and reasons == ["Out of water"])

	# --- O2 generator hook ---
	_gs.reset()
	_gs.consume_oxygen(20)
	_gs.o2_generator_built = true
	var o2: float = _gs.oxygen
	var w: float = _gs.water
	_gs._process(1.0)
	_check("O2 generator: +0.45 O2/s and -0.15 water/s on top of the drain",
		_near(_gs.oxygen, o2 + 0.45 - 0.4) and _near(_gs.water, w - 0.15 - 0.4))
	_gs.reset()
