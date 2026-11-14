
extends RigidBody2D

# Maximum allowed ball speed (pixels per second)
@export var max_speed: float = 700.0

# Called every physics frame
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity = state.linear_velocity

	# Prevent the ball from reaching excessively high speeds
	if velocity.length() > max_speed:
		state.linear_velocity = velocity.normalized() * max_speed


# Launch the ball using an impulse
func launch(impulse: Vector2) -> void:
	sleeping = false
	apply_central_impulse(impulse)
