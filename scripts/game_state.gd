extends Node
## Shared game state (autoload "GameState"): oxygen, water, health, inventory, machines.
##
## The HUD, the player and the machines only READ these values and call the
## methods below. Nobody keeps their own copy. All numbers live in config.gd.

signal oxygen_changed(value: float)
signal oxygen_depleted
signal water_changed(value: float, limit: float)
signal metal_changed(value: int)
## A short line for the player, for example why a harvest was blocked.
signal message(text: String)
## The game is lost. `reason` is "Out of oxygen" or "Out of water".
signal game_ended(reason: String)
## The player went somewhere else. `place` is "Surface" or for example "Ice Cave L2".
signal location_changed(place: String)
## A machine was built (or everything was reset).
signal machines_changed
## Something was added to or taken from the inventory.
signal inventory_changed
## Build Book recipes were just discovered (a list of machine ids).
signal recipes_unlocked(ids: Array)
## A ship module was built or installed, or the wreck was salvaged.
signal ship_changed
## Power made, power used or the battery changed.
signal power_changed
signal day_night_changed(sol: int, sun_level: float)
## Health went up or down. `hurt` is true for damage (the HUD flashes).
signal health_changed(value: float, hurt: bool)
## A hint points at something: "health", "oxygen", "water", "power", "wreck" or "book:<page id>".
signal highlight(target: String)
## Ice deposits refilled (resource_node.gd reloads its uses).
signal deposits_changed
## A fresh ice deposit appeared on the surface / a used-up one melted away (world_gen.gd).
signal ice_spawned(id: String)
signal ice_removed(id: String)

var sol_elapsed_seconds: float = 0.0
var sol_number: int = 1

var oxygen: float = Config.O2_START
var water: float = Config.WATER_START
var water_limit: float = Config.WATER_BASE_LIMIT
var metal: int = Config.METAL_START

## Health: hunger lowers it slowly, radiation and dust storms hurt. 0 = game over.
var health: float = Config.HEALTH_MAX
## How many potatoes the player has eaten (the hints use it).
var meals: int = 0
## True while the player is inside the Emergency Shelter (scenes/Shelter.tscn).
var in_shelter: bool = false
var _grow_time := 0.0
## Why the game ended, for the ending animation: "oxygen", "water", "hunger",
## "radiation", "storm", "time" or "won".
var death_cause: String = ""
## Ice: empty deposit id -> time it ran empty; fresh surface deposits id -> position.
var ice_empty_since: Dictionary = {}
var ice_spawns: Dictionary = {}
## Open surface spots where fresh ice can appear (world_gen.gd fills this).
var ice_spawn_spots: Array = []
var _ice_time := 0.0
var _ice_serial := 0

var zero_oxygen_time: float = 0.0
var zero_water_time: float = 0.0
var game_over: bool = false
var game_over_reason: String = ""

## Hooks for the O2 generator machine. The build menu sets `o2_generator_built`,
## the power system sets `o2_generator_powered`.
var o2_generator_built: bool = false
var o2_generator_powered: bool = true
var o2_generator_running: bool = false

# --- Where the player is (see travel.gd) ---
## "" on the surface, otherwise a cave id from Config.CAVES.
var cave_id: String = ""
## 0 = the first layer of the cave.
var cave_layer: int = 0
## How the player enters the scene that is loading: "" (new game),
## "from_surface", "ladder_down", "ladder_up" or "entrance:<cave id>".
var arrival: String = ""
## Uses left of every deposit that was harvested: deposit id -> charges.
## Deposits that are not in here are still full.
var node_charges: Dictionary = {}
## What the player carries: item id (see Config.ITEMS) -> how many.
var inventory: Dictionary = {}
## Every item id the player ever obtained. Recipes unlock from this and never lock again.
var discovered: Dictionary = {}
## Recipes discovered but not looked at in the book yet (their page shimmers once).
var new_recipes: Array[String] = []
## True after the first radiation event (unlocks the radiation recipes).
var radiation_seen: bool = false
## Ship repair: modules built in the book and waiting to be installed, and installed ones.
var modules_ready: Array[String] = []
var installed: Array[String] = []
var wreck_salvaged: bool = false
## Story lines already told (dialogue.gd).
var story_seen: Dictionary = {}
## Production: ore waiting in the refinery, and finished goods waiting in machines.
var refinery_queue: Dictionary = {}
var machine_output: Dictionary = {}          # item id -> count, collected with E
var _refine_time := 0.0
var _co2_time := 0.0
## The lamp from the wreck: switched on at the first nightfall.
var lamp_found: bool = false

