class_name ResourceNode
extends Sprite2D
## A metal or ice deposit. The player harvests it with E (see harvester.gd).
## It has a few uses (charges). When they are gone it shows the depleted art.
## The map generator (world_gen.gd) creates these.

const GROUP := "resource_nodes"
const TEX_FULL := {
	"metal": preload("res://art/decor/metal_ore_full.png"),
	"ice": preload("res://art/decor/ice_deposit_full.png"),
}
const TEX_DEPLETED := {
	"metal": preload("res://art/decor/metal_ore_depleted.png"),
	"ice": preload("res://art/decor/ice_deposit_depleted.png"),
}
const SPARKLE_NAME := "Sparkle"

@export_enum("metal", "ice") var kind: String = "metal"
@export var charges_left: int = Config.NODE_CHARGES


func _ready() -> void:
	add_to_group(GROUP)
	_refresh()


func is_empty() -> bool:
	return charges_left <= 0


## Tries to harvest once. Returns the text to float above the player
## ("+8 metal"), or "" when it was blocked (the player then gets a message why).
func harvest() -> String:
	if is_empty():
		GameState.say("This deposit is empty")
		return ""
	if GameState.oxygen < Config.O2_MIN_TO_HARVEST:
		GameState.say("Not enough oxygen to go outside")
		return ""

	var text := ""
	if kind == "ice":
		if GameState.is_water_full():
			# Nothing is spent: no O2, and the node keeps its charge.
			GameState.say("Water full, build a tank")
			return ""
		var added: float = GameState.add_water(Config.WATER_PER_HARVEST)
		text = "+%s water" % _short_number(added)
	else:
		if GameState.metal >= Config.METAL_MAX:
			GameState.say("Metal storage full")
			return ""
		text = "+%d metal" % GameState.add_metal(Config.METAL_PER_HARVEST)

	GameState.consume_oxygen(Config.O2_HARVEST_COST)
	charges_left -= 1
	_refresh()
	return text


func _refresh() -> void:
	var textures: Dictionary = TEX_DEPLETED if is_empty() else TEX_FULL
	texture = textures.get(kind, texture)
	if is_empty():
		var old := get_node_or_null(SPARKLE_NAME)
		if old != null:
			old.queue_free()
	elif not has_node(SPARKLE_NAME):
		add_child(_make_sparkle())


## A slow glint so full deposits catch the eye from a distance.
func _make_sparkle() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = SPARKLE_NAME
	p.amount = 3
	p.lifetime = 0.9
	p.randomness = 1.0
	p.lifetime_randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, 5)
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.5, Color(1.0, 1.0, 0.9, 1.0) if kind == "metal" else Color(0.85, 0.97, 1.0, 1.0))
	p.color_ramp = ramp
	return p


func _short_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value
