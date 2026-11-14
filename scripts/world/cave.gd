extends Node2D
## One layer of a cave (scenes/Cave.tscn). Which cave and layer comes from
## GameState.cave_id / cave_layer; the layout comes from CaveGen and Config.CAVES.
## The same scene is used for every cave and every layer.
##
## What it does when it loads:
##   1. builds the layout (CaveGen)
##   2. paints floor, rock and cliffs
##   3. places deposits, rocks, craters, ladders and the way out
##   4. puts the player where they came in
##   5. makes it dark, with a suit light around the player
##
## Run it alone (F6) and it shows the first layer of the first cave.

const TILE := 16
const SOURCE_ID := 0                         # the atlas inside mars_tileset.tres

# Atlas coordinates in art/atlases/terrain_paths_autotile_16px.png (column, row)
const T_REGOLITH := Vector2i(0, 0)
const T_CRACKED := Vector2i(2, 0)
const T_ROCKS := Vector2i(3, 0)
const T_WALL_ROCK := Vector2i(4, 0)         # has collision in the TileSet
const T_ICE := Vector2i(5, 0)
const T_PEBBLES := Vector2i(3, 1)
const T_ROCKY := Vector2i(4, 1)
const T_CRATERS := Vector2i(5, 1)
const T_SAND_C := Vector2i(3, 2)

const TEX_METAL := preload("res://art/decor/metal_ore_full.png")
const TEX_ICE := preload("res://art/decor/ice_deposit_full.png")
const TEX_ROCKS := [
	preload("res://art/decor/small_rock.png"),
	preload("res://art/decor/rock_cluster_small.png"),
	preload("res://art/decor/rock_cluster_large.png"),
]
const TEX_CRATER_SMALL := preload("res://art/craters/crater_single.png")
const TEX_CRATER_BIG := preload("res://art/craters/crater_3x3.png")
const TEX_CLIFF_LEFT := preload("res://art/cliffs/cliff_left.png")
const TEX_CLIFF_RIGHT := preload("res://art/cliffs/cliff_right.png")
## PLACEHOLDER art. Swap these files (or these paths) when the real art exists.
const TEX_LADDER_UP := preload("res://art/placeholders/ladder_up_placeholder.png")
const TEX_LADDER_DOWN := preload("res://art/placeholders/ladder_down_placeholder.png")
const TEX_EXIT := preload("res://art/placeholders/cave_exit_placeholder.png")

const RESOURCE_NODE_SCRIPT := preload("res://scripts/resource_node.gd")
const CRATER_SCRIPT := preload("res://scripts/crater_hazard.gd")
const LADDER_SCRIPT := preload("res://scripts/ladder.gd")
const EXIT_SCRIPT := preload("res://scripts/cave_exit.gd")

const DECOR_SCALE := Vector2(0.25, 0.25)    # rock art is drawn ~4x larger than tiles
const NODE_SCALE := Vector2(2.0, 2.0)       # metal / ice deposits (16 px art)

@export var camera_zoom: float = 2.0

## The layout this layer was built from.
var layout: CaveGen
var _light: PointLight2D

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var ground_decor: Node2D = $GroundDecor
@onready var cliffs: Node2D = $Cliffs
@onready var doors: Node2D = $Doors
@onready var nodes: Node2D = $Entities/Nodes
@onready var decor: Node2D = $Entities/Decor
@onready var player: CharacterBody2D = $Entities/Player
@onready var darkness: CanvasModulate = $Darkness


func _ready() -> void:
	var cave := Config.cave(GameState.cave_id)
	if cave.is_empty():
		# Started on its own (F6): show the first cave.
		cave = Config.CAVES[0]
		GameState.set_location(cave.id, 0, "from_surface")
	var layer := clampi(GameState.cave_layer, 0, cave.layers.size() - 1)
	layout = CaveGen.build(cave, layer)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cave.seed, layer, "paint"])
	_paint_ground(cave, rng)
	_paint_walls()
	_place_cliffs()
	_place_things(rng)
	_place_doors()
	_place_player()
	_make_dark(cave)
	_setup_camera()
	get_viewport().size_changed.connect(_setup_camera)


func _process(_delta: float) -> void:
	if _light != null:
		_light.position = player.position


# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

