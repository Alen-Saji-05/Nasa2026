
extends CharacterBody2D

@export var speed: float = 250.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(_delta: float) -> void:
	var direction = Vector2.ZERO

	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
		play_movement_animation(direction)
	else:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		animated_sprite.frame = 0

	move_and_slide()


func play_movement_animation(direction: Vector2) -> void:

	if abs(direction.x) > abs(direction.y):
		animated_sprite.play("side")
		animated_sprite.flip_h = direction.x > 0

	elif direction.y < 0:
		animated_sprite.play("back")
		animated_sprite.flip_h = false

	else:
		animated_sprite.play("front")
		animated_sprite.flip_h = false
