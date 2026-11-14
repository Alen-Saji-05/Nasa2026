class_name FloatingText
extends RefCounted
## Small text that pops up in the world, floats up and fades ("+8 metal", "-4 O2").
## Use: FloatingText.spawn(get_tree().current_scene, global_position, "+8 metal")


static func spawn(parent: Node, world_position: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.scale = Vector2(0.5, 0.5)          # the camera zooms 2x, so this stays sharp
	label.z_index = 100                      # above the map and the player
	parent.add_child(label)
	label.reset_size()
	label.global_position = world_position - label.size * label.scale * Vector2(0.5, 1.0)

	# Float up for a second; stay fully visible first, then fade out.
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)
