# Dust Storm Dispatch: 8-Hour Beginner Edition

For a team of 4 beginners, 8 hours, Godot 4, 2D pixel art. Give this file to your AI assistant at the start of every chat.
- Numbers are TUNABLE placeholders. Items marked (verify) must be checked.
- The code below has not been run. Expect small typos. Test each piece the moment you paste it.
- This version is much smaller than the 16-hour plan. Do not add features. Finish the small game first.

## 1. The game in one paragraph
A pixel-art astronaut stands next to a small Mars base. Walk around, press E near ore and ice to collect metal and water (costs a little oxygen). Press E at build slots around the base to build machines: solar panels, batteries, an oxygen generator, backup power, and finally an ascent vehicle. A dust storm (generated to look like a real global storm) arrives around sol 10 to 18: solar power collapses and the base freezes unless you built backup power. Survive, build the ascent vehicle, launch, win.

## 2. NASA resources used (explain in README and end screen)
From the provided list:
- Mission Design Lab: machines are grouped by real spacecraft subsystems (power, life support, thermal, launch).
- NASA mission segments (launch, space, ground, user): used on the briefing screen.
- Learning Game About Telescopes: copied its pattern of constrained choices and an end screen that links your design to real NASA missions.
Data honesty: the provided list has no Mars weather dataset. Weather is GENERATED to resemble a real global dust storm. Say "based on real storm behaviour". Never say "real NASA data".

## 3. Scope (8 hours, beginners)
MUST:
- One map (640x360 px), walking player, camera.
- Collect metal and ice from hand-placed nodes.
- 9 build slots, 5 machines, build menu.
- HUD, weather-driven solar, day/night tint, dust haze, one storm.
- Win, lose, restart. Briefing screen. End screen with 3 NASA facts.
- Repo with README. Web build in `docs/` if export works.
- 90 to 120 second demo video.
SHOULD: forecast text, message line, harvest messages.
COULD (only if everything works at H5.25): walking bob, rocks decoration, sound, rocket sprite rise.
CUT: tilemaps, procedural generation, tool-use animation, ice drill, dust wiper, panel dirt, save, title screen, particles, shaders, demo mode, sound.

## 4. Game rules and numbers
- 1 sol = 15 real seconds. Keys 1 and 2: speed x1 and x3. Game window ends at sol 30 (lose).
- Start: O2 100, water 80, metal 30, battery 50, hab temp 20.
- Use per sol: O2 -6, water -3. Harvest costs 1 O2.
- Metal node: +8 metal, 5 charges. Ice node: +6 water, 5 charges. 8 metal nodes, 5 ice nodes.
- Machines (build on slots, cost metal unless stated):

| id | Name | Cost | Effect |
|---|---|---|---|
| solar | Solar panel | 15 | +3.0 power at full sun, scaled by dust and daylight |
| battery | Battery | 10 | +40 battery capacity (base capacity 20) |
| o2gen | O2 generator | 25 | uses 1.0 power and 0.15 water per s, makes 0.45 O2 per s, runs automatically when O2 < 95 |
| rtg | Backup power | 50 | +2.0 power always (storm-proof) |
| ascent | Ascent vehicle | 80 metal + 40 water | Launch in 3 s: WIN. Only on the launch pad slot |
- Start with 2 solar panels and 1 battery already built (3 preset slots).
- Formulas: `sun_factor = clamp(exp(-0.35 * tau), 0.03, 1)`; `daylight = max(0, sin(TAU*(sol_t-0.25)))`; `heat_need = max(0, 15 - temp) * 0.01`.
- Power: if battery is empty and power is short, heating and O2 generator run at reduced strength.
- Hab temp drifts toward 20 when heated, toward outside temp when not. Below 0: integrity -1 per s.
- Lose: O2 or water at 0 for 6 s, integrity 0, or sol 30 passes.
- Why it works: normal days need about 3 panels. In the storm, sun_factor is about 0.12, so panels give almost nothing. Backup power (2.0) covers heating plus O2 generator (about 1.7). Players who skip it freeze.

