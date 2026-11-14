# Dust Storm Dispatch: Project Context (v3: Godot 2D pixel art, 16-hour scope)

Give this file to any AI assistant or teammate before they touch the project. It is the single source of truth.
- Game-balance numbers are TUNABLE placeholders.
- Real-world facts and engine settings marked (verify) must be checked before relying on them.
- Changes from v2: engine is now Godot 4 (GDScript), 2D top-down, pixel art in the style of Stardew Valley. Three.js is dropped.

## 1. One-liner
A lone astronaut lands on Mars with a minimal kit, walks around a pixel-art landscape gathering metal and ice, builds a small base, and must survive a dust storm replayed from NASA weather data, then launch home.

## 2. Pitch (30 seconds)
- Cozy-survival top-down pixel game (Stardew-like camera and look), runs in the browser.
- Real weather data drives the dust storm. Dust cuts solar power. Cold raises heating cost.
- Core lesson: Mars missions need backup power and on-site resource production.
- Story hook: the 2018 global dust storm ended the Opportunity rover's mission (verify details).
- Why 2D pixel: far faster to make look good in 16 hours than 3D, and the style is instantly readable to judges.

## 3. NASA resources used (cite all in submission)
From the provided resource list:
- Mission Design Lab (MDL) subsystems: power, thermal, comms, structures, risk. They define the machine categories and survival stats.
- Learning Game About Telescopes: design pattern copied: constrained choices, and an end screen that names real NASA missions matching the player's design.
- Mission segments (launch, space, ground, user): used in the briefing screen and end screen.
- Concept Maturity Levels: tech progression idea (idea, feasibility, design).
Data decision (made): the provided resource list contains tools and documents (MDL, GMAT, Mission Viz, CMLs, CubeSat 101, games), but NO Mars weather dataset. So:
- Game structure, subsystems, stages and end-screen content come from the provided resources (design references, not numeric data).
- Weather uses a generated 40-sol curve shaped like a real global dust storm (script in section 11). In the README and in game, call it "based on real storm behaviour", never "real data".
- Optional upgrade: P2 may spend at most 45 minutes in H0 to H1 looking for real Perseverance MEDA or Curiosity REMS summary data (NASA PDS). If it is not usable by H1, drop it for good.

## 4. Game design

### 4.1 Loop
1. Read the sol forecast (HUD plus radio messages).
2. Walk to resource nodes, hold E to harvest (costs suit O2).
3. Press B, pick a machine, click a tile in the base zone to place it.
4. Keep O2, water, power and base temperature alive.
5. Survive the storm. Build the ascent vehicle. Launch.

### 4.2 Starting state
- Habitat (pre-placed, centre of map), 2 solar panels, 1 battery (pre-placed beside hab).
- O2 100, water 80, metal 30, battery charge 50.
- Food is NOT tracked (rations assumed to cover the mission).
- Player stands next to hab. Briefing screen explains controls in 4 lines.

### 4.3 Resources
| Resource | Source | Use |
|---|---|---|
| Metal | Ore nodes (finite) | All machines |
| Water | Ice nodes (finite) or Ice drill (infinite) | Drinking, O2 generator, ascent propellant |
| O2 | Starting tanks, O2 generator | Breathing, harvesting |
| Power | Solar, Backup power | All machines and heating |
CO2 is free and implicit (used by the O2 generator).

### 4.4 Machines (exactly 7)
| id | Name | Cost | Power | Effect |
|---|---|---|---|---|
| solar | Solar panel | 15 metal | gen 3.0 peak | Output = 3.0 * sun * daylight * panel_clean |
| battery | Battery | 10 metal | none | +40 battery capacity |
| drill | Ice drill | 20 metal | uses 0.5/s | +0.35 water/s at full power |
| o2gen | O2 generator | 25 metal | uses 1.0/s | uses 0.15 water/s, makes 0.45 O2/s (MOXIE-style, verify) |
| wiper | Dust wiper | 15 metal | uses 0.2/s | +0.01 panel_clean per s |
| rtg | Backup power | 60 metal | gen 2.0 constant | Storm-proof (RTG or fission style, verify) |
| ascent | Ascent vehicle | 150 metal + 60 water | none | Win condition |
Starting machines (free): 2 solar, 1 battery. Base battery capacity (hab) 20, so start capacity is 60.
Machines can be toggled on/off by pressing E next to them (strategy: shut down O2 gen when O2 is full).

### 4.5 Win and lose
- Win: ascent vehicle built, countdown 3 seconds, launch sequence, end screen.
- Lose: O2 or water at 0 for 6 game-seconds; or hab integrity at 0; or sol 35 reached ("return window closed").
- Score: sol of launch (earlier is better), resources left, power diversity (solar plus backup), no integrity damage.
- Demo mode (toggle on title screen): storm peaks around sol 5, window closes at sol 20. Judges see everything in about 5 minutes.

