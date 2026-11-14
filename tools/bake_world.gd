extends SceneTree
## Regenerates the map and saves it into scenes/World.tscn (same as clicking
## "Generate Map" in the editor and saving). Run from the project folder:
##   godot --headless --path . --script res://tools/bake_world.gd
## Close the World scene in the editor first, or reload it afterwards.

const SCENE := "res://scenes/World.tscn"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var world := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	world.generate()

	var out := PackedScene.new()
	var err := out.pack(world)
	if err == OK:
		err = ResourceSaver.save(out, SCENE)
	world.free()
	if err != OK:
		push_error("bake_world: could not save %s (error %d)" % [SCENE, err])
		quit(1)
		return
	print("bake_world: saved %s" % SCENE)
	quit(0)
