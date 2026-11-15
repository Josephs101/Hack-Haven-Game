extends Control

@onready var score_label: Label = $CenterContainer/PanelContainer/BoxContainer/ScoreLabel
@onready var restart_button: Button = $CenterContainer/PanelContainer/BoxContainer/RestartButton
@onready var defeat_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	hide()
	defeat_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart)

func show_game_over() -> void:
	score_label.text = "SCORE: %d" %GameStats.score
	show()
	_stop_level_music()
	defeat_sound.play()
	get_tree().paused = true
	restart_button.grab_focus()

# Stop every other 2D player in the level so the defeat jingle is the only
# track playing. Walk up to the level root instead of trusting current_scene.
func _stop_level_music() -> void:
	var root := _level_root()
	for node in root.find_children("*", "AudioStreamPlayer2D", true, false):
		if node != defeat_sound:
			node.stop()


func _level_root() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node

func _on_restart() -> void:
	defeat_sound.stop()
	get_tree().paused = false
	GameStats.start_run(1)
	get_tree().change_scene_to_file("res://scenes/level1/Level1.tscn")