## 5. Balance model (all tunable)
Time: 1 sol = 20 real seconds at 1x. Speed keys: 1 = 1x, 2 = 3x.
Per sol: O2 -8 (0.4/s), water -6 (0.3/s).
Harvest: metal node gives 8 metal, 4 charges each. Ice node gives 6 water, 4 charges each. Each harvest costs 2 O2 and takes 1.5 s (hold E).
Nodes: 12 metal, 8 ice. Total metal available 384. Ascent plus essentials need roughly 340. This forces exploring the whole map.
Weather formulas:
- `sun_factor = clamp(exp(-0.35 * tau), 0.03, 1)` (game approximation, not physics).
- `daylight = max(0, sin(TAU * (sol_t - 0.25)))` (day is sol_t 0.25 to 0.75).
- `temp(t) = mid + amp * sin(TAU * (sol_t - 0.35))` using that sol's tmin/tmax.
- `heat_need = max(0, 15 - temp) * 0.01` units/s.
- Panel dirt: `panel_clean -= (0.0004 * tau + 0.0002 * wind) * dt`, min 0.2. Wipers restore.
Worked check (verify with playtests):
- Normal sol (tau 0.6): 2 panels average about 1.5/s. Heating average about 0.75/s. Surplus charges battery.
- Full base wants about 2.4/s (heat 0.7, O2 gen 1.0, drill 0.5, wiper 0.2). Players need about 4 to 5 panels.
- Storm (tau 6): sun_factor 0.12. 5 panels average about 0.6/s. Deficit about 1.8/s for 8 sols = roughly 290 units. Backup power (2.0/s) covers most of it, batteries cover the rest. Solar-only runs should fail or barely survive.
If solar-only players easily win, raise storm tau or lower panel output. If everyone dies, raise starting metal.

## 6. Tech stack
- Godot 4.3 or newer (verify; TileMapLayer node is used). GDScript only. No C#, no plugins.
- Renderer: GL Compatibility (required for web export).
- Base resolution 320x180, integer-scaled to 1280x720. Nearest-neighbour filtering everywhere.
- Web export, single-threaded (verify the option name in the export dialog for your Godot version). Test with a local HTTP server, not file://.
- Submission is a GitHub repo. The repo contains the Godot project plus a ready-to-play web export in `docs/` (GitHub Pages serves it, single-threaded export needs no special headers, verify). Deploy a blank build in hour 1.
- Art: Pixelorama, LibreSprite, or Aseprite. CC0 packs (Kenney etc.) allowed if licence checked (verify). Free tool: Tiled not needed; the map is generated by script.
- Audio: COULD only. Browsers block audio until first click; the title screen click handles it.

Project Settings to change (verify exact paths in your version):
- Display > Window > Size: viewport 320x180, window override 1280x720.
- Display > Window > Stretch: mode `viewport`, aspect `keep`, scale mode `integer`.
- Rendering > Textures > Canvas Textures > Default Texture Filter: `Nearest`.
- Rendering > 2D > Snap: snap 2D transforms and vertices to pixel ON.
- Rendering > Renderer: `gl_compatibility`.
- Export > Web preset > Resources > Filters to export non-resource files: `*.json` (otherwise weather.json is missing in the web build).
- Autoloads (in this order): `Config`, `WeatherDB`, `GameState`, `Bus`.
- Input Map actions: `move_left` (A, Left), `move_right` (D, Right), `move_up` (W, Up), `move_down` (S, Down), `interact` (E), `build_menu` (B), `cancel` (Escape), `speed_1` (1), `speed_2` (2), `pause` (P), `toggle_machine` (E, handled by the same interact action), debug keys F1 to F4.

## 7. Project structure
```
res://
  project.godot
  data/weather.json
  art/        tiles.png player.png nodes.png machines.png hab.png ui.png rocket.png
  fonts/      pixel.ttf
  scenes/     Main.tscn World.tscn Player.tscn ResourceNode.tscn Machine.tscn
              Hab.tscn HUD.tscn BuildMenu.tscn Briefing.tscn EndScreen.tscn DustDevil.tscn
  scripts/
    autoload/ config.gd weather_db.gd game_state.gd bus.gd
    world/    world_gen.gd player.gd resource_node.gd machine.gd build_controller.gd
              day_night.gd dust_devil.gd launch.gd
    ui/       hud.gd build_menu.gd briefing.gd end_screen.gd
  shaders/    dust_haze.gdshader
```
Rule: simulation lives in `game_state.gd` and `machine.gd` and never reads the scene tree for rendering. Rendering and UI only read state and listen to signals.

## 8. Scene tree
```
Main (Node)
  World (Node2D)
    Ground (TileMapLayer)          // sand variants, generated
    Walls (TileMapLayer)           // rock border with collision
    Entities (Node2D, y_sort_enabled = true)
      Hab (StaticBody2D)
      Player (CharacterBody2D)
        AnimatedSprite2D, CollisionShape2D, Camera2D, InteractRay (RayCast2D)
      Nodes (Node2D)               // ResourceNode instances
      Machines (Node2D)            // placed Machine instances
    BuildController (Node2D)       // holds ghost Sprite2D
  DayNight (CanvasModulate)
  DustLayer (CanvasLayer, layer 5)
    DustRect (ColorRect, full screen, dust_haze shader)
  HUD (CanvasLayer, layer 10)
  Screens (CanvasLayer, layer 20)  // Briefing, BuildMenu, EndScreen, Pause
```
Notes: CanvasModulate tints only its own canvas (the world). CanvasLayers (HUD, screens) are not tinted (verify visually). The dust shader reads the screen below its layer, so HUD stays clean.

## 9. Implementation detail, system by system

### 9.1 Autoload: Config (`config.gd`)
Constants only: SOL_SECONDS 20.0, WINDOW_SOL 35, HEAT_COEF 0.01, HEAT_THRESHOLD 15.0, MACHINE_DEFS dictionary (section 9.6), TILE 16, MAP_SIZE Vector2i(48, 32), BUILD_RECT Rect2i(17, 10, 14, 12) in tile coords (centred on hab), SEED 1337. Demo mode flag `demo := false` overrides WINDOW_SOL to 20 and shifts the weather rows (storm earlier).

