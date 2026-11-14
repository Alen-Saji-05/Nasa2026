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


func _process(delta: float) -> void:
	if game_over:
		return

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


# --- Messages, game over, restart ---

func say(text: String) -> void:
	message.emit(text)


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
	oxygen_changed.emit(oxygen)
	water_changed.emit(water, water_limit)
	metal_changed.emit(metal)


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
