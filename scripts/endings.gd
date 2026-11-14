extends Control
## The ending animations. hud.gd plays one before it shows the game-over panel.
## Every way to lose looks different, and winning launches the repaired ship.
## Everything here runs while the game is paused (the HUD processes always).
##
##   await endings.play(GameState.death_cause)

## True once the last animation has finished (tests read it).
var finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Plays the ending for `cause`: "oxygen", "water", "hunger", "radiation",
## "storm", "time" or "won".
func play(cause: String) -> void:
	finished = false
	Dialogue.clear()                             # the ending line comes right away
	var scene := get_tree().current_scene
	var player := scene.get_node_or_null("Entities/Player") as Node2D if scene != null else null
	if player != null:
		var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null:
			sprite.stop()
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		match cause:
			"won": await _launch(scene, player, cam)
			"oxygen": await _suffocate(player, cam)
			"water": await _dehydrate(player, cam)
			"hunger": await _starve(player, cam)
			"radiation": await _irradiate(player, cam)
			"storm": await _buried(player, cam)
			_: await _too_late(cam)
	finished = true


# --- The ways to lose ---

## Out of oxygen: gasping and swaying, the view turns blue-black and closes in, then a collapse.
func _suffocate(player: Node2D, cam: Camera2D) -> void:
	Dialogue.say("Can't... breathe... the air... is gone...", true)
	var veil := _veil(Color(0.02, 0.04, 0.16))
	var t := create_tween()
	t.tween_property(veil, "color:a", 0.75, 2.6)
	t.parallel().tween_property(player, "modulate", Color(0.55, 0.65, 1.0), 2.0)
	if cam != null:
		t.parallel().tween_property(cam, "zoom", cam.zoom * 1.5, 2.6)
	var sway := create_tween()
	for i in 4:
		sway.tween_property(player, "rotation", 0.18, 0.3)
		sway.tween_property(player, "rotation", -0.18, 0.3)
	await sway.finished
	await _fall(player, PI * 0.5, veil, 0.9)


## Out of water: the sun bleaches everything, the air shimmers, the astronaut slumps sideways.
func _dehydrate(player: Node2D, cam: Camera2D) -> void:
	Dialogue.say("So... thirsty... everything is spinning...", true)
	var veil := _veil(Color(1.0, 0.92, 0.65))
	var t := create_tween()
	t.tween_property(veil, "color:a", 0.6, 2.8)
	t.parallel().tween_property(player, "modulate", Color(1.0, 0.85, 0.7), 2.0)
	t.parallel().tween_property(player, "scale:y", player.scale.y * 0.9, 2.0)
	if cam != null:
		var shimmer := create_tween()
		for i in 7:
			shimmer.tween_property(cam, "offset", Vector2(3, 1), 0.2)
			shimmer.tween_property(cam, "offset", Vector2(-3, -1), 0.2)
		shimmer.tween_property(cam, "offset", Vector2.ZERO, 0.2)
	await t.finished
	await _fall(player, -PI * 0.5, veil, 0.95)


## Starved: getting weaker, sinking to the knees, the colour drains out of the world.
func _starve(player: Node2D, cam: Camera2D) -> void:
	Dialogue.say("Too weak... I needed food... I should have grown more...", true)
	var veil := _veil(Color(0.18, 0.18, 0.2))
	var t := create_tween()
	t.tween_property(veil, "color:a", 0.65, 3.2)
	t.parallel().tween_property(player, "modulate", Color(0.7, 0.7, 0.7), 3.0)
	t.parallel().tween_property(player, "position:y", player.position.y + 3.0, 1.6)
	t.parallel().tween_property(player, "rotation", 0.25, 1.6)
	if cam != null:
		t.parallel().tween_property(cam, "zoom", cam.zoom * 1.3, 3.2)
	await t.finished
	await _fall(player, PI * 0.5, veil, 0.95, 1.4)


## Radiation: green flashes, the suit glows, and the astronaut fades away in a burst of specks.
func _irradiate(player: Node2D, cam: Camera2D) -> void:
	Dialogue.say("MC:SOL30, your dosimeter is off the scale... SOL30, respond!", true)
	var veil := _veil(Color(0.55, 1.0, 0.25))
	var t := create_tween()
	for i in 3:
		t.tween_property(veil, "color:a", 0.65, 0.12)
		t.tween_property(veil, "color:a", 0.1, 0.45)
	t.parallel().tween_property(player, "modulate", Color(0.7, 2.2, 0.6), 1.5)
	await t.finished
	if cam != null:
		_shake(cam, 8)
	var burst := _particles(player, 60, Color(0.75, 1.0, 0.35), 25.0, 60.0)
	burst.one_shot = true
	burst.emitting = true
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 1.4)
	fade.parallel().tween_property(veil, "color:a", 0.8, 1.6)
	await fade.finished
	await _wait(0.6)


