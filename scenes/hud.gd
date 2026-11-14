extends Control
## The HUD: oxygen bar, water bar, metal counter, a message line and a simple
## game-over label. It only reads from GameState.

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
const DIGITS: Array[Texture2D] = [
	preload("res://art/metal_scrap_bar/digit_0.png"),
	preload("res://art/metal_scrap_bar/digit_1.png"),
	preload("res://art/metal_scrap_bar/digit_2.png"),
	preload("res://art/metal_scrap_bar/digit_3.png"),
	preload("res://art/metal_scrap_bar/digit_4.png"),
	preload("res://art/metal_scrap_bar/digit_5.png"),
	preload("res://art/metal_scrap_bar/digit_6.png"),
	preload("res://art/metal_scrap_bar/digit_7.png"),
	preload("res://art/metal_scrap_bar/digit_8.png"),
	preload("res://art/metal_scrap_bar/digit_9.png"),
]
const BLINK_COLOR := Color(1.0, 0.35, 0.3)
const MESSAGE_SECONDS := 2.5

@onready var oxygen_bar: TextureRect = $Bars/OxygenRow/OxygenBar
@onready var oxygen_value: Label = $Bars/OxygenRow/OxygenValue
@onready var water_bar: TextureRect = $Bars/WaterRow/WaterBar
@onready var water_value: Label = $Bars/WaterRow/WaterValue
@onready var metal_digits: Array[TextureRect] = [
	$Bars/MetalRow/MetalFrame/Digits/Digit1,
	$Bars/MetalRow/MetalFrame/Digits/Digit2,
	$Bars/MetalRow/MetalFrame/Digits/Digit3,
]
@onready var message_label: Label = $Message
@onready var game_over_panel: Control = $GameOver
@onready var game_over_label: Label = $GameOver/Label

var _blink_tweens := {}        # bar -> Tween, only while that bar is blinking
var _message_tween: Tween


func _ready() -> void:
	# Keep working while the game is paused on the game-over screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	message_label.text = ""
	game_over_panel.hide()

	GameState.oxygen_changed.connect(update_oxygen)
	GameState.water_changed.connect(update_water)
	GameState.metal_changed.connect(update_metal)
	GameState.message.connect(show_message)
	GameState.game_ended.connect(_on_game_ended)

	update_oxygen(GameState.oxygen)
	update_water(GameState.water, GameState.water_limit)
	update_metal(GameState.metal)


func update_oxygen(value: float) -> void:
	oxygen_bar.texture = O2_FRAMES[_frame_index(value, Config.O2_MAX)]
	oxygen_value.text = str(roundi(value))
	_set_blink(oxygen_bar, value < Config.O2_LOW_WARNING)


## The water bar fills relative to the limit, so a bigger tank = same full bar.
func update_water(value: float, limit: float) -> void:
	water_bar.texture = WATER_FRAMES[_frame_index(value, limit)]
	water_value.text = "%d/%d" % [roundi(value), roundi(limit)]
	_set_blink(water_bar, value < Config.WATER_LOW_WARNING)


func update_metal(value: int) -> void:
	var shown := clampi(value, 0, 999)
	metal_digits[0].texture = DIGITS[shown / 100]
	metal_digits[1].texture = DIGITS[(shown / 10) % 10]
	metal_digits[2].texture = DIGITS[shown % 10]


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
	if not GameState.game_over:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		GameState.reset()
		get_tree().paused = false
		get_tree().reload_current_scene()