# --- Machines and power (see builder.gd, machine.gd) ---
## Every machine that was built: build pad id -> machine id ("pad_03" -> "solar").
var machines: Dictionary = {}
## How bright the sun is, 0 to 1. Day/night and dust storms will change it later.
var sun: float = 1.0
var battery_charge: float = Config.HAB_BATTERY_CAPACITY
## Power per second, from the last frame.
var power_made: float = 0.0
var power_used: float = 0.0
## True after a successful launch.
var game_won: bool = false


func _process(delta: float) -> void:
	if game_over:
		return

	_update_day_night(delta)

	_run_power(delta)
	_run_production(delta)
	_run_o2_generator(delta)

	damage(Config.HUNGER_PER_SOL / Config.SOL_SECONDS * delta, false, "hunger")
	if game_over:
		return
	if oxygen > 0.0:
		oxygen = maxf(0.0, oxygen - Config.O2_DRAIN_PER_SEC * delta)
		oxygen_changed.emit(oxygen)
	if water > 0.0:
		water = maxf(0.0, water - Config.WATER_DRAIN_PER_SEC * delta)
		water_changed.emit(water, water_limit)

	# Lose timers. They start at zero again as soon as the value is above 0.
	if oxygen <= 0.0:
		zero_oxygen_time += delta
		if zero_oxygen_time >= Config.O2_ZERO_GRACE:
			oxygen_depleted.emit()
			death_cause = "oxygen"
			_end_game("Out of oxygen")
			return
	else:
		zero_oxygen_time = 0.0

	if water <= 0.0:
		zero_water_time += delta
		if zero_water_time >= Config.WATER_ZERO_GRACE:
			death_cause = "water"
			_end_game("Out of water")
	else:
		zero_water_time = 0.0


# --- Oxygen ---

func consume_oxygen(amount: float) -> void:
	if game_over:
		return
	oxygen = maxf(0.0, oxygen - amount)
	oxygen_changed.emit(oxygen)


func add_oxygen(amount: float) -> void:
	if game_over:
		return
	oxygen = minf(Config.O2_MAX, oxygen + amount)
	oxygen_changed.emit(oxygen)


# --- Health and food ---

## Takes health. `hurt` = a real hit (radiation, storm): the HUD flashes red.
func damage(amount: float, hurt: bool = true, cause: String = "radiation") -> void:
	if game_over or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, hurt)
	if health <= 0.0:
		death_cause = cause
		_end_game({"hunger": "Starved - you ran out of food", "storm": "Lost in the dust storm",
			"radiation": "Killed by radiation"}.get(cause, "Your health ran out"))


func heal(amount: float) -> void:
	if game_over:
		return
	health = minf(Config.HEALTH_MAX, health + amount)
	health_changed.emit(health, false)


## Eats one potato (F key). Returns false if there is none or health is full.
func eat_potato() -> bool:
	if game_over:
		return false
	if item_count("potato") <= 0:
		say("No potatoes to eat")
		return false
	if health >= Config.HEALTH_MAX - 1.0:
		say("Not hungry right now")
		return false
	inventory["potato"] -= 1
	inventory_changed.emit()
	meals += 1
	heal(Config.POTATO_HEALTH)
	say("Ate a potato: +%d health" % roundi(Config.POTATO_HEALTH))
	return true


## True when the player stands outside on the surface (hazards hurt there).
func is_outside() -> bool:
	return cave_id == "" and not in_shelter


# --- Water ---

## Adds water up to the limit. Returns how much was really added (0 if full).
func add_water(amount: float) -> float:
	if game_over:
		return 0.0
	var added := minf(amount, water_limit - water)
	if added <= 0.0:
		return 0.0
	water += added
	water_changed.emit(water, water_limit)
	return added


func consume_water(amount: float) -> void:
	if game_over:
		return
	water = maxf(0.0, water - amount)
	water_changed.emit(water, water_limit)


func is_water_full() -> bool:
	return water >= water_limit


## Called by the Water Tank machine: add_water_limit(Config.WATER_TANK_LIMIT_BONUS).
func add_water_limit(amount: float) -> void:
	water_limit += amount
	water_changed.emit(water, water_limit)