### 9.2 Autoload: WeatherDB (`weather_db.gd`)
```gdscript
extends Node

var rows: Array = []

func _ready() -> void:
	var txt := FileAccess.get_file_as_string("res://data/weather.json")
	var parsed = JSON.parse_string(txt)
	assert(parsed != null and parsed.has("sols"), "weather.json missing or invalid")
	rows = parsed["sols"]

func row(sol: int) -> Dictionary:
	return rows[clampi(sol - 1, 0, rows.size() - 1)]

func at(sol: int, t: float) -> Dictionary:
	var a: Dictionary = row(sol)
	var b: Dictionary = row(sol + 1)
	var tau := lerpf(a.tau, b.tau, t)
	var wind := lerpf(a.wind_ms, b.wind_ms, t)
	var mid := (a.tmax_c + a.tmin_c) * 0.5
	var amp := (a.tmax_c - a.tmin_c) * 0.5
	var temp := mid + amp * sin(TAU * (t - 0.35))
	return {"tau": tau, "wind": wind, "temp": temp}

func sun_factor(tau: float) -> float:
	return clampf(exp(-0.35 * tau), 0.03, 1.0)
```
Demo mode: `Config.demo` makes `row()` read `sol + 9` so the storm arrives 9 sols earlier (storm centre in the data is sol 14, so it peaks around sol 5 and is already building at sol 1 to 3). Verify with the generated data.

### 9.3 Autoload: GameState (`game_state.gd`)
Holds all simulation state and runs the sim in `_process`.
```gdscript
extends Node

signal sol_changed(sol: int)
signal game_ended(won: bool, reason: String)

var running := false
var build_mode := false
var speed := 1.0
var sol := 1
var sol_t := 0.0
var o2 := 100.0
var water := 80.0
var metal := 30.0
var battery := 50.0
var hab_temp := 20.0
var integrity := 100.0
var panel_clean := 1.0
var power_gen := 0.0
var power_use := 0.0
var heat_eff := 1.0
var o2_zero := 0.0
var water_zero := 0.0
var machines: Array = []
var current_weather: Dictionary = {}

func battery_cap() -> float:
	var cap := 20.0
	for m in machines:
		if m.id == "battery":
			cap += 40.0
	return cap

func daylight() -> float:
	return maxf(0.0, sin(TAU * (sol_t - 0.25)))

func _process(delta: float) -> void:
	if not running:
		return
	var dt := delta * speed
	_advance_clock(dt)
	current_weather = WeatherDB.at(sol, sol_t)
	_update_dirt(dt)
	_update_power_and_machines(dt)
	_update_life_support(dt)
	_check_end(dt)

func _advance_clock(dt: float) -> void:
	sol_t += dt / Config.SOL_SECONDS
	if sol_t >= 1.0:
		sol_t -= 1.0
		sol += 1
		sol_changed.emit(sol)

func _update_dirt(dt: float) -> void:
	var w := current_weather
	panel_clean = maxf(0.2, panel_clean - (0.0004 * w.tau + 0.0002 * w.wind) * dt)
```
Power and machine update (fractional allocation, no flicker):
```gdscript
func _update_power_and_machines(dt: float) -> void:
	var w := current_weather
	var sun := WeatherDB.sun_factor(w.tau) * daylight()
	var gen := 0.0
	for m in machines:
		gen += m.power_output(sun, panel_clean)
	power_gen = gen

	var budget := gen * dt + battery
	var used := 0.0

	# heating first (priority 1)
	var heat_need := maxf(0.0, Config.HEAT_THRESHOLD - w.temp) * Config.HEAT_COEF
	var heat_cost := heat_need * dt
	heat_eff = 1.0 if heat_cost <= 0.0 else clampf(budget / heat_cost, 0.0, 1.0)
	budget -= heat_cost * heat_eff
	used += heat_need * heat_eff

	# machines by priority: o2gen (2), drill (3), wiper (4)
	var consumers: Array = machines.filter(func(m): return m.power_need() > 0.0)
	consumers.sort_custom(func(a, b): return a.priority < b.priority)
	for m in consumers:
		var cost: float = m.power_need() * dt
		var eff := 1.0 if cost <= 0.0 else clampf(budget / cost, 0.0, 1.0)
		m.efficiency = eff
		budget -= cost * eff
		used += m.power_need() * eff
	for m in machines:
		if m.power_need() <= 0.0:
			m.efficiency = 1.0
	power_use = used
	battery = clampf(budget, 0.0, battery_cap())

	for m in machines:
		m.produce(dt)
```
Note: machines that are toggled off return `power_need() == 0` and `power_output == 0` (solar and rtg still produce when toggled on only; toggling is allowed for consumers only).
Life support:
```gdscript
func _update_life_support(dt: float) -> void:
	o2 -= 8.0 / Config.SOL_SECONDS * dt
	water -= 6.0 / Config.SOL_SECONDS * dt
	o2 = maxf(o2, 0.0)
	water = maxf(water, 0.0)
	var target := lerpf(current_weather.temp, 20.0, heat_eff)
	hab_temp = move_toward(hab_temp, target, 0.6 * dt)
	if hab_temp < 0.0:
		integrity = maxf(0.0, integrity - 1.0 * dt)
	o2_zero = o2_zero + dt if o2 <= 0.0 else 0.0
	water_zero = water_zero + dt if water <= 0.0 else 0.0

func _check_end(_dt: float) -> void:
	if o2_zero >= 6.0:
		_end(false, "Out of oxygen")
	elif water_zero >= 6.0:
		_end(false, "Out of water")
	elif integrity <= 0.0:
		_end(false, "Habitat frozen")
	elif sol > Config.WINDOW_SOL:
		_end(false, "Return window closed")

func _end(won: bool, reason: String) -> void:
	running = false
	game_ended.emit(won, reason)
```
Also: `reset()` re-initialises every variable, clears `machines`, and is called by the restart button (Restart must work from the end screen without reloading the page).

### 9.4 Autoload: Bus (`bus.gd`)
Signals only, for UI and world decoupling: `message(text: String)`, `harvested(kind: String, amount: float, pos: Vector2)`, `machine_placed(m)`, `launch_requested()`.

