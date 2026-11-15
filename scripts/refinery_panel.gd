extends Control
## The Ore Refinery's panel (press E at the refinery). Tick the ores to refine,
## set how many of each with - / +, then START. A clock counts down while it
## works; when the batch is done it says READY and COLLECT takes the ingots.
## The game keeps running while it is open. E, Esc or walking away closes it.

const ORES: Array[String] = ["iron", "aluminum", "sulfur"]
const CLOSE_DISTANCE := 90.0
const GOLD := Color(1.0, 0.82, 0.4)
const GREEN := Color(0.45, 1.0, 0.45)
const RED := Color(1.0, 0.45, 0.35)
const DIM := Color(0.75, 0.68, 0.62)

## The refinery it was opened at (for the walk-away check).
var machine: Node2D = null
## ore -> ticked, ore -> how many to put in.
var picked: Dictionary = {}
var amount: Dictionary = {}

var _rows: Dictionary = {}          # ore -> {tick, minus, plus, count, have}
var _panel: PanelContainer
var _clock: Control
var _status: Label
var _time: Label
var _bar: ProgressBar
var _total: Label
var _start: Button
var _collect: Button


func _ready() -> void:
	name = "RefineryPanel"
	add_to_group("modal_ui")                 # hides the world's "E" prompt while open
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make()
	hide()
	GameState.inventory_changed.connect(_refresh_rows)
	GameState.game_ended.connect(func(_r: String) -> void: close())
	GameState.refinery_done.connect(_on_done)


func is_open() -> bool:
	return visible


func open(at: Node2D) -> void:
	machine = at
	for ore in ORES:
		var have := GameState.item_count(ore)
		picked[ore] = have > 0
		amount[ore] = have
	show()
	move_to_front()                          # above the HUD's message line
	_refresh_rows()
	_process(0.0)
	_panel.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	hide()
	machine = null


## Ticks or unticks an ore. Ticking an ore with nothing chosen picks all you carry.
func set_picked(ore: String, on: bool) -> void:
	picked[ore] = on
	if on and amount.get(ore, 0) == 0:
		amount[ore] = GameState.item_count(ore)
	_refresh_rows()


## Changes how many of an ore go in (clamped to what you carry).
func change(ore: String, by: int) -> void:
	set_amount(ore, amount.get(ore, 0) + by)


## Sets how many of an ore go in, from the - / + buttons or typed in the box.
## Clamped to what you carry; a number above zero ticks the ore.
func set_amount(ore: String, n: int) -> void:
	amount[ore] = clampi(n, 0, GameState.item_count(ore))
	if amount[ore] > 0:
		picked[ore] = true
	_refresh_rows()


## Typing in an amount box: digits only, kept within what you carry.
func _on_typed(text: String, ore: String) -> void:
	var box := _rows[ore].count as LineEdit
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		amount[ore] = 0
		if text != "":
			box.text = ""
		_refresh_rows()
		return
	set_amount(ore, int(digits))
	if box.text != str(amount[ore]):
		box.text = str(amount[ore])
		box.caret_column = box.text.length()


## What START would load: only ticked ores with an amount above zero.
func selection() -> Dictionary:
	var out := {}
	for ore in ORES:
		if picked.get(ore, false) and amount.get(ore, 0) > 0:
			out[ore] = amount[ore]
	return out


func start() -> void:
	var loaded := GameState.refine(selection())
	if loaded <= 0:
		GameState.say("Tick at least one ore and choose how many.")
		return
	GameState.say("Ore Refinery: loaded %d ore. %s until done." % [loaded, _clock_text(GameState.refinery_seconds_left())])
	for ore in ORES:
		amount[ore] = mini(amount[ore], GameState.item_count(ore))
		picked[ore] = picked[ore] and amount[ore] > 0
	_refresh_rows()


func collect() -> void:
	var got := GameState.collect_output(Config.REFINE.values())
	if got != "":
		GameState.say("Collected " + got)
		_collect.hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	if machine != null and (not is_instance_valid(machine) or _player_distance() > CLOSE_DISTANCE):
		close()
		return
	var left := GameState.refinery_seconds_left()
	var busy := GameState.refinery_left() > 0
	var ready := GameState.refinery_ready()
	_bar.value = 1.0 - left / maxf(0.01, GameState.refinery_total) if busy else (1.0 if ready else 0.0)
	_time.text = _clock_text(left) if busy else ("DONE" if ready else "--:--")
	if busy and not GameState.o2_generator_powered:
		_status.text = "Paused: no power"
		_status.add_theme_color_override("font_color", RED)
	elif busy:
		_status.text = "Refining %d ore..." % GameState.refinery_left()
		_status.add_theme_color_override("font_color", GOLD)
	elif ready:
		_status.text = "READY! " + _ready_list()
		_status.add_theme_color_override("font_color", GREEN)
	else:
		_status.text = "Idle - choose ore below"
		_status.add_theme_color_override("font_color", DIM)
	_time.add_theme_color_override("font_color", GREEN if ready and not busy else Color.WHITE)
	_collect.visible = ready
	if ready:
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_collect.modulate = Color.WHITE.lerp(Color(1.3, 1.5, 1.1), glow)
	_clock.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if typing and event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()   # clicking elsewhere finishes typing
	elif event.is_action_pressed("ui_cancel") or (event.is_action_pressed("interact") and not typing):
		close()
		get_viewport().set_input_as_handled()


