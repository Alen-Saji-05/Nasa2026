class_name Machine
extends StaticBody2D
## One built machine (scenes/Machine.tscn). Everything about it comes from
## Config.MACHINES[machine_id]: art, size, cost, text. Its numbers (power, oxygen)
## are worked out in GameState, so they keep running while the player is in a cave.
##
## The look follows the game:
##   solar         "running" loop in the sun, idle frame when there is no sun
##   battery       frame by charge (empty, 25%, 50%, full)
##   o2_generator  "running" while it makes oxygen; a warning icon when it has no power or water
##   backup_power  always "running"
##   water_tank    frame by how full the water is
##   ascent        idle; the flame and the launch start when it is built
## Press E next to a machine to see what it is doing.

const GROUP := "machines"
const RefineryPanel := preload("res://scripts/refinery_panel.gd")
const FPS := 6.0

@export var machine_id: String = ""
## The build pad it stands on.
var pad_id: String = ""

var _launching := false
var _base_scale := Vector2.ONE
var _pop := 0.0                              # the refinery's "ready" bounce

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var warning: Sprite2D = $Warning


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactor.GROUP)
	var def := Config.machine(machine_id)
	if def.is_empty():
		push_warning("Machine: unknown machine '%s'" % machine_id)
		return
	sprite.sprite_frames = _make_frames(def)
	sprite.scale = Vector2.ONE * float(def.get("scale", 1.0))
	if def.has("pixels"):
		sprite.scale = Vector2.ONE * float(def.pixels) / _art_size().x
	# The art stands on the node's position (its feet), so y-sorting works.
	var frame_size := _art_size()
	sprite.offset = Vector2(0, -frame_size.y * 0.5)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(frame_size.x * sprite.scale.x * 0.8, 10.0)
	collision.shape = shape
	collision.position = Vector2(0, -5)
	warning.texture = load(Config.MACHINE_WARNING_ICON)
	warning.position = Vector2(0, -height() - 6)
	warning.visible = false
	_base_scale = sprite.scale
	if def.get("acts_as", "") == "refinery":
		GameState.refinery_done.connect(_on_refinery_done)
	_update_look()


func _process(delta: float) -> void:
	_pop = maxf(0.0, _pop - delta * 1.5)
	if not _launching:
		_update_look()


## How tall the machine is on screen, in pixels.
func height() -> float:
	return _art_size().y * sprite.scale.y


func display_name() -> String:
	return Config.machine(machine_id).get("name", machine_id)


## One line about what the machine is doing right now.
func status_text() -> String:
	var name_text := display_name()
	match Config.machine(machine_id).get("acts_as", machine_id):
		"solar":
			if GameState.sun <= 0.05:
				return "%s: no sunlight, making nothing" % name_text
			return "%s: making %.1f power" % [name_text, Config.SOLAR_OUTPUT * GameState.sun]
		"battery":
			return "%s: storage %d / %d" % [name_text, roundi(GameState.battery_charge), roundi(GameState.battery_capacity())]
		"o2_generator":
			var problem := GameState.o2_generator_problem()
			if problem != "":
				return "%s: stopped, %s" % [name_text, problem]
			if GameState.o2_generator_working():
				return "%s: making oxygen" % name_text
			return "%s: waiting, oxygen is above %d" % [name_text, roundi(Config.O2_GEN_ON_BELOW)]
		"backup_power":
			return "%s: making %.1f power" % [name_text, Config.BACKUP_OUTPUT]
		"water_tank":
			return "%s: water limit %d" % [name_text, roundi(GameState.water_limit)]
		"refinery":
			if GameState.refinery_left() > 0:
				return "%s: refining, %s left" % [name_text, RefineryPanel._clock_text(GameState.refinery_seconds_left())]
			return "%s: %s" % [name_text, "ready to collect" if GameState.refinery_ready() else "idle"]
		"greenhouse":
			return "%s: growing (%d potatoes ready)" % [name_text, GameState.machine_output.get("potato", 0)]
		"shelter":
			return "%s: %s" % [name_text, "safe outside" if Hazards.is_safe() else "get inside!"]
		"co2_capture":
			if not GameState.o2_generator_powered:
				return "%s: stopped, no power" % name_text
			return "%s: capturing CO2 (%d capsules ready)" % [name_text, GameState.machine_output.get("co2", 0)]
	return name_text


# --- Used by the player's Interactor (E key) ---

