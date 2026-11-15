class_name Config
extends RefCounted
## Every tunable number of the game in one place. Change values here, not in the
## scripts that use them. Numbers follow GAME_FLOW.md.

# --- Scenes ---
const TITLE_SCENE := "res://scenes/TitleScreen.tscn"
const WORLD_SCENE := "res://scenes/World.tscn"
## The intro video after Play (scripts/intro.gd). Godot plays Ogg Theora (.ogv) only:
## art/video/intro.mp4 converted to this file.
const INTRO_SCENE := "res://scenes/Intro.tscn"
const INTRO_VIDEO := "res://art/video/intro.ogv"

# --- Time ---
const SOL_SECONDS := 60.0                    # 1 sol (Mars day) in real seconds
const TOTAL_SOLS := 30                       # the return window: after this sol the game is lost
const NIGHT_COLOR := Color(0.42, 0.45, 0.68) # how the surface is tinted at full night
const LAMP_RADIUS := 6.0                     # tiles lit around the player at night on the surface

# --- Oxygen ---
const O2_START := 100.0
const O2_MAX := 100.0
const O2_DRAIN_PER_SOL := 8.0                # 100 oxygen lasts 12.5 sols (same per-second rate as before)
const O2_DRAIN_PER_SEC := O2_DRAIN_PER_SOL / SOL_SECONDS
const O2_ZERO_GRACE := 6.0                   # seconds at 0 before "Out of oxygen"
const O2_HARVEST_COST := 1.0                 # O2 spent per harvest (metal or ice)
const O2_MIN_TO_HARVEST := 1.0               # below this you cannot harvest
const O2_LOW_WARNING := 25.0                 # HUD bar blinks red below this
const CRATER_O2_PENALTY := 0.0               # 0 = walking over craters costs no oxygen (design rule)
const CRATER_COOLDOWN := 1.0                 # seconds before the same crater can hurt again

# O2 generator (the machine itself comes with the build menu)
const O2_GEN_RATE := 0.45                    # O2 per second while running
const O2_GEN_ON_BELOW := 95.0
const O2_GEN_OFF_AT := 100.0
const O2_GEN_WATER_PER_SEC := 0.15

# --- Power (GAME_FLOW Part 8) ---
const HAB_BATTERY_CAPACITY := 20.0           # the hab's own battery; it starts full
const POWER_LOW_HINT := 15.0                 # battery at or below this with no Solar Panel: Mission Control warns
const BATTERY_CAPACITY_BONUS := 40.0         # each Battery machine adds this much storage
const SOLAR_OUTPUT := 3.0                    # power per second from one panel in full sun
const BACKUP_OUTPUT := 2.0                   # power per second from Backup power, day and night
const O2_GEN_POWER_USE := 1.0                # power per second while the O2 generator runs

# --- Health and food ---
const HEALTH_MAX := 100.0
const HUNGER_PER_SOL := 24.0                 # health lost to hunger every sol (100 lasts about 4 sols)
const POTATO_HEALTH := 30.0                  # eating one potato (F) gives back this much health
const HEALTH_LOW_WARNING := 30.0             # HUD bar blinks red below this
const HUNGER_HINT_1 := 60.0                  # first "I'm hungry" hint below this health
const HUNGER_HINT_2 := 75.0                  # after eating once: "I need a way to grow food"
const GREENHOUSE_SECONDS := 30.0             # the greenhouse grows one potato this often

# --- Environmental hazards (hazards.gd). Times in seconds of game time ---
const RADIATION_FIRST := 200.0               # the first warning (sol 4)
const RADIATION_EVERY := Vector2(220.0, 320.0)   # then again after a random time in this range
const RADIATION_WARNING := 12.0              # warning before it hits
const RADIATION_WARNING_SENSOR := 30.0       # ... with a Radiation Sensor Station built
const RADIATION_DURATION := 30.0
const RADIATION_DAMAGE := 3.0                # health lost every HAZARD_DAMAGE_EVERY when outside
const STORM_FIRST := 420.0                   # the first dust storm warning (sol 8)
const STORM_EVERY := Vector2(260.0, 380.0)
const STORM_WARNING := 10.0
const STORM_APPROACH := 12.0                 # dust and wind build up
const STORM_DURATION := 40.0                 # full strength
const STORM_CLEAR := 12.0                    # dust settles again
const STORM_DAMAGE := 2.0                    # health lost every HAZARD_DAMAGE_EVERY outside at full strength
const STORM_SLOW := 0.45                     # share of walking speed lost at full strength
const STORM_WIND := 30.0                     # px/s the wind pushes the player at full strength
const STORM_SOLAR_LOSS := 0.8                # share of solar power lost at full strength
const HAZARD_DAMAGE_EVERY := 2.0
const SHELTER_SCENE := "res://scenes/Shelter.tscn"

