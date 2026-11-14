
extends Node2D

@export var collision_ratio: float = 0.32

func _ready() -> void:
	for sprite in get_children():
		if not sprite is Sprite2D:
			continue

		if sprite.texture == null:
			continue

		var body = StaticBody2D.new()
		body.name = "ObstacleBody"
		sprite.add_child(body)

		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"

		var shape = CircleShape2D.new()
		var texture_size = sprite.texture.get_size()

		shape.radius = min(
			texture_size.x,
			texture_size.y
		) * collision_ratio

		collision.shape = shape
		body.add_child(collision)
