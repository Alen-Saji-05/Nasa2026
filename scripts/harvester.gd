class_name Interactor
extends Node2D
## The player's E key. Add it as a child of the player (the node is called Harvester).
##
## Anything in the group "interactables" with an `interact(player)` method can be
## used: metal and ice deposits, ladders, later machines. When several are in
## range the NEAREST one wins, and a small "E" shows above it.
##
## Optional methods on a target:
##   interact_penalty() -> float   extra distance, so it loses against other targets
##   prompt_offset() -> Vector2    where the "E" goes, relative to the target

const ACTION := "interact"
const GROUP := "interactables"

var _cooldown := 0.0
var _focus: Node2D = null
var _prompt: Label


func _ready() -> void:
	# Use the "interact" action if the project defines one, otherwise bind E here.
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event(ACTION, key)
	_make_prompt()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_focus = _nearest()
	_prompt.visible = _focus != null and not GameState.game_over
	if _prompt.visible:
		var offset := Vector2(0, -20)
		if _focus.has_method("prompt_offset"):
			offset = _focus.prompt_offset()
		_prompt.position = _focus.global_position + offset - _prompt.size * _prompt.scale * Vector2(0.5, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		use()


## What E would act on right now, or null.
func focus() -> Node2D:
	return _focus


## Uses the nearest thing in range (same as pressing E).
func use() -> void:
	if _cooldown > 0.0 or GameState.game_over or Travel.busy:
		return
	var target := _nearest()
	if target == null:
		return
	_cooldown = Config.HARVEST_COOLDOWN
	target.interact(get_parent())


func _nearest() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(GROUP):
		var target := n as Node2D
		if target == null or not target.has_method("interact"):
			continue
		var d := global_position.distance_to(target.global_position)
		if d > Config.INTERACT_RANGE:
			continue
		var score := d
		if target.has_method("interact_penalty"):
			score += target.interact_penalty()
		if score < best_score:
			best_score = score
			best = target
	return best


## The small "E" tag. It sits on its own canvas layer that moves with the camera,
## so it stays bright in a dark cave.
func _make_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PromptLayer"
	layer.layer = 5
	layer.follow_viewport_enabled = true
	add_child(layer)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.07, 0.05, 0.92)
	box.border_color = Color(1.0, 0.86, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 1
	box.content_margin_bottom = 1

	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = "E"
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_prompt.add_theme_stylebox_override("normal", box)
	_prompt.scale = Vector2(0.5, 0.5)        # the camera zooms 2x or more, so this stays sharp
	_prompt.visible = false
	layer.add_child(_prompt)
	_prompt.reset_size()
