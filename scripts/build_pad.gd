class_name BuildPad
extends Sprite2D
## A marked square on the base where one machine can be built.
## The map generator (world_gen.gd) creates these; the launch pad is one too.
##
## While the player is placing a machine (see builder.gd) the pads that fit
## light up, and E (or a click) on one builds the machine there.
## Built machines are remembered in GameState.machines, so when the surface is
## loaded again (back from a cave) each pad puts its machine back.

const GROUP := "build_pads"
const FIT_COLOR := Color(0.65, 1.0, 0.6)
const NO_FIT_COLOR := Color(1.0, 1.0, 1.0, 0.35)

## Stable name ("pad_01" ... or "launch"), used to remember what was built here.
@export var pad_id: String = ""
## "machine" pads take normal machines. The "launch" pad takes only the Ascent vehicle.
@export_enum("machine", "launch") var pad_type: String = "machine"

## The machine standing on this pad, or null.
var machine: Node = null


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactor.GROUP)
	Builder.placing_changed.connect(_on_placing_changed)
	var built: String = GameState.machines.get(pad_id, "")
	if built != "":
		# Wait until the whole scene is ready before adding to it.
		spawn_machine.call_deferred(built)


func is_free() -> bool:
	return machine == null


## True if this machine may be built here (right pad type and free).
func fits(machine_id: String) -> bool:
	return is_free() and Config.machine(machine_id).get("pad", "") == pad_type


## Puts the machine's scene on this pad. Does not pay or record anything:
## builder.gd does that. Returns the new machine.
func spawn_machine(machine_id: String) -> Node:
	var scene: PackedScene = load(Config.MACHINE_SCENE)
	var m := scene.instantiate()
	m.set("machine_id", machine_id)
	m.set("pad_id", pad_id)
	# Feet a little below the pad's middle, so it stands on the pad.
	m.position = position + Vector2(0, 12)
	var entities := get_tree().current_scene.get_node_or_null("Entities")
	(entities if entities != null else get_parent()).add_child(m)
	machine = m
	return m


# --- Used by the player's Interactor (E key) ---

func interact(_player: Node2D) -> void:
	Builder.place_on(self)


## Only a pad that fits the machine being placed can be picked with E.
func interact_penalty() -> float:
	return 0.0 if Builder.placing != "" and fits(Builder.placing) else INF


func _on_placing_changed(machine_id: String) -> void:
	if machine_id == "":
		modulate = Color.WHITE
	elif fits(machine_id):
		modulate = FIT_COLOR
	else:
		modulate = NO_FIT_COLOR