# --- Water ---
const WATER_START := 50.0
const WATER_BASE_LIMIT := 60.0
const WATER_DRAIN_PER_SOL := 24.0            # same per-second rate as before
const WATER_DRAIN_PER_SEC := WATER_DRAIN_PER_SOL / SOL_SECONDS
const WATER_ZERO_GRACE := 6.0                # seconds at 0 before "Out of water"
const WATER_PER_HARVEST := 6.0
const WATER_LOW_WARNING := 20.0              # HUD bar blinks red below this
const WATER_TANK_LIMIT_BONUS := 40.0         # each Water Tank adds this to the limit
const WATER_TANK_METAL_COST := 20

# --- Metal ---
const METAL_START := 30
const METAL_MAX := 999                       # the counter has 3 digits
const METAL_PER_HARVEST := 8

# --- Harvesting ---
const NODE_CHARGES := 5                      # uses per metal / ice node
const HARVEST_COOLDOWN := 0.4                # seconds between two harvests

# --- Map rewards (whole game: surface + all caves) ---
const METAL_NODE_COUNT := 15                 # surface iron + every ore deposit in the caves
const ICE_NODE_COUNT := 6
const MAX_NODES_PER_CHAMBER := 3             # used by the cave generator
const MIN_REWARD_DISTANCE := 0.4             # nearest deposit >= this share of the farthest walk (caves)

# --- Surface: the base area (used by scripts/world/world_gen.gd) ---
const BUILD_PAD_COUNT := 10                  # marked squares for machines (the launch pad is extra)
const SURFACE_METAL_NODES := 2               # starter deposits on the surface; the rest is in the caves
const SURFACE_ICE_NODES := 1
# Ice is dynamic: used-up deposits refill a little, and fresh ones appear elsewhere on the surface.
const ICE_REGEN_SECONDS := 90.0              # an empty ice deposit refills after this long ...
const ICE_REGEN_CHARGES := 2                 # ... with this many uses (less than new)
const ICE_SPAWN_SECONDS := 60.0              # how often fresh ice appears somewhere on the surface
const ICE_SPAWN_MAX := 3                     # at most this many fresh deposits at the same time
const STARTER_NODE_MIN_WALK := 15            # tiles a starter deposit must be from the spawn, on foot
const BASE_SAFE_RADIUS := 9                  # tiles around the hab with no craters
const SURFACE_MAX_EMPTY_SQUARE := 3          # "no dead space": no plain empty floor bigger than 3x3 tiles

# --- Caves ---
const CAVE_SCENE := "res://scenes/Cave.tscn"
const CAVE_SIZE_MIN := Vector2i(24, 18)      # every cave layer is at least this big (tiles)
const CAVE_SIZE_MAX := Vector2i(32, 24)      # ... and at most this big
const CAVE_MIN_FLOOR_SHARE := 0.6            # "no dead space": at least 60% of a layer is floor
const CAVE_MAX_EMPTY_SQUARE := 3             # ... and no plain empty floor bigger than 3x3 tiles
const CAVE_DARKNESS := 0.45                  # brightness of a cave away from any light (1 = daylight)
const SUIT_LIGHT_RADIUS := 7.0               # tiles lit around the player in a cave
const TRAVEL_FADE_SECONDS := 0.25            # fade to black when entering a cave or using a ladder
const INTERACT_RANGE := 30.0                 # pixels: how close the player must be to use E on something

