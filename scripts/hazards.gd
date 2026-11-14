extends Node
## Environmental hazards (autoload "Hazards"): radiation events and dust storms.
## Two independent timelines on game time. They keep running while the player is
## in a cave or in the Emergency Shelter, and stop while the game is paused.
##   radiation:   warning -> active -> over
##   dust storm:  warning -> approaching -> active -> clearing -> over
## Outside on the surface they hurt (GameState.damage). Caves and the Emergency
## Shelter protect. This node also draws their effects and the warning banners.
##
##   Hazards.trigger("radiation") / trigger("storm")   start one now (debug keys, tests)
##   Hazards.is_safe()                                 nothing dangerous going on

signal changed

const RAD_COLOR := Color(0.6, 1.0, 0.3)
const DUST_COLOR := Color(0.8, 0.5, 0.28)
const SAFE_COLOR := Color(0.65, 1.0, 0.75)
const FX_SHADER := preload("res://scripts/hazard_fx.gdshader")

## "", "warning" or "active".
var radiation := ""
## "", "warning", "approaching", "active" or "clearing".
var storm := ""
## Seconds left in the current stage.
var rad_left := 0.0
var storm_left := 0.0
## Seconds until the next warning.
var next_radiation := Config.RADIATION_FIRST
var next_storm := Config.STORM_FIRST
## Dust storm strength, 0 to 1.
var intensity := 0.0

var _hurt_time := 0.0
var _rng := RandomNumberGenerator.new()

var _fx: CanvasLayer
var _dust_veil: ColorRect
var _rad_veil: ColorRect
var _dust: CPUParticles2D
var _dust_puffs: CPUParticles2D
var _specks: CPUParticles2D
var _flash: ColorRect
var _rad_banner: Label
var _storm_banner: Label
var _status: Label


func _ready() -> void:
	_rng.randomize()
	_make_effects()


func _process(delta: float) -> void:
	if not GameState.game_over:
		_tick(delta)
	_update_effects(delta)


# --- Rules ---

## Starts an event now, unless that kind is already going on.
func trigger(kind: String) -> void:
	if kind == "radiation" and radiation == "":
		_start_radiation()
	elif kind == "storm" and storm == "":
		_start_storm()


## Nothing dangerous: no radiation, and no storm (a clearing storm is harmless).
func is_safe() -> bool:
	return radiation == "" and (storm == "" or storm == "clearing")


## Why it is not safe to go out, or "".
func danger_text() -> String:
	var parts: Array[String] = []
	if radiation != "":
		parts.append("radiation %s (%s)" % ["incoming" if radiation == "warning" else "active", _clock(_radiation_total_left())])
	if storm != "" and storm != "clearing":
		parts.append("dust storm %s (%s)" % [storm, _clock(_storm_total_left())])
	return ", ".join(parts)


## True when the player stands outside on the surface, where hazards hurt.
func exposed() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == Config.WORLD_SCENE and GameState.is_outside()


## How much of the sunlight reaches the solar panels (dust blocks it).
func solar_factor() -> float:
	return 1.0 - Config.STORM_SOLAR_LOSS * intensity


## Walking speed multiplier and wind push for the player (only outside).
func speed_factor() -> float:
	return 1.0 - Config.STORM_SLOW * intensity if exposed() else 1.0


func wind() -> Vector2:
	if not exposed() or intensity <= 0.0:
		return Vector2.ZERO
	var gust := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
	return Vector2(1.0, 0.2) * Config.STORM_WIND * intensity * gust


## A new game: calm weather and fresh timers.
func reset() -> void:
	radiation = ""
	storm = ""
	rad_left = 0.0
	storm_left = 0.0
	next_radiation = Config.RADIATION_FIRST
	next_storm = Config.STORM_FIRST
	intensity = 0.0
	_hurt_time = 0.0
	_rng.randomize()
	if _fx != null:
		_dust_veil.material.set_shader_parameter("strength", 0.0)
		_rad_veil.material.set_shader_parameter("strength", 0.0)
		_dust.emitting = false
		_dust_puffs.emitting = false
		_specks.emitting = false
	changed.emit()


