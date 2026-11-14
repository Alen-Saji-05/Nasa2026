extends Node
## Building machines (autoload "Builder").
##
##   Builder.start_placing("solar")   the pads that fit light up
##   E on a lit pad, or a click on it  -> pays, builds, done
##   Esc or a right click              -> cancel
##
## The Build Book calls start_placing() for machines and craft() for items and ship modules.

## Emitted when placing starts or stops. `machine_id` is "" when it stops.
signal placing_changed(machine_id: String)
## Emitted after a machine was built.
signal built(machine_id: String, pad_id: String)

## The machine being placed, or "".
var placing: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # so the debug keys work on a pause too


## Why this machine cannot be built now, or "" if it can.
func build_problem(machine_id: String) -> String:
	var def := Config.machine(machine_id)
	if def.is_empty():
		return "Unknown machine"
	if GameState.game_over:
		return "The game is over"
	var kind: String = def.get("kind", "machine")
	if kind == "machine" and GameState.cave_id != "":
		return "Machines are built at the base"
	if (def.get("unique", false) or kind == "module") and GameState.has_built(machine_id):
		return "Already built"
	if def.has("requires") and not GameState.has_built(def.requires):
		return "Needs a %s first" % Config.machine(def.requires).name
	var cost := GameState.cost_problem(machine_id)
	if cost != "":
		return cost
	if kind != "machine":
		return ""
	if _pads().filter(func(p: Node) -> bool: return p.fits(machine_id)).is_empty():
		return "No free launch pad" if def.pad == "launch" else "No free build pad"
	return ""


## Starts placing. Returns false (and says why) if it cannot be built.
func start_placing(machine_id: String) -> bool:
	var problem := build_problem(machine_id)
	if problem != "":
		GameState.say(problem)
		return false
	placing = machine_id
	placing_changed.emit(placing)
	var where := "the launch pad" if Config.machine(machine_id).pad == "launch" else "a lit pad"
	GameState.say("%s: press E on %s, or click it. Esc cancels." % [Config.machine(machine_id).name, where])
	return true


func cancel() -> void:
	if placing == "":
		return
	placing = ""
	placing_changed.emit("")


## Builds the machine being placed on this pad. Returns the machine, or null.
func place_on(pad: Node) -> Node:
	if placing == "" or pad == null:
		return null
	var machine_id := placing
	if not pad.fits(machine_id):
		GameState.say("That pad does not fit the %s" % Config.machine(machine_id).name)
		return null
	var def := Config.machine(machine_id)
	var paid: bool = GameState.spend_items(def.cost) if def.has("cost") else GameState.spend(int(def.metal), float(def.water))
	if not paid:
		GameState.say(GameState.cost_problem(machine_id))
		cancel()
		return null
	var first := not GameState.has_built(machine_id)
	cancel()
	GameState.add_machine(pad.pad_id, machine_id)
	var m: Node = pad.spawn_machine(machine_id)
	GameState.say("%s built!" % def.name if first else "Another %s built" % def.name)
	built.emit(machine_id, pad.pad_id)
	Dialogue.once("built_" + machine_id)
	return m


## Crafts an item or a ship module from the book (no pad). Returns true if done.
func craft(machine_id: String) -> bool:
	var problem := build_problem(machine_id)
	var def := Config.machine(machine_id)
	if problem != "" or not GameState.spend_items(def.cost):
		GameState.say(problem if problem != "" else GameState.cost_problem(machine_id))
		return false
	if def.kind == "module":
		GameState.modules_ready.append(machine_id)
		GameState.ship_changed.emit()
		GameState.say("%s built. Install it at its port on the ship (E)." % def.name)
		Dialogue.once("crafted_module")
	else:
		GameState.add_item(machine_id, 1)
		GameState.say("Crafted 1 %s" % def.name)
	built.emit(machine_id, "")
	return true


func _pads() -> Array[Node]:
	return get_tree().get_nodes_in_group(BuildPad.GROUP)


## The pad under the mouse pointer, or null.
func _pad_at_mouse() -> Node:
	var scene := get_tree().current_scene as Node2D
	if scene == null:
		return null
	var point := scene.get_global_mouse_position()
	for pad: Node in _pads():
		var sprite := pad as Sprite2D
		var rect := sprite.get_rect()
		rect = Rect2(sprite.to_global(rect.position), rect.size * sprite.global_scale)
		if rect.has_point(point):
			return pad
	return null


func _unhandled_input(event: InputEvent) -> void:
	if placing != "":
		if event.is_action_pressed("ui_cancel"):
			cancel()
			GameState.say("Building cancelled")
			get_viewport().set_input_as_handled()
			return
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			if click.button_index == MOUSE_BUTTON_RIGHT:
				cancel()
			elif click.button_index == MOUSE_BUTTON_LEFT:
				var pad := _pad_at_mouse()
				if pad != null:
					place_on(pad)
			get_viewport().set_input_as_handled()
			return

	var key := event as InputEventKey
	if not Config.DEBUG_KEYS or key == null or not key.pressed or key.echo or get_tree().paused:
		return
	if key.physical_keycode == KEY_F1:
		for id: String in Config.ITEM_ORDER:
			GameState.add_item(id, 10)
		GameState.add_water(30.0)
		GameState.say("Debug: +10 of every material")
	elif key.physical_keycode == KEY_F3:
		Hazards.trigger("radiation")
	elif key.physical_keycode == KEY_F4:
		Hazards.trigger("storm")
	elif key.physical_keycode == KEY_F2:
		GameState.sol_elapsed_seconds += Config.SOL_SECONDS * 0.5
		GameState.say("Debug: half a sol later")