func _paint_ground(cave: Dictionary, rng: RandomNumberGenerator) -> void:
	var theme: String = cave.get("theme", "")
	var noise := FastNoiseLite.new()
	noise.seed = int(cave.seed) + layout.layer
	noise.frequency = 0.11
	for x in layout.size.x:
		for y in layout.size.y:
			var n := noise.get_noise_2d(x, y)
			var r := rng.randf()
			var tile := T_REGOLITH
			match theme:
				"ice":                           # frozen ground in patches
					if n > 0.18:
						tile = T_ICE
					elif r < 0.10:
						tile = T_CRACKED
					elif r < 0.16:
						tile = T_PEBBLES
				"ore":                           # stony, lots of loose rock
					if n > 0.25:
						tile = T_ROCKY
					elif r < 0.14:
						tile = T_ROCKS
					elif r < 0.24:
						tile = T_PEBBLES
				_:                               # deep: cracked, pitted ground
					if n > 0.15:
						tile = T_CRACKED
					elif r < 0.10:
						tile = T_CRATERS
					elif r < 0.18:
						tile = T_ROCKS
			ground.set_cell(Vector2i(x, y), SOURCE_ID, tile)

	# The floor of a reward room hints at what is inside.
	for chamber in layout.chambers:
		var rect: Rect2i = chamber.rect
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var roll := rng.randf()
				if chamber.kind == "ice" and roll < 0.6:
					ground.set_cell(Vector2i(x, y), SOURCE_ID, T_ICE)
				elif chamber.kind == "metal" and roll < 0.5:
					ground.set_cell(Vector2i(x, y), SOURCE_ID, T_ROCKY if roll < 0.25 else T_ROCKS)

	# The way out is lit sand.
	if layout.exit_tile != CaveGen.NONE:
		ground.set_cell(layout.exit_tile, SOURCE_ID, T_SAND_C)


## Everything that is not floor is solid rock.
func _paint_walls() -> void:
	for x in layout.size.x:
		for y in layout.size.y:
			if not layout.is_walk(Vector2i(x, y)):
				walls.set_cell(Vector2i(x, y), SOURCE_ID, T_WALL_ROCK)


## Cliff faces on every rock edge that looks down onto floor.
func _place_cliffs() -> void:
	for y in layout.size.y - 1:
		for x in layout.size.x:
			if not _faces_south(Vector2i(x, y)):
				continue
			var left_end := not _faces_south(Vector2i(x - 1, y))
			var right_end := not _faces_south(Vector2i(x + 1, y))
			var use_left := left_end or (not right_end and x % 2 == 0)
			var tex: Texture2D = TEX_CLIFF_LEFT if use_left else TEX_CLIFF_RIGHT
			_sprite(cliffs, "Cliff_%d_%d" % [x, y], tex, Vector2(TILE, TILE) / tex.get_size(), _tile_centre(Vector2i(x, y)))


