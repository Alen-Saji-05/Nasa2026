extends StaticBody2D
## The hab. Press E next to it to refine every ore you carry:
## Iron Ore -> Iron Ingots, Aluminum Ore -> Aluminum Ingots, Sulfur -> Sulfur Compound
## (Config.REFINE). This stands in until the Ore Refinery machine is built.


func _ready() -> void:
	add_to_group(Interactor.GROUP)


func interact(_player: Node2D) -> void:
	var made: Array[String] = []
	for ore: String in Config.REFINE:
		var count: int = GameState.item_count(ore)
		if count > 0 and GameState.spend_items({ore: count}):
			GameState.add_item(Config.REFINE[ore], count)
			made.append("%d %s" % [count, Config.item(Config.REFINE[ore]).name])
	GameState.say("Refined: " + ", ".join(made) if not made.is_empty() else "Bring ore here to refine it into ingots")


func prompt_offset() -> Vector2:
	return Vector2(0, -30)