### 9.5 Player (`player.gd`)
```gdscript
extends CharacterBody2D

const SPEED := 55.0
const HARVEST_TIME := 1.5
var facing := Vector2.DOWN
var harvesting: Node = null
var harvest_progress := 0.0
@onready var ray: RayCast2D = $InteractRay
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	if not GameState.running or GameState.build_mode:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if harvesting != null:
		dir = Vector2.ZERO
	velocity = dir * SPEED
	if dir != Vector2.ZERO:
		facing = Vector2(signf(dir.x), 0.0) if absf(dir.x) > absf(dir.y) else Vector2(0.0, signf(dir.y))
		ray.target_position = facing * 14.0
	move_and_slide()
	_animate(dir)
	_handle_interact(delta)
```
(`build_mode` is a bool on GameState, set by the build controller while the ghost is active.)
Interaction: RayCast2D `collide_with_bodies = true`, collision mask = layer 2 (interactables: ResourceNode, Machine, Hab). While `interact` is held and the ray hits a ResourceNode with charges > 0 and `GameState.o2 >= 2.0`: accumulate progress; at 1.5 s call `node.harvest()` which adds the resource, deducts 2 O2, emits `Bus.harvested`, and decrements charges. Releasing the key cancels. If the ray hits a Machine: `interact` (tapped, not held) calls `machine.toggle()`.
Animation: AnimatedSprite2D with animations `idle_down`, `idle_up`, `idle_side`, `walk_down`, `walk_up`, `walk_side` (2 frames each, 6 fps). Left is `walk_side` with `flip_h = true`. Harvesting plays `walk_*` frame 0 plus a small particle puff.
Camera2D child of Player: `position_smoothing_enabled = true`, speed 8, limits set to map pixel bounds in `world_gen.gd`. Zoom stays at 1 (integer scaling does the rest).
Collision: player capsule or rect about 8x6 px at the feet. Hab, machines, nodes, rock walls have collision on layer 1; interactables also on layer 2.

### 9.6 Machines (`machine.gd`) and definitions
Definitions live in `config.gd` as a Dictionary (faster than .tres for a 16-hour build):
```gdscript
const MACHINE_DEFS := {
	"solar":  {"name": "Solar panel", "metal": 15, "water": 0, "priority": 0, "frame": 0},
	"battery":{"name": "Battery", "metal": 10, "water": 0, "priority": 0, "frame": 1},
	"drill":  {"name": "Ice drill", "metal": 20, "water": 0, "priority": 3, "frame": 2},
	"o2gen":  {"name": "O2 generator", "metal": 25, "water": 0, "priority": 2, "frame": 3},
	"wiper":  {"name": "Dust wiper", "metal": 15, "water": 0, "priority": 4, "frame": 4},
	"rtg":    {"name": "Backup power", "metal": 60, "water": 0, "priority": 0, "frame": 5},
	"ascent": {"name": "Ascent vehicle", "metal": 150, "water": 60, "priority": 0, "frame": 6},
}
```
`machine.gd` (StaticBody2D) exposes: `id`, `priority`, `efficiency`, `enabled`, `power_output(sun, clean) -> float`, `power_need() -> float`, `produce(dt)`, `toggle()`.
- `power_output`: solar returns `3.0 * sun * clean`; rtg returns 2.0; others 0.0.
- `power_need`: drill 0.5, o2gen 1.0, wiper 0.2 if `enabled` else 0.0. Others 0.0.
- `produce(dt)`: drill: `GameState.water += 0.35 * efficiency * dt`. o2gen: water use `0.15 * efficiency * dt` (scale efficiency down if water is short), `GameState.o2 += 0.45 * eff * dt`. wiper: `GameState.panel_clean = minf(1.0, GameState.panel_clean + 0.01 * efficiency * dt)`.
- Visual feedback: sprite `modulate` brightness follows `efficiency` (dim when starved). Small status icon above the machine: green dot (running), red dot (no power), grey (off). Solar panel sprite brightens with `sun * clean`.
- The ascent machine on placement starts the launch sequence (9.10).

### 9.7 Resource nodes (`resource_node.gd`)
StaticBody2D with `kind` ("metal" or "ice"), `charges := 4`. `harvest()`:
```gdscript
func harvest() -> void:
	if charges <= 0 or GameState.o2 < 2.0:
		return
	GameState.o2 -= 2.0
	if kind == "metal":
		GameState.metal += 8.0
	else:
		GameState.water += 6.0
	charges -= 1
	Bus.harvested.emit(kind, 8.0 if kind == "metal" else 6.0, global_position)
	sprite.frame = 0 if charges > 0 else 1   # full or depleted art
	if charges == 0:
		$CollisionShape2D.set_deferred("disabled", true)
```
Floating text "+8 metal" is a Label tweened up 10 px and faded over 0.8 s, created by the HUD or World listening to `Bus.harvested`.

### 9.8 World generation (`world_gen.gd`)
Runs once in `_ready` using `RandomNumberGenerator` with `Config.SEED` (same map every run, so balance is testable).
1. Fill `Ground` with sand tiles. Pick tile variant from `FastNoiseLite` (frequency 0.08) mapped to 3 sand variants plus 1 dark-sand patch variant.
2. Border: `Walls` layer ring of rock tiles around the map (collision from tileset physics layer).
3. Place Hab at tile (24, 16).
4. Place 12 metal nodes and 8 ice nodes by rejection sampling: random tile inside the map, at least 4 tiles from hab, at least 3 tiles from other nodes, not on border. Mix distances (some near, most far) by using 3 distance rings: 4 to 8, 8 to 14, 14 to 20 tiles. Ensure 3 metal and 2 ice in the nearest ring so the first minutes are playable.
5. Scatter 40 decorative rocks (no collision, or small collision for 10 of them) on the Decor layer or as Sprite2D.
6. Set Camera2D limits to `Rect2(0, 0, 48*16, 32*16)`.
7. Place the starting machines: 2 solar and 1 battery in free tiles adjacent to hab.