## 5. Team split (nobody edits another person's files)
| Person | Role | Files they own |
|---|---|---|
| P1 | World | `scenes/World.tscn`, `Player.tscn`, `ResourceNode.tscn`, `Slot.tscn`, `scripts/player.gd`, `resource_node.gd`, `slot.gd` |
| P2 | Brain (simulation and data) | `scripts/game_state.gd`, `weather_db.gd`, `data/weather.json`, `tools/make_weather.py` |
| P3 | Art | everything in `art/`, `art/CREDITS.md` |
| P4 | UI and shipping | `project.godot`, `scenes/Main.tscn`, `UI.tscn`, `scripts/hud.gd`, `build_menu.gd`, `briefing.gd`, `end_screen.gd`, `day_night.gd`, `dust.gd`, `README.md`, `docs/` |
Rules: if you need a change in someone else's file, tell them in chat. Work directly on `main`. Pull before you push. Commit small and often. Commit message format: `who: what`.

## 6. The 8-hour schedule
| Hours | What happens |
|---|---|
| H0 to H1 | Setup (section 7). Everyone installs, clones, runs the blank project. |
| H1 to H3 | Build your own part in parallel (task cards, section 9). |
| H3 to H3.5 | BREAK 30 min. After it: CHECKPOINT 1 together. |
| H3.5 to H5 | Connect the parts. Finish features. |
| H5 to H5.25 | BREAK 15 min. Then CHECKPOINT 2. |
| H5.25 to H6.5 | Playtest, balance, fix bugs, swap in final art. |
| H6.5 | FEATURE FREEZE. No new features. Bug fixes only. |
| H6.5 to H7.25 | Final test, web export, README. |
| H7.25 to H8 | Demo video, submit, buffer. |
Rest total: 45 minutes. Do not skip it.
Checkpoint 1 (H3.5): player walks around the map, HUD shows ticking values from the simulation, placeholder art visible.
Checkpoint 2 (H5.25): you can harvest, build, survive or die, win or lose, and restart. Ugly is fine.
If behind at Checkpoint 2: drop every COULD and SHOULD and fix the MUST list only.

## 7. Setup (H0 to H1, everyone)
1. Install Godot 4.3 or newer (standard version, not .NET) from godotengine.org. Install GitHub Desktop.
2. P4 creates the GitHub repo (public), adds a Godot `.gitignore` (template), and invites the others. Everyone clones it with GitHub Desktop.
3. P4 creates the Godot project in the repo folder and sets (verify exact names):
   - Project Settings > Display > Window: Viewport Width 320, Height 180, Window Width Override 1280, Height Override 720.
   - Display > Window > Stretch: Mode `viewport`, Aspect `keep`, Scale Mode `integer`.
   - Rendering > Textures > Canvas Textures > Default Texture Filter: `Nearest`.
   - Rendering > Renderer: `gl_compatibility`.
   - Input Map: `move_left` (A, Left), `move_right` (D, Right), `move_up` (W, Up), `move_down` (S, Down), `interact` (E), `speed_1` (1), `speed_2` (2).
   - Autoloads (in this order, after P2 commits the files): `WeatherDB` (`res://scripts/weather_db.gd`), `GameState` (`res://scripts/game_state.gd`).
   P4 commits and pushes. Everyone pulls.
4. P4 does a blank web export test: Project > Export > Add > Web, export to `docs/index.html`, and serve it with `python3 -m http.server` inside `docs/` (open `http://localhost:8000`). In the export Resources tab add `*.json` to "Filters to export non-resource files". If web export fails and costs more than 30 minutes, STOP. Fallback: the repo plus a screen recording is the submission.
5. P3 commits placeholder PNGs with the exact sizes in section 8 so no one waits for art.
6. P2 commits `game_state.gd` and `weather_db.gd` from section 10 and generates `data/weather.json`.

Beginner glossary:
- Scene: a saved tree of nodes (`.tscn`). Script: code attached to a node (`.gd`).
- Autoload: a script that is always loaded and reachable by name from anywhere (here `GameState` and `WeatherDB`).
- Signal: a node announcing "something happened". Group: a label on nodes so other code can find them.
- `@export`: a variable you can edit in the Inspector. Run the game: F5 (set Main.tscn as main scene).

