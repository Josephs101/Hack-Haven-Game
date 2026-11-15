extends Control

const GAME_SCENE := "res://scenes/level1/Level1.tscn"


func _ready() -> void:
	get_tree().paused = false
	%NewRun.pressed.connect(_on_new_run)
	%Quit.pressed.connect(_on_quit)
	%NewRun.grab_focus()


func _on_new_run() -> void:
	GameStats.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit() -> void:
	get_tree().quit()
