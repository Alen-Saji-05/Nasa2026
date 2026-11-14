extends Node
## Shared game state (autoload "GameState"): oxygen, water and metal.
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
## Power made, power used or the battery changed.
signal power_changed
signal day_night_changed(sol: int, sun_level: float)

var sol_elapsed_seconds: float = 0.0
var sol_number: int = 1

var oxygen: float = Config.O2_START
var water: float = Config.WATER_START
var water_limit: float = Config.WATER_BASE_LIMIT
var metal: int = Config.METAL_START

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
	_run_o2_generator(delta)

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
			_end_game("Out of oxygen")
			return
	else:
		zero_oxygen_time = 0.0

	if water <= 0.0:
		zero_water_time += delta
		if zero_water_time >= Config.WATER_ZERO_GRACE:
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


# --- Machines and power ---

## What stops this machine from being paid for, or "" if it can be.
## For example "Need 15 metal (you have 3)".
func cost_problem(machine_id: String) -> String:
	var def := Config.machine(machine_id)
	if def.is_empty():
		return "Unknown machine"
	var missing: Array[String] = []
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
	if machine_id == "water_tank":
		add_water_limit(Config.WATER_TANK_LIMIT_BONUS)
	if machine_id == "o2_generator":
		o2_generator_built = true
	machines_changed.emit()


func machine_count(machine_id: String) -> int:
	return machines.values().count(machine_id)


func has_built(machine_id: String) -> bool:
	return machine_count(machine_id) > 0


func battery_capacity() -> float:
	return Config.HAB_BATTERY_CAPACITY + machine_count("battery") * Config.BATTERY_CAPACITY_BONUS


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
	power_made = machine_count("solar") * Config.SOLAR_OUTPUT * sun + machine_count("backup_power") * Config.BACKUP_OUTPUT
	var wants := o2_generator_built and o2_generator_running and water > 0.0
	var need := Config.O2_GEN_POWER_USE if wants else 0.0
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
	location_changed.emit(location_name())


## "Surface", or the cave and layer: "Ice Cave L2".
func location_name() -> String:
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
	game_over = false
	game_over_reason = ""
	o2_generator_built = false
	o2_generator_powered = true
	o2_generator_running = false
	cave_id = ""
	cave_layer = 0
	arrival = ""
	node_charges.clear()
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
	location_changed.emit(location_name())
	machines_changed.emit()
	power_changed.emit()


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