## Every cave: one dark entrance on the surface for each. A cave is made of
## layers (floors) joined by ladders. Each layer is generated from these numbers:
##   cols, rows       how many rooms wide and tall the layer is
##   metal, ice       deposits in this layer
##   ores             what each "metal" deposit really is, in order (see ITEMS); none = plain metal
##   guarded          how many of the richest rooms have a crater you cannot avoid in the door
##   crater_chance    chance of a small crater in each ordinary room
##   loops            extra doors that make a shortcut (each has a crater in it)
## The deposits of all caves plus the surface add up to METAL_NODE_COUNT / ICE_NODE_COUNT.
const CAVES: Array[Dictionary] = [
	{
		"id": "ice", "name": "Ice Cave", "seed": 101, "theme": "ice", "tint": Color(0.78, 0.92, 1.0),
		"layers": [
			{"cols": 5, "rows": 4, "metal": 0, "ice": 2, "guarded": 0, "crater_chance": 0.2, "loops": 1},
			{"cols": 6, "rows": 4, "ores": ["aluminum"], "metal": 1, "ice": 2, "guarded": 1, "crater_chance": 0.3, "loops": 1},
		],
	},
	{
		"id": "ore", "name": "Ore Cave", "seed": 202, "theme": "ore", "tint": Color(1.0, 0.86, 0.72),
		"layers": [
			{"cols": 5, "rows": 4, "ores": ["iron", "aluminum", "electronics"], "metal": 3, "ice": 0, "guarded": 0, "crater_chance": 0.25, "loops": 1},
			{"cols": 6, "rows": 4, "ores": ["iron", "aluminum", "sulfur", "iron"], "metal": 4, "ice": 0, "guarded": 1, "crater_chance": 0.35, "loops": 1},
		],
	},
	{
		"id": "deep", "name": "Deep Cave", "seed": 303, "theme": "deep", "tint": Color(0.84, 0.78, 0.95),
		"layers": [
			{"cols": 5, "rows": 4, "ores": ["sulfur"], "metal": 1, "ice": 0, "guarded": 0, "crater_chance": 0.35, "loops": 1},
			{"cols": 6, "rows": 4, "ores": ["aluminum"], "metal": 1, "ice": 1, "guarded": 1, "crater_chance": 0.45, "loops": 2},
			{"cols": 6, "rows": 5, "ores": ["aluminum", "aluminum", "electronics"], "metal": 3, "ice": 0, "guarded": 2, "crater_chance": 0.5, "loops": 2},
		],
	},
]


# --- Mars fact papers (fact_paper.gd on the map, fact_viewer.gd full screen) ---
## "where" is "surface" or "<cave id>/<layer index>".
const FACTS: Array[Dictionary] = [
	{"where": "surface", "title": "The God of War",
		"text": "Named after the Roman God of war, Mars is the fourth planet from the Sun in our Solar System."},
	{"where": "surface", "title": "The Red Planet",
		"text": "Mars is also known as the ‘Red Planet’ because, well, it’s red! This signature colour comes from the large amount of a chemical called iron oxide (or ‘rust’ as you might know it) in its rocks and soil."},
	{"where": "ore/0", "title": "Small but Mighty",
		"text": "Mars is the second smallest planet in the solar system after Mercury. With a diameter (distance through the middle) of 6,791 kilometres, it’s roughly half the size of Earth."},
	{"where": "ice/0", "title": "Brr! So Cold",
		"text": "It can get pretty cold on Mars –– much colder than our own planet, since it’s further away from the Sun. At the equator, temperatures can reach 20°C, but at its poles they can plummet to as low as -140°C. Brr!"},
	{"where": "ore/1", "title": "Olympus Mons",
		"text": "Mars is home to the highest mountain in our solar system –– a volcano called Olympus Mons. Standing a whopping 24 kilometres high, it’s about three times the height of Mount Everest!"},
	{"where": "deep/1", "title": "Boing!",
		"text": "You could jump around three times higher on Mars than you can on Earth. Boing! This is because the planet’s gravity – the force that keeps us on the ground – is much weaker."},
	{"where": "surface", "title": "Two Moons",
		"text": "Do you like to look at the Moon at night? Well, check this out – Mars has two moons! One is called Phobos and the other Deimos."},
	{"where": "surface", "title": "Days and Years",
		"text": "A day on Mars is 24 hours and 37 minutes – only a little bit longer than a day on our own planet. A year on Mars, however, is almost twice as long, lasting 687 Earth days! This is because Mars takes a lot longer than Earth to complete its orbit around the Sun."},
	{"where": "ice/1", "title": "A Hidden Lake",
		"text": "Scientists once believed that there was no liquid water on the surface of Mars – only rocks, soil dust and ice. But in 2018, they found evidence of a lake under the planet’s south polar ice cap. Exciting stuff!"},
]


## The data of one cave from CAVES, or an empty Dictionary if the id is unknown.
static func cave(cave_id: String) -> Dictionary:
	for c in CAVES:
		if c.id == cave_id:
			return c
	return {}


