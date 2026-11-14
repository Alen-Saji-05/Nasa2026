extends Control
## The HUD: health, oxygen and water bars, the inventory, a message line and a
## simple game-over label. It reads GameState; F eats a potato. Hints (GameState.highlight)
## make a bar glow.

const O2_FRAMES: Array[Texture2D] = [
	preload("res://art/oxgen_bar/oxygen_bar_000.png"),
	preload("res://art/oxgen_bar/oxygen_bar_010.png"),
	preload("res://art/oxgen_bar/oxygen_bar_020.png"),
	preload("res://art/oxgen_bar/oxygen_bar_030.png"),
	preload("res://art/oxgen_bar/oxygen_bar_040.png"),
	preload("res://art/oxgen_bar/oxygen_bar_050.png"),
	preload("res://art/oxgen_bar/oxygen_bar_060.png"),
	preload("res://art/oxgen_bar/oxygen_bar_070.png"),
	preload("res://art/oxgen_bar/oxygen_bar_080.png"),
	preload("res://art/oxgen_bar/oxygen_bar_090.png"),
	preload("res://art/oxgen_bar/oxygen_bar_100.png"),
]
const WATER_FRAMES: Array[Texture2D] = [
	preload("res://art/water_bar/water_bar_000.png"),
	preload("res://art/water_bar/water_bar_010.png"),
	preload("res://art/water_bar/water_bar_020.png"),
	preload("res://art/water_bar/water_bar_030.png"),
	preload("res://art/water_bar/water_bar_040.png"),
	preload("res://art/water_bar/water_bar_050.png"),
	preload("res://art/water_bar/water_bar_060.png"),
	preload("res://art/water_bar/water_bar_070.png"),
	preload("res://art/water_bar/water_bar_080.png"),
	preload("res://art/water_bar/water_bar_090.png"),
	preload("res://art/water_bar/water_bar_100.png"),
]
const BLINK_COLOR := Color(1.0, 0.35, 0.3)
const MESSAGE_SECONDS := 2.5

@onready var oxygen_bar: TextureRect = $Bars/OxygenRow/OxygenBar
@onready var oxygen_value: Label = $Bars/OxygenRow/OxygenValue
@onready var water_bar: TextureRect = $Bars/WaterRow/WaterBar
@onready var water_value: Label = $Bars/WaterRow/WaterValue
@onready var health_bar: TextureRect = $Bars/HealthRow/HealthBar
@onready var health_value: Label = $Bars/HealthRow/HealthValue
@onready var message_label: Label = $Message
@onready var game_over_panel: Control = $GameOver
@onready var game_over_label: Label = $GameOver/Label

var _blink_tweens := {}        # bar -> Tween, only while that bar is blinking
var _message_tween: Tween
var _location_label: Label
var _power_label: Label
var _sol_label: Label


func _ready() -> void:
	# Keep working while the game is paused on the game-over screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	(get_parent() as CanvasLayer).layer = 2      # above the hazard effects (hazards.gd)
	message_label.text = ""
	message_label.offset_top -= 110             # above the dialogue box (dialogue.gd)
	message_label.offset_bottom -= 110
	game_over_panel.hide()

	GameState.oxygen_changed.connect(update_oxygen)
	GameState.water_changed.connect(update_water)
	GameState.health_changed.connect(update_health)
	GameState.highlight.connect(highlight)
	GameState.message.connect(show_message)
	GameState.game_ended.connect(_on_game_ended)
	GameState.location_changed.connect(show_location)
	GameState.power_changed.connect(update_power)
	GameState.day_night_changed.connect(update_sol)
	GameState.inventory_changed.connect(update_inventory)
	add_child(preload("res://scripts/build_book.gd").new())
	update_inventory()
	GameState.inventory_changed.connect(func() -> void: update_health(GameState.health, false))
	_make_location_label()
	show_location(GameState.location_name())
	update_power()

	update_oxygen(GameState.oxygen)
	update_water(GameState.water, GameState.water_limit)
	update_health(GameState.health, false)


func update_oxygen(value: float) -> void:
	oxygen_bar.texture = O2_FRAMES[_frame_index(value, Config.O2_MAX)]
	oxygen_value.text = str(roundi(value))
	_set_blink(oxygen_bar, value < Config.O2_LOW_WARNING)


## The water bar fills relative to the limit, so a bigger tank = same full bar.
func update_water(value: float, limit: float) -> void:
	water_bar.texture = WATER_FRAMES[_frame_index(value, limit)]
	water_value.text = "%d/%d" % [roundi(value), roundi(limit)]
	_set_blink(water_bar, value < Config.WATER_LOW_WARNING)


func update_health(value: float, hurt: bool) -> void:
	health_bar.texture = load("res://art/new_sprites/health_bar/health_%d_of_10.png" % _frame_index(value, Config.HEALTH_MAX))
	var potatoes := GameState.item_count("potato")
	health_value.text = str(roundi(value)) + ("   F: eat potato (%d)" % potatoes if potatoes > 0 and value < Config.HEALTH_MAX - 1.0 else "")
	_set_blink(health_bar, value < Config.HEALTH_LOW_WARNING)
	if hurt:
		var row := $Bars/HealthRow as Control
		var shake := row.create_tween()
		for i in 3:
			shake.tween_property(row, "position:x", 4.0, 0.04)
			shake.tween_property(row, "position:x", -4.0, 0.04)
		shake.tween_property(row, "position:x", 0.0, 0.04)