### 9.9 Build controller (`build_controller.gd`)
States: `idle`, `placing(def_id)`. Flow:
1. `build_menu` opens the BuildMenu (list of 7 with icon, name, cost, grey if unaffordable; keys 1 to 7 select).
2. Selecting a def sets `placing`, shows `Ghost` (Sprite2D, 50% alpha), sets `GameState.build_mode = true`.
3. `_process`: `var tile := ground.local_to_map(get_global_mouse_position())`; `ghost.global_position = ground.map_to_local(tile)`. Valid if tile inside `Config.BUILD_RECT`, not in `occupied` (Dictionary of Vector2i), not a wall tile, and resources are enough. Ghost tinted green when valid, red when not.
4. Left click on valid: deduct cost, instantiate `Machine.tscn`, set id, add to `Entities/Machines`, `occupied[tile] = machine`, append to `GameState.machines`, emit `Bus.machine_placed`. Stay in placing mode (shift to place many); Escape or right click cancels.
5. `ascent` can only be placed once; the menu greys it out after.
Occupied tiles must also include the hab footprint, resource nodes, and starting machines (filled in world generation).

### 9.10 Launch sequence (`launch.gd`)
On ascent placement: freeze player input, `Bus.message("Ignition in 3...")`, Timer counts 3 s (3, 2, 1 messages), then tween the rocket sprite `position.y -= 220` over 2.5 s with ease-in, camera shake (random offset up to 2 px, 1.5 s), fade a ColorRect to white, then `GameState._end(true, "Launch successful")`.

### 9.11 Day and night plus dust (`day_night.gd`, `dust_haze.gdshader`)
CanvasModulate colour each frame:
```gdscript
func _process(_d: float) -> void:
	var day := lerpf(0.0, 1.0, GameState.daylight())
	var base := night_color.lerp(day_color, day)          # night_color ~ (0.25, 0.30, 0.55), day_color = white
	var tau := GameState.current_weather.get("tau", 0.6)
	var dust_amount := clampf(tau / 8.0, 0.0, 1.0)
	color = base.lerp(base * storm_tint, dust_amount)      # storm_tint ~ (1.0, 0.65, 0.4)
```
Dust haze full-screen shader on `DustRect` (set `strength` from tau, `wind` from weather each frame; keep noise pixel-snapped):
```glsl
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float wind = 0.0;
uniform vec4 dust_color : source_color = vec4(0.78, 0.45, 0.25, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 px = floor(UV * vec2(320.0, 180.0)) / vec2(320.0, 180.0);
	vec4 base = texture(screen_tex, SCREEN_UV);
	float n = vnoise(px * vec2(24.0, 14.0) + vec2(TIME * wind * 0.15, 0.0));
	float haze = strength * (0.55 + 0.45 * n);
	COLOR = vec4(mix(base.rgb, dust_color.rgb, haze), 1.0);
}
```
`strength = clampf(tau / 8.0, 0.0, 0.85)`. Streaks: a `CPUParticles2D` (not GPU, safer on web) child of Camera2D: 1 to 2 px rectangles moving horizontally, amount scaled by wind, max 120 particles.
Vignette: optional second ColorRect with a radial-darkening shader (COULD).

### 9.12 Dust devil event (SHOULD)
Weather rows may contain `"event": "dust_devil"` (generated at sol 7). When that sol begins, spawn `DustDevil.tscn` (animated sprite, 3 frames) at a random edge, move across the map in 6 s. If it passes within 24 px of any solar panel: `panel_clean = minf(1.0, panel_clean + 0.4)` and `Bus.message("Dust devil cleaned your panels")` (real rovers saw wind cleaning events, verify). Cut first if behind.

### 9.13 Radio forecast (SHOULD)
On each `sol_changed`: if `WeatherDB.row(sol + 2).tau - WeatherDB.row(sol).tau > 1.5` show `"ORBITER: dust opacity rising. Storm expected in ~2 sols."` Once the storm peaks: `"Opacity at maximum. Conserve power."` When tau drops below 1.5 after the storm: `"Skies clearing."` Messages appear in a HUD ticker for 6 s.

### 9.14 HUD (`hud.gd`) layout at 320x180
- Top-left: icon + number rows for O2, Water, Metal (8x8 icons, pixel font 8 px). Bars 40x4 px under each.
- Top-right: "SOL 12 / 35", clock bar showing sol_t, sun/moon icon.
- Bottom-left: power block: battery bar (charge/cap), `+gen / -use` numbers, hab temp.
- Bottom-centre: message ticker (one line, fades).
- Bottom-right: forecast strip: next 5 sols as small bars of tau (height) with storm bars in orange. This is the main teaching tool: players see the storm coming.
- Harvest progress: small bar above the player while holding E.
- Warnings: blinking red icon if O2 < 25, water < 20, battery < 10, hab_temp < 5.

### 9.15 Screens
- Title: game name, "Start", "Demo mode" checkbox, click starts audio context.
- Briefing (one screen, 6 lines max): mission segments (launch, space, ground, user) in one line each; controls: WASD move, hold E harvest, B build, 1/2 speed; goal: build the ascent vehicle before sol 35.
- End screen: result, reason, sol reached, score. Section "Your design": list placed machines with counts, power diversity label. Section "Real NASA parallels" (all claims verify):
  - Backup power: Curiosity and Perseverance use radioisotope power (MMRTG).
  - O2 generator: MOXIE on Perseverance made oxygen from Mars CO2.
  - Solar panels and dust: Opportunity (2018 storm) and InSight (dust-covered panels).
  - Dust wiper: wind cleaning events on Spirit and Opportunity.
  - Ascent vehicle: Mars Ascent Vehicle concept in Mars Sample Return planning (status uncertain, verify).
  Buttons: Restart, Quit.

