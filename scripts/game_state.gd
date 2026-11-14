
extends Node

signal oxygen_changed(value: float)
signal oxygen_depleted

var oxygen: float = 100.0

const OXYGEN_DRAIN_PER_SECOND: float = 0.4
const OXYGEN_GRACE_TIME: float = 6.0

var zero_oxygen_time: float = 0.0
var game_over: bool = false


func _process(delta: float) -> void:
	if game_over:
		return

	if oxygen > 0.0:
		oxygen = maxf(0.0, oxygen - OXYGEN_DRAIN_PER_SECOND * delta)
		oxygen_changed.emit(oxygen)

	if oxygen <= 0.0:
		zero_oxygen_time += delta

		if zero_oxygen_time >= OXYGEN_GRACE_TIME:
			game_over = true
			oxygen_depleted.emit()


func consume_oxygen(amount: float) -> void:
	if game_over:
		return

	oxygen = maxf(0.0, oxygen - amount)
	oxygen_changed.emit(oxygen)


func add_oxygen(amount: float) -> void:
	if game_over:
		return

	oxygen = minf(100.0, oxygen + amount)
	oxygen_changed.emit(oxygen)