func interact(_player: Node2D) -> void:
	match Config.machine(machine_id).get("acts_as", machine_id):
		"refinery":
			var panel := get_tree().current_scene.get_node_or_null("UI/HUD/RefineryPanel")
			if panel != null:
				panel.call("open", self)
			else:
				GameState.say(status_text())
		"co2_capture":
			var got := GameState.collect_output(["co2"])
			GameState.say("Collected " + got if got != "" else status_text())
		"greenhouse":
			var got := GameState.collect_output(["potato"])
			GameState.say("Harvested " + got + " (press F to eat)" if got != "" else status_text())
		"shelter":
			Travel.enter_shelter()
		_:
			GameState.say(status_text())


func prompt_offset() -> Vector2:
	if machine_id == "shelter":
		return Vector2(0, -height() * 0.12)        # on the door
	return Vector2(0, -height() - 4)


func prompt_text() -> String:
	return "Press E to Enter Emergency Shelter" if machine_id == "shelter" else "E"


# ---------------------------------------------------------------------------

func _update_look() -> void:
	var problem := ""
	match Config.machine(machine_id).get("acts_as", machine_id):
		"solar":
			_play("running" if GameState.sun > 0.05 else "idle")
		"battery":
			_show_level(GameState.battery_charge / maxf(1.0, GameState.battery_capacity()))
		"o2_generator":
			problem = GameState.o2_generator_problem()
			_play("running" if GameState.o2_generator_working() else "idle")
		"backup_power":
			_play("idle" if GameState.game_over else "running")
		"water_tank":
			_show_level(GameState.water / maxf(1.0, GameState.water_limit))
		"refinery":
			_set_working(GameState.refinery_working())
			if GameState.refinery_left() > 0 and not GameState.o2_generator_powered:
				problem = "no power"
			_refinery_look()
		"greenhouse":
			_play("idle")
			sprite.modulate = Color(1.15, 1.25, 1.0) if GameState.machine_output.get("potato", 0) > 0 else Color.WHITE
		"co2_capture":
			_set_working(GameState.co2_capture_working())
			problem = "" if GameState.o2_generator_powered else "no power"
		_:
			_play("idle")
	warning.visible = problem != ""


## Machines with one picture: smoke from the top and a gentle hum while they work.
func _set_working(on: bool) -> void:
	_play("idle")
	var smoke := get_node_or_null("Smoke") as CPUParticles2D
	if smoke == null:
		smoke = CPUParticles2D.new()
		smoke.name = "Smoke"
		smoke.position = Vector2(0, -height() * 0.9)
		smoke.amount = 10
		smoke.lifetime = 1.6
		smoke.direction = Vector2(0, -1)
		smoke.spread = 15.0
		smoke.gravity = Vector2(4, -8)
		smoke.initial_velocity_min = 5.0
		smoke.initial_velocity_max = 10.0
		smoke.scale_amount_min = 1.5
		smoke.scale_amount_max = 3.0
		smoke.color = Color(0.75, 0.72, 0.75, 0.6)
		add_child(smoke)
	smoke.emitting = on
	sprite.position.y = sin(Time.get_ticks_msec() * 0.02) * 0.6 if on else 0.0


