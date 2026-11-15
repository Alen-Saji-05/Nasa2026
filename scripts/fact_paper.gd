extends Node2D
## A paper with a Mars fact lying on the ground (surface or cave). Press E to read
## it full screen (fact_viewer.gd). Unread papers shine; read ones stay so you can
## read them again. Which fact is in Config.FACTS[fact].

const TEX := preload("res://art/paper_artefact_in_cave.png")
const WIDTH := 28.0                           # pixels on the map

@export var fact: int = 0

var _sprite: Sprite2D
var _shine: CPUParticles2D


func _ready() -> void:
	add_to_group(Interactor.GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2.ONE * WIDTH / TEX.get_width()
	add_child(_sprite)
	_shine = CPUParticles2D.new()
	_shine.amount = 8
	_shine.lifetime = 1.2
	_shine.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_shine.emission_rect_extents = Vector2(6, 3)
	_shine.direction = Vector2.UP
	_shine.spread = 20.0
	_shine.gravity = Vector2.ZERO
	_shine.initial_velocity_min = 4.0
	_shine.initial_velocity_max = 8.0
	_shine.scale_amount_min = 1.0
	_shine.scale_amount_max = 2.0
	_shine.color = Color(1.0, 0.95, 0.6, 0.9)
	add_child(_shine)


func _process(_delta: float) -> void:
	var unread := not GameState.facts_read.has(fact)
	_shine.emitting = unread
	var t := Time.get_ticks_msec() * 0.004 + fact
	_sprite.modulate = Color.WHITE.lerp(Color(1.8, 1.6, 1.0), 0.5 + 0.5 * sin(t)) if unread else Color.WHITE


func interact(_player: Node2D) -> void:
	var viewer := get_tree().current_scene.get_node_or_null("UI/HUD/FactViewer")
	if viewer != null:
		viewer.call("open", fact)


func prompt_text() -> String:
	return "E: read" if not GameState.facts_read.has(fact) else "E: read again"


func prompt_offset() -> Vector2:
	return Vector2(0, -12)