## 10. Art specification
- Tile and sprite grid 16x16. Base screen 320x180 = 20 x 11.25 tiles.
- Palette (proposal, 16 colours, keep strict): `#1b1218 #2b1a1a #4a2620 #7a3b2a #a8512f #c9703a #e09a52 #f0c27a #f6e2b3 #5a4a48 #8a7a72 #f4efe6` plus UI cold: `#1b2238 #2f4a73 #5b8fb9 #9ad1d4` and danger `#d1495b`. Use hue shifting (shadows toward purple-brown, highlights toward yellow) for the Stardew-like warmth.
- Tiles (tiles.png, 16x16): sand A, B, C, dark-sand patch, pebbles, rock wall (with edge variants), hab floor. 8 to 10 tiles. Light source top-left.
- Player (16x16, player.png): idle and 2-frame walk for down, up, side. Suit is white with orange accents, visor reflects blue. 9 frames. Left uses flip_h.
- Nodes (16x16, nodes.png): metal ore full, metal depleted, ice full, ice depleted. 4 frames.
- Hab (48x32): dome or module with door, small light. 1 frame, optional blinking light second frame.
- Machines (16x16 each, machines.png): solar panel (tilted), battery, ice drill (animated 2 frames), O2 generator (animated 2 frames), dust wiper (small arm), backup power (RTG with glow, 2 frames). Rocket (rocket.png) 32x48, 2 frames of engine flame.
- Dust devil: 3 frames 16x24.
- UI icons (8x8): O2, water, metal, power, thermometer, sol, sun, moon, warning. 9 icons.
- Particles: 1 px and 2 px squares, drawn in code (ColorRect or particle texture of white 2x2).
- Font: a pixel font with permissive licence, size 8 (for example Pixelify Sans or m5x7, verify the licence before use). Import with antialiasing off and `Nearest` filter.
- Placeholder rule (hour 0): every sprite exists as a flat coloured 16x16 square on day 1 so coding never waits for art. Replace by overwriting the PNG with the same name and frame layout.
- Art budget: one person, about 4 hours total across the project. If art is behind at H9, keep placeholders for machines but give each a distinct silhouette and colour.

## 11. Weather data pipeline
`weather.json` format:
```json
{ "source": "derived from MEDA/REMS trends", "sols": [
  { "sol": 1, "tau": 0.6, "tmin_c": -85, "tmax_c": -30, "wind_ms": 5, "event": "" } ] }
```
Real data path (only if it works in the first hour): download MEDA or REMS summary tables from NASA PDS, resample to per-sol tau proxy, tmin, tmax, wind; trim to 40 sols; save as above. Keep a README line naming the dataset and sol range.
Fallback generator (Python, run once, commit the JSON):
```python
import json, math, random
random.seed(7)
sols = []
for s in range(1, 41):
    storm = math.exp(-((s - 14) / 3.2) ** 2)          # 0..1, peak at sol 14
    tau = 0.6 + 5.4 * storm + random.uniform(-0.1, 0.1)
    tmin = -85 + 18 * storm + random.uniform(-2, 2)    # dust warms nights (verify)
    tmax = -30 - 6 * storm + random.uniform(-2, 2)     # dust cools days
    wind = 5 + 10 * storm + random.uniform(-1, 1)
    sols.append({"sol": s, "tau": round(max(tau, 0.3), 2), "tmin_c": round(tmin, 1),
                 "tmax_c": round(tmax, 1), "wind_ms": round(wind, 1),
                 "event": "dust_devil" if s == 7 else ""})
json.dump({"source": "derived, shaped like a real global storm", "sols": sols},
          open("weather.json", "w"), indent=1)
```
Always verify real-world claim in the submission text: say "based on" unless the numbers are genuinely NASA data.

## 12. Web export checklist
1. Install Godot web export templates (Editor > Manage Export Templates).
2. Project > Export > Add > Web. Thread support off (single-threaded) unless you control hosting headers (verify option name).
3. Resources > Filters to export non-resource files: `*.json`.
4. Export to `docs/index.html` (inside the repo). Test with `python3 -m http.server` inside `docs/`, open `http://localhost:8000`.
5. Commit `docs/`, then GitHub repo Settings > Pages > deploy from branch `main`, folder `/docs`.
6. Re-export and commit after every milestone (H1, H6.5, H12, H14). A working build must always exist in the repo.
Pitfalls: first load of a web build is a few MB (keep PNGs small, no big audio); audio starts only after a click; fonts must be imported as resources; do not use `OS.execute`, threads, or file writes (no save system).

## 13. Debug tools and testing
Debug keys (remove or hide at H12, or keep behind a flag):
- F1: add 50 metal and 50 water. F2: skip 1 sol. F3: force tau = 7 (instant storm). F4: toggle speed 10x. F5: print state to console.
Test checklist (run at H7 to H9 and again at H12.5 to H14):
- [ ] Can the player reach every node without getting stuck on colliders?
- [ ] Harvest cancels cleanly when releasing E or moving; depleted nodes lose collision.
- [ ] Cannot place on hab, nodes, walls, or outside the build rectangle; cannot place with insufficient resources.
- [ ] Power never goes negative; battery never exceeds capacity; toggle off removes power need.
- [ ] Solar-only strategy fails or barely survives the storm; solar plus RTG plus batteries wins comfortably.
- [ ] Every lose condition triggers once and shows the end screen; Restart resets all state and the map.
- [ ] Ascent can be built only once; launch plays; win screen shows.
- [ ] Demo mode reaches storm by sol 5 and ends the game by sol 20 at the latest.
- [ ] Web build loads in a fresh browser, weather.json loads, no console errors (check the browser console).
- [ ] Runs at 60 fps on a mid-range laptop; particle count capped.
- [ ] Full playthrough by someone who has never seen the game, without instructions beyond the briefing.