## 8. Art spec (P3)
- Pixel size 16x16. Screen is 320x180. Use only about 12 colours. Suggested palette: `#2b1a1a #4a2620 #7a3b2a #a8512f #c9703a #e09a52 #f0c27a #f6e2b3 #5a4a48 #8a7a72 #f4efe6 #5b8fb9`.
- Tools (free, check licences, verify): Piskel (browser), Pixelorama, LibreSprite. You may recolour free CC0 art (for example Kenney assets, CC0, verify) instead of drawing everything.
- Files, exact sizes (frames left to right, each 16x16 unless noted):

| File | Size | Frames |
|---|---|---|
| ground.png | 32x32 | one sand tile that repeats without visible seams |
| player.png | 48x16 | 0 facing down, 1 facing up, 2 facing side (left is mirrored in code) |
| nodes.png | 64x16 | 0 metal full, 1 metal empty, 2 ice full, 3 ice empty |
| machines.png | 80x16 | 0 solar, 1 battery, 2 O2 generator, 3 backup power, 4 ascent vehicle |
| marker.png | 16x16 | empty build slot (outlined square) |
| hab.png | 48x32 | the base |
| rocks.png (COULD) | 32x16 | 2 decorative rocks |
- Hour 0: placeholders (flat coloured shapes). Replace later by saving over the same file name and size, so nothing in Godot breaks.
- In Godot, select each PNG, Import tab: make sure filter is Nearest (project default), press Reimport.
- Write `art/CREDITS.md` listing tools and any borrowed assets and licences.

## 9. Task cards
Each task is 30 to 60 minutes. "Done when" tells you it works. Stuck for 15 minutes? Ask your AI assistant with this file attached, then ask a teammate.

### P1 World
1. (H0 to H1) Setup with everyone.
2. (H1 to H2) `World.tscn` and `Player.tscn`. Nodes below. Done when: you can walk around, the camera follows, and you cannot leave the map.
3. (H2 to H3) `ResourceNode.tscn` and `Slot.tscn` with the scripts below. Place 8 metal nodes, 5 ice nodes, and 9 slots. Done when: standing next to a node and pressing E does something (use `print`).
4. (H3.5 to H5) After P2's simulation is in: check harvest changes metal/water, slots open the menu P4 makes, built machines appear. Set 3 slots as `start_machine` (2 solar, 1 battery).
5. (H5.25 to H6.5) Fix movement and placement bugs. Swap in final art. Optional: walking bob, rocks.
6. (H6.5 onward) Test as a player. Help P4 with README controls section.

### P2 Brain
1. (H0 to H1) Run `tools/make_weather.py` (section 10) to create `data/weather.json`. No Python? Ask your AI to produce the JSON file directly with 40 rows. Commit `game_state.gd` and `weather_db.gd`.
2. (H1 to H2) Read both scripts line by line. Register autoloads (with P4). Test: add a temporary Label that shows `GameState.o2` and watch it fall.
3. (H2 to H3) Test the numbers with the debug keys. Print O2, water, battery each sol to the Output panel. Done when: the numbers move as section 4 says.
4. (H3.5 to H5) Connect with P1 (harvest, build). Confirm win, lose, launch timer, restart.
5. (H5.25 to H6.5) Balance. Play with F3 (force storm). Check: without backup power you lose in the storm, with it you survive. Tweak constants only at the top of `game_state.gd`.
6. (H6.5 onward) Own the test checklist (section 13). Write the README "Data and balance" section.

### P3 Art
1. (H0 to H1) Palette. Placeholder PNGs in exact sizes. Commit.
2. (H1 to H2.5) ground, player, hab.
3. (H2.5 to H3.5) nodes, machines, marker.
4. (H3.5 to H5) Check in the running game: sizes, alignment, nothing blurry. Fix.
5. (H5.25 to H6.5) Improve whatever looks worst. Optional rocks.
6. (H6.5 onward) CREDITS file. Take 3 screenshots and one GIF for README. Help record the video.