func _on_done() -> void:
	if not visible:
		return
	_clock.pivot_offset = _clock.size * 0.5
	_clock.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_clock, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------

func _refresh_rows() -> void:
	if _rows.is_empty():
		return
	var seconds := 0.0
	for ore in ORES:
		var row: Dictionary = _rows[ore]
		var have := GameState.item_count(ore)
		amount[ore] = mini(amount.get(ore, 0), have)
		var on: bool = picked.get(ore, false)
		(row.tick as Button).set_pressed_no_signal(on)
		(row.tick as Button).queue_redraw()
		var box := row.count as LineEdit
		if not box.has_focus() or (box.text != "" and box.text != str(amount[ore])):
			box.text = str(amount[ore])
		box.editable = have > 0
		(row.have as Label).text = "You carry %d" % have
		(row.minus as Button).disabled = not on or amount[ore] <= 0
		(row.plus as Button).disabled = amount[ore] >= have
		(row.box as Control).modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
		if on:
			seconds += amount[ore] * Config.REFINE_SECONDS
	_total.text = "Takes %s" % _clock_text(seconds) if seconds > 0.0 else "Nothing chosen"
	_start.disabled = seconds <= 0.0


func _ready_list() -> String:
	var parts: Array[String] = []
	for id: String in Config.REFINE.values():
		var n: int = GameState.machine_output.get(id, 0)
		if n > 0:
			parts.append("%d %s" % [n, Config.item(id).name])
	return ", ".join(parts)


func _player_distance() -> float:
	var player := get_tree().current_scene.get_node_or_null("Entities/Player") as Node2D
	return 0.0 if player == null else player.global_position.distance_to(machine.global_position)


static func _clock_text(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [s / 60, s % 60]


## A little clock: the face, the time still left as a shrinking wedge, and a hand.
## When the batch is done it shows a green tick instead. Also used above the machine.
static func draw_clock(ci: CanvasItem, c: Vector2, r: float, share: float, busy: bool, done: bool) -> void:
	ci.draw_circle(c, r, Color(0.1, 0.07, 0.06, 0.9))
	if done:
		ci.draw_circle(c, r * 0.85, Color(0.2, 0.6, 0.25))
		ci.draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.1, 0.4) * r,
			c + Vector2(0.5, -0.4) * r]), Color.WHITE, maxf(1.0, r * 0.18))
	elif busy:
		var start := -PI * 0.5 + TAU * share
		var points := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			points.append(c + Vector2.from_angle(start + (TAU - TAU * share) * i / steps) * r * 0.85)
		if share < 0.999:
			ci.draw_colored_polygon(points, Color(1.0, 0.7, 0.25, 0.75))
		ci.draw_line(c, c + Vector2.from_angle(start) * r * 0.9, Color.WHITE, maxf(1.0, r * 0.1))
	ci.draw_arc(c, r, 0.0, TAU, 32, GOLD, maxf(1.0, r * 0.12))
	ci.draw_circle(c, maxf(0.8, r * 0.1), Color.WHITE)