func _play(anim: String) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## The refinery's countdown clock above it, and its "ready" animation: it bounces,
## glows gold, sparkles and shows READY! until the batch is collected.
func _refinery_look() -> void:
	var clock := get_node_or_null("Clock") as Node2D
	if clock == null:
		clock = Node2D.new()
		clock.name = "Clock"
		clock.z_index = 40
		var label := Label.new()
		label.name = "Time"
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.04))
		label.add_theme_constant_override("outline_size", 6)
		label.scale = Vector2(0.5, 0.5)
		label.position = Vector2(-2, -7)
		clock.add_child(label)
		clock.draw.connect(func() -> void:
			var busy := GameState.refinery_left() > 0
			RefineryPanel.draw_clock(clock, Vector2(-9, 0), 5.5,
				1.0 - GameState.refinery_seconds_left() / maxf(0.01, GameState.refinery_total),
				busy, not busy and GameState.refinery_ready()))
		add_child(clock)
		var sparks := CPUParticles2D.new()
		sparks.name = "Sparks"
		sparks.amount = 14
		sparks.lifetime = 0.9
		sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		sparks.emission_rect_extents = Vector2(height() * 0.35, height() * 0.3)
		sparks.position = Vector2(0, -height() * 0.5)
		sparks.direction = Vector2.UP
		sparks.spread = 40.0
		sparks.gravity = Vector2(0, 20)
		sparks.initial_velocity_min = 10.0
		sparks.initial_velocity_max = 25.0
		sparks.scale_amount_min = 1.0
		sparks.scale_amount_max = 2.0
		sparks.color = Color(1.0, 0.9, 0.4)
		sparks.emitting = false
		add_child(sparks)
	var busy := GameState.refinery_left() > 0
	var ready := not busy and GameState.refinery_ready()
	var t := Time.get_ticks_msec() * 0.001
	clock.visible = busy or ready
	var label := clock.get_node("Time") as Label
	if busy:
		label.text = RefineryPanel._clock_text(GameState.refinery_seconds_left())
		label.add_theme_color_override("font_color", Color.WHITE if GameState.o2_generator_powered else Color(1.0, 0.45, 0.35))
		clock.position = Vector2(0, -height() - 22)
	elif ready:
		label.text = "READY!"
		label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.45))
		clock.position = Vector2(0, -height() - 22 + sin(t * 5.0) * 2.0)
	clock.queue_redraw()
	(get_node("Sparks") as CPUParticles2D).emitting = ready
	var bounce := (0.03 * absf(sin(t * 4.0)) if ready else 0.0) + _pop * 0.25
	sprite.scale = _base_scale * Vector2(1.0 - bounce * 0.5, 1.0 + bounce)
	sprite.modulate = Color.WHITE.lerp(Color(1.35, 1.2, 0.7), 0.5 + 0.5 * sin(t * 5.0)) if ready else Color.WHITE


func _on_refinery_done() -> void:
	_pop = 1.0
	var burst := CPUParticles2D.new()
	burst.position = Vector2(0, -height() * 0.6)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 30
	burst.lifetime = 0.8
	burst.spread = 180.0
	burst.gravity = Vector2(0, 40)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 60.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 2.5
	burst.color = Color(1.0, 0.85, 0.35)
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


## Picks a "levels" frame: 0 = empty, last = full. Empty only at (almost) zero.
func _show_level(share: float) -> void:
	if not sprite.sprite_frames.has_animation("levels"):
		_play("idle")
		return
	sprite.animation = "levels"
	var last := sprite.sprite_frames.get_frame_count("levels") - 1
	var index := 0
	if share > 0.02:
		index = clampi(ceili(share * last), 1, last)
	sprite.frame = index


func _make_frames(def: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ["idle", "running", "levels"]:
		if not def.has(anim):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, anim != "levels")
		for path: String in def[anim]:
			frames.add_frame(anim, load(path))
	if not frames.has_animation("idle"):
		# Machines that only have levels show the first level when idle.
		frames.add_animation("idle")
		frames.add_frame("idle", frames.get_frame_texture("levels", 0))
	return frames


func _art_size() -> Vector2:
	var anim := "levels" if sprite.sprite_frames.has_animation("levels") else "idle"
	return sprite.sprite_frames.get_frame_texture(anim, 0).get_size()


# ---------------------------------------------------------------------------
# Launch (Ascent vehicle only)
# ---------------------------------------------------------------------------

## The countdown, the flame and the climb. Then the game is won.
## The game is paused meanwhile, so nothing else moves or drains.
func launch() -> void:
	_launching = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	var tree := get_tree()
	tree.paused = true

	var player := tree.current_scene.get_node_or_null("Entities/Player")
	if player:
		player.visible = false

	for n in [3, 2, 1]:
		GameState.say("Ignition in %d..." % n)
		await tree.create_timer(1.0).timeout

	GameState.say("Lift-off!")
	sprite.play("running")
	add_child(_exhaust())

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 260.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	GameState.win("Launch successful! You are on your way home.")


func _exhaust() -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.name = "Exhaust"
	smoke.process_mode = Node.PROCESS_MODE_ALWAYS
	smoke.amount = 40
	smoke.lifetime = 1.4
	smoke.local_coords = false
	smoke.direction = Vector2(0, 1)
	smoke.spread = 25.0
	smoke.gravity = Vector2(0, -10)
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 45.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	ramp.set_color(1, Color(0.6, 0.55, 0.55, 0.0))
	ramp.add_point(0.3, Color(0.85, 0.6, 0.45, 0.8))
	smoke.color_ramp = ramp
	return smoke