### P4 UI and shipping
1. (H0 to H1) Repo, settings, input map, blank web export, README stub.
2. (H1 to H3) `UI.tscn` with HUD, Briefing, EndScreen and `Main.tscn` (instances `World.tscn`, `DayNight`, `DustLayer`, `UI`). Use the scripts below. Done when: briefing shows, Start begins the clock, HUD numbers move.
3. (H3.5 to H5) BuildMenu, DayNight tint, Dust haze, forecast text, message line.
4. (H5.25 to H6.5) UI polish. Write the end screen NASA lines. Make text readable.
5. (H6.5 to H7.25) Final web export to `docs/`. Fresh clone test. Finish README.
6. (H7.25 to H8) Demo video and submission.

Finished early? Help someone else. Do not start new features before checkpoint 2.

## 10. The code (copy, then test)

### 10.1 `scripts/weather_db.gd` (P2)
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
	var tau: float = lerpf(a.tau, b.tau, t)
	var base_temp: float = lerpf(a.temp_c, b.temp_c, t)
	var swing: float = 25.0 * sin(TAU * (t - 0.35))
	return {"tau": tau, "temp": base_temp + swing}

func sun_factor(tau: float) -> float:
	return clampf(exp(-0.35 * tau), 0.03, 1.0)
```

### 10.2 `tools/make_weather.py` (P2, run once, commit the JSON)
```python
import json, math, random
random.seed(7)
sols = []
for s in range(1, 41):
    storm = math.exp(-((s - 14) / 3.0) ** 2)       # peaks at sol 14
    sols.append({
        "sol": s,
        "tau": round(0.6 + 5.4 * storm + random.uniform(-0.1, 0.1), 2),
        "temp_c": round(-55 + 4 * storm + random.uniform(-1, 1), 1),
    })
json.dump({"source": "generated, shaped like a real global dust storm", "sols": sols},
          open("../data/weather.json", "w"), indent=1)
```
(Run from inside `tools/`, or adjust the path.)

### 10.3 `scripts/game_state.gd` (P2)
```gdscript
extends Node

signal message(text: String)
signal ended(won: bool, reason: String)

const DEBUG := true
const SOL_SECONDS := 15.0
const WINDOW_SOL := 30
const HEAT_COEF := 0.01
const HEAT_THRESHOLD := 15.0
const MACHINE_DEFS := {
	"solar":   {"name": "Solar panel", "metal": 15, "water": 0, "frame": 0},
	"battery": {"name": "Battery", "metal": 10, "water": 0, "frame": 1},
	"o2gen":   {"name": "O2 generator", "metal": 25, "water": 0, "frame": 2},
	"rtg":     {"name": "Backup power", "metal": 50, "water": 0, "frame": 3},
	"ascent":  {"name": "Ascent vehicle", "metal": 80, "water": 40, "frame": 4},
}

var running := false
var menu_open := false
var speed := 1.0
var sol := 1
var sol_t := 0.0
var o2 := 100.0
var water := 80.0
var metal := 30.0
var battery := 50.0
var hab_temp := 20.0
var integrity := 100.0
var n_solar := 2
var n_battery := 1
var n_o2gen := 0
var n_rtg := 0
var power_gen := 0.0
var power_use := 0.0
var o2_zero := 0.0
var water_zero := 0.0
var launch_timer := 0.0
var force_tau := -1.0
var weather: Dictionary = {"tau": 0.6, "temp": -55.0}

func reset() -> void:
	running = false
	menu_open = false
	speed = 1.0
	sol = 1
	sol_t = 0.0
	o2 = 100.0
	water = 80.0
	metal = 30.0
	battery = 50.0
	hab_temp = 20.0
	integrity = 100.0
	n_solar = 2
	n_battery = 1
	n_o2gen = 0
	n_rtg = 0
	power_gen = 0.0
	power_use = 0.0
	o2_zero = 0.0
	water_zero = 0.0
	launch_timer = 0.0
	force_tau = -1.0

func start_game() -> void:
	reset()
	running = true

func battery_cap() -> float:
	return 20.0 + 40.0 * n_battery

func daylight() -> float:
	return maxf(0.0, sin(TAU * (sol_t - 0.25)))

func harvest(kind: String) -> bool:
	if o2 < 1.0:
		message.emit("Not enough oxygen to go outside")
		return false
	o2 -= 1.0
	if kind == "metal":
		metal += 8.0
		message.emit("+8 metal")
	else:
		water += 6.0
		message.emit("+6 water")
	return true