## The display name of a cave ("Ice Cave"), or the id itself if it is unknown.
static func cave_name(cave_id: String) -> String:
	var c := cave(cave_id)
	return c.name if not c.is_empty() else cave_id


# --- Machines (built on the base pads; GAME_FLOW Part 7) ---
const MACHINE_SCENE := "res://scenes/Machine.tscn"
const NS := "res://art/new_sprites/"
const PH := "res://art/placeholders/machines/"   # PLACEHOLDER art; swap the paths when real art exists
## The order machines are listed in (debug keys 1-6, and the book later).
## Every buildable thing in the Build Book. "kind":
##   "machine"  built on a base pad (Builder.start_placing)
##   "item"     crafted into the inventory at once (Builder.craft)
##   "module"   a ship repair module: crafted, then installed at its port on the ship
## "cost" is paid in ITEMS ("water" = the water bar). "requires": a machine that must
## be built first. "acts_as": which behaviour a machine has (machine.gd, GameState).
## "unique": only one. "needs_radiation": locked until the first radiation event.
## "pixels": how wide it is drawn. Modules: "port" (pixel on the crashed ship art
## where its pipe connects) and "color" (connection colour, master prompt 12).
const MACHINES: Dictionary = {
	# ---- 1. Processing: the first thing the player can build, from raw ore ----
	"ore_refinery": {
		"name": "Ore Refinery", "kind": "machine", "pad": "machine", "pixels": 90, "unique": true, "acts_as": "refinery",
		"cost": {"iron": 4, "aluminum": 4},
		"idle": [NS + "machines/ore_refinery.png"],
		"description": "Smelts ore into ingots and sulfur into compounds, slowly, using power. Press E to load ore and collect.",
	},
	"wire": {
		"name": "Wire", "kind": "item", "cost": {"iron_ingot": 1},
		"idle": [NS + "research_sites/06_broken_cable_bundle.png"],
		"description": "Drawn from one iron ingot. Batteries and air scrubbers need wiring.",
	},
	# ---- 2. Power ----
	"solar": {
		"name": "Solar Panel", "kind": "machine", "pad": "machine", "pixels": 60,
		"cost": {"iron_ingot": 2, "aluminum_ingot": 3},
		"idle": ["res://art/solar_panel/solar_panel_generate_01.png"],
		"running": ["res://art/solar_panel/solar_panel_generate_02.png", "res://art/solar_panel/solar_panel_generate_03.png",
			"res://art/solar_panel/solar_panel_generate_04.png", "res://art/solar_panel/solar_panel_generate_05.png"],
		"description": "Makes power from sunlight: +3 per second by day, nothing at night.",
	},
	"battery": {
		"name": "Battery", "kind": "machine", "pad": "machine", "pixels": 50,
		"cost": {"iron_ingot": 1, "aluminum_ingot": 2, "wire": 1},
		"levels": ["res://art/battery/battery_empty.png", "res://art/battery/battery_low_25.png",
			"res://art/battery/battery_medium_50.png", "res://art/battery/battery_full_100.png"],
		"description": "Stores spare solar power for the night (+40 storage).",
	},
	# ---- 3. Survival ----
	"oxygen_gen": {
		"name": "Oxygen Generator", "kind": "machine", "pad": "machine", "pixels": 90, "acts_as": "o2_generator", "unique": true,
		"cost": {"iron_ingot": 3, "aluminum_ingot": 4, "electronics": 1},
		"idle": [NS + "machines/Oxygen_Generator.png"],
		"description": "Generates oxygen.",
	},
	"reservoir": {
		"name": "Water Reservoir Tank", "kind": "machine", "pad": "machine", "pixels": 90, "acts_as": "water_tank", "unique": true,
		"cost": {"iron_ingot": 3, "aluminum_ingot": 4, "sulfur_compound": 2},
		"idle": [NS + "machines/Water_Reservoir_Tank.png"],
		"description": "Stores collected water.",
	},
	"greenhouse": {
		"name": "Greenhouse", "kind": "machine", "pad": "machine", "pixels": 90, "unique": true,
		"cost": {"iron_ingot": 3, "aluminum_ingot": 5, "sulfur_compound": 2, "potato": 2},
		"idle": [NS + "machines/greenhouse.png"],
		"description": "Grows potatoes to eat. Plant 2 seed potatoes.",
	},
	# ---- 4. Propellant chemistry ----
	"co2_capture": {
		"name": "CO2 Capture Machine", "kind": "machine", "pad": "machine", "pixels": 90, "acts_as": "co2_capture", "unique": true,
		"cost": {"aluminum_ingot": 3, "iron_ingot": 2, "electronics": 1, "wire": 1},
		"idle": [NS + "machines/CO2_Capture_Machine.png"],
		"description": "Direct air capture: pulls CO2 out of the air using power. Press E to collect the capsules.",
	},
	"oxygen": {
		"name": "Oxygen Capsule", "kind": "item", "requires": "oxygen_gen", "cost": {"water": 2},
		"idle": [NS + "new_ores/oxygen_capsule.png"],
		"description": "Electrolysis: the Oxygen Generator splits water and bottles the oxygen.",
	},
	"methane": {
		"name": "Methane Capsule", "kind": "item", "requires": "co2_capture", "cost": {"co2": 1, "water": 2},
		"idle": [NS + "new_ores/methane_capsule.png"],
		"description": "Sabatier process: CO2 plus hydrogen from water makes methane rocket fuel.",
	},
	# ---- 5. Radiation (after the first radiation event) ----
	"radiation_sensor": {
		"name": "Radiation Sensor Station", "kind": "machine", "pad": "machine", "pixels": 90, "unique": true, "needs_radiation": true,
		"cost": {"iron_ingot": 2, "aluminum_ingot": 2, "electronics": 1},
		"idle": [NS + "machines/Radiation_Sensor_Station.png"],
		"description": "Monitors radiation.",
	},
	"shelter": {
		"name": "Emergency Shelter", "kind": "machine", "pad": "machine", "pixels": 100, "acts_as": "shelter", "unique": true, "needs_radiation": true,
		"cost": {"iron_ingot": 6, "aluminum_ingot": 5, "sulfur_compound": 3},
		"idle": [NS + "machines/radioactive_protection_shelter.png"],
		"description": "Walk-in shelter. Protects you from radiation and dust storms.",
	},
	# ---- 6. The six ship repair modules ----
	"power_station": {
		"name": "Solar Panel", "kind": "module", "pixels": 48, "port": Vector2(746, 465), "color": Color(1.0, 0.85, 0.2),
		"cost": {"iron_ingot": 3, "aluminum_ingot": 5, "sulfur_compound": 2},
		"idle": ["res://art/solar_panel/solar_panel_generate_01.png"],
		"description": "Generates electricity for repair systems.",
	},
	"engine": {
		"name": "Engine & Thrusters", "kind": "module", "pixels": 46,
		"cost": {"iron_ingot": 6, "aluminum_ingot": 4, "sulfur_compound": 2},
		"idle": [NS + "spaceship_components/engine_thrusters_simple_transparent.png"],
		"description": "Restores rocket propulsion.",
	},
	"thermal": {
		"name": "Thermal Control", "kind": "module", "pixels": 54, "port": Vector2(780, 739), "color": Color(0.25, 0.55, 1.0),
		"cost": {"iron_ingot": 2, "aluminum_ingot": 5, "sulfur_compound": 2},
		"idle": [NS + "spaceship_components/thermal_control_transparent.png"],
		"description": "Restores temperature regulation.",
	},
	"avionics": {
		"name": "Avionics & Communications Console", "kind": "module", "pixels": 50, "port": Vector2(764, 585), "color": Color(0.85, 0.85, 0.88),
		"cost": {"iron_ingot": 2, "aluminum_ingot": 4, "sulfur_compound": 2, "electronics": 1},
		"idle": [NS + "spaceship_components/Satellite_Communications_Console.png"],
		"description": "Restores navigation and communication.",
	},
	"propellant": {
		"name": "Propellant & Pressurization Module", "kind": "module", "pixels": 52, "port": Vector2(743, 1107), "color": Color(0.95, 0.35, 0.15),
		"cost": {"iron_ingot": 3, "aluminum_ingot": 4, "methane": 3, "oxygen": 3},
		"idle": [NS + "spaceship_components/Propellant_Synthesizer.png"],
		"description": "Stores and supplies rocket propellant.",
	},
	"life_support": {
		"name": "Life Support Refill Station", "kind": "module", "pixels": 52, "port": Vector2(776, 917), "color": Color(0.65, 0.35, 0.95),
		"cost": {"iron_ingot": 2, "aluminum_ingot": 3, "oxygen": 4, "water": 3},
		"idle": [NS + "spaceship_components/life_Support_Refill_Station.png"],
		"description": "Refills oxygen and water.",
	},
}
const MACHINE_WARNING_ICON := PH + "warning_icon.png"