func _tick(delta: float) -> void:
	if radiation == "":
		next_radiation -= delta
		if next_radiation <= 0.0:
			_start_radiation()
	else:
		rad_left -= delta
		if rad_left <= 0.0:
			_set_radiation("active" if radiation == "warning" else "", Config.RADIATION_DURATION)

	if storm == "":
		next_storm -= delta
		if next_storm <= 0.0:
			_start_storm()
	else:
		storm_left -= delta
		if storm_left <= 0.0:
			match storm:
				"warning": _set_storm("approaching", Config.STORM_APPROACH)
				"approaching": _set_storm("active", Config.STORM_DURATION)
				"active": _set_storm("clearing", Config.STORM_CLEAR)
				_: _set_storm("", 0.0)
	intensity = _storm_intensity()

	# Damage outside, every few seconds (not every frame).
	var hit := 0.0
	if radiation == "active":
		hit += Config.RADIATION_DAMAGE
	if storm == "active":
		hit += Config.STORM_DAMAGE
	if hit > 0.0 and exposed():
		_hurt_time += delta
		if _hurt_time >= Config.HAZARD_DAMAGE_EVERY:
			_hurt_time -= Config.HAZARD_DAMAGE_EVERY
			GameState.damage(hit, true, "radiation" if radiation == "active" else "storm")
			_hurt_effect(hit)
	else:
		_hurt_time = minf(_hurt_time, Config.HAZARD_DAMAGE_EVERY * 0.5)


func _start_radiation() -> void:
	var sensor := GameState.machine_count("radiation_sensor") > 0
	_set_radiation("warning", Config.RADIATION_WARNING_SENSOR if sensor else Config.RADIATION_WARNING)
	next_radiation = _rng.randf_range(Config.RADIATION_EVERY.x, Config.RADIATION_EVERY.y)


func _start_storm() -> void:
	_set_storm("warning", Config.STORM_WARNING)
	next_storm = _rng.randf_range(Config.STORM_EVERY.x, Config.STORM_EVERY.y)


func _set_radiation(stage: String, seconds: float) -> void:
	radiation = stage
	rad_left = seconds
	match stage:
		"warning":
			_announce("RADIATION WARNING! Seek Emergency Shelter immediately!", _rad_banner)
			if not GameState.radiation_seen:
				GameState.see_radiation()          # Mission Control + the shelter recipes
			if not GameState.has_built("shelter"):
				Dialogue.once("radiation_hide", true)
		"active":
			_announce("Radiation event active! Stay in the shelter or underground!", _rad_banner)
		_:
			GameState.say("Radiation levels are safe.")
			_after_hazard()
	changed.emit()


func _set_storm(stage: String, seconds: float) -> void:
	storm = stage
	storm_left = seconds
	match stage:
		"warning":
			_announce("A dust storm is approaching! Find shelter!", _storm_banner)
			Dialogue.once("storm", true)
		"approaching":
			_announce("Dust storm intensity increasing!", _storm_banner)
		"active":
			_announce("Severe dust storm conditions! Stay indoors!", _storm_banner)
		"clearing":
			GameState.say("The dust storm is clearing...")
			_after_hazard()
		_:
			GameState.say("The dust storm has passed.")
			GameState.spawn_ice()                   # the wind blew the dust off some ice
	changed.emit()


## A hazard ended: tell a sheltered player they may leave; suggest a shelter.
func _after_hazard() -> void:
	if not is_safe():
		return
	if GameState.in_shelter:
		GameState.say("Environmental conditions are safe. You may exit the Emergency Shelter.")
	elif not GameState.has_built("shelter"):
		Dialogue.once("need_shelter", true)
		GameState.highlight.emit("book:shelter")


func _storm_intensity() -> float:
	match storm:
		"approaching": return clampf(1.0 - storm_left / Config.STORM_APPROACH, 0.0, 1.0)
		"active": return 1.0
		"clearing": return clampf(storm_left / Config.STORM_CLEAR, 0.0, 1.0)
	return 0.0


func _radiation_total_left() -> float:
	return rad_left + (Config.RADIATION_DURATION if radiation == "warning" else 0.0)


func _storm_total_left() -> float:
	var left := storm_left
	var after := {"warning": [Config.STORM_APPROACH, Config.STORM_DURATION], "approaching": [Config.STORM_DURATION]}
	for s: float in after.get(storm, []):
		left += s
	return left


func _clock(seconds: float) -> String:
	var s := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [s / 60, s % 60]


# --- Effects ---

func _announce(text: String, banner: Label) -> void:
	GameState.say(text)
	if banner == null:
		return
	# Drops in from above with a little bounce, then blinks a few times.
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(1.25, 1.25)
	banner.modulate.a = 0.0
	var tween := banner.create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 3:
		tween.tween_property(banner, "modulate:a", 0.35, 0.18)
		tween.tween_property(banner, "modulate:a", 1.0, 0.18)


func _hurt_effect(amount: float) -> void:
	_flash.color.a = 0.32
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.4)
	var player := get_tree().current_scene.get_node_or_null("Entities/Player") as Node2D
	if player == null:
		return
	FloatingText.spawn(get_tree().current_scene, player.global_position + Vector2(0, -20), "-%d" % roundi(amount),
		RAD_COLOR if radiation == "active" else Color(1.0, 0.45, 0.35))
	player.modulate = Color(1.0, 0.35, 0.35)
	player.create_tween().tween_property(player, "modulate", Color.WHITE, 0.35)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		var shake := cam.create_tween()
		for i in 4:
			shake.tween_property(cam, "offset", Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)), 0.04)
		shake.tween_property(cam, "offset", Vector2.ZERO, 0.04)


