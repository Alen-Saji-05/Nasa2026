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
const FPS := 6.0

@export var machine_id: String = ""
## The build pad it stands on.
var pad_id: String = ""

var _launching := false

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
	sprite.scale = Vector2.ONE * float(def.scale)
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
	_update_look()


func _process(_delta: float) -> void:
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
	match machine_id:
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
	return name_text


# --- Used by the player's Interactor (E key) ---

func interact(_player: Node2D) -> void:
	GameState.say(status_text())


func prompt_offset() -> Vector2:
	return Vector2(0, -height() - 4)


# ---------------------------------------------------------------------------

func _update_look() -> void:
	var problem := ""
	match machine_id:
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
		_:
			_play("idle")
	warning.visible = problem != ""


func _play(anim: String) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## Picks a "levels" frame: 0 = empty, last = full. Empty only at (almost) zero.
func _show_level(share: float) -> void:
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