# --- Metal ---

## Adds metal up to METAL_MAX. Returns how much was really added.
func add_metal(amount: int) -> int:
	if game_over:
		return 0
	var added := mini(amount, Config.METAL_MAX - metal)
	if added <= 0:
		return 0
	metal += added
	metal_changed.emit(metal)
	return added


## Pays `amount` metal. Returns false and changes nothing if there is not enough.
func spend_metal(amount: int) -> bool:
	if game_over or amount < 0 or amount > metal:
		return false
	metal -= amount
	metal_changed.emit(metal)
	return true


## Pays for something. Returns false and changes nothing if there is not enough.
func spend(metal_cost: int, water_cost: float) -> bool:
	if game_over or metal_cost > metal or water_cost > water:
		return false
	metal -= metal_cost
	water -= water_cost
	metal_changed.emit(metal)
	water_changed.emit(water, water_limit)
	return true


# --- Inventory ---

func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = item_count(item_id) + amount
	inventory_changed.emit()
	discover(item_id)


## Marks a material as found: story line the first time, and recipes that use it unlock.
func discover(item_id: String) -> void:
	if discovered.has(item_id):
		return
	var before := unlocked_recipes()
	discovered[item_id] = true
	var dialogue := get_node_or_null("/root/Dialogue") if is_inside_tree() else null
	if dialogue != null:
		dialogue.once("found_" + item_id)
	_announce_unlocks(before)


## "water" is the water bar, everything else is the inventory.
func item_count(item_id: String) -> int:
	if item_id == "water":
		return floori(water)
	return inventory.get(item_id, 0)


# --- Build Book recipes ---

## A recipe is discovered once the player has obtained at least one of its
## materials. Radiation machines also need the first radiation event.
func recipe_unlocked(machine_id: String) -> bool:
	var def := Config.machine(machine_id)
	if def.get("needs_radiation", false) and not radiation_seen:
		return false
	for item_id: String in def.get("cost", {}):
		if discovered.has(item_id):
			return true
	return false


func unlocked_recipes() -> Array:
	return Config.BOOK_ORDER.filter(recipe_unlocked)


## Call when the first radiation event happens.
func see_radiation() -> void:
	var before := unlocked_recipes()
	radiation_seen = true
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue != null:
		dialogue.once("radiation", true)
	_announce_unlocks(before)


func _announce_unlocks(before: Array) -> void:
	var fresh: Array = unlocked_recipes().filter(func(id: String) -> bool: return not before.has(id))
	if not fresh.is_empty():
		new_recipes.append_array(fresh)
		recipes_unlocked.emit(fresh)


## True when all six ship modules are installed.
func ship_repaired() -> bool:
	return Config.REPAIR_ORDER.all(func(id: String) -> bool: return installed.has(id))


## Puts a built module into its port on the ship. The sixth one wins the game.
func install(module_id: String) -> void:
	if not modules_ready.has(module_id):
		return
	modules_ready.erase(module_id)
	installed.append(module_id)
	ship_changed.emit()
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue != null:
		dialogue.once("installed_" + module_id, true)
		dialogue.say("Ship repair: %d / %d systems installed." % [installed.size(), Config.REPAIR_ORDER.size()])
		if installed.size() == Config.REPAIR_ORDER.size() / 2:
			dialogue.once("half_repaired", true)
	if ship_repaired():
		if dialogue != null:
			dialogue.once("repaired", true)
		win("All six ship systems are repaired. You launch for home!")


## Once: the emergency power cell (more storage, full) and the seed potatoes.
func salvage_wreck() -> void:
	if wreck_salvaged:
		return
	wreck_salvaged = true
	battery_charge = battery_capacity()
	add_item("potato", Config.WRECK_POTATOES)
	power_changed.emit()
	ship_changed.emit()


# --- Production: the refinery and the CO2 capture machine ---

