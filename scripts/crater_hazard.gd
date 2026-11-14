extends Sprite2D
## A crater on a path. It only costs oxygen if Config.CRATER_O2_PENALTY is above 0
## (it is 0 now: walking over craters must not cost oxygen).
## The penalty is applied once per entry, never every frame.
##
## The trigger area is created at run time, so the .tscn stays clean.

## Size of the trigger as a fraction of the sprite. 1.0 or more = the whole
## picture (used for craters that fill a corridor and cannot be avoided).
@export var hazard_fraction: Vector2 = Vector2(0.7, 0.7)

var _next_hit_msec := 0


func _ready() -> void:
	if texture == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = texture.get_size() * hazard_fraction
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var area := Area2D.new()
	area.name = "HazardArea"
	area.collision_layer = 0
	area.collision_mask = 1                  # the player's layer
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D) or GameState.game_over or Config.CRATER_O2_PENALTY <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now < _next_hit_msec:
		return
	_next_hit_msec = now + int(Config.CRATER_COOLDOWN * 1000.0)

	GameState.consume_oxygen(Config.CRATER_O2_PENALTY)
	FloatingText.spawn(get_tree().current_scene, body.global_position + Vector2(0, -20),
		"-%d O2" % roundi(Config.CRATER_O2_PENALTY), Color(1.0, 0.85, 0.8))

	# Short red flash on the player.
	var sprite := body.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite != null:
		sprite.modulate = Color(1.0, 0.35, 0.3)
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.35)
