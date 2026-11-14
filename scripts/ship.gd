extends StaticBody2D
## The crashed ship (world_gen.gd builds it with six ShipSlots around it).
## E on the ship: the first time, salvage the emergency power cell and the seed
## potatoes; after that it tells the repair progress. When all six modules are
## installed it shows the repaired ship.

const CRASHED := preload("res://art/new_sprites/spaceship_components/Crashed Pixel Spaceship Sprite.png")
const REPAIRED := preload("res://art/new_sprites/spaceship_components/Repaired_Spaceship.png")


func _ready() -> void:
	add_to_group(Interactor.GROUP)
	GameState.ship_changed.connect(_refresh)
	GameState.highlight.connect(func(target: String) -> void:
		if target == "wreck":
			_point_at())
	_refresh()


func interact(_player: Node2D) -> void:
	if not GameState.wreck_salvaged:
		GameState.salvage_wreck()
		Dialogue.once("wreck")
		GameState.say("+1 emergency power cell (+%d storage), +%d Potatoes" % [roundi(Config.POWER_CELL_BONUS), Config.WRECK_POTATOES])
		return
	GameState.say("Ship repair: %d / %d systems installed" % [GameState.installed.size(), Config.REPAIR_ORDER.size()])


func prompt_offset() -> Vector2:
	return Vector2(0, -24)


## A hint points at the ship: a bouncing yellow arrow above it for a few seconds.
func _point_at() -> void:
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-7, -10), Vector2(7, -10), Vector2(0, 0)])
	arrow.color = Color(1.0, 0.85, 0.2)
	arrow.position = Vector2(0, -40)
	arrow.z_index = 50
	add_child(arrow)
	var tween := arrow.create_tween()
	for i in 10:
		tween.tween_property(arrow, "position:y", -48.0, 0.3)
		tween.tween_property(arrow, "position:y", -40.0, 0.3)
	tween.tween_callback(arrow.queue_free)


func _refresh() -> void:
	var sprite := $Sprite2D as Sprite2D
	sprite.texture = REPAIRED if GameState.ship_repaired() else CRASHED
