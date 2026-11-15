extends Node2D

@onready var bumper = $Bumper
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	bumper.bumper_hit.connect(_on_bumper_hit)
	sprite.play("Rest")
	sprite.animation_finished.connect(_on_animation_finished)


func _on_bumper_hit() -> void:
	sprite.play("Bounce")


func _on_animation_finished() -> void:
	if sprite.animation == "Bounce":
		sprite.play("Rest")
