extends CanvasLayer
## Moves the player between places (autoload "Travel"): surface <-> cave, and
## between the layers of a cave. Every move is a short fade to black.
##
##   Travel.enter_cave("ice")          from a cave entrance on the surface
##   Travel.change_layer(1, "ladder_down")   down a ladder
##   Travel.exit_cave()                out of the cave, back to its entrance
##
## Where the player is lives in GameState (cave_id, cave_layer, arrival).
## The scene that loads reads those and puts the player in the right spot.

## True while a move is in progress. Nothing else should start then.
var busy := false

var _fade: ColorRect


func _ready() -> void:
	layer = 100                                  # above the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS      # the fade runs while the game is paused
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


## Into the first layer of a cave.
func enter_cave(cave_id: String) -> void:
	if Config.cave(cave_id).is_empty():
		push_warning("Travel: unknown cave '%s'" % cave_id)
		return
	_go(cave_id, 0, "from_surface", Config.CAVE_SCENE)


## To another layer of the cave the player is in. `how` is "ladder_down" or "ladder_up".
func change_layer(layer_index: int, how: String) -> void:
	var cave := Config.cave(GameState.cave_id)
	if cave.is_empty() or layer_index < 0 or layer_index >= cave.layers.size():
		return
	_go(GameState.cave_id, layer_index, how, Config.CAVE_SCENE)


## Out of the cave: back on the surface, in front of the entrance.
func exit_cave() -> void:
	_go("", 0, "entrance:" + GameState.cave_id, Config.WORLD_SCENE)


func _go(cave_id: String, layer_index: int, how: String, scene: String) -> void:
	if busy or GameState.game_over:
		return
	busy = true
	var tree := get_tree()
	tree.paused = true                           # nobody moves or loses oxygen during the fade
	await _fade_to(1.0)
	GameState.set_location(cave_id, layer_index, how)
	tree.change_scene_to_file(scene)
	await tree.process_frame                     # the new scene is in place after two frames
	await tree.process_frame
	tree.paused = false
	await _fade_to(0.0)
	busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, Config.TRAVEL_FADE_SECONDS)
	await tween.finished
