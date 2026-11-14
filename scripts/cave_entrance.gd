class_name CaveEntrance
extends Area2D
## A dark cave mouth in a cliff on the surface. Walking into it enters the cave.
## The map generator (world_gen.gd) creates these, one per cave in Config.CAVES.
##
## Children made by the generator:
##   Mouth (Sprite2D)            the dark opening
##   CollisionShape2D            the trigger strip at the foot of the opening
##   Exit (Marker2D)             where the player stands when coming back out

const GROUP := "cave_entrances"

## Emitted when the player walks into the mouth.
signal player_entered(cave_id: String)

## Which cave this leads to: an id from Config.CAVES ("ice", "ore", "deep").
@export var cave_id: String = ""


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 1                       # the player's layer
	body_entered.connect(_on_body_entered)


## Where the player appears when leaving this cave.
func exit_position() -> Vector2:
	var marker := get_node_or_null("Exit") as Node2D
	return marker.global_position if marker != null else global_position


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D) or GameState.game_over:
		return
	player_entered.emit(cave_id)
	Travel.enter_cave(cave_id)
