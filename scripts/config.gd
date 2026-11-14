class_name Config
extends RefCounted
## Every tunable number of the game in one place. Change values here, not in the
## scripts that use them. Numbers follow GAME_FLOW.md.

# --- Scenes ---
const TITLE_SCENE := "res://scenes/TitleScreen.tscn"
const WORLD_SCENE := "res://scenes/World.tscn"

# --- Time ---
const SOL_SECONDS := 15.0                    # 1 sol (Mars day) in real seconds

# --- Oxygen ---
const O2_START := 100.0
const O2_MAX := 100.0
const O2_DRAIN_PER_SOL := 2.0
const O2_DRAIN_PER_SEC := O2_DRAIN_PER_SOL / SOL_SECONDS   # 0.4 per second
const O2_ZERO_GRACE := 6.0                   # seconds at 0 before "Out of oxygen"
const O2_HARVEST_COST := 1.0                 # O2 spent per harvest (metal or ice)
const O2_MIN_TO_HARVEST := 1.0               # below this you cannot harvest
const O2_LOW_WARNING := 25.0                 # HUD bar blinks red below this
const CRATER_O2_PENALTY := 4.0               # O2 lost each time you walk into a crater
const CRATER_COOLDOWN := 1.0                 # seconds before the same crater can hurt again

# O2 generator (the machine itself comes with the build menu)
const O2_GEN_RATE := 0.45                    # O2 per second while running
const O2_GEN_ON_BELOW := 95.0
const O2_GEN_OFF_AT := 100.0
const O2_GEN_WATER_PER_SEC := 0.15

# --- Power (GAME_FLOW Part 8) ---
const HAB_BATTERY_CAPACITY := 20.0           # the hab's own battery; it starts full
const BATTERY_CAPACITY_BONUS := 40.0         # each Battery machine adds this much storage
const SOLAR_OUTPUT := 3.0                    # power per second from one panel in full sun
const BACKUP_OUTPUT := 2.0                   # power per second from Backup power, day and night
const O2_GEN_POWER_USE := 1.0                # power per second while the O2 generator runs

# --- Water ---
const WATER_START := 50.0
const WATER_BASE_LIMIT := 60.0
const WATER_DRAIN_PER_SOL := 6.0
const WATER_DRAIN_PER_SEC := WATER_DRAIN_PER_SOL / SOL_SECONDS   # 0.4 per second
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
const METAL_NODE_COUNT := 12                 # 12 x 5 uses x 8 = 480 metal in the game
const ICE_NODE_COUNT := 6
const MAX_NODES_PER_CHAMBER := 3             # used by the cave generator
const MIN_REWARD_DISTANCE := 0.4             # nearest deposit >= this share of the farthest walk (caves)

