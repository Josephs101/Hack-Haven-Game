extends Control

const GAME_SCENE := "res://scenes/LevelScreen.tscn"

func _ready() -> void:
	%NewRun.pressed.connect(_on_new_run);
	%Quit.pressed.connect(_on_quit);

func _on_new_run() -> void:
	GameStats.reset();
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/LevelScreen.tscn")

func _on_quit() -> void:
	get_tree().quit()
	
	
