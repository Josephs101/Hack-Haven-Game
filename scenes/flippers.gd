
extends Node2D

@export var input_action: String = "LeftFlipper"
@export var rotation_speed: float = 900.0
@export var rotation_direction: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var physics_body: AnimatableBody2D = $AnimatableBody2D

var raise_angles: Array[float] = [
	-45.0, -60.0, -75.0, -80.0, -80.0
]

var fall_angles: Array[float] = [
	-50.0, -10.0, -5.0
]

var is_pressed: bool = false
var target_angle: float = 0.0


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("Rest")
	physics_body.rotation_degrees = 0.0


func _physics_process(delta: float) -> void:
	var pressed = Input.is_action_pressed(input_action)

	if pressed and not is_pressed:
		sprite.play("Raise")
		is_pressed = true

	elif not pressed and is_pressed:
		sprite.play("Fall")
		is_pressed = false

	if sprite.animation == "Raise":
		var frame = mini(sprite.frame, raise_angles.size() - 1)
		target_angle = raise_angles[frame]*rotation_direction

	elif sprite.animation == "Fall":
		var frame = mini(sprite.frame, fall_angles.size() - 1)
		target_angle = fall_angles[frame]*rotation_direction

	physics_body.rotation_degrees = move_toward(
		physics_body.rotation_degrees,
		target_angle,
		rotation_speed * delta
	)


func _on_animation_finished() -> void:
	if sprite.animation == "Fall":
		sprite.play("Rest")
		target_angle = 0.0
