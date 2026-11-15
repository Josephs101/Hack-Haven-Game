
extends StaticBody2D

@export var min_outward_speed: float = 500.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
func _ready() -> void:
	$BumperArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is RigidBody2D:
		return

	# Calculate direction away from bumper centre
	var offset = body.global_position - global_position

	if offset.length_squared() < 0.001:
		return

	var direction = offset.normalized()

	# Calculate how quickly the ball is already moving
	# away from the bumper
	var current_velocity = body.linear_velocity
	var outward_speed = current_velocity.dot(direction)

	# Only boost if the ball isn't moving away fast enough
	if outward_speed < min_outward_speed:
		var additional_speed = min_outward_speed - outward_speed

		body.linear_velocity = current_velocity + direction * additional_speed
	
	# Play Animation
	sprite.play("bounce")
	body.sleeping = false
