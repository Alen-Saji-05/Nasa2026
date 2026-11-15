extends Control
## Title screen. Shows art/title_screen.png (the SOL30 logo with a painted "Play"
## button) and puts an invisible button exactly on top of the painted one.
##
## Start the game with a click on Play, or with Enter / Space. The intro video
## plays first (scenes/Intro.tscn), then the world.
## The picture keeps its shape in any window size (dark bars fill the rest).

## Where the painted Play button is inside the picture, in picture pixels.
## Change this only if the title art changes.
@export var play_rect := Rect2(615, 554, 444, 103)
@export var fade_seconds := 0.4

var _starting := false

@onready var art: TextureRect = $Art
@onready var play_button: Button = $PlayButton
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	# We may arrive here from a paused game-over screen.
	get_tree().paused = false

	_style_button()
	play_button.pressed.connect(start_game)
	resized.connect(_place_button)
	_place_button()

	# Fade in from black.
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, fade_seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):   # Enter or Space
		start_game()


func start_game() -> void:
	if _starting:
		return
	_starting = true
	GameState.reset()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_seconds)
	tween.tween_callback(get_tree().change_scene_to_file.bind(Config.INTRO_SCENE))   # the intro video, then the game


## Where the picture really is on screen: it is scaled to fit and centred.
func picture_rect() -> Rect2:
	var image_size := art.texture.get_size()
	var fit := minf(size.x / image_size.x, size.y / image_size.y)
	return Rect2((size - image_size * fit) * 0.5, image_size * fit)


## Moves the invisible button over the painted one. Runs again on every resize.
func _place_button() -> void:
	var picture := picture_rect()
	var fit := picture.size.x / art.texture.get_size().x
	play_button.position = picture.position + play_rect.position * fit
	play_button.size = play_rect.size * fit


## Invisible normally, a warm glow when the mouse is over it.
func _style_button() -> void:
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(1.0, 0.82, 0.5, 0.22)
	glow.border_color = Color(1.0, 0.86, 0.55, 0.9)
	glow.set_border_width_all(2)
	glow.set_corner_radius_all(6)
	var pressed := glow.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1.0, 0.9, 0.7, 0.4)

	var empty := StyleBoxEmpty.new()
	play_button.add_theme_stylebox_override("normal", empty)
	play_button.add_theme_stylebox_override("focus", empty)
	play_button.add_theme_stylebox_override("disabled", empty)
	play_button.add_theme_stylebox_override("hover", glow)
	play_button.add_theme_stylebox_override("pressed", pressed)
