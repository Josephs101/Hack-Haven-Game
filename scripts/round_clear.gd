extends Control

signal continue_pressed

@onready var score_label: Label = $CenterContainer/PanelContainer/BoxContainer/ScoreLabel
@onready var damage_label: Label = $CenterContainer/PanelContainer/BoxContainer/DamageLabel
@onready var continue_button: Button = $CenterContainer/PanelContainer/BoxContainer/RestartButton
@onready var confetti: AnimatedSprite2D = %Confetti
@onready var victory_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	hide()
	victory_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue)
	if confetti != null:
		confetti.visible = false
		confetti.animation_finished.connect(_on_confetti_finished)


func open(score: int, damage: int) -> void:
	score_label.text = "SCORE: %d" % score
	damage_label.text = "DAMAGE DEALT: %d" % damage
	show()
	_stop_level_music()
	victory_sound.play()
	continue_button.grab_focus()
	_play_confetti()


func _on_continue() -> void:
	victory_sound.stop()
	continue_pressed.emit()


# Stop every other 2D player in the level so the victory jingle is the only
# track playing. Walk up to the level root instead of trusting current_scene.
func _stop_level_music() -> void:
	var root := _level_root()
	for node in root.find_children("*", "AudioStreamPlayer2D", true, false):
		if node != victory_sound:
			node.stop()


func _level_root() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node


func _play_confetti() -> void:
	if confetti == null or confetti.sprite_frames == null:
		return
	if not confetti.sprite_frames.has_animation(&"big_confetti"):
		return

	confetti.visible = true
	confetti.play(&"big_confetti")


func _on_confetti_finished() -> void:
	confetti.visible = false