## 14. Scope
MUST: generated map, player movement and harvest, 7 machines with build mode, HUD (O2, water, metal, power, temp, sol), weather-driven solar and heating, one storm, day/night tint, dust haze shader, win/lose and restart, briefing, end screen with NASA parallels, web build deployed, demo video.
SHOULD: forecast strip, radio messages, dust particles, dust devil, machine status icons, harvest floating text.
COULD: sound effects and ambient wind, title animation, vignette, second map seed.
CUT: food, fabricator and tech tiers, rover, greenhouse, comms relay, voxel digging, save and load, multiplayer, live data, mobile controls, multiple biomes.

## 15. 16-hour plan (H = hours from start)
Budget: build 6.5h, test and debug 3.5h, polish 2.5h, demo and submission 2h, rest 1.5h (three 30-min breaks). Total 16h.
Team of 4 (P1 to P4): roles, ownership, contracts and per-person hours are in section 20. The table below is the whole-team milestone view.

| Hours | Work | Done when |
|---|---|---|
| H0 to H1 | Install Godot 4.3+, create project with all settings (section 6), folder structure, placeholder sprites, export and host a blank web build. Check real weather data feasibility. | Blank pixel scene runs on the public link |
| H1 to H3 | A: world_gen, tilemap, player move, camera, collisions. B: weather_db, game_state clock, life support, weather.json (generator). C: art batch 1 (tiles, player, nodes, hab) and font. | Walk around a generated map with ticking sol clock |
| H3 to H5 | A: resource nodes, harvest, build controller, machine scene. B: power model, machine defs and effects, debug keys. C: HUD scene, build menu, art batch 2 (machines). | Gather, build all 7 machines, see power numbers react |
| H5 to H6.5 | Wire weather into solar, heating, day/night tint, dust shader, forecast strip. Win/lose and launch sequence stub. | Full loop playable start to finish, ugly OK |
| H6.5 to H7 | BREAK. Commit, export, deploy. | Link works |
| H7 to H9 | Playtest 5+ runs. Balance with section 5. Fix bugs. Restart flow. Briefing and end screen text. | Solar-only fails, solar plus RTG wins |
| H9 to H9.5 | BREAK | |
| H9.5 to H12 | Polish: art pass 3 (animations, ascent rocket, dust devil), particles, harvest floating text, status icons, radio messages, screen shake. | Looks like a real game |
| H12 | FEATURE FREEZE. Bug fixes only. Hide debug keys. | |
| H12 to H12.5 | BREAK | |
| H12.5 to H14 | Final test (section 13) on two other devices and browsers. Performance. Fix. Deploy. | Checklist green |
| H14 to H16 | Demo video (screen plus voice, 2 to 3 min), submission text citing NASA resources, final deploy, buffer. | Submitted |
Cut order if behind: sound, vignette, dust devil, particles, radio messages, status icons, art pass 3.
Never cut: win and lose, storm, NASA parallels on end screen, public link, demo video.

## 16. Visual and feel guidelines
- Stardew-like: warm, readable, slightly oversized sprites, soft limited palette, gentle camera smoothing, small satisfying feedback (puff, floating text, screen shake on launch).
- Mars specifics: butterscotch day, deep blue night, orange-brown storm. Blue sunsets are real on Mars (verify), optional detail.
- Keep the HUD minimal and legible at 320x180.

## 17. Submission checklist
- [ ] Repo is public (or shared as the event requires) and clones cleanly
- [ ] README complete (section 20.6) and the web build in `docs/` plays in a fresh browser
- [ ] Project opens in Godot with no errors and F5 runs from a clean clone
- [ ] 2 to 3 minute demo video linked in README, storm shown, ends with launch
- [ ] NASA resources named and explained (section 3)
- [ ] Data source stated honestly (real vs derived)
- [ ] Summary, team, tools used, art credits and licences
- [ ] Controls explained in game

## 18. Rules for the AI assistant
- Be precise. Working GDScript only (Godot 4 syntax, typed where practical). No shortcuts, no pseudo-code left behind.
- Keep simulation separate from rendering.
- Never call live web APIs at runtime. Never write files at runtime.
- Free nodes you remove (`queue_free`). Cap particles. Use CPUParticles2D.
- Do not add features outside section 14 MUST and SHOULD without asking.
- Mark any uncertain claim about Mars, NASA, or Godot settings as (verify).
- When changing a number in section 5, also update section 4 so the document stays consistent.

## 19. Decisions (formerly open questions)
1. Team: 4 people. P3 is the dedicated artist.
2. Deadline: 16 hours from start. Submission: a repo.
3. Weather data: generated curve (no dataset in provided resources). Optional 45-minute real-data attempt by P2, dropped at H1.
4. Hosting: GitHub repo plus `docs/` web build via GitHub Pages.
Still open: licence for the repo (ask event rules), and whether the event wants a video link in the repo.

## 20. Team, ownership, handoffs, repo

### 20.1 Roles
| Person | Role | Owns |
|---|---|---|
| P1 | Gameplay engineer | World generation, player, camera, collisions, resource nodes, build controller, machine scene visuals, launch sequence, dust devil |
| P2 | Simulation and data | Autoloads (Config, WeatherDB, GameState, Bus), machine logic, power model, weather.json generator, balance, debug keys, test checklist |
| P3 | Artist | All pixel art, animations, tileset, palette, sprite sheets, credits file |
| P4 | UI, shaders, integration | Main scene, project settings, HUD, build menu, screens, day/night, dust shader, particles, audio, README, export, demo video |