func _faces_south(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < layout.size.x and not layout.is_walk(t) and layout.is_walk(t + Vector2i.DOWN)


# ---------------------------------------------------------------------------
# Deposits, rocks, craters
# ---------------------------------------------------------------------------

func _place_things(rng: RandomNumberGenerator) -> void:
	for n in layout.nodes:
		var kind: String = n.get("ore", n.kind)
		var tex: Texture2D = TEX_METAL if kind == "metal" else TEX_ICE
		var scl := NODE_SCALE
		if Config.ITEMS.has(kind):
			tex = load(Config.item(kind).icon)
			scl = Vector2.ONE * Config.DEPOSIT_PIXELS / tex.get_size().x
		var s := _sprite(nodes, str(n.id).get_file(), tex, scl,
			_tile_centre(n.tile), RESOURCE_NODE_SCRIPT, {"kind": kind, "node_id": n.id})
		s.set_meta("kind", kind)

	var i := 0
	for t in layout.rocks:
		i += 1
		var tex: Texture2D = TEX_ROCKS[rng.randi() % TEX_ROCKS.size()]
		_sprite(decor, "Rock%02d" % i, tex, DECOR_SCALE, _tile_centre(t))

	i = 0
	for t in layout.small_craters:
		# One tile: costs oxygen if you walk into it, easy to step around.
		i += 1
		_sprite(ground_decor, "Crater%02d" % i, TEX_CRATER_SMALL,
			Vector2.ONE * (TILE * 1.1) / TEX_CRATER_SMALL.get_size().x, _tile_centre(t), CRATER_SCRIPT,
			{"hazard_fraction": Vector2(0.7, 0.7)})
	for rect in layout.door_craters:
		# Fills a whole door: there is no way around it.
		i += 1
		var pixels := Vector2(rect.size * TILE)
		_sprite(ground_decor, "DoorCrater%02d" % i, TEX_CRATER_BIG, pixels * 1.08 / TEX_CRATER_BIG.get_size(),
			Vector2(rect.position * TILE) + pixels * 0.5, CRATER_SCRIPT, {"hazard_fraction": Vector2(0.95, 0.95)})


# ---------------------------------------------------------------------------
# The way out and the ladders
# ---------------------------------------------------------------------------

func _place_doors() -> void:
	if layout.exit_tile != CaveGen.NONE:
		var exit_area := Area2D.new()
		exit_area.set_script(EXIT_SCRIPT)
		exit_area.name = "Exit"
		exit_area.position = _tile_centre(layout.exit_tile)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE, TILE * 0.5)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(0, TILE * 0.25)      # the lower half of the notch
		exit_area.add_child(collision)
		var glow := Sprite2D.new()
		glow.name = "Daylight"
		glow.texture = TEX_EXIT
		exit_area.add_child(glow)
		exit_area.add_child(_small_light(Color(1.0, 0.85, 0.6), 3.0))
		doors.add_child(exit_area)

	if layout.ladder_up_tile != CaveGen.NONE:
		# Leans on the rock wall north of its floor tile.
		var up := _sprite(doors, "LadderUp", TEX_LADDER_UP, Vector2.ONE,
			Vector2(layout.ladder_up_tile.x * TILE + TILE * 0.5, layout.ladder_up_tile.y * TILE), LADDER_SCRIPT, {"direction": "up"})
		up.offset = Vector2(0, -TEX_LADDER_UP.get_size().y * 0.5 + 4.0)
		up.add_child(_small_light(Color(1.0, 0.9, 0.7), 2.5))

	if layout.ladder_down_tile != CaveGen.NONE:
		var down := _sprite(doors, "LadderDown", TEX_LADDER_DOWN, Vector2.ONE, _tile_centre(layout.ladder_down_tile),
			LADDER_SCRIPT, {"direction": "down"})
		down.add_child(_small_light(Color(0.8, 0.85, 1.0), 2.5))


# ---------------------------------------------------------------------------
# Player, light and camera
# ---------------------------------------------------------------------------

## Puts the player's FEET on the middle of the arrival tile.
func _place_player() -> void:
	var feet := Vector2.ZERO
	var shape := player.get_node_or_null("CollisionShape2D") as Node2D
	if shape != null:
		feet = shape.position * player.scale
	player.position = _tile_centre(layout.spawn_tile(GameState.arrival)) - feet


func _make_dark(cave: Dictionary) -> void:
	var tint: Color = cave.get("tint", Color.WHITE)
	var d := Config.CAVE_DARKNESS
	darkness.color = Color(tint.r * d, tint.g * d, tint.b * d)

	_light = _small_light(Color(1.0, 0.96, 0.88), Config.SUIT_LIGHT_RADIUS)
	_light.name = "SuitLight"
	_light.energy = 1.1
	add_child(_light)
	_light.position = player.position


## A round, soft light. `radius` is in tiles.
func _small_light(color: Color, radius: float) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0, 0, 0, 1))
	gradient.add_point(0.55, Color(0.45, 0.45, 0.45, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = tex
	light.color = color
	light.energy = 0.8
	light.texture_scale = radius * TILE * 2.0 / tex.width
	return light


## The camera stays inside the layer. A layer smaller than the view is zoomed in
## until it fills the window, so the outside never shows.
func _setup_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var map_pixels := Vector2(layout.size * TILE)
	var view := Vector2(get_viewport().get_visible_rect().size)
	var zoom := maxf(camera_zoom, maxf(view.x / map_pixels.x, view.y / map_pixels.y))
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_pixels.x)
	cam.limit_bottom = int(map_pixels.y)
	cam.zoom = Vector2(zoom, zoom)
	cam.reset_smoothing()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE) + Vector2(TILE, TILE) * 0.5


## `script` and `props` are applied before the sprite enters the tree, so the
## script's _ready() already sees them.
func _sprite(parent: Node, node_name: String, tex: Texture2D, scl: Vector2, pos: Vector2,
		script: Script = null, props: Dictionary = {}) -> Sprite2D:
	var s := Sprite2D.new()
	if script != null:
		s.set_script(script)
	s.name = node_name
	s.texture = tex
	s.scale = scl
	s.position = pos
	for key: String in props:
		s.set(key, props[key])
	parent.add_child(s)
	return s
