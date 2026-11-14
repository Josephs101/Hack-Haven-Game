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
	GameStats.reset()
	get_tree().reload_current_scene()
