class_name Config
extends RefCounted
## Every tunable number of the game in one place. Change values here, not in the
## scripts that use them. Numbers follow GAME_FLOW.md.

# --- Time ---
const SOL_SECONDS := 15.0                    # 1 sol (Mars day) in real seconds

# --- Oxygen ---
const O2_START := 100.0
const O2_MAX := 100.0
const O2_DRAIN_PER_SOL := 6.0
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
const HARVEST_RANGE := 30.0                  # pixels from the player to the node

# --- Map rewards (used by scripts/world/world_gen.gd) ---
const METAL_NODE_COUNT := 12                 # 12 x 5 uses x 8 = 480 metal in the map
const ICE_NODE_COUNT := 6
const MAX_NODES_PER_CHAMBER := 3
const MIN_REWARD_DISTANCE := 0.4             # nearest deposit >= this share of the farthest walk
