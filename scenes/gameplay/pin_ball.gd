extends RigidBody2D

@export var trail_length := 14
@export var trail_width := 12.0
@export var trail_color := Color(1.0, 1.0, 1.0, 0.55)

var _trail: Line2D = null


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	gravity_scale *= GameStats.gravity_multiplier
	_setup_trail()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("scoreable"):
		GameStats.register_hit()

		# Pegs react to being hit; bumpers and flippers animate themselves.
		if body.has_method(&"jiggle"):
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


func _physics_process(_delta: float) -> void:
	if _trail == null:
		return

	if freeze or sleeping:
		_trail.clear_points()
		return

	_trail.add_point(global_position)
	while _trail.get_point_count() > trail_length:
		_trail.remove_point(0)
