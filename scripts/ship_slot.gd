class_name ShipSlot
extends Sprite2D
## The place on the ship where one repair module goes (world_gen.gd makes six).
## Before: a dark outline of the module. Built in the Build Book: it pulses,
## press E here to install it. Installed: the real module, connected by its pipe.

## A module id from Config.REPAIR_ORDER.
@export var module_id: String = ""

var _base_scale := Vector2.ONE
var _pulse: Tween


func _ready() -> void:
	_base_scale = scale
	add_to_group(Interactor.GROUP)
	GameState.ship_changed.connect(_refresh)
	_refresh()


func interact(_player: Node2D) -> void:
	var name_text: String = Config.machine(module_id).name
	if GameState.installed.has(module_id):
		GameState.say("%s: installed" % name_text)
	elif GameState.modules_ready.has(module_id):
		GameState.install(module_id)
		_install_effect()
	else:
		GameState.say("%s port: build the module in the Build Book (B)" % name_text)


## A port with a module ready to install wins over the ship itself and anything else near.
func interact_penalty() -> float:
	return -100.0 if GameState.modules_ready.has(module_id) else 5.0


func prompt_offset() -> Vector2:
	return Vector2(0, -texture.get_size().y * _base_scale.y * 0.5 - 6)


func _refresh() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if GameState.installed.has(module_id):
		modulate = Color.WHITE
	elif GameState.modules_ready.has(module_id):
		# Ready to install: blinks between outline and full colour.
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "modulate", Color(1, 1, 1, 0.9), 0.5)
		_pulse.tween_property(self, "modulate", Color(0.25, 0.2, 0.25, 0.6), 0.5)
	else:
		modulate = Color(0.16, 0.12, 0.16, 0.55)          # empty port: dark outline


func _install_effect() -> void:
	scale = _base_scale * 1.6
	modulate = Color(2.0, 1.8, 1.2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", _base_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
