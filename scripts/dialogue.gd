extends CanvasLayer
## Story lines in a classic dialogue box (autoload "Dialogue").
##
##   Dialogue.once("found_iron")       says LINES["found_iron"] the first time only
##   Dialogue.say("Any text", true)    always; true = important (stays longer)
##
## Text types out letter by letter. Enter, Space or a click shows it all / goes
## to the next line; otherwise it moves on by itself. The game keeps running.
## A line starting with "MC:" is spoken by Mission Control.

const ASTRONAUT := preload("res://art/astronaut.png")
const MC_ICON := preload("res://art/new_sprites/spaceship_components/Satellite_Communications_Console.png")
const CHARS_PER_SECOND := 45.0

## Every story line, by event. Ids: found_<item>, built_<machine>, crafted_<item>,
## installed_<module>, cave_<cave>, and a few milestones.
const LINES := {
	"intro": "MC:Mission Control to SOL30... do you copy? Your ship is wrecked but you are alive. You have 30 sols before the return window closes. Find materials, repair the ship, get home.",
	"wreck": "I can strip an emergency power cell and a crate of seed potatoes from the wreck. Every bit helps.",
	"lamp": "It's getting dark. Good thing I grabbed the portable lamp from the wreck.",
	"found_iron": "Iron Ore! Rusty, heavy and exactly what an engineer stranded on Mars wants to see.",
	"found_aluminum": "Aluminum Ore. Light and strong - perfect for panels and frames.",
	"found_sulfur": "Sulfur! It smells like rotten eggs, but refined into compounds it holds machines together.",
	"found_electronics": "Salvaged electronics. Someone's broken gear is about to become my working gear.",
	"found_circuits": "Circuit boards from an old research site. Still warm with possibility.",
	"found_water": "Ice! Melted and filtered, that's drinking water. Rule one on Mars: never waste water.",
	"found_iron_ingot": "My first iron ingots straight from the refinery. Now we're manufacturing.",
	"found_aluminum_ingot": "Aluminum ingots. Shiny. I could almost see my reflection, if I wanted to.",
	"found_sulfur_compound": "Sulfur Compounds discovered! Several new construction options just opened up.",
	"found_wire": "Fresh wire. Battery packs and air scrubbers both need wiring.",
	"found_co2": "Captured CO2 - the Martian air is 95% of it. Mix it with water and power and you get rocket fuel.",
	"found_methane": "Methane! Half of a working rocket propellant. Never thought I'd be happy to smell gas.",
	"found_oxygen": "A full oxygen capsule. Some for the ship, some for my lungs.",
	"found_potato": "Potatoes from the ship's galley. Food for now - and seeds, if I can build a greenhouse. (F = eat one)",
	"built_ore_refinery": "The Ore Refinery is humming. Feed it raw ore, collect ingots. Simple as that.",
	"built_solar": "Solar Panel online. Free power as long as the sun is up.",
	"built_battery": "A battery bank. Now the lights stay on after sunset.",
	"built_oxygen_gen": "My first Oxygen Generator is running. At least I won't have to worry about breathing just yet.",
	"built_reservoir": "The Water Reservoir is ready. Another step towards being self-sufficient.",
	"built_greenhouse": "Potatoes are in the ground. In a few sols I'll have dinner that isn't a ration bar.",
	"built_co2_capture": "The CO2 Capture Machine is pulling carbon dioxide straight out of the sky.",
	"built_radiation_sensor": "Radiation sensor online. Now I'll get a warning before the next storm hits.",
	"built_shelter": "The Emergency Shelter is sealed. When radiation or a dust storm hits, I walk in and wait it out.",
	"crafted_module": "Module built. Now I need to carry it to the ship and plug it into its port.",
	"installed_power_station": "Solar Panel installed on the ship! Its systems flicker back to life.",
	"installed_propellant": "Propellant & Pressurization Module installed. The tanks are holding pressure.",
	"installed_engine": "Engine module installed! The ship is one step closer to flying.",
	"installed_avionics": "MC:We have telemetry! Avionics and comms are back online, SOL30. Good work.",
	"installed_thermal": "Thermal Control installed. The ship won't freeze or cook on the way home.",
	"installed_life_support": "Life Support connected. Air and water for the trip home.",
	"half_repaired": "MC:Three of six systems repaired. You're halfway there, keep going!",
	"repaired": "MC:All six systems are green. Fire it up, SOL30 - you're coming home!",
	"cave_ice": "The Ice Cave. Cold, blue and full of frozen water.",
	"cave_ore": "The Ore Cave. These walls are streaked with metal.",
	"cave_deep": "The Deep Cave. Darker, rougher... and probably where the good stuff is.",
	"radiation": "MC:Warning! Solar particle event incoming. The Radiation Sensor Station and Emergency Shelter designs are in your Build Book.",
	"radiation_hide": "No shelter yet... the caves! A few metres of rock overhead will block the radiation. Get underground, fast!",
	"need_shelter": "That was too close. Next time I want walls around me. (Hint: build the Emergency Shelter from the Build Book.)",
	"storm": "MC:SOL30, a dust storm is rolling in. Visibility will drop, the wind will push you around and the solar panels will starve. Get inside!",
	"shelter_inside": "Safe inside. Thick walls, filtered air. Whatever is happening out there, I'll wait here until it's clear.",
	"hint_wreck": "MC:SOL30, your wrecked ship still has supplies on board. Walk up to it and press E to salvage them.",
	"hint_refinery": "Raw ore is no use on its own. (Hint: open the Build Book with B. The Ore Refinery needs 4 Iron Ore and 4 Aluminum Ore. Aluminum is in the caves.)",
	"hunger_1": "Hmm... my health is slipping. I need to keep this in check. I'm feeling hungry - where could I find something to refill me?",
	"food_wreck": "Wait... the ship's galley! There were potatoes on board. (Hint: press E at the wreck, then F to eat.)",
	"food_eat": "I've got potatoes from the wreck. (Hint: press F to eat one, +30 health.)",
	"hunger_2": "Uh oh! Health dropping again - it's the hunger. These potatoes won't last 30 sols. I need a way to harvest my own food.",
	"food_grow": "(Hint: the Greenhouse in the Build Book grows potatoes. Keep 2 potatoes to plant as seeds!)",
	"hint_oxygen": "My suit's oxygen keeps dropping. The tanks won't last forever - I need an Oxygen Generator. (Hint: see the Build Book.)",
	"hint_water": "Throat's dry... water is getting low. There's ice in the Ice Cave I can melt. (Hint: press E on ice deposits.)",
	"hint_power": "The battery is draining - the refinery eats power. A Solar Panel would recharge it every day. (Hint: see the Build Book.)",
	"hint_battery": "Night falls and my power dies with the sun. A Battery would store daytime power for the night.",
	"hint_reservoir": "My water tank is full and I'm wasting ice. A Water Reservoir Tank would let me store more.",
	"hint_co2": "The ship's propellant needs methane, and methane needs CO2. A CO2 Capture Machine can pull it out of the air.",
	"hint_ship": "MC:Your base is stable, SOL30. Now the ship: six systems, all on the SHIP REPAIR pages of your Build Book.",
}