func _update_effects(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var outside := exposed()
	var t := Time.get_ticks_msec() * 0.001

	var dust := intensity if outside else 0.0
	_dust_veil.material.set_shader_parameter("strength", dust * 0.62)
	for p: CPUParticles2D in [_dust, _dust_puffs]:
		p.emitting = dust > 0.05
		p.modulate.a = dust
		p.speed_scale = 0.6 + dust
		p.position = Vector2(-30, view.y * 0.5)
		p.emission_rect_extents = Vector2(20, view.y * 0.6)

	var rad := 0.0
	if outside and radiation == "warning":
		rad = 0.25 + 0.15 * sin(t * 5.0)
	elif outside and radiation == "active":
		rad = 0.6 + 0.2 * sin(t * 9.0)
	var current: float = _rad_veil.material.get_shader_parameter("strength")
	_rad_veil.material.set_shader_parameter("strength", lerpf(current, rad, minf(1.0, delta * 6.0)))
	_specks.emitting = outside and radiation == "active"
	_specks.position = view * 0.5
	_specks.emission_rect_extents = view * 0.5

	_rad_banner.visible = radiation != ""
	if radiation != "":
		_rad_banner.text = "RADIATION %s  %s" % ["WARNING" if radiation == "warning" else "ACTIVE", _clock(_radiation_total_left())]
	_storm_banner.visible = storm != "" and storm != "clearing"
	if _storm_banner.visible:
		_storm_banner.text = "DUST STORM %s  %s" % [storm.to_upper(), _clock(_storm_total_left())]
	_status.visible = _rad_banner.visible or _storm_banner.visible
	if _status.visible:
		if GameState.in_shelter:
			_status.text = "Protected: Emergency Shelter"
		elif GameState.cave_id != "":
			_status.text = "Protected: underground"
		elif radiation == "active" or storm == "active":
			_status.text = "EXPOSED! Get to shelter!"
		else:
			_status.text = "Outside - find shelter"
		var safe := not outside or (radiation != "active" and storm != "active")
		_status.add_theme_color_override("font_color", SAFE_COLOR if not outside else (Color(1.0, 0.85, 0.4) if safe else Color(1.0, 0.4, 0.35)))
		_status.modulate.a = 1.0 if safe else 0.6 + 0.4 * absf(sin(t * 6.0))


func _make_effects() -> void:
	_fx = CanvasLayer.new()
	_fx.name = "HazardEffects"
	_fx.layer = 1                                # over the world, under the HUD (layer 2)
	add_child(_fx)
	_dust_veil = _veil(DUST_COLOR, 0.35, 0.0, 1.0)
	_rad_veil = _veil(RAD_COLOR, 0.0, 1.0, 0.0)

	# Wind-blown dust: fine grains and big soft puffs blowing across the screen.
	_dust = _particles(320, 3.2, Vector2(1, 0.12), 280.0, 420.0, 2.0, 4.0, Color(0.95, 0.72, 0.5, 0.9))
	_dust_puffs = _particles(36, 5.0, Vector2(1, 0.08), 120.0, 200.0, 8.0, 16.0, Color(0.75, 0.48, 0.3, 0.25))
	# Radiation: bright specks flickering everywhere (particles hitting the sensor of the suit camera).
	_specks = _particles(70, 0.2, Vector2.UP, 0.0, 0.0, 1.5, 3.0, Color(0.8, 1.0, 0.45, 0.9))
	_specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.1, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.add_child(_flash)

	# Banners: under the SOL label, above the HUD, below the dialogue box.
	var ui := CanvasLayer.new()
	ui.name = "HazardBanners"
	ui.layer = 55
	add_child(ui)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 44
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(column)
	_rad_banner = _banner(RAD_COLOR)
	_storm_banner = _banner(DUST_COLOR)
	_status = _banner(SAFE_COLOR)
	_status.remove_theme_stylebox_override("normal")
	_status.add_theme_font_size_override("font_size", 14)
	for b in [_rad_banner, _storm_banner, _status]:
		column.add_child(b)
		b.visible = false


func _veil(color: Color, centre: float, scan: float, drift: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = FX_SHADER
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("centre", centre)
	mat.set_shader_parameter("scan", scan)
	mat.set_shader_parameter("drift", drift)
	mat.set_shader_parameter("strength", 0.0)
	rect.material = mat
	_fx.add_child(rect)
	return rect


func _particles(amount: int, life: float, direction: Vector2, v_min: float, v_max: float,
		s_min: float, s_max: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = direction
	p.spread = 6.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.color = color
	_fx.add_child(p)
	return p


func _banner(color: Color) -> Label:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.05, 0.05, 0.85)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_content_margin_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_stylebox_override("normal", box)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
