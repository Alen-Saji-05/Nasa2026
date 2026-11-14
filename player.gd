extends CharacterBody2D

## Emitted when the player hits something solid hard enough to bounce.
## `collider` is the thing that was hit, `impact_speed` how fast we hit it (px/s).
signal bumped(collider: Object, impact_speed: float)

@export var speed: float = 250.0

@export_group("Bounce")
## How much of the impact is thrown back. 0 = no bounce, 1 = full rebound.
@export_range(0.0, 1.0) var bounce_strength: float = 0.6
## Seconds the bounce lasts. The player cannot steer during it.
@export var bounce_time: float = 0.2
## Light brushes along a wall do not bounce; only hits faster than this (px/s) do.
@export var min_bounce_speed: float = 80.0

var _bounce_velocity := Vector2.ZERO
var _bounce_left := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Top-down game: there is no floor or gravity, so use floating mode.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	# While bouncing, the knock-back replaces player input and fades out.
	if _bounce_left > 0.0:
		_bounce_left -= delta
		velocity = _bounce_velocity * clampf(_bounce_left / bounce_time, 0.0, 1.0)
		move_and_slide()
		return

	var direction := Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
		play_movement_animation(direction)
	else:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		animated_sprite.frame = 0

	var intended := velocity
	move_and_slide()
	_check_bounce(intended)


## Looks at everything we touched this frame and bounces off the hardest hit.
## Works for any solid thing: rock walls, the hab, rocks, metal, ice.
func _check_bounce(intended: Vector2) -> void:
	var best_impact := 0.0
	var best_normal := Vector2.ZERO
	var best_collider: Object = null

	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var normal := hit.get_normal()
		var impact := -intended.dot(normal)   # speed straight into the surface
		if impact > best_impact:
			best_impact = impact
			best_normal = normal
			best_collider = hit.get_collider()

	if best_impact < min_bounce_speed:
		return

	_bounce_velocity = intended.bounce(best_normal) * bounce_strength
	_bounce_left = bounce_time
	velocity = _bounce_velocity
	bumped.emit(best_collider, best_impact)


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
