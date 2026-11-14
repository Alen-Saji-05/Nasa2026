extends Node2D
## Harvest component. Add it as a child of the player.
## Press E near a metal or ice node: instant harvest with a short cooldown.
## The rules (what you get, when it is blocked) live in resource_node.gd.

const ACTION := "interact"

var _cooldown := 0.0


func _ready() -> void:
	# Use the "interact" action if the project defines one, otherwise bind E here.
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event(ACTION, key)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		_try_harvest()


func _try_harvest() -> void:
	if _cooldown > 0.0 or GameState.game_over:
		return
	var node := _nearest_node()
	if node == null:
		return
	_cooldown = Config.HARVEST_COOLDOWN
	var text := node.harvest()
	if text != "":
		var color := Color(0.75, 0.93, 1.0) if node.kind == "ice" else Color(1.0, 0.9, 0.7)
		FloatingText.spawn(get_tree().current_scene, global_position + Vector2(0, -20), text, color)


## Closest node in range. Full nodes win over empty ones, so standing between
## an empty and a full node still harvests the full one.
func _nearest_node() -> ResourceNode:
	var best: ResourceNode = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		var node := n as ResourceNode
		if node == null:
			continue
		var d := global_position.distance_to(node.global_position)
		if d > Config.HARVEST_RANGE:
			continue
		var score := d + (1000.0 if node.is_empty() else 0.0)
		if score < best_score:
			best_score = score
			best = node
	return best