## A hint points here: the bar (or the power line) glows gold for a few seconds
## with an arrow next to it. "book:<id>" goes to the Build Book.
func highlight(target: String) -> void:
	if target.begins_with("book:"):
		($BuildBook as Node).call("highlight", target.trim_prefix("book:"))
		return
	var node: Control = {"health": $Bars/HealthRow, "oxygen": $Bars/OxygenRow, "water": $Bars/WaterRow,
		"power": _power_label}.get(target)
	if node == null:
		return
	var arrow := Label.new()
	arrow.text = "<< !" if node != _power_label else "! >>"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	arrow.add_theme_constant_override("outline_size", 6)
	add_child(arrow)
	var rect := node.get_global_rect()
	if node != _power_label:
		rect.end.x = node.get_child(node.get_child_count() - 1).get_global_rect().end.x
	arrow.position = Vector2(rect.end.x + 8, rect.position.y + 4) if node != _power_label 		else Vector2(rect.position.x - 52, rect.position.y)
	var tween := create_tween()
	for i in 8:
		tween.tween_property(node, "modulate", Color(1.6, 1.4, 0.5), 0.35)
		tween.parallel().tween_property(arrow, "position:x", arrow.position.x + (6 if node != _power_label else -6), 0.35)
		tween.tween_property(node, "modulate", Color.WHITE, 0.35)
		tween.parallel().tween_property(arrow, "position:x", arrow.position.x, 0.35)
	tween.tween_callback(arrow.queue_free)


## Where the player is ("Surface", "Ice Cave L2"), top right.
func show_location(place: String) -> void:
	_location_label.text = place


## Power line under the location: what is made and used, and the battery.
func update_power() -> void:
	var net := GameState.power_made - GameState.power_used
	_power_label.text = "Power %s%.1f/s   Battery %d/%d" % [
		"+" if net >= 0.0 else "", net, roundi(GameState.battery_charge), roundi(GameState.battery_capacity())]
	_power_label.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.45) if net < 0.0 and GameState.battery_charge < 5.0 else Color(1.0, 0.92, 0.75))


func _make_location_label() -> void:
	_location_label = Label.new()
	_location_label.name = "Location"
	_location_label.add_theme_font_size_override("font_size", 18)
	_location_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_location_label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.04))
	_location_label.add_theme_constant_override("outline_size", 6)
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_location_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_location_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_location_label.offset_right = -16
	_location_label.offset_top = 12
	add_child(_location_label)

	_power_label = _location_label.duplicate() as Label
	_power_label.name = "Power"
	_power_label.add_theme_font_size_override("font_size", 14)
	_power_label.offset_top = 38
	add_child(_power_label)

	# "SOL 07 / 30", top centre.
	_sol_label = _location_label.duplicate() as Label
	_sol_label.name = "Sol"
	_sol_label.add_theme_font_size_override("font_size", 22)
	_sol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sol_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_sol_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sol_label.offset_top = 10
	add_child(_sol_label)
	update_sol(GameState.sol_number, GameState.sun)


## One row under the bars for every item the player carries: picture, name, amount.
func update_inventory() -> void:
	var bars := $Bars
	for row in bars.get_children():
		if row.name.begins_with("Item_"):
			bars.remove_child(row)
			row.queue_free()
	for id in Config.ITEM_ORDER:
		var count: int = GameState.item_count(id)
		if count <= 0:
			continue
		var def := Config.item(id)
		var row := HBoxContainer.new()
		row.name = "Item_" + id
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load(def.icon)
		icon.modulate = def.get("tint", Color.WHITE)
		icon.custom_minimum_size = Vector2(30, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s  %d" % [def.name, count]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.04))
		label.add_theme_constant_override("outline_size", 5)
		row.add_child(label)
		bars.add_child(row)


func update_sol(sol: int, _sun: float) -> void:
	_sol_label.text = "SOL %02d / %d" % [sol, Config.TOTAL_SOLS]


func show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SECONDS)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


## Which of the 11 frames to show. Frame 0 (empty) only at exactly zero.
func _frame_index(value: float, maximum: float) -> int:
	if value <= 0.0 or maximum <= 0.0:
		return 0
	return clampi(ceili(value / maximum * 10.0), 1, 10)


func _set_blink(bar: CanvasItem, on: bool) -> void:
	var tween: Tween = _blink_tweens.get(bar)
	if on and tween == null:
		tween = bar.create_tween().set_loops()
		tween.tween_property(bar, "modulate", BLINK_COLOR, 0.3)
		tween.tween_property(bar, "modulate", Color.WHITE, 0.3)
		_blink_tweens[bar] = tween
	elif not on and tween != null:
		tween.kill()
		_blink_tweens.erase(bar)
		bar.modulate = Color.WHITE


# --- Game over (simple version; the real end screen comes later) ---

func _on_game_ended(reason: String) -> void:
	game_over_label.text = "%s\n\nPress R to restart" % reason
	game_over_panel.show()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not GameState.game_over:
		if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F and not get_tree().paused:
			GameState.eat_potato()
		return
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		# Back to the title screen; it resets the game when Play is pressed.
		GameState.reset()
		get_tree().paused = false
		get_tree().change_scene_to_file(Config.TITLE_SCENE)
