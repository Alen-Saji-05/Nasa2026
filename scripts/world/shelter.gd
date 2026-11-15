extends Node2D
## Inside the Emergency Shelter (scenes/Shelter.tscn, Travel.enter_shelter()).
## A small room built here in code: floor, walls with collision, a bunk, the
## comms console, life support, a window to the outside and the door (shelter_door.gd).
## Radiation and dust storms cannot hurt the player here (GameState.in_shelter),
## but they keep running outside: the window and the wall screen show them.

const ROOM := Rect2(0, 0, 196, 120)          # the floor, in pixels
## What the camera shows: same size as before the room got smaller, so the
## astronaut keeps its size and the room looks snug, with dark space around it.
const VIEW := Rect2(-62, -79, 320, 250)
const GRATE := preload("res://art/overlays/metal_grate.png")
const CRATE := preload("res://art/new_sprites/research_sites/04_electronics_storage_crate.png")
## The shelter furniture sheet: bed corner, radiation monitor desk, supply shelf,
## O2 tanks and the door. Decoration only (the door art is used by shelter_door.gd).
const SHEET := preload("res://art/Pixel-Art emergentcy shelter Assets.png")
const BED := Rect2(202, 18, 572, 410)
const DESK := Rect2(902, 16, 595, 412)
const SHELF := Rect2(143, 487, 422, 398)
const O2_TANKS := Rect2(638, 490, 350, 396)
const DOOR := Rect2(1072, 475, 446, 412)
const DOOR_SCRIPT := preload("res://scripts/shelter_door.gd")

const WALL := Color(0.55, 0.53, 0.58)
const WALL_DARK := Color(0.3, 0.29, 0.33)
const GREEN := Color(0.42, 0.66, 0.16)
const GLOW := Color(0.75, 1.0, 0.25)

var _window: ColorRect
var _screen: Label


func _ready() -> void:
	_build_room()
	var player := $Entities/Player as Node2D
	player.position = Vector2(ROOM.size.x * 0.5, ROOM.end.y - 14)
	_setup_camera(player.get_node("Camera2D") as Camera2D)
	get_viewport().size_changed.connect(func() -> void: _setup_camera(player.get_node("Camera2D") as Camera2D))
	Dialogue.once("shelter_inside")
	if Hazards.is_safe():
		GameState.say("Conditions outside are safe. Press E at the door to go back out.")
	else:
		GameState.say("You are safe in here: %s outside." % Hazards.danger_text())


func _process(_delta: float) -> void:
	# The window shows the weather outside; the wall screen shows the hazards.
	var t := Time.get_ticks_msec() * 0.001
	var sky := Color(0.12, 0.1, 0.2).lerp(Color(0.86, 0.62, 0.42), GameState.sun)
	sky = sky.lerp(Color(0.55, 0.33, 0.18), Hazards.intensity * (0.8 + 0.2 * sin(t * 7.0)))
	if Hazards.radiation == "active":
		sky = sky.lerp(Hazards.RAD_COLOR, 0.35 + 0.15 * sin(t * 9.0))
	_window.color = sky
	var danger := Hazards.danger_text()
	var kinds: Array[String] = []
	if Hazards.radiation != "":
		kinds.append("RADIATION")
	if danger.contains("dust"):
		kinds.append("DUST STORM")
	_screen.text = "OUTSIDE: " + (" + ".join(kinds) if danger != "" else "SAFE")
	_screen.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if danger != "" else Color(0.6, 1.0, 0.5))


func _setup_camera(cam: Camera2D) -> void:
	var view := get_viewport().get_visible_rect().size
	var zoom := minf(view.x / VIEW.size.x, view.y / VIEW.size.y)   # the whole room on screen
	cam.zoom = Vector2(zoom, zoom)
	cam.limit_left = int(VIEW.position.x)
	cam.limit_top = int(VIEW.position.y)
	cam.limit_right = int(VIEW.end.x)
	cam.limit_bottom = int(VIEW.end.y)
	cam.reset_smoothing()