## Debug keys for testing (turn OFF before the submission):
##   F1 = +10 of every material,  F2 = jump half a sol ahead (day <-> night),
##   F3 = a radiation event starts (warning now),  F4 = a dust storm starts.
const DEBUG_KEYS := true


## The data of one machine from MACHINES, or an empty Dictionary.
static func machine(machine_id: String) -> Dictionary:
	return MACHINES.get(machine_id, {})


# --- Items the player carries (the inventory on the HUD) ---
## Ores are mined from deposits: "per_harvest" is what one press of E gives.
## "tint" recolours a reused picture (circuits reuse the electronics art).
const ITEMS: Dictionary = {
	"iron": {"name": "Iron Ore", "icon": NS + "new_ores/iron_ore.png", "per_harvest": 3},
	"aluminum": {"name": "Aluminum Ore", "icon": NS + "new_ores/aluminum_ore.png", "per_harvest": 3},
	"sulfur": {"name": "Sulfur", "icon": NS + "new_ores/sulfur.png", "per_harvest": 2},
	"electronics": {"name": "Salvaged Electronics", "icon": NS + "new_ores/salvaged_electronics.png", "per_harvest": 1},
	"circuits": {"name": "Circuits", "icon": NS + "research_sites/05_circuit_board_pickup.png", "per_harvest": 1},
	# Made from ore (see REFINE) or by machines.
	"iron_ingot": {"name": "Iron Ingots", "icon": NS + "new_ores/iron_ingot.png"},
	"aluminum_ingot": {"name": "Aluminum Ingots", "icon": NS + "new_ores/aluminium_ingot.png"},
	"sulfur_compound": {"name": "Sulfur Compounds", "icon": NS + "new_ores/sulfer_compound.png"},
	"wire": {"name": "Wire", "icon": NS + "research_sites/06_broken_cable_bundle.png"},
	"methane": {"name": "Methane", "icon": NS + "new_ores/methane_capsule.png"},
	"oxygen": {"name": "Oxygen", "icon": NS + "new_ores/oxygen_capsule.png"},
	"co2": {"name": "Captured CO2", "icon": NS + "new_ores/co2_capsule.png"},
	"potato": {"name": "Potatoes", "icon": NS + "potato.png"},
	# Not carried as an item: this is the water on the HUD bar.
	"water": {"name": "Purified Water", "icon": "res://art/decor/ice_deposit_full.png"},
}
const ITEM_ORDER: Array[String] = ["iron", "aluminum", "sulfur", "electronics", "circuits",
	"iron_ingot", "aluminum_ingot", "sulfur_compound", "wire", "methane", "oxygen", "co2", "potato"]
