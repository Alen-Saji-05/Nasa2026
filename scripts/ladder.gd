class_name Ladder
extends Sprite2D
## A ladder between two layers of a cave. Walk up to it and press E.
## The cave scene (scripts/world/cave.gd) creates these.

## "down" = a hole with a ladder to the layer below, "up" = a ladder back up.
@export_enum("up", "down") var direction: String = "down"


func _ready() -> void:
	add_to_group(Interactor.GROUP)


# --- Used by the player's Interactor (E key) ---

func interact(_player: Node2D) -> void:
	if direction == "down":
		Travel.change_layer(GameState.cave_layer + 1, "ladder_down")
	else:
		Travel.change_layer(GameState.cave_layer - 1, "ladder_up")


func prompt_offset() -> Vector2:
	return Vector2(0, -26) if direction == "up" else Vector2(0, -14)
