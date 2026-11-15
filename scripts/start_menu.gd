extends Control

const GAME_SCENE := "res://scenes/level1/Level1.tscn"


func _ready() -> void:
	get_tree().paused = false
	%NewRun.pressed.connect(_on_new_run)
	%Quit.pressed.connect(_on_quit)
	$Credits.pressed.connect(_on_credits)
	%howToPlay.pressed.connect(_on_help)

	for button in [%NewRun, %Quit]:
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	%NewRun.grab_focus()

	GameStats.best_bosses_changed.connect(_on_best_changed)
	_refresh_best()


func _refresh_best() -> void:
	var best: int = GameStats.best_bosses

	if best <= 0:
		%BestScore.text = "NO BOSSES BEATEN YET"
		return

	var noun := "BOSS" if best == 1 else "BOSSES"
	%BestScore.text = "BEST: %d %s" % [best, noun]


func _on_best_changed(_best: int) -> void:
	_refresh_best()


func _on_new_run() -> void:
	GameStats.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_help() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/howToPlay.tscn")
	
func _on_quit() -> void:
	get_tree().quit()

func _on_credits() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
