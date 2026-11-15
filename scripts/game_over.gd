extends Control

@onready var score_label: Label = $CenterContainer/PanelContainer/BoxContainer/ScoreLabel
@onready var restart_button: Button = $CenterContainer/PanelContainer/BoxContainer/RestartButton

func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart)

func show_game_over() -> void:
	score_label.text = "SCORE: %d" %GameStats.score
	show()
	get_tree().paused = true
	restart_button.grab_focus()

func _on_restart() -> void:
	get_tree().paused = false
	GameStats.start_run(1)
	get_tree().change_scene_to_file("res://scenes/level1/Level1.tscn")
