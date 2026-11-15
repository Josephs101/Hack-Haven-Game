extends RigidBody2D

@export var trail_length := 14
@export var trail_width := 12.0
@export var trail_color := Color(1.0, 1.0, 1.0, 0.55)

# A ball wedged between two obstacles never comes back down on its own, which
# stalls the round because the ball count only drops when a ball drains. Watch
# for a ball that has stopped moving, bump it a couple of times, and finally
# drop it back over the flippers so play always continues.
@export var stuck_speed := 14.0
@export var stuck_seconds := 2.0
@export var nudge_impulse := 260.0
@export var max_nudges := 2

## Balls at or below this height are resting on the flippers or falling through
## the drain — sitting still there is normal, so never nudge those.
@export var flipper_zone_y := 900.0

## Where a ball that cannot be freed is put back into play. Sits just above the
## left flipper, so it is clear of every layout and the player can save it.
@export var drop_point := Vector2(380.0, 905.0)

var _trail: Line2D = null
var _stuck_time := 0.0
var _nudges := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	gravity_scale *= GameStats.gravity_multiplier
	_rng.randomize()
	_setup_trail()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("scoreable"):
		GameStats.register_hit()

		# Pegs change colour and eventually break when hit; bumpers and
		# flippers animate themselves.
		if body.has_method(&"hit"):
			body.hit()
		elif body.has_method(&"jiggle"):
			body.jiggle()


func _setup_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_as_relative = false
	_trail.z_index = 1
	_trail.width = trail_width
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND

	var gradient := Gradient.new()
	gradient.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	gradient.set_color(1, trail_color)
	_trail.gradient = gradient

	add_child(_trail)
	move_child(_trail, 0)


func _physics_process(delta: float) -> void:
	_update_trail()
	_update_stuck(delta)


func _update_trail() -> void:
	if _trail == null:
		return

	if freeze or sleeping:
		_trail.clear_points()
		return

	_trail.add_point(global_position)
	while _trail.get_point_count() > trail_length:
		_trail.remove_point(0)


func _update_stuck(delta: float) -> void:
	# The waiting ball in the launcher is frozen on purpose.
	if freeze:
		_stuck_time = 0.0
		return

	# Down in the flipper area the player is in control, so a still ball there
	# is resting on a flipper, not stuck.
	if global_position.y >= flipper_zone_y:
		_stuck_time = 0.0
		_nudges = 0
		return

	if linear_velocity.length() > stuck_speed:
		_stuck_time = 0.0
		_nudges = 0
		return

	_stuck_time += delta
	if _stuck_time < stuck_seconds:
		return

	_stuck_time = 0.0
	_nudges += 1

	if _nudges > max_nudges:
		_drop_free()
	else:
		_nudge()


# A sideways knock with a little lift, like bumping the table.
func _nudge() -> void:
	sleeping = false

	var direction := Vector2(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.15)
	).normalized()

	apply_central_impulse(direction * nudge_impulse)


# Last resort: put the ball back over the flippers so the round can finish.
func _drop_free() -> void:
	sleeping = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = drop_point

	_stuck_time = 0.0
	_nudges = 0

	if _trail != null:
		_trail.clear_points()
