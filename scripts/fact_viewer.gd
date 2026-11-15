extends Control
## A Mars fact paper read full screen (fact_paper.gd opens it with E).
## The paper unfolds from the ground into the middle of the screen; the fact fills
## the page in the largest size that fits. E or Esc folds it away again.
## The game is paused while it is open.

const PAPER := preload("res://art/paper_artefact.png")
const TITLE_FONT := preload("res://art/fonts/Jacquard24.ttf")
const BODY_FONT := preload("res://art/fonts/PixelifySans.ttf")
const INK := Color(0.27, 0.13, 0.06)
const INK_SOFT := Color(0.45, 0.26, 0.13)
## Where the writing goes on the paper picture (fractions of its size).
const TEXT_AREA := Rect2(0.17, 0.12, 0.66, 0.74)

## The fact shown, -1 when closed.
var fact := -1

var _dim: ColorRect
var _paper: TextureRect
var _number: Label
var _title: Label
var _body: Label
var _footer: Label
var _closing := false
var _tween: Tween
var _was_paused := false


func _ready() -> void:
	name = "FactViewer"
	add_to_group("modal_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.02, 0.02, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = TextureRect.new()
	_paper.name = "Paper"
	_paper.texture = PAPER
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_number = _label(TITLE_FONT, INK_SOFT, "Number")
	_title = _label(TITLE_FONT, INK, "Title")
	_body = _label(BODY_FONT, INK, "Body")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer = _label(BODY_FONT, INK_SOFT, "Footer")
	hide()


func is_open() -> bool:
	return visible


func open(index: int) -> void:
	if visible or _closing or index < 0 or index >= Config.FACTS.size():
		return
	fact = index
	var first := not GameState.facts_read.has(index)
	GameState.read_fact(index)
	_was_paused = get_tree().paused
	get_tree().paused = true
	get_tree().call_group("world_prompt", "hide")
	show()
	move_to_front()
	_layout()
	var f: Dictionary = Config.FACTS[index]
	_number.text = "Mars Fact  No. %d" % (index + 1)
	_title.text = f.title
	_body.text = f.text
	_footer.text = "Papers found: %d / %d      E: close" % [GameState.facts_read.size(), Config.FACTS.size()]
	_fit_text()
	# Unfold: from small and tilted near the bottom, up into the middle.
	var rest := _paper.position
	_paper.position = rest + Vector2(0, size.y * 0.35)
	_paper.scale = Vector2(0.12, 0.12)
	_paper.rotation = -0.5
	_paper.modulate.a = 0.0
	for label in [_number, _title, _body, _footer]:
		label.modulate.a = 0.0
	var t := create_tween()
	_tween = t
	t.tween_property(_dim, "color:a", 0.75, 0.25)
	t.parallel().tween_property(_paper, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(_paper, "position", rest, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_paper, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_paper, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for label in [_number, _title, _body, _footer]:
		t.tween_property(label, "modulate:a", 1.0, 0.18)
	if first:
		t.tween_property(_title, "scale", Vector2(1.12, 1.12), 0.12)
		t.tween_property(_title, "scale", Vector2.ONE, 0.2)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween != null:
		_tween.kill()                            # closing straight away is fine
	_title.scale = Vector2.ONE
	var t := create_tween()
	t.tween_property(_paper, "scale", Vector2(0.1, 0.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_paper, "rotation", 0.4, 0.22)
	t.parallel().tween_property(_paper, "modulate:a", 0.0, 0.22)
	for label in [_number, _title, _body, _footer]:
		t.parallel().tween_property(label, "modulate:a", 0.0, 0.1)
	t.parallel().tween_property(_dim, "color:a", 0.0, 0.22)
	await t.finished
	hide()
	fact = -1
	_closing = false
	get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_E):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------

## The paper fills almost the whole screen height; the labels sit on it.
func _layout() -> void:
	var h := size.y * 0.95
	var paper_size := Vector2(h * PAPER.get_width() / PAPER.get_height(), h)
	_paper.size = paper_size
	_paper.position = (size - paper_size) * 0.5
	_paper.pivot_offset = paper_size * 0.5
	var area := Rect2(_paper.position + paper_size * TEXT_AREA.position, paper_size * TEXT_AREA.size)
	var number_h := area.size.y * 0.07
	var title_h := area.size.y * 0.14
	var footer_h := area.size.y * 0.07
	_number.position = area.position
	_number.size = Vector2(area.size.x, number_h)
	_title.position = area.position + Vector2(0, number_h)
	_title.size = Vector2(area.size.x, title_h)
	_title.pivot_offset = _title.size * 0.5
	_body.position = area.position + Vector2(0, number_h + title_h + area.size.y * 0.03)
	_body.size = Vector2(area.size.x, area.size.y - number_h - title_h - footer_h - area.size.y * 0.05)
	_footer.position = area.position + Vector2(0, area.size.y - footer_h)
	_footer.size = Vector2(area.size.x, footer_h)
	_number.add_theme_font_size_override("font_size", int(number_h * 0.95))
	_title.add_theme_font_size_override("font_size", int(title_h * 0.9))
	_footer.add_theme_font_size_override("font_size", int(footer_h * 0.6))


## The biggest body font size whose wrapped text still fits the page.
func _fit_text() -> void:
	var box := _body.size
	var font_size := 40
	while font_size > 12:
		var need := BODY_FONT.get_multiline_string_size(_body.text, HORIZONTAL_ALIGNMENT_CENTER, box.x, font_size,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		if need.y * 1.12 <= box.y:
			break
		font_size -= 1
	_body.add_theme_font_size_override("font_size", font_size)
	_body.add_theme_constant_override("line_spacing", int(font_size * 0.12))


func _label(font: Font, color: Color, label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
