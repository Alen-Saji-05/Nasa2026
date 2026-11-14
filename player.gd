extends CharacterBody2D
@export var speed: float = 250.0

func _physics_process(_delta: float) -> void:

	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		print("Moving: ", direction)
func _input(event):
	if event is InputEventKey and event.pressed:
		print("Key detected: ", event.as_text())
