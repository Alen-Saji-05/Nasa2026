extends Control
## The Build Book: the icon on the right of the HUD and the book it opens.
## hud.gd adds it. One page per recipe in Config.BOOK_ORDER; all text is drawn
## live from Config.MACHINES and the inventory in GameState.
##
## Click the icon or press B to open. Arrows (or the left/right keys) turn the
## page, Esc or X closes. "Build" closes the book and starts placing the machine
## (builder.gd), which takes the materials when it is placed.
## The game is paused while the book is open.

const SHEET := preload("res://art/new_sprites/book_sprite.png")
# Where each picture is on the sheet.
const OPEN_A := Rect2(20, 110, 574, 432)     # open book
const TURNING := Rect2(602, 110, 574, 432)   # a page in mid-turn
const OPEN_B := Rect2(1182, 110, 574, 432)   # open book, page just landed
const ICON := Rect2(470, 582, 214, 218)      # the small open book: the HUD button
const BOOK_SIZE := Vector2(720, 542)
const INK := Color(0.27, 0.13, 0.08)
const GOOD := Color(0.13, 0.45, 0.16)
const BAD := Color(0.75, 0.12, 0.1)

var page := 0
var _turning := false

var icon: TextureButton
var overlay: ColorRect
var book: TextureRect
var content: Control
var title: Label
var picture: TextureRect
var purpose: Label
var status: Label
var materials: VBoxContainer
var build: Button
var problem: Label
var counter: Label
var section: Label


func _ready() -> void:
	name = "BuildBook"
	process_mode = Node.PROCESS_MODE_ALWAYS      # works while the game is paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_icon()
	_make_book()
	GameState.recipes_unlocked.connect(_on_recipes_unlocked)
	GameState.inventory_changed.connect(_refresh)


func is_open() -> bool:
	return overlay.visible


func page_id() -> String:
	return Config.BOOK_ORDER[page]


func open() -> void:
	if is_open() or GameState.game_over or Travel.busy or Builder.placing != "":
		return
	get_tree().paused = true
	overlay.show()
	_refresh()
	# Opening: the page-turn picture first, growing into the open book.
	book.texture = _part(TURNING)
	content.hide()
	book.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.tween_property(book, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		book.texture = _part(OPEN_A)
		content.show())


func close() -> void:
	if not is_open():
		return
	overlay.hide()
	get_tree().paused = false


## Turns `direction` pages (1 = next, -1 = back) with the page-turn pictures.
func flip(direction: int) -> void:
	if _turning or not is_open():
		return
	_turning = true
	content.hide()
	book.flip_h = direction < 0
	book.texture = _part(TURNING)
	await get_tree().create_timer(0.14).timeout
	book.texture = _part(OPEN_B)
	show_page(page + direction)
	await get_tree().create_timer(0.07).timeout
	book.flip_h = false
	book.texture = _part(OPEN_A)
	content.show()
	_turning = false


## Shows a recipe at once (no animation). Wraps around at both ends.
func show_page(index: int) -> void:
	page = posmod(index, Config.BOOK_ORDER.size())
	_refresh()
	# A recipe seen for the first time since it was discovered shimmers once.
	if GameState.new_recipes.has(page_id()):
		GameState.new_recipes.erase(page_id())
		content.modulate = Color(1.7, 1.5, 0.8)
		create_tween().tween_property(content, "modulate", Color.WHITE, 0.9)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		if is_open():
			close()
		else:
			open()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		close()
	elif is_open() and event.is_action_pressed("ui_right"):
		flip(1)
	elif is_open() and event.is_action_pressed("ui_left"):
		flip(-1)
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------

## Fills the open page from the recipe data and the inventory.
func _refresh() -> void:
	if not is_open():
		return
	var id := page_id()
	var def := Config.machine(id)
	var unlocked: bool = GameState.recipe_unlocked(id)
	var is_new: bool = GameState.new_recipes.has(id)
	counter.text = "%d / %d" % [page + 1, Config.BOOK_ORDER.size()]
	picture.texture = load((def.get("idle", def.get("levels", [])) as Array)[0])
	picture.modulate = Color.WHITE if unlocked else Color(0.12, 0.08, 0.08)
	title.text = def.name if unlocked else "???"
	section.text = ""
	for row in materials.get_children():
		materials.remove_child(row)
		row.queue_free()
	if not unlocked:
		purpose.text = "Locked until the first radiation event." if def.get("needs_radiation", false) and not GameState.radiation_seen \
			else "Locked. Find one of its materials to discover this recipe."
		status.text = "LOCKED"
		status.add_theme_color_override("font_color", BAD)
		build.disabled = true
		problem.text = ""
		return
	purpose.text = def.description
	var kind: String = def.get("kind", "machine")
	var built: bool = GameState.has_built(id)
	status.text = "NEW!" if is_new else "DISCOVERED"
	if kind == "module" and GameState.installed.has(id):
		status.text = "INSTALLED ON THE SHIP"
	elif kind == "module" and built:
		status.text = "READY - INSTALL AT THE SHIP"
	elif kind == "machine" and built:
		status.text = "BUILT"
	build.text = "CRAFT" if kind == "item" else "BUILD"
	section.text = {"machine": "BASE MACHINE", "item": "CRAFTING", "module": "SHIP REPAIR  %d / %d" % [
		GameState.installed.size(), Config.REPAIR_ORDER.size()]}[kind]
	status.add_theme_color_override("font_color", GOOD)
	for item_id: String in def.cost:
		var have: int = GameState.item_count(item_id)
		var need: int = def.cost[item_id]
		var row := HBoxContainer.new()
		var item_icon := TextureRect.new()
		item_icon.texture = load(Config.item(item_id).icon)
		item_icon.custom_minimum_size = Vector2(26, 26)
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(item_icon)
		var item_name := _label(Config.item(item_id).name, 14)
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_name)
		var amount := _label("%d / %d" % [have, need], 15)
		amount.add_theme_color_override("font_color", GOOD if have >= need else BAD)
		row.add_child(amount)
		materials.add_child(row)
	var why: String = Builder.build_problem(id)
	build.disabled = why != ""
	problem.text = why


