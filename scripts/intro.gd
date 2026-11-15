extends Control
## The intro video (Config.INTRO_VIDEO), played after Play on the title screen and
## before the game starts. Space, Enter, Esc or a click skips it. It keeps its shape
## in any window size (black bars fill the rest). Godot plays Ogg Theora (.ogv)
## video only; if that file is missing the game simply starts.

const FADE_SECONDS := 0.5

var _done := false
var _video: VideoStreamPlayer
var _box: AspectRatioContainer
var _fade: ColorRect
var _hint: Label


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not has_video():
		push_warning("Intro: %s not found, starting the game." % Config.INTRO_VIDEO)
		_go_on.call_deferred()
		return

	_box = AspectRatioContainer.new()
	_box.ratio = 16.0 / 9.0                      # corrected from the video's first frame
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video = VideoStreamPlayer.new()
	_video.name = "Video"
	_video.stream = load(Config.INTRO_VIDEO)
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_video)
	_video.finished.connect(_go_on)

	_hint = Label.new()
	_hint.text = "Space: skip"
	_hint.add_theme_font_override("font", preload("res://art/fonts/PixelifySans.ttf"))
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.8))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.modulate.a = 0.0
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.play()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	t.tween_interval(1.0)
	t.tween_property(_hint, "modulate:a", 0.7, 0.6)


static func has_video() -> bool:
	return ResourceLoader.exists(Config.INTRO_VIDEO)


func _process(_delta: float) -> void:
	if _video == null:
		return
	var frame := _video.get_video_texture()
	if frame != null and frame.get_height() > 0:
		_box.ratio = float(frame.get_width()) / frame.get_height()


func _unhandled_input(event: InputEvent) -> void:
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()


## Ends the intro now (the game starts).
func skip() -> void:
	_go_on()


func _go_on() -> void:
	if _done:
		return
	_done = true
	if _fade == null:
		get_tree().change_scene_to_file(Config.WORLD_SCENE)
		return
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	if _video != null:
		t.parallel().tween_property(_video, "volume_db", -40.0, FADE_SECONDS)
	t.tween_callback(get_tree().change_scene_to_file.bind(Config.WORLD_SCENE))