func build(id: String) -> bool:
	var def: Dictionary = MACHINE_DEFS[id]
	if metal < def.metal or water < def.water:
		message.emit("Not enough resources")
		return false
	metal -= def.metal
	water -= def.water
	match id:
		"solar": n_solar += 1
		"battery": n_battery += 1
		"o2gen": n_o2gen += 1
		"rtg": n_rtg += 1
		"ascent":
			launch_timer = 3.0
			message.emit("Ignition in 3 seconds!")
	return true

func end_game(won: bool, reason: String) -> void:
	if not running:
		return
	running = false
	ended.emit(won, reason)

func _process(delta: float) -> void:
	if not running or menu_open:
		return
	var dt := delta * speed
	sol_t += dt / SOL_SECONDS
	if sol_t >= 1.0:
		sol_t -= 1.0
		sol += 1
	_simulate(dt)
	if launch_timer > 0.0:
		launch_timer -= delta
		if launch_timer <= 0.0:
			end_game(true, "Launch successful")
			return
	_check_lose(dt)

func _simulate(dt: float) -> void:
	weather = WeatherDB.at(sol, sol_t)
	if force_tau >= 0.0:
		weather["tau"] = force_tau
	var tau: float = weather["tau"]
	var temp: float = weather["temp"]
	var sun: float = WeatherDB.sun_factor(tau) * daylight()
	power_gen = n_solar * 3.0 * sun + n_rtg * 2.0
	var heat_need: float = maxf(0.0, HEAT_THRESHOLD - temp) * HEAT_COEF
	var o2_running: bool = n_o2gen > 0 and o2 < 95.0 and water > 0.0
	var o2_need: float = 0.0
	if o2_running:
		o2_need = 1.0 * n_o2gen
	var need: float = heat_need + o2_need
	var net: float = power_gen - need
	var ratio := 1.0
	if net < 0.0 and battery <= 0.0 and need > 0.0:
		ratio = clampf(power_gen / need, 0.0, 1.0)
	battery = clampf(battery + net * dt, 0.0, battery_cap())
	power_use = need * ratio
	if o2_running:
		o2 += 0.45 * n_o2gen * ratio * dt
		water -= 0.15 * n_o2gen * ratio * dt
	o2 -= 6.0 / SOL_SECONDS * dt
	water -= 3.0 / SOL_SECONDS * dt
	o2 = clampf(o2, 0.0, 100.0)
	water = maxf(water, 0.0)
	var target: float = lerpf(temp, 20.0, ratio)
	hab_temp = move_toward(hab_temp, target, 0.6 * dt)
	if hab_temp < 0.0:
		integrity = maxf(0.0, integrity - 1.0 * dt)

func _check_lose(dt: float) -> void:
	o2_zero = o2_zero + dt if o2 <= 0.0 else 0.0
	water_zero = water_zero + dt if water <= 0.0 else 0.0
	if o2_zero >= 6.0:
		end_game(false, "Out of oxygen")
	elif water_zero >= 6.0:
		end_game(false, "Out of water")
	elif integrity <= 0.0:
		end_game(false, "Habitat froze")
	elif sol > WINDOW_SOL:
		end_game(false, "Return window closed")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("speed_1"):
		speed = 1.0
	elif event.is_action_pressed("speed_2"):
		speed = 3.0
	if DEBUG and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				metal += 50.0
				water += 50.0
			KEY_F2:
				sol += 1
			KEY_F3:
				force_tau = 7.0 if force_tau < 0.0 else -1.0
```
Notes: `weather` is replaced every frame, so `force_tau` is applied after the lookup. Set `DEBUG := false` at feature freeze.

### 10.4 `scripts/player.gd` (P1)
Scene `Player.tscn`: `CharacterBody2D` > `CollisionShape2D` (small rectangle about 8x6 at the feet), `Sprite2D` (texture `player.png`, Hframes 3), `Camera2D` (Position Smoothing on; set limits Left 0, Top 0, Right 640, Bottom 360), `InteractArea` (`Area2D` with a `CollisionShape2D` circle radius 14).
```gdscript
extends CharacterBody2D

