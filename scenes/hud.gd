
extends Control

@onready var oxygen_bar: TextureRect = $OxygenPanel/VBoxContainer/OxygenBar

const OXYGEN_TEXTURES = {
	10: preload("res://art/oxgen_bar/oxygen_bar_010.png"),
	20: preload("res://art/oxgen_bar/oxygen_bar_020.png"),
	30: preload("res://art/oxgen_bar/oxygen_bar_030.png"),
	40: preload("res://art/oxgen_bar/oxygen_bar_040.png"),
	50: preload("res://art/oxgen_bar/oxygen_bar_050.png"),
	60: preload("res://art/oxgen_bar/oxygen_bar_060.png"),
	70: preload("res://art/oxgen_bar/oxygen_bar_070.png"),
	80: preload("res://art/oxgen_bar/oxygen_bar_080.png"),
	90: preload("res://art/oxgen_bar/oxygen_bar_090.png"),
	100: preload("res://art/oxgen_bar/oxygen_bar_100.png")
}

func _ready() -> void:
	GameState.oxygen_changed.connect(update_oxygen)
	update_oxygen(GameState.oxygen)

func update_oxygen(value: float) -> void:
	var level = clampi(int(floor(value / 10.0)) * 10, 10, 100)
	oxygen_bar.texture = OXYGEN_TEXTURES[level]
