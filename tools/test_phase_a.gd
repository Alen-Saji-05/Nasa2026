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

	# --- drain: one sol costs O2_DRAIN_PER_SOL oxygen and WATER_DRAIN_PER_SOL water ---
	for i in int(Config.SOL_SECONDS * 10.0):
		_gs._process(0.1)
	_check("one sol drains %d O2 (now %.2f)" % [Config.O2_DRAIN_PER_SOL, _gs.oxygen], _near(_gs.oxygen, 100.0 - Config.O2_DRAIN_PER_SOL))
	_check("one sol drains %d water (now %.2f)" % [Config.WATER_DRAIN_PER_SOL, _gs.water], _near(_gs.water, 50.0 - Config.WATER_DRAIN_PER_SOL))
	_check("a sol is 60 seconds", _near(Config.SOL_SECONDS, 60.0))

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
		_near(_gs.oxygen, o2 + Config.O2_GEN_RATE - Config.O2_DRAIN_PER_SEC) and _near(_gs.water, w - 0.15 - Config.WATER_DRAIN_PER_SEC))
	_gs.reset()

	# --- inventory ---
	_gs.add_item("iron", 3)
	_gs.add_item("iron", 3)
	_gs.add_item("sulfur", 2)
	_check("items add up: 6 iron, 2 sulfur, 0 aluminum",
		_gs.item_count("iron") == 6 and _gs.item_count("sulfur") == 2 and _gs.item_count("aluminum") == 0)
	_check("cannot spend what you do not have, and nothing is taken",
		not _gs.spend_items({"iron": 2, "aluminum": 1}) and _gs.item_count("iron") == 6)
	_check("spending takes the items", _gs.spend_items({"iron": 5, "sulfur": 2}) and _gs.item_count("iron") == 1 and _gs.item_count("sulfur") == 0)
	var ore = _node_script.new()
	ore.kind = "aluminum"
	root.add_child(ore)
	var ore_o2: float = _gs.oxygen
	_check("an aluminum deposit gives '%s' and costs 1 O2" % ore.harvest(),
		_gs.item_count("aluminum") == Config.item("aluminum").per_harvest and _near(_gs.oxygen, ore_o2 - Config.O2_HARVEST_COST))
	for i in Config.NODE_CHARGES - 1:
		ore.harvest()
	_check("after %d uses the ore deposit is empty and greyed out" % Config.NODE_CHARGES,
		ore.is_empty() and ore.harvest() == "" and ore.modulate.r < 0.6)
	ore.free()
	_gs.reset()
	_check("a new game has an empty inventory and no lamp yet", _gs.inventory.is_empty() and not _gs.lamp_found)

	# --- sols, night and the 30-sol deadline ---
	_check("a new game starts on sol 1 of %d" % Config.TOTAL_SOLS, _gs.sol_number == 1 and Config.TOTAL_SOLS == 30)
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 6.3
	_gs._process(0.0)
	_check("after 6.3 sols it is sol 7, daytime (sun %.1f)" % _gs.sun, _gs.sol_number == 7 and _near(_gs.sun, 1.0))
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 6.8
	_gs._process(0.0)
	_check("later the same sol it is night (sun %.1f)" % _gs.sun, _gs.sol_number == 7 and _near(_gs.sun, 0.0))
	_gs.sol_elapsed_seconds = Config.SOL_SECONDS * 29.9
	_gs._process(0.0)
	_check("sol 30 is still playable", _gs.sol_number == 30 and not _gs.game_over)
	reasons.clear()
	_gs._process(Config.SOL_SECONDS * 0.2)
	_check("when sol 30 ends the game is lost: %s" % str(reasons), _gs.game_over and reasons == ["Return window closed"] and not _gs.game_won)
	_check("walking over craters costs no oxygen (penalty %d)" % Config.CRATER_O2_PENALTY, Config.CRATER_O2_PENALTY == 0.0)
	_gs.reset()
