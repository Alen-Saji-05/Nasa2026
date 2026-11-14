class_name CaveExit
extends Area2D
## The way out of a cave, in the south wall of its first layer. Walking into it
## takes the player back to the cave's entrance on the surface.
## The cave scene (scripts/world/cave.gd) creates this.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1                       # the player's layer
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		Travel.exit_cave()
