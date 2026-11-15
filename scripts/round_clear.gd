extends Control

signal continue_pressed

@onready var score_label: Label = $CenterContainer/PanelContainer/BoxContainer/ScoreLabel
@onready var damage_label: Label = $CenterContainer/PanelContainer/BoxContainer/DamageLabel
@onready var continue_button: Button = $CenterContainer/PanelContainer/BoxContainer/RestartButton
@onready var confetti: AnimatedSprite2D = %Confetti


func _ready() -> void:
	hide()
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	if confetti != null:
		confetti.visible = false
		confetti.animation_finished.connect(_on_confetti_finished)


func open(score: int, damage: int) -> void:
	score_label.text = "SCORE: %d" % score
	damage_label.text = "DAMAGE DEALT: %d" % damage
	show()
	continue_button.grab_focus()
	_play_confetti()


func _play_confetti() -> void:
	if confetti == null or confetti.sprite_frames == null:
		return
	if not confetti.sprite_frames.has_animation(&"big_confetti"):
		return

	confetti.visible = true
	confetti.play(&"big_confetti")


func _on_confetti_finished() -> void:
	confetti.visible = false
