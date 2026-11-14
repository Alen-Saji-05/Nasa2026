extends Node
## Survival hints (autoload "Guide"). Watches the game and, once each, lets the
## astronaut notice a problem and points at the fix: a HUD bar or the wreck is
## highlighted, and the Build Book icon bounces and opens on the right page.
## Lines live in dialogue.gd (LINES), "seen" in GameState.story_seen.
## At most one hint at a time, and only while the dialogue box is free.

const CHECK_EVERY := 0.5

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= CHECK_EVERY:
		_time = 0.0
		check()


## Gives the most urgent hint that is due (if any). Returns its key or "".
func check() -> String:
	var scene := get_tree().current_scene
	if GameState.game_over or Travel.busy or scene == null or scene.scene_file_path == Config.TITLE_SCENE \
			or Dialogue.is_showing():
		return ""
	var gs := GameState
	var t := gs.sol_elapsed_seconds
	var rules := [
		# Food: first hungry, then "I need to grow food".
		[gs.meals == 0 and gs.health < Config.HUNGER_HINT_1, "hunger_1", ["health"]],
		[gs.meals == 0 and gs.health < Config.HUNGER_HINT_1 and gs.item_count("potato") == 0, "food_wreck", ["wreck"]],
		[gs.meals == 0 and gs.health < Config.HUNGER_HINT_1 and gs.item_count("potato") > 0, "food_eat", ["health"]],
		[gs.meals > 0 and gs.health < Config.HUNGER_HINT_2 and not gs.has_built("greenhouse"), "hunger_2", ["health"]],
		[gs.meals > 0 and gs.health < Config.HUNGER_HINT_2 and not gs.has_built("greenhouse"), "food_grow", ["book:greenhouse"]],
		# Air and water.
		[gs.oxygen < 70.0 and not gs.has_built("oxygen_gen"), "hint_oxygen", ["oxygen", "book:oxygen_gen"]],
		[gs.water < gs.water_limit * 0.4, "hint_water", ["water"]],
		# The first steps.
		[t > 25.0 and not gs.wreck_salvaged, "hint_wreck", ["wreck"]],
		[t > 35.0 and gs.discovered.has("iron") and not gs.has_built("ore_refinery"), "hint_refinery", ["book:ore_refinery"]],
		# Power.
		[gs.has_built("ore_refinery") and gs.machine_count("solar") == 0 and gs.battery_charge < gs.battery_capacity() * 0.35,
			"hint_power", ["power", "book:solar"]],
		[gs.machine_count("solar") > 0 and gs.machine_count("battery") == 0 and gs.sun < 0.1 and gs.battery_charge < gs.battery_capacity() * 0.4,
			"hint_battery", ["power", "book:battery"]],
		# Growing the base.
		[gs.has_built("oxygen_gen") and gs.water >= gs.water_limit - 1.0 and not gs.has_built("reservoir"), "hint_reservoir", ["water", "book:reservoir"]],
		[gs.has_built("oxygen_gen") and gs.has_built("greenhouse") and not gs.has_built("co2_capture"), "hint_co2", ["book:co2_capture"]],
		[gs.has_built("oxygen_gen") and gs.has_built("greenhouse") and gs.installed.is_empty() and gs.modules_ready.is_empty(),
			"hint_ship", ["wreck", "book:power_station"]],
	]
	for rule: Array in rules:
		if rule[0] and not gs.story_seen.has(rule[1]):
			Dialogue.once(rule[1], true)
			for target: String in rule[2]:
				gs.highlight.emit(target)
			return rule[1]
	return ""