func _build_room() -> void:
	var room := $Room
	_rect(room, VIEW.grow(400), Color(0.07, 0.06, 0.08))                                  # outside the walls
	_rect(room, ROOM, Color(0.32, 0.31, 0.35))
	var floor_tiles := TextureRect.new()
	floor_tiles.texture = GRATE
	floor_tiles.stretch_mode = TextureRect.STRETCH_TILE
	floor_tiles.position = ROOM.position
	floor_tiles.scale = Vector2(0.25, 0.25)
	floor_tiles.size = ROOM.size * 4.0
	floor_tiles.modulate = Color(0.6, 0.6, 0.7, 0.18)
	room.add_child(floor_tiles)

	# Back wall (seen from the front), side walls and the front wall.
	_rect(room, Rect2(-16, -50, ROOM.size.x + 32, 50), WALL)
	_rect(room, Rect2(-16, -6, ROOM.size.x + 32, 6), WALL_DARK)
	_rect(room, Rect2(-16, -50, ROOM.size.x + 32, 6), GREEN)
	_rect(room, Rect2(-16, -50, 16, ROOM.size.y + 66), WALL_DARK)
	_rect(room, Rect2(ROOM.end.x, -50, 16, ROOM.size.y + 66), WALL_DARK)
	_rect(room, Rect2(-16, ROOM.end.y, ROOM.size.x + 32, 16), WALL)
	_rect(room, Rect2(158, -44, 32, 20), WALL_DARK)                             # a porthole to the outside
	_window = _rect(room, Rect2(161, -41, 26, 14), Color.BLACK)
	_screen = Label.new()
	_screen.position = Vector2(66, -43)
	_screen.scale = Vector2(0.25, 0.25)
	_screen.add_theme_font_size_override("font_size", 22)
	_screen.add_theme_color_override("font_outline_color", Color.BLACK)
	_screen.add_theme_constant_override("outline_size", 6)
	room.add_child(_screen)

	# Walls the player cannot pass: back, front (only the door leads out), left, right.
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	for r: Rect2 in [Rect2(-60, -80, 360, 86), Rect2(-60, ROOM.end.y - 2, 360, 60),
			Rect2(-60, -80, 60, 320), Rect2(ROOM.end.x, -80, 60, 320)]:
		_solid(walls, r)

	# Furniture (each solid at its base).
	var entities := $Entities
	# Along the back wall: bed corner (with its lamp and plant shelf), desk, O2 tanks, supplies.
	_sprite(entities, piece(BED), 64.0, Vector2(33, 12), "Bed")
	_sprite(entities, piece(DESK), 58.0, Vector2(95, 12), "Desk")
	_sprite(entities, piece(O2_TANKS), 28.0, Vector2(139, 12), "O2Tanks")
	_sprite(entities, piece(SHELF), 36.0, Vector2(174, 12), "Shelf")
	_sprite(entities, CRATE, 28.0, Vector2(180, 112), "Crate")

	var door := Node2D.new()
	door.name = "Door"
	door.set_script(DOOR_SCRIPT)
	door.position = Vector2(ROOM.size.x * 0.5, ROOM.end.y + 12)
	entities.add_child(door)


func _rect(parent: Node, r: Rect2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = r.position
	rect.size = r.size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _solid(body: Node, r: Rect2) -> void:
	if not body is CollisionObject2D:
		var static_body := StaticBody2D.new()
		body.add_child(static_body)
		body = static_body
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = r.get_center()
	body.add_child(collision)


## One picture cut out of the furniture sheet.
static func piece(region: Rect2) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = region
	return tex


## A picture standing on `feet`, `width` pixels wide, solid at its base.
func _sprite(parent: Node, tex: Texture2D, width: float, feet: Vector2, title := "") -> void:
	var holder := Node2D.new()
	if title != "":
		holder.name = title
	holder.position = feet
	parent.add_child(holder)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2.ONE * width / tex.get_size().x
	sprite.offset = Vector2(0, -tex.get_size().y * 0.5)
	holder.add_child(sprite)
	_solid(holder, Rect2(-width * 0.35, -6, width * 0.7, 6))
