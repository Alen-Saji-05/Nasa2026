extends Node2D
## Gives every Sprite2D child a solid collider so the player cannot walk through it.
##
## Put this script on a container node (Entities/Nodes, Entities/Decor, ...).
## The collider is a small box at the BASE of each sprite (its "footprint"), not the
## whole picture, so the player can walk behind tall things like crystals and still
## bump into the part that touches the ground. It scales with the sprite.
##
## Colliders are created at run time, so the .tscn stays clean. Sprites that are
## added later (for example by the map generator) get one as well.

const BODY_NAME := "ObstacleBody"

## Footprint size as a fraction of the sprite: x = width, y = height (measured from the bottom).
@export var footprint: Vector2 = Vector2(0.7, 0.4)


func _ready() -> void:
	for child in get_children():
		_add_collider(child)
	child_entered_tree.connect(_on_child_entered)


func _on_child_entered(child: Node) -> void:
	# Wait one frame so the sprite already has its texture and scale.
	_add_collider.call_deferred(child)


func _add_collider(node: Node) -> void:
	var sprite := node as Sprite2D
	if sprite == null or sprite.texture == null or not is_instance_valid(sprite):
		return
	if sprite.has_node(BODY_NAME):
		return

	var tex_size := sprite.texture.get_size()
	var center := sprite.offset + (Vector2.ZERO if sprite.centered else tex_size * 0.5)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(tex_size.x * footprint.x, tex_size.y * footprint.y)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	# Sit the box on the bottom edge of the sprite.
	collision.position = Vector2(center.x, center.y + tex_size.y * 0.5 - shape.size.y * 0.5)

	var body := StaticBody2D.new()
	body.name = BODY_NAME
	body.collision_layer = 1   # same layer as the rock walls and the hab
	body.add_child(collision)
	sprite.add_child(body)
