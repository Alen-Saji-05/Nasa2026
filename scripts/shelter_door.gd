extends Node2D
## The door out of the Emergency Shelter (inside view, shelter.gd builds it).
## E opens it only when it is safe outside; otherwise it says what is still going on.
## The lamp above it is red while a hazard is dangerous, green when it is safe.

var _lamp: ColorRect


func _ready() -> void:
	add_to_group(Interactor.GROUP)
	_box(Vector2(-22, -30), Vector2(44, 30), Color(0.35, 0.34, 0.38))            # frame
	_box(Vector2(-18, -27), Vector2(36, 27), Color(0.16, 0.16, 0.19))            # the door
	for i in 6:                                                                  # hazard stripes
		_box(Vector2(-18 + i * 6, -8), Vector2(3, 8), Color(0.98, 0.72, 0.1))
	_lamp = _box(Vector2(-4, -36), Vector2(8, 5), Color.RED)


func _process(_delta: float) -> void:
	var safe := Hazards.is_safe()
	var blink := 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006))
	_lamp.color = Color(0.4, 1.0, 0.45) if safe else Color(1.0, 0.2, 0.15, blink)


func interact(_player: Node2D) -> void:
	if Hazards.is_safe():
		Travel.exit_shelter()
	else:
		GameState.say("Not safe outside: %s. Stay in the shelter!" % Hazards.danger_text())


func prompt_text() -> String:
	return "Press E to Exit Emergency Shelter" if Hazards.is_safe() else "Exit locked: hazard outside"


func prompt_offset() -> Vector2:
	return Vector2(0, -40)


func _box(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
