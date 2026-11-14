
extends Control

@onready var oxygen_bar: ProgressBar = $OxygenPanel/VBoxContainer/OxygenBar
@onready var oxygen_value: Label = $OxygenPanel/VBoxContainer/OxygenValue


func _ready() -> void:
	GameState.oxygen_changed.connect(update_oxygen)

	update_oxygen(GameState.oxygen)


func update_oxygen(value: float) -> void:
	oxygen_bar.value = value
	oxygen_value.text = str(roundi(value)) + "% O₂"