# --- Surface: the base area (used by scripts/world/world_gen.gd) ---
const BUILD_PAD_COUNT := 10                  # marked squares for machines (the launch pad is extra)
const SURFACE_METAL_NODES := 2               # starter deposits on the surface; the rest is in the caves
const SURFACE_ICE_NODES := 1
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
##   guarded          how many of the richest rooms have a crater you cannot avoid in the door
##   crater_chance    chance of a small crater in each ordinary room
##   loops            extra doors that make a shortcut (each has a crater in it)
## The deposits of all caves plus the surface add up to METAL_NODE_COUNT / ICE_NODE_COUNT.
const CAVES: Array[Dictionary] = [
	{
		"id": "ice", "name": "Ice Cave", "seed": 101, "theme": "ice", "tint": Color(0.78, 0.92, 1.0),
		"layers": [
			{"cols": 5, "rows": 4, "metal": 0, "ice": 2, "guarded": 0, "crater_chance": 0.2, "loops": 1},
			{"cols": 6, "rows": 4, "metal": 1, "ice": 2, "guarded": 1, "crater_chance": 0.3, "loops": 1},
		],
	},
	{
		"id": "ore", "name": "Ore Cave", "seed": 202, "theme": "ore", "tint": Color(1.0, 0.86, 0.72),
		"layers": [
			{"cols": 5, "rows": 4, "metal": 2, "ice": 0, "guarded": 0, "crater_chance": 0.25, "loops": 1},
			{"cols": 6, "rows": 4, "metal": 3, "ice": 0, "guarded": 1, "crater_chance": 0.35, "loops": 1},
		],
	},
	{
		"id": "deep", "name": "Deep Cave", "seed": 303, "theme": "deep", "tint": Color(0.84, 0.78, 0.95),
		"layers": [
			{"cols": 5, "rows": 4, "metal": 1, "ice": 0, "guarded": 0, "crater_chance": 0.35, "loops": 1},
			{"cols": 6, "rows": 4, "metal": 1, "ice": 1, "guarded": 1, "crater_chance": 0.45, "loops": 2},
			{"cols": 6, "rows": 5, "metal": 2, "ice": 0, "guarded": 2, "crater_chance": 0.5, "loops": 2},
		],
	},
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
const PH := "res://art/placeholders/machines/"   # PLACEHOLDER art; swap the paths when real art exists
## The order machines are listed in (debug keys 1-6, and the book later).
const MACHINE_ORDER: Array[String] = ["solar", "battery", "o2_generator", "backup_power", "water_tank", "ascent"]
## Every machine. Art: "idle" and "running" are animations; "levels" are frames
## picked by how full something is (battery charge, water). "scale" sizes the art.
## "nasa" is the real-world link shown in the book. Facts marked (verify) must be
## checked before the submission, like in GAME_FLOW.md.
const MACHINES: Dictionary = {
	"solar": {
		"name": "Solar Panel", "metal": 15, "water": 0, "pad": "machine", "scale": 0.19,
		"idle": ["res://art/solar_panel/solar_panel_generate_01.png"],
		"running": ["res://art/solar_panel/solar_panel_generate_02.png", "res://art/solar_panel/solar_panel_generate_03.png",
			"res://art/solar_panel/solar_panel_generate_04.png", "res://art/solar_panel/solar_panel_generate_05.png"],
		"description": "Makes power from sunlight. Nothing at night, very little in a dust storm.",
		"how": "+3 power per second in full sun.",
		"nasa": "The rovers Spirit and Opportunity ran on solar panels; dust on the panels ended Opportunity in 2018 (verify).",
	},
	"battery": {
		"name": "Battery", "metal": 10, "water": 0, "pad": "machine", "scale": 0.135,
		"levels": ["res://art/battery/battery_empty.png", "res://art/battery/battery_low_25.png",
			"res://art/battery/battery_medium_50.png", "res://art/battery/battery_full_100.png"],
		"description": "Stores spare power for the night.",
		"how": "+40 power storage.",
		"nasa": "Mars rovers store energy in rechargeable lithium-ion batteries (verify).",
	},
	"o2_generator": {
		"name": "Oxygen Generator", "metal": 25, "water": 0, "pad": "machine", "scale": 1.0,
		"idle": [PH + "o2_generator_idle.png"],
		"running": [PH + "o2_generator_run1.png", PH + "o2_generator_run2.png"],
		"description": "Makes oxygen using power and a little water. Starts by itself when oxygen is below 95.",
		"how": "+0.45 oxygen per second, uses 1 power and 0.15 water per second.",
		"nasa": "MOXIE on the Perseverance rover made oxygen from the Martian air (verify).",
	},
	"backup_power": {
		"name": "Backup Power", "metal": 60, "water": 0, "pad": "machine", "scale": 1.0,
		"idle": [PH + "backup_power_idle.png"],
		"running": [PH + "backup_power_run1.png", PH + "backup_power_run2.png"],
		"description": "Makes power all the time, even at night and in a dust storm.",
		"how": "+2 power per second, always.",
		"nasa": "Curiosity and Perseverance use a radioisotope power system that works without sunlight (verify).",
	},
	"water_tank": {
		"name": "Water Tank", "metal": WATER_TANK_METAL_COST, "water": 0, "pad": "machine", "scale": 1.0,
		"levels": [PH + "water_tank_empty.png", PH + "water_tank_low.png", PH + "water_tank_medium.png", PH + "water_tank_full.png"],
		"description": "Stores more water, so you can carry more ice home.",
		"how": "+40 water limit.",
		"nasa": "There is water ice under the Martian ground; future crews plan to use it (verify).",
	},
	"ascent": {
		"name": "Ascent Vehicle", "metal": 80, "water": 40, "pad": "launch", "scale": 1.0,
		"idle": [PH + "ascent_vehicle_idle.png"],
		"running": [PH + "ascent_vehicle_run1.png", PH + "ascent_vehicle_run2.png"],
		"description": "The rocket home. Build it on the launch pad to launch.",
		"how": "Launches right away. You win.",
		"nasa": "NASA has studied a Mars Ascent Vehicle to lift samples off Mars (verify).",
	},
}
const MACHINE_WARNING_ICON := PH + "warning_icon.png"

## Debug keys for testing (turn OFF before the submission):
##   1-6 = start placing machine 1-6 of MACHINE_ORDER,  F1 = +50 metal and +50 water,
##   F2 = switch the sun on/off (day/night is not built yet).
const DEBUG_KEYS := true


## The data of one machine from MACHINES, or an empty Dictionary.
static func machine(machine_id: String) -> Dictionary:
	return MACHINES.get(machine_id, {})