## Loads all carried ore into the refinery and collects what is finished.
## Returns a line for the player.
func use_refinery() -> String:
	var loaded := 0
	for ore: String in Config.REFINE:
		var n := item_count(ore)
		if n > 0:
			inventory[ore] = 0
			refinery_queue[ore] = refinery_queue.get(ore, 0) + n
			loaded += n
	if loaded > 0:
		inventory_changed.emit()
	var got := collect_output(Config.REFINE.values())
	var parts: Array[String] = []
	if got != "":
		parts.append("Collected " + got)
	if loaded > 0:
		parts.append("Loaded %d ore" % loaded)
	if parts.is_empty():
		return "Ore Refinery: empty. Bring Iron Ore, Aluminum Ore or Sulfur."
	return ". ".join(parts) + (" (%d still refining)" % refinery_left() if refinery_left() > 0 else "")


func refinery_left() -> int:
	var n := 0
	for ore: String in refinery_queue:
		n += refinery_queue[ore]
	return n


## Moves finished goods of these item ids from the machines into the inventory.
## Returns "3 Iron Ingots, 1 ..." or "".
func collect_output(ids: Array) -> String:
	var parts: Array[String] = []
	for id: String in ids:
		var n: int = machine_output.get(id, 0)
		if n > 0:
			machine_output[id] = 0
			add_item(id, n)
			parts.append("%d %s" % [n, Config.item(id).name])
	return ", ".join(parts)


func refinery_working() -> bool:
	return machine_count("refinery") > 0 and refinery_left() > 0 and o2_generator_powered


func co2_capture_working() -> bool:
	return machine_count("co2_capture") > 0 and o2_generator_powered


func _run_production(delta: float) -> void:
	if refinery_working():
		_refine_time += delta
		while _refine_time >= Config.REFINE_SECONDS and refinery_left() > 0:
			_refine_time -= Config.REFINE_SECONDS
			for ore: String in Config.REFINE:
				if refinery_queue.get(ore, 0) > 0:
					refinery_queue[ore] -= 1
					var made: String = Config.REFINE[ore]
					machine_output[made] = machine_output.get(made, 0) + 1
					break
	if machine_count("greenhouse") > 0:
		_grow_time += delta
		while _grow_time >= Config.GREENHOUSE_SECONDS:
			_grow_time -= Config.GREENHOUSE_SECONDS
			machine_output["potato"] = machine_output.get("potato", 0) + 1
	_run_ice(delta)
	if co2_capture_working():
		_co2_time += delta
		while _co2_time >= Config.CO2_CAPTURE_SECONDS:
			_co2_time -= Config.CO2_CAPTURE_SECONDS
			machine_output["co2"] = machine_output.get("co2", 0) + 1


# --- Ice: refills and fresh deposits ---

## A deposit ran empty. Fixed ice deposits refill a little later; a fresh one melts away.
func deposit_emptied(node_id: String, kind: String) -> void:
	if kind != "ice" or node_id == "":
		return
	if ice_spawns.has(node_id):
		ice_spawns.erase(node_id)
		node_charges.erase(node_id)
		ice_removed.emit(node_id)
	else:
		ice_empty_since[node_id] = sol_elapsed_seconds


func _run_ice(delta: float) -> void:
	for id: String in ice_empty_since.keys():
		if sol_elapsed_seconds - float(ice_empty_since[id]) >= Config.ICE_REGEN_SECONDS:
			ice_empty_since.erase(id)
			node_charges[id] = Config.ICE_REGEN_CHARGES
			deposits_changed.emit()
	_ice_time += delta
	if _ice_time >= Config.ICE_SPAWN_SECONDS:
		_ice_time = 0.0
		spawn_ice()


## Fresh ice (full) at a random open surface spot away from the others. Returns its id or "".
func spawn_ice() -> String:
	if ice_spawn_spots.is_empty() or ice_spawns.size() >= Config.ICE_SPAWN_MAX:
		return ""
	var spot: Vector2 = ice_spawn_spots.pick_random()
	for attempt in 30:
		if ice_spawns.values().all(func(p: Vector2) -> bool: return p.distance_to(spot) > 64.0):
			break
		spot = ice_spawn_spots.pick_random()
	_ice_serial += 1
	var id := "surface/IceNew%03d" % _ice_serial
	ice_spawns[id] = spot
	ice_spawned.emit(id)
	say("Fresh ice has been exposed somewhere on the surface!")
	return id


## True if the inventory holds everything in `cost` (item id -> amount).
func has_items(cost: Dictionary) -> bool:
	for id: String in cost:
		if item_count(id) < int(cost[id]):
			return false
	return true