const SPEED := 60.0
@onready var area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(_delta: float) -> void:
	if not GameState.running or GameState.menu_open:
		velocity = Vector2.ZERO
		return
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	move_and_slide()
	if velocity.x != 0.0:
		sprite.frame = 2
		sprite.flip_h = velocity.x < 0.0
	elif velocity.y < 0.0:
		sprite.frame = 1
	elif velocity.y > 0.0:
		sprite.frame = 0

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not GameState.running or GameState.menu_open:
		return
	var best: Node = null
	var best_d := 1000000.0
	for a in area.get_overlapping_areas():
		if a.is_in_group("interactable"):
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a
	if best != null:
		best.interact()
```

### 10.5 `scripts/resource_node.gd` (P1)
Scene `ResourceNode.tscn`: `Area2D` > `CollisionShape2D` (circle radius 8), `Sprite2D` (texture `nodes.png`, Hframes 4). Attach the script. After instancing, set `Kind` in the Inspector for each one.
```gdscript
extends Area2D

@export_enum("metal", "ice") var kind: String = "metal"
var charges := 5
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("interactable")
	_update_sprite()

func interact() -> void:
	if charges <= 0:
		return
	if GameState.harvest(kind):
		charges -= 1
		_update_sprite()

func _update_sprite() -> void:
	var base := 0 if kind == "metal" else 2
	sprite.frame = base + (0 if charges > 0 else 1)
```

### 10.6 `scripts/slot.gd` (P1)
Scene `Slot.tscn`: `Area2D` > `CollisionShape2D` (circle radius 10), `Marker` (`Sprite2D`, `marker.png`), `Machine` (`Sprite2D`, `machines.png`, Hframes 5, hidden).
```gdscript
extends Area2D

@export var pad := false
@export_enum("", "solar", "battery", "o2gen", "rtg") var start_machine: String = ""
var machine_id := ""
@onready var marker: Sprite2D = $Marker
@onready var machine: Sprite2D = $Machine

func _ready() -> void:
	add_to_group("interactable")
	machine.visible = false
	if start_machine != "":
		set_machine(start_machine)

func interact() -> void:
	if machine_id != "":
		return
	get_tree().call_group("build_menu", "open", self)

func set_machine(id: String) -> void:
	machine_id = id
	machine.frame = GameState.MACHINE_DEFS[id].frame
	machine.visible = true
	marker.visible = false
```
Layout in `World.tscn` (positions relative to the hab at (320, 180)): slots at offsets (-48,-40), (0,-48), (48,-40), (-64,0), (64,0), (-48,40), (0,48), (48,40); the launch pad slot (`pad` on) at offset (110, 0). Preset: (-64,0) solar, (-48,-40) solar, (48,-40) battery.

### 10.7 `World.tscn` structure (P1)
```
World (Node2D)
  Ground (Sprite2D: ground.png, Centered off, Region Enabled, Region Rect 0,0,640,360, CanvasItem > Texture > Repeat = Enabled)
  Walls (StaticBody2D) with 4 CollisionShape2D rectangles:
      top (320,-8) size 640x16, bottom (320,368), left (-8,180) size 16x360, right (648,180)
  Entities (Node2D, Y Sort Enabled on)
    Hab (Sprite2D: hab.png at (320,180)) with a StaticBody2D child + CollisionShape2D (about 40x24)
    Slots (Node2D): 9 instances of Slot.tscn
    Resources (Node2D): 13 instances of ResourceNode.tscn (8 metal, 5 ice) spread around; put 3 metal and 2 ice within about 80 px of the hab
    Player (instance of Player.tscn) at (320, 215)
```
Spread the rest of the nodes so the farthest ones are 200+ px from the hab. This makes players explore.

### 10.8 `scripts/build_menu.gd` (P4)
Scene: `BuildMenu` (`Control`, full rect, script attached) > `Panel` (centered) > `List` (`VBoxContainer`).
```gdscript
extends Control

var slot: Node = null

func _ready() -> void:
	add_to_group("build_menu")
	visible = false

