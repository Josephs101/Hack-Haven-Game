extends Node2D

@export var level_number := 1


func _ready() -> void:
	GameStats.start_level(level_number)
