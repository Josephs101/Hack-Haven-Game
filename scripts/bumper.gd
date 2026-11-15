
extends StaticBody2D

signal bumper_hit

@export var min_outward_speed: float = 500.0

func _ready() -> void:
	$BumperArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is RigidBody2D:
		return

	var offset = body.global_position - global_position

	if offset.length_squared() < 0.001:
		return

	var direction = offset.normalized()

	var current_velocity = body.linear_velocity
	var outward_speed = current_velocity.dot(direction)

	if outward_speed < min_outward_speed:
		var additional_speed = min_outward_speed - outward_speed
		body.linear_velocity = current_velocity + direction * additional_speed
	
	# Play Animation
	body.sleeping = false

	# Notify the visual bumper
	bumper_hit.emit()
	GameStats.bouncer_hit.emit()

	# Score + combo + boss damage
	GameStats.register_hit()