func _make() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.07, 1.0)
	style.border_color = Color(0.85, 0.5, 0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(480, 0)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	var title := _label("ORE REFINERY", 24, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("X", close))
	col.add_child(head)

	# The countdown: clock, status, progress bar, time left.
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	_clock = Control.new()
	_clock.name = "Clock"
	_clock.custom_minimum_size = Vector2(46, 46)
	_clock.draw.connect(func() -> void:
		var busy := GameState.refinery_left() > 0
		draw_clock(_clock, _clock.size * 0.5, 21.0, 1.0 - GameState.refinery_seconds_left() / maxf(0.01, GameState.refinery_total),
			busy, not busy and GameState.refinery_ready()))
	timer_row.add_child(_clock)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	_status = _label("", 16, DIM)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_status)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.65, 0.2)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.03, 0.03)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	mid.add_child(_bar)
	timer_row.add_child(mid)
	_time = _label("--:--", 30, Color.WHITE)
	_time.name = "Time"
	_time.custom_minimum_size.x = 84
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_row.add_child(_time)
	col.add_child(timer_row)

	_collect = _button("COLLECT", collect)
	_collect.name = "Collect"
	_collect.add_theme_font_size_override("font_size", 18)
	_style(_collect, Color(0.2, 0.55, 0.22))
	_collect.custom_minimum_size = Vector2(200, 34)
	_collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_collect)

	col.add_child(HSeparator.new())
	col.add_child(_label("Choose what to refine:", 15, DIM))

	for ore in ORES:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		var tick := _button("", func() -> void: pass)
		tick.name = "Tick"
		tick.toggle_mode = true
		tick.custom_minimum_size = Vector2(28, 28)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.toggled.connect(func(on: bool) -> void: set_picked(ore, on))
		tick.draw.connect(func() -> void:
			if tick.button_pressed:
				tick.draw_polyline(PackedVector2Array([Vector2(7, 14), Vector2(12, 20), Vector2(21, 8)]), GREEN, 3.5))
		box.add_child(tick)
		var icon := TextureRect.new()
		icon.texture = load(Config.item(ore).icon)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(icon)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		names.add_child(_label("%s  >  %s" % [Config.item(ore).name, Config.item(Config.REFINE[ore]).name], 15, Color.WHITE))
		var have := _label("", 12, DIM)
		names.add_child(have)
		box.add_child(names)
		var minus := _button("-", change.bind(ore, -1))
		var count := LineEdit.new()
		count.name = "Amount"
		count.text = "0"
		count.custom_minimum_size = Vector2(46, 30)
		count.alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.max_length = 3
		count.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		count.select_all_on_focus = true
		count.context_menu_enabled = false
		count.add_theme_font_size_override("font_size", 18)
		count.add_theme_color_override("font_color", GOLD)
		count.add_theme_color_override("font_uneditable_color", Color(0.45, 0.38, 0.33))
		var field := StyleBoxFlat.new()
		field.bg_color = Color(0.06, 0.04, 0.03)
		field.border_color = Color(0.55, 0.35, 0.2)
		field.set_border_width_all(2)
		field.set_corner_radius_all(4)
		field.set_content_margin_all(2)
		var field_focus := field.duplicate() as StyleBoxFlat
		field_focus.border_color = GOLD
		count.add_theme_stylebox_override("normal", field)
		count.add_theme_stylebox_override("read_only", field)
		count.add_theme_stylebox_override("focus", field_focus)
		count.text_changed.connect(_on_typed.bind(ore))
		count.text_submitted.connect(func(_t: String) -> void:
			count.release_focus()
			_refresh_rows())
		count.focus_exited.connect(_refresh_rows)
		var plus := _button("+", change.bind(ore, 1))
		for b: Button in [minus, plus]:
			b.custom_minimum_size = Vector2(30, 30)
			b.add_theme_font_size_override("font_size", 18)
		box.add_child(minus)
		box.add_child(count)
		box.add_child(plus)
		col.add_child(box)
		_rows[ore] = {"box": box, "tick": tick, "minus": minus, "plus": plus, "count": count, "have": have}

	var foot := HBoxContainer.new()
	_total = _label("", 15, DIM)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_total)
	_start = _button("START REFINING", start)
	_start.name = "Start"
	_start.add_theme_font_size_override("font_size", 16)
	_style(_start, Color(0.75, 0.4, 0.15))
	_start.custom_minimum_size = Vector2(170, 34)
	foot.add_child(_start)
	col.add_child(foot)
	col.add_child(_label("E / Esc: close", 11, DIM))

	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_top -= 40                  # clear of the dialogue box at the bottom
	_panel.offset_bottom -= 40
	_panel.pivot_offset = _panel.get_combined_minimum_size() * 0.5


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	_style(b, Color(0.32, 0.2, 0.15))
	return b


## Mars-coloured buttons: a base colour, lighter on hover, dark when disabled.
func _style(b: Button, base: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"hover": base.lightened(0.2), "pressed": base.darkened(0.2),
			"disabled": Color(0.18, 0.13, 0.11)}.get(state, base)
		box.border_color = Color(0.85, 0.5, 0.25) if state != "disabled" else Color(0.3, 0.22, 0.18)
		box.set_border_width_all(2)
		box.set_corner_radius_all(5)
		box.set_content_margin_all(4)
		if state == "focus":
			box.draw_center = false
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.38, 0.33))