## Takes everything in `cost`. Returns false and changes nothing if something is missing.
func spend_items(cost: Dictionary) -> bool:
	if not has_items(cost):
		return false
	for id: String in cost:
		if id == "water":
			consume_water(float(cost[id]))
		else:
			inventory[id] = item_count(id) - int(cost[id])
	inventory_changed.emit()
	return true


# --- Machines and power ---

## What stops this machine from being paid for, or "" if it can be.
## For example "Need 15 metal (you have 3)".
func cost_problem(machine_id: String) -> String:
	var def := Config.machine(machine_id)
	if def.is_empty():
		return "Unknown machine"
	var missing: Array[String] = []
	if def.has("cost"):
		for item_id: String in def.cost:
			if item_count(item_id) < int(def.cost[item_id]):
				missing.append("%d %s (you have %d)" % [def.cost[item_id], Config.item(item_id).name, item_count(item_id)])
		return "" if missing.is_empty() else "Need " + ", ".join(missing)
	if metal < int(def.metal):
		missing.append("%d metal (you have %d)" % [def.metal, metal])
	if water < float(def.water):
		missing.append("%d water (you have %d)" % [def.water, floori(water)])
	if missing.is_empty():
		return ""
	return "Need " + " and ".join(missing)


## Records a built machine and applies what it does once (a tank raises the water limit).
func add_machine(pad_id: String, machine_id: String) -> void:
	machines[pad_id] = machine_id
	var kind: String = Config.machine(machine_id).get("acts_as", machine_id)
	if kind == "water_tank":
		add_water_limit(Config.WATER_TANK_LIMIT_BONUS)
	if kind == "o2_generator":
		o2_generator_built = true
	machines_changed.emit()


## Counts machines of this id, and machines that act as it (see "acts_as" in Config.MACHINES).
func machine_count(machine_id: String) -> int:
	var count := 0
	for built: String in machines.values():
		if built == machine_id or Config.machine(built).get("acts_as", "") == machine_id:
			count += 1
	return count


## Built on a pad, or (ship modules) built in the book or installed.
func has_built(machine_id: String) -> bool:
	return machine_count(machine_id) > 0 or modules_ready.has(machine_id) or installed.has(machine_id)


func battery_capacity() -> float:
	return Config.HAB_BATTERY_CAPACITY + machine_count("battery") * Config.BATTERY_CAPACITY_BONUS \
		+ (Config.POWER_CELL_BONUS if wreck_salvaged else 0.0)


## True while the O2 generator really makes oxygen (wants to run, has power and water).
func o2_generator_working() -> bool:
	return o2_generator_built and o2_generator_running and o2_generator_powered and water > 0.0


## Why the O2 generator stands still although it should run, or "".
func o2_generator_problem() -> String:
	if not o2_generator_built or not o2_generator_running:
		return ""
	if not o2_generator_powered:
		return "no power"
	if water <= 0.0:
		return "no water"
	return ""


## Power made = solar (by sun) + backup. Power used = the O2 generator while it runs.
## Spare power fills the battery; missing power comes out of it. When the battery
## is empty and there is not enough power, the O2 generator stops.
func _run_power(delta: float) -> void:
	var hazards := get_node_or_null("/root/Hazards") if is_inside_tree() else null
	var light: float = sun * (hazards.solar_factor() if hazards != null else 1.0)
	power_made = machine_count("solar") * Config.SOLAR_OUTPUT * light + machine_count("backup_power") * Config.BACKUP_OUTPUT
	var wants := o2_generator_built and o2_generator_running and water > 0.0
	var need := Config.O2_GEN_POWER_USE if wants else 0.0
	if machine_count("refinery") > 0 and refinery_left() > 0:
		need += Config.REFINERY_POWER_USE
	if machine_count("co2_capture") > 0:
		need += Config.CO2_POWER_USE
	var capacity := battery_capacity()
	# After running dry, wait for a little charge before starting again (no flicker).
	var reserve := 0.0 if o2_generator_powered else 1.0
	if power_made >= need or battery_charge > reserve:
		o2_generator_powered = true
		power_used = need
		battery_charge = clampf(battery_charge + (power_made - need) * delta, 0.0, capacity)
	else:
		o2_generator_powered = false
		power_used = 0.0
		battery_charge = clampf(battery_charge + power_made * delta, 0.0, capacity)
	power_changed.emit()