var _queue: Array[String] = []
var _hold := 0.0
var _box: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _text: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_box()
	GameState.location_changed.connect(func(_place: String) -> void:
		if GameState.cave_id != "":
			once("cave_" + GameState.cave_id))


## Says the line for `key` from LINES, only the first time in this game.
func once(key: String, important: bool = false) -> void:
	if GameState.story_seen.has(key) or not LINES.has(key):
		return
	GameState.story_seen[key] = true
	say(LINES[key], important)


func say(text: String, important: bool = false) -> void:
	_queue.append(("!" if important else "") + text)
	if not _box.visible:
		_next()


## Clears everything (a new game).
func clear() -> void:
	_queue.clear()
	_box.hide()


func is_showing() -> bool:
	return _box.visible


func current_text() -> String:
	return _text.text


func _process(delta: float) -> void:
	if not _box.visible:
		return
	if _text.visible_ratio < 1.0:
		_text.visible_characters += maxi(1, roundi(CHARS_PER_SECOND * delta))
		if _text.visible_characters >= _text.text.length():
			_text.visible_ratio = 1.0
		return
	_hold -= delta
	if _hold <= 0.0:
		_next()


func _input(event: InputEvent) -> void:
	if not _box.visible:
		return
	var click := event as InputEventMouseButton
	var clicked := click != null and click.pressed and _box.get_global_rect().has_point(click.position)
	if clicked or event.is_action_pressed("ui_accept"):
		if _text.visible_ratio < 1.0:
			_text.visible_ratio = 1.0
		else:
			_next()
		get_viewport().set_input_as_handled()


func _next() -> void:
	if _queue.is_empty():
		_box.hide()
		return
	var line: String = _queue.pop_front()
	var important := line.begins_with("!")
	line = line.trim_prefix("!")
	var mc := line.begins_with("MC:")
	line = line.trim_prefix("MC:")
	_speaker.text = "Mission Control" if mc else "You"
	_portrait.texture = _mc_icon() if mc else _astronaut_face()
	_text.text = line
	_text.visible_characters = 0
	_hold = 2.5 + line.length() * 0.03 + (3.0 if important else 0.0)
	_box.show()


func _astronaut_face() -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = ASTRONAUT
	tex.region = Rect2(0, 0, 418, 418)
	return tex


func _mc_icon() -> Texture2D:
	return MC_ICON


func _make_box() -> void:
	_box = PanelContainer.new()
	_box.name = "DialogueBox"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.07, 0.15, 0.94)
	style.border_color = Color(1.0, 0.62, 0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_box.add_theme_stylebox_override("panel", style)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.offset_left = -330
	_box.offset_right = 330
	_box.offset_top = -112
	_box.offset_bottom = -12
	_box.hide()
	add_child(_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(72, 72)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 15)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	column.add_child(_speaker)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(540, 0)
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	column.add_child(_text)