### 20.2 Contracts (agree in H0 to H1, then do not change without telling everyone)
- Simulation API: fields and signals in 9.3 and 9.4, machine methods in 9.6. P2 commits the skeleton by end of H1 so P1 and P4 can code against it.
- Input actions: section 6.
- Sprite sheets (P3 delivers placeholders in H0, final art overwrites the same files):

| File | Size | Frames, left to right, each 16x16 |
|---|---|---|
| tiles.png | 128x32 | 8x2 grid: sand A, B, C, dark patch, pebbles, rock wall, wall edge, hab floor, plus 7 spare |
| player.png | 144x16 | idle_down, walk_down_1, walk_down_2, idle_up, walk_up_1, walk_up_2, idle_side, walk_side_1, walk_side_2 |
| nodes.png | 64x16 | metal full, metal empty, ice full, ice empty |
| machines.png | 112x16 | solar, battery, drill, o2gen, wiper, rtg, ascent icon (index matches `frame` in config) |
| machines_anim.png | 96x16 | drill 1 to 2, o2gen 1 to 2, rtg 1 to 2 |
| hab.png | 48x32 | 1 frame (optional 2nd frame: blinking light, 96x32 total) |
| rocket.png | 64x48 | 2 frames of 32x48 (engine flame) |
| dustdevil.png | 48x24 | 3 frames of 16x24 |
| ui.png | 72x8 | 9 icons of 8x8: o2, water, metal, power, thermometer, sol, sun, moon, warning |

### 20.3 Git rules (Godot scenes conflict easily)
- One repo, `main` always runs. Each person works on their own branch and merges to `main` at checkpoints: H3, H6.5, H9, H12, H14.
- Each file has one owner (20.1). To change someone else's file, ask them or send a tiny change through them.
- P4 owns `Main.tscn` and `project.godot`. Settings changes go through P4.
- Never two people edit the same `.tscn` at once. Prefer small scenes (one per entity) so ownership is clean.
- Pull before you push. Commit small and often. Message format: `area: what changed`.
- `.gitignore`:
```
.godot/
*.import
export_presets.cfg.bak
.DS_Store
```
(Keep `export_presets.cfg` committed so everyone exports the same way; remove any credentials from it, verify.)
- Do not commit large raw files. Source art (`.aseprite` or `.pixelorama`) goes in `art_src/`.

### 20.4 Per-person hours
| Hours | P1 Gameplay | P2 Sim and data | P3 Art | P4 UI and integration |
|---|---|---|---|---|
| H0 to H1 | Install Godot, help set settings, agree contracts | Commit sim skeleton (state, signals, config, weather_db). Generate weather.json. 45-min real data attempt | Palette, placeholder sprite sheets in exact layouts, nearest import settings | Repo, .gitignore, project settings, blank web export to `docs/`, font choice |
| H1 to H3 | world_gen, tilemap, player move, camera, collisions | Sol clock, life support, win/lose, debug panel | tiles, player, nodes, hab | HUD with fake values, pixel font, theme |
| H3 to H5 | Resource nodes and harvest, build controller, machine scene | Power model, machine logic, defs, debug keys | Machine sprites, UI icons | Build menu, title, briefing, end screen skeleton |
| H5 to H6.5 | Integrate sim with world, launch stub, bug fixing | Hook weather into solar and heating, forecast data, end-condition tests | Walk animations, drill, o2gen, rtg frames | Day/night tint, dust shader, forecast strip |
| H6.5 to H7 | BREAK and merge | BREAK and merge | BREAK | BREAK, export, commit |
| H7 to H9 | Playtest, fix movement and build bugs, restart flow | Balance with a script that simulates solar-only vs rtg runs, report numbers | Rocket, dust devil, tile polish | End screen text and NASA parallels, message ticker |
| H9 to H9.5 | BREAK | BREAK | BREAK | BREAK |
| H9.5 to H12 | Launch polish, dust devil, camera shake, floating text | Radio messages, events, final tuning | Art pass 3, title art | Particles, vignette, sound if time |
| H12 | FREEZE | FREEZE | FREEZE | FREEZE |
| H12 to H12.5 | BREAK | BREAK | BREAK | BREAK |
| H12.5 to H14 | Fix bugs from test list | Run checklist (section 13), fix sim bugs | Fix alignment and art bugs | Cross-browser and fresh-clone test, export |
| H14 to H16 | README tech section, help video | README data and balance section, verify NASA text | Credits file, screenshots, GIFs | Demo video, final README, final export, submit |
Breaks are staggered if needed, but everyone gets at least 1.5 hours total. Fatigue causes bugs.

### 20.5 Communication
- One chat channel. Post when a contract changes, when `main` breaks, and at each checkpoint.
- Blocking issues are raised immediately, not at the next checkpoint.
- Each person keeps a personal to-do list of at most 3 items "now".

### 20.6 README outline (P4 owns, everyone contributes)
1. Title, one-paragraph pitch, screenshot or GIF.
2. Play: link to GitHub Pages build, or open `docs/index.html` through a local server (give the 2-line command).
3. Run from source: Godot version, open `project.godot`, press F5.
4. Controls (4 lines).
5. NASA resources used and how (section 3).
6. Data statement: weather is generated and shaped like a real storm, not raw NASA data.
7. How the design maps to real mission subsystems (power, thermal, ISRU, backup power).
8. Team and roles.
9. Credits and licences (fonts, any CC0 assets, tools).
10. Known issues.
11. Demo video link.