## The rocket got away: the game is won.
func win(reason: String) -> void:
	if game_over:
		return
	game_won = true
	death_cause = "won"
	_end_game(reason)


# --- Messages, game over, restart ---

func say(text: String) -> void:
	message.emit(text)


# --- Location ---

## Records where the player is going. `how` is kept in `arrival` for the next scene.
func set_location(cave: String, layer: int, how: String) -> void:
	cave_id = cave
	cave_layer = layer
	arrival = how
	in_shelter = how == "shelter"
	location_changed.emit(location_name())


## "Surface", or the cave and layer: "Ice Cave L2".
func location_name() -> String:
	if in_shelter:
		return "Emergency Shelter"
	if cave_id == "":
		return "Surface"
	return "%s L%d" % [Config.cave_name(cave_id), cave_layer + 1]


## Puts every value back to the start. Call before reloading the scene.
func reset() -> void:
	oxygen = Config.O2_START
	water = Config.WATER_START
	water_limit = Config.WATER_BASE_LIMIT
	metal = Config.METAL_START
	zero_oxygen_time = 0.0
	zero_water_time = 0.0
	health = Config.HEALTH_MAX
	meals = 0
	death_cause = ""
	ice_empty_since.clear()
	ice_spawns.clear()
	_ice_time = 0.0
	in_shelter = false
	_grow_time = 0.0
	game_over = false
	game_over_reason = ""
	o2_generator_built = false
	o2_generator_powered = true
	o2_generator_running = false
	cave_id = ""
	cave_layer = 0
	arrival = ""
	node_charges.clear()
	inventory.clear()
	discovered.clear()
	new_recipes.clear()
	modules_ready.clear()
	installed.clear()
	wreck_salvaged = false
	story_seen.clear()
	refinery_queue.clear()
	machine_output.clear()
	_refine_time = 0.0
	_co2_time = 0.0
	var dialogue := (get_node_or_null("/root/Dialogue") if is_inside_tree() else null)
	if dialogue != null:
		dialogue.clear()
	var hazards := (get_node_or_null("/root/Hazards") if is_inside_tree() else null)
	if hazards != null:
		hazards.reset()
	radiation_seen = false
	lamp_found = false
	inventory_changed.emit()
	machines.clear()
	sun = 1.0
	battery_charge = Config.HAB_BATTERY_CAPACITY
	power_made = 0.0
	power_used = 0.0
	sol_elapsed_seconds = 0.0
	sol_number = 1
	game_won = false
	oxygen_changed.emit(oxygen)
	water_changed.emit(water, water_limit)
	metal_changed.emit(metal)
	health_changed.emit(health, false)
	location_changed.emit(location_name())
	machines_changed.emit()
	power_changed.emit()
	ship_changed.emit()


func _end_game(reason: String) -> void:
	game_over = true
	game_over_reason = reason
	game_ended.emit(reason)


## Runs by itself once built: on below 95, off at 100, needs power and water.
func _run_o2_generator(delta: float) -> void:
	if not o2_generator_built:
		o2_generator_running = false
		return
	if oxygen < Config.O2_GEN_ON_BELOW:
		o2_generator_running = true
	elif oxygen >= Config.O2_GEN_OFF_AT:
		o2_generator_running = false
	if not o2_generator_running or not o2_generator_powered or water <= 0.0:
		return
	water = maxf(0.0, water - Config.O2_GEN_WATER_PER_SEC * delta)
	oxygen = minf(Config.O2_MAX, oxygen + Config.O2_GEN_RATE * delta)


func _update_day_night(delta: float) -> void:
	sol_elapsed_seconds += delta

	sol_number = int(floor(sol_elapsed_seconds / Config.SOL_SECONDS)) + 1
	if sol_number > Config.TOTAL_SOLS:
		sol_number = Config.TOTAL_SOLS
		death_cause = "time"
		_end_game("Return window closed")
		return

	var progress := fmod(sol_elapsed_seconds, Config.SOL_SECONDS) / Config.SOL_SECONDS

	if progress < 0.1:
		var t := progress / 0.1
		sun = t * t * (3.0 - 2.0 * t)
	elif progress < 0.5:
		sun = 1.0
	elif progress < 0.6:
		var t := (progress - 0.5) / 0.1
		sun = 1.0 - t * t * (3.0 - 2.0 * t)
	else:
		sun = 0.0

	day_night_changed.emit(sol_number, sun)