func open(s: Node) -> void:
	slot = s
	var list := $Panel/List
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for id in GameState.MACHINE_DEFS:
		if (id == "ascent") != slot.pad:
			continue
		var def: Dictionary = GameState.MACHINE_DEFS[id]
		var b := Button.new()
		b.text = "%s (%d metal, %d water)" % [def.name, def.metal, def.water]
		b.pressed.connect(_choose.bind(id))
		list.add_child(b)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(close)
	list.add_child(cancel)
	visible = true
	GameState.menu_open = true
	list.get_child(0).grab_focus()

func _choose(id: String) -> void:
	if GameState.build(id):
		slot.set_machine(id)
		close()

func close() -> void:
	visible = false
	GameState.menu_open = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
```

### 10.9 `scripts/hud.gd` (P4)
Scene: `HUD` (`Control`, full rect, Mouse Filter Ignore) > `Stats` (`Label`, top-left), `Message` (`Label`, bottom-centre), `Forecast` (`Label`, top-right), `MsgTimer` (`Timer`, One Shot). Use a small pixel font (size 8).
```gdscript
extends Control

@onready var stats: Label = $Stats
@onready var msg: Label = $Message
@onready var forecast: Label = $Forecast
@onready var msg_timer: Timer = $MsgTimer

func _ready() -> void:
	GameState.message.connect(_on_message)
	msg_timer.timeout.connect(func() -> void: msg.text = "")

func _on_message(text: String) -> void:
	msg.text = text
	msg_timer.start(3.0)

func _process(_delta: float) -> void:
	stats.text = "SOL %d/%d\nO2 %d  WATER %d  METAL %d\nPOWER +%.1f -%.1f  BATT %d/%d\nOUTSIDE %d C  BASE %d C" % [
		GameState.sol, GameState.WINDOW_SOL,
		int(GameState.o2), int(GameState.water), int(GameState.metal),
		GameState.power_gen, GameState.power_use,
		int(GameState.battery), int(GameState.battery_cap()),
		int(GameState.weather["temp"]), int(GameState.hab_temp)]
	var tau_ahead: float = WeatherDB.row(GameState.sol + 2).tau
	var level := "LOW"
	if tau_ahead > 3.5:
		level = "HIGH"
	elif tau_ahead > 1.5:
		level = "MEDIUM"
	forecast.text = "DUST IN 2 SOLS: " + level
```

### 10.10 `scripts/briefing.gd` and `scripts/end_screen.gd` (P4)
Briefing scene: `Briefing` (`Control`, full rect) > `Panel` > `Text` (`Label`), `Start` (`Button`). Text (edit freely):
```
DUST STORM DISPATCH
You are the SPACE segment. Earth's ground segment cannot help in time.
WASD move. E collect and build. 1 / 2 speed.
Build solar power, oxygen, backup power. A dust storm is coming.
Build the ascent vehicle on the launch pad before sol 30.
```
```gdscript
extends Control

func _ready() -> void:
	visible = true
	$Panel/Start.pressed.connect(_start)

func _start() -> void:
	visible = false
	GameState.start_game()
```
End screen: `EndScreen` (`Control`, full rect) > `Panel` > `Title` (`Label`), `Body` (`Label`), `Restart` (`Button`).
```gdscript
extends Control

@onready var title: Label = $Panel/Title
@onready var body: Label = $Panel/Body

func _ready() -> void:
	visible = false
	GameState.ended.connect(_on_ended)
	$Panel/Restart.pressed.connect(_restart)

func _on_ended(won: bool, reason: String) -> void:
	title.text = "LAUNCH SUCCESSFUL" if won else "MISSION FAILED: " + reason
	body.text = "Reached sol %d\nSolar %d, batteries %d, O2 generators %d, backup power %d\n\nREAL NASA PARALLELS (verify)\nBackup power: Curiosity and Perseverance use radioisotope power that works without sunlight.\nO2 generator: Perseverance's MOXIE experiment made oxygen from Mars carbon dioxide.\nDust: storms cut solar power; the 2018 global storm ended the Opportunity rover mission." % [
		GameState.sol, GameState.n_solar, GameState.n_battery, GameState.n_o2gen, GameState.n_rtg]
	visible = true

func _restart() -> void:
	GameState.reset()
	get_tree().reload_current_scene()