func _on_build() -> void:
	var id := page_id()
	if Config.machine(id).get("kind", "machine") != "machine":
		Builder.craft(id)                        # items and ship modules: right here
		_refresh()
		return
	close()
	Builder.start_placing(id)


## A hint points at a page: the icon bounces for a while and the book opens there.
func highlight(id: String) -> void:
	var index := Config.BOOK_ORDER.find(id)
	if index < 0:
		return
	page = index
	if GameState.recipe_unlocked(id) and not GameState.new_recipes.has(id):
		GameState.new_recipes.append(id)          # the page shimmers when it is opened
	icon.pivot_offset = icon.size * 0.5
	var tween := create_tween().set_loops(8)
	tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.2)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.25)


## New recipes: a message, and the icon pulses a few times.
func _on_recipes_unlocked(_ids: Array) -> void:
	GameState.say("NEW RECIPES DISCOVERED!")
	icon.pivot_offset = icon.size * 0.5
	var tween := create_tween().set_loops(3)
	tween.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.18)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.18)


func _part(region: Rect2) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = region
	return tex


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	return b


## The HUD button: the small open book from the sheet, unchanged, with a slow glow.
func _make_icon() -> void:
	icon = TextureButton.new()
	icon.name = "Icon"
	icon.texture_normal = _part(ICON)
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(60, 61)
	icon.focus_mode = Control.FOCUS_NONE
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	icon.offset_left = -76
	icon.offset_right = -16
	icon.offset_top = -30
	icon.offset_bottom = 31
	icon.pressed.connect(open)
	add_child(icon)
	var glow := icon.create_tween().set_loops()
	glow.tween_property(icon, "modulate", Color(1.25, 1.2, 1.1), 0.9)
	glow.tween_property(icon, "modulate", Color.WHITE, 0.9)


func _make_book() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.05, 0.02, 0.04, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	add_child(overlay)

	book = TextureRect.new()
	book.name = "Book"
	book.texture = _part(OPEN_A)
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book.offset_left = -BOOK_SIZE.x * 0.5
	book.offset_right = BOOK_SIZE.x * 0.5
	book.offset_top = -BOOK_SIZE.y * 0.5
	book.offset_bottom = BOOK_SIZE.y * 0.5
	book.pivot_offset = BOOK_SIZE * 0.5
	overlay.add_child(book)

	content = Control.new()
	content.name = "Content"
	content.size = BOOK_SIZE
	book.add_child(content)

	# Left page: what it is.
	var left := VBoxContainer.new()
	left.position = BOOK_SIZE * Vector2(0.085, 0.1)
	left.size = BOOK_SIZE * Vector2(0.37, 0.64)
	content.add_child(left)
	section = _label("", 12)
	section.name = "Section"
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_color_override("font_color", Color(0.6, 0.3, 0.12))
	left.add_child(section)
	title = _label("", 20)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(title)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = Vector2(0, 130)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(picture)
	purpose = _label("", 14)
	purpose.name = "Purpose"
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(purpose)
	status = _label("", 15)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(status)

	# Right page: what it costs, and the Build button.
	var right := VBoxContainer.new()
	right.position = BOOK_SIZE * Vector2(0.545, 0.1)
	right.size = BOOK_SIZE * Vector2(0.37, 0.64)
	content.add_child(right)
	var heading := _label("Required Materials", 17)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(heading)
	materials = VBoxContainer.new()
	materials.name = "Materials"
	materials.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(materials)
	problem = _label("", 12)
	problem.name = "Problem"
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problem.add_theme_color_override("font_color", BAD)
	right.add_child(problem)
	build = _button("BUILD", _on_build)
	build.name = "Build"
	right.add_child(build)
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(nav)
	nav.add_child(_button("  <  ", flip.bind(-1)))
	counter = _label("", 15)
	counter.name = "Counter"
	counter.custom_minimum_size = Vector2(70, 0)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(counter)
	nav.add_child(_button("  >  ", flip.bind(1)))

	var x := _button(" X ", close)
	x.name = "Close"
	x.position = Vector2(BOOK_SIZE.x - 58, 6)
	book.add_child(x)