## Refining: ore -> what it becomes, one for one.
const REFINE: Dictionary = {"iron": "iron_ingot", "aluminum": "aluminum_ingot", "sulfur": "sulfur_compound"}
## The Build Book: one page each, in the order the player can make them
## (see the dependency map in tools/test_book.gd). The ship modules come last.
const BOOK_ORDER: Array[String] = ["ore_refinery", "wire", "solar", "battery", "oxygen_gen", "reservoir",
	"greenhouse", "co2_capture", "oxygen", "methane", "radiation_sensor", "shelter",
	"power_station", "engine", "thermal", "avionics", "propellant", "life_support"]
const REPAIR_ORDER: Array[String] = ["power_station", "engine", "thermal", "avionics", "propellant", "life_support"]
## Production (machines keep working while the player is away, like power).
const REFINE_SECONDS := 2.0                  # one ore -> one ingot / compound
const REFINERY_POWER_USE := 0.5
const CO2_CAPTURE_SECONDS := 15.0            # one CO2 capsule
const CO2_POWER_USE := 0.5
## The wreck: salvaged once with E.
const POWER_CELL_BONUS := 40.0               # emergency power cell: extra storage, delivered full
const WRECK_POTATOES := 5
const DEPOSIT_PIXELS := 30.0                 # how wide an ore deposit is drawn


## The data of one item from ITEMS, or an empty Dictionary.
static func item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})
