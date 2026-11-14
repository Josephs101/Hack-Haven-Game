extends AnimatableBody2D

@export var rest_angle: float = 20.0
@export var raised_angle: float = -35.0
@export var rotation_speed: float = 1000.0

@export var input_action: String = "flipper_left"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	rotation_degrees = rest_angle
	sprite.play("rest")

func _physics_process(delta: float) -> void:
	var target_angle = rest_angle

	if Input.is_action_pressed(input_action):
		target_angle = raised_angle
		sprite.play("raised")
	else:
		sprite.play("rest")

	rotation_degrees = move_toward(
		rotation_degrees,
		target_angle,
		rotation_speed * delta
	)