```

### 10.11 `scripts/day_night.gd` and `scripts/dust.gd` (P4)
`DayNight` is a `CanvasModulate` node in `Main.tscn`.
```gdscript
extends CanvasModulate

const NIGHT := Color(0.35, 0.40, 0.65)
const STORM := Color(1.0, 0.7, 0.45)

func _process(_delta: float) -> void:
	var tau: float = GameState.weather["tau"]
	var base: Color = NIGHT.lerp(Color.WHITE, GameState.daylight())
	color = base.lerp(base * STORM, clampf(tau / 8.0, 0.0, 1.0))
```
`DustLayer` is a `CanvasLayer` (layer 5) with a full-rect `ColorRect` (Mouse Filter Ignore) with this script:
```gdscript
extends ColorRect

func _process(_delta: float) -> void:
	var tau: float = GameState.weather["tau"]
	color = Color(0.78, 0.45, 0.25, clampf(tau / 8.0, 0.0, 0.6) * 0.8)
```

### 10.12 `Main.tscn` (P4)
```
Main (Node)
  World (instance of World.tscn)
  DayNight (CanvasModulate, day_night.gd)
  DustLayer (CanvasLayer, layer 5) > ColorRect (dust.gd)
  UI (CanvasLayer, layer 10) > HUD, BuildMenu, Briefing, EndScreen (instances or nodes from UI.tscn)
```
Set Main.tscn as the main scene (Project Settings > Application > Run).

## 11. Common beginner problems
- "Invalid access to property" or "null instance": a node name in `$Name` does not match the scene tree. Check spelling and case.
- Autoload not found: Project Settings > Globals > Autoload, check the name and path.
- Nothing happens on E: the Input Map action name is wrong, or the Area2D layers/masks were changed (leave them at default 1 and 1).
- Sprites look blurry: texture filter is not Nearest, or the stretch settings were not set.
- weather.json missing in web build: add `*.json` to export "Filters to export non-resource files".
- Git conflict: do not panic. Ask in chat, then keep both versions and ask the file's owner to merge.
- Using your AI assistant: paste this file first. Ask for ONE small change at a time. Run the game after each change. Commit when it works.

## 12. Submission (repo)
README (P4, everyone contributes):
1. Title, one-paragraph pitch, screenshot or GIF.
2. How to play: link to the GitHub Pages build, or open the project in Godot 4.3+ and press F5.
3. Controls (3 lines).
4. NASA resources used and how (section 2).
5. Data statement (generated weather, based on real storm behaviour).
6. How the design maps to real mission subsystems.
7. Team and roles, credits and licences (link `art/CREDITS.md`).
8. Known issues. Demo video link.
If the web build works: commit `docs/`, then Settings > Pages > branch `main`, folder `/docs`.

## 13. Test checklist (P2 owns, all play)
- [ ] The game starts from the briefing; sol clock runs; speed keys work.
- [ ] Cannot walk out of the map; no stuck spots near the hab or nodes.
- [ ] Harvest gives resources, costs 1 O2, nodes run out after 5 uses.
- [ ] Menu opens on an empty slot, only shows pad machine on the pad slot, blocks movement while open, closes on Escape.
- [ ] Cannot build without enough resources; message shows.
- [ ] Power numbers on HUD change with day/night and with built machines.
- [ ] Press F3 (storm): solar output collapses; with backup power the base survives.
- [ ] Every lose condition ends the game once; Restart works and resets everything.
- [ ] Ascent on the pad gives a 3-second countdown, then the win screen.
- [ ] Fresh clone opens in Godot with no errors; web build loads in a new browser tab.
- [ ] Someone who has not seen the game plays through using only the briefing text.

## 14. Rules for the AI assistant
- Use Godot 4 GDScript only, typed variables where practical. Never use `:=` on a value read from a Dictionary or `.get()` (it is a Variant); write the type explicitly.
- Give complete, working code for one file at a time. No placeholders like "your code here".
- Do not add features outside section 3 MUST and SHOULD. Do not change numbers in section 4 without updating this file.
- Explain errors in simple words and give the exact fix.
- Mark anything uncertain about Godot settings or NASA facts as (verify).
