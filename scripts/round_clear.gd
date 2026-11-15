extends Control

signal continue_pressed

@onready var score_label: Label = $CenterContainer/PanelContainer/BoxContainer/ScoreLabel
@onready var damage_label: Label = $CenterContainer/PanelContainer/BoxContainer/DamageLabel
@onready var continue_button: Button = $CenterContainer/PanelContainer/BoxContainer/RestartButton


func _ready() -> void:
	hide()
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())


func open(score: int, damage: int) -> void:
	score_label.text = "SCORE: %d" % score
	damage_label.text = "DAMAGE DEALT: %d" % damage
	show()
	continue_button.grab_focus()