## Lost in the storm: the dust closes in completely and the wind carries the astronaut off.
func _buried(player: Node2D, cam: Camera2D) -> void:
	Dialogue.say("I can't see anything... which way is the base...?", true)
	var veil := _veil(Color(0.72, 0.45, 0.25))
	var dust := _particles(self, 220, Color(0.9, 0.65, 0.42, 0.9), 300.0, 460.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.position = Vector2(-20, size.y * 0.5)
	dust.emission_rect_extents = Vector2(10, size.y * 0.6)
	dust.direction = Vector2(1, 0.1)
	dust.spread = 6.0
	dust.lifetime = 3.0
	dust.emitting = true
	var t := create_tween()
	t.tween_property(veil, "color:a", 0.55, 1.4)
	t.tween_property(player, "position:x", player.position.x + 40.0, 2.0).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(player, "rotation", 1.2, 2.0)
	t.parallel().tween_property(player, "modulate:a", 0.0, 2.0)
	t.parallel().tween_property(veil, "color:a", 0.95, 2.2)
	if cam != null:
		_shake(cam, 10)
	await t.finished
	await _wait(0.4)


## The return window closed: Mission Control's last call, the view pulls back and goes dark.
func _too_late(cam: Camera2D) -> void:
	Dialogue.say("MC:SOL30... the return window has closed. We're so sorry. We'll keep listening.", true)
	var veil := _veil(Color(0.0, 0.0, 0.02))
	var t := create_tween()
	if cam != null:
		t.tween_property(cam, "zoom", cam.zoom * 0.7, 3.5)
	t.parallel().tween_property(veil, "color:a", 0.85, 3.5)
	await t.finished


# --- Winning: the launch ---

func _launch(scene: Node, player: Node2D, cam: Camera2D) -> void:
	var ship := scene.get_node_or_null("Entities/BrokenRocket") as Node2D
	if ship == null:
		return
	ship.process_mode = Node.PROCESS_MODE_ALWAYS
	var ship_sprite := ship.get_node_or_null("Sprite2D") as Sprite2D
	Dialogue.say("MC:All systems green. Ignition sequence start... Godspeed, SOL30!", true)
	await _wait(1.2)

	# The astronaut walks to the hatch and climbs in.
	var board := create_tween()
	board.tween_property(player, "global_position", ship.global_position + Vector2(0, -4), 0.9)
	board.tween_property(player, "modulate:a", 0.0, 0.4)
	await board.finished
	if cam != null:
		var view := cam.get_screen_center_position()
		cam.top_level = true
		cam.position_smoothing_enabled = false
		cam.global_position = view
		create_tween().tween_property(cam, "global_position", ship.global_position + Vector2(0, -50), 0.8)

	# Ignition: fire and smoke under the ship, everything shakes.
	var flame := _particles(ship, 50, Color(1.0, 0.6, 0.15), 40.0, 80.0)
	flame.name = "Flame"
	flame.direction = Vector2.DOWN
	flame.spread = 18.0
	flame.lifetime = 0.45
	flame.scale_amount_max = 3.0
	flame.emitting = true
	var smoke := _particles(ship, 70, Color(0.75, 0.7, 0.68, 0.7), 20.0, 55.0)
	smoke.name = "Smoke"
	smoke.local_coords = false
	smoke.direction = Vector2.DOWN
	smoke.spread = 70.0
	smoke.lifetime = 2.2
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 7.0
	smoke.emitting = true
	if ship_sprite != null:
		var rumble := create_tween()
		for i in 12:
			rumble.tween_property(ship_sprite, "offset:x", 2.0 if i % 2 == 0 else -2.0, 0.06)
		rumble.tween_property(ship_sprite, "offset:x", 0.0, 0.06)
	if cam != null:
		_shake(cam, 14)
	await _wait(1.6)

	# Lift-off: slow at first, then faster and faster, the camera follows up.
	var up := create_tween()
	up.tween_property(ship, "position:y", ship.position.y - 900.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if cam != null:
		up.parallel().tween_property(cam, "global_position:y", cam.global_position.y - 260.0, 3.0).set_ease(Tween.EASE_IN)
	await _wait(2.8)
	var veil := _veil(Color(1.0, 0.97, 0.9))
	var flash := create_tween()
	flash.tween_property(veil, "color:a", 1.0, 1.0)
	await flash.finished
	await _wait(0.3)


# --- Helpers ---

func _fall(player: Node2D, angle: float, veil: ColorRect, dark: float, seconds := 0.5) -> void:
	var t := create_tween()
	t.tween_property(player, "rotation", angle, seconds).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(player, "position:y", player.position.y + 4.0, seconds)
	t.tween_property(veil, "color:a", dark, 1.0)
	await t.finished
	await _wait(0.4)


func _veil(color: Color) -> ColorRect:
	var veil := ColorRect.new()
	veil.color = Color(color, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	return veil


func _particles(parent: Node, amount: int, color: Color, v_min: float, v_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.amount = amount
	p.emitting = false
	p.lifetime = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.z_index = 60
	parent.add_child(p)
	return p


func _shake(cam: Camera2D, times: int) -> void:
	var t := create_tween()
	for i in times:
		t.tween_property(cam, "offset", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout
