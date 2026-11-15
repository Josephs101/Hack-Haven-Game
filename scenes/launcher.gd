extends Node2D

@export var ball_scene: PackedScene = preload("res://scenes/gameplay/PinBall.tscn")
@export var min_speed := 1700.0
@export var max_speed := 3200.0
@export var charge_rate := 0.7
@export var launch_action := "launch"
@export var charge_up_action := "charge_up"
@export var charge_down_action := "charge_down"

const TRAJECTORY_SCRIPT := preload("res://scripts/trajectory.gd")

@onready var meter: PowerMeter = $PowerMeter
@onready var spawn: Marker2D = $BallSpawn
@onready var anim: AnimatedSprite2D = $Spring
@onready var SFX_Spring: AudioStreamPlayer2D = $SFX_Spring

var _waiting_ball: RigidBody2D = null
var _waiting_layer := 1
var _waiting_mask := 1
var _power := 0.0
var _can_launch := true
var _pending_ball: RigidBody2D = null
var _pending_extras: Array[RigidBody2D] = []
var _pending_power := 0.0
var _spring_tops: Array[float] = []
var _release_frame := 14
var _trajectory: Node2D = null
var _last_traj_power := -1.0
var _last_traj_ready := false
var _one_way_rids: Array[RID] = []

# Vertical gap between the primary and extra multiball so they do not spawn
# inside each other. Extras stack *below* the primary: the space above it is
# right under the one-way gate, and a ball spawned there gets wedged in it.
const EXTRA_BALL_OFFSET := 36.0

func _ready() -> void:
	anim.frame_changed.connect(_on_spring_frame_changed)
	GameStats.balls_changed.connect(_on_balls_changed)
	_build_spring_profile()
	_collect_one_way_rids(get_parent())

	_trajectory = TRAJECTORY_SCRIPT.new()
	_trajectory.z_index = 5
	add_child(_trajectory)

	_spawn_waiting_ball()


# The launch lane has a one-way gate the ball passes through, but a raycast
# still reports it as a ceiling. Ignore those bodies in the preview.
func _collect_one_way_rids(root: Node) -> void:
	_one_way_rids.clear()

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()

		if node is CollisionShape2D and (node as CollisionShape2D).one_way_collision:
			var body := node.get_parent()
			if body is CollisionObject2D:
				var rid := (body as CollisionObject2D).get_rid()
				if not _one_way_rids.has(rid):
					_one_way_rids.append(rid)

		for child in node.get_children():
			stack.append(child)


# The ball rides on top of the spring, so the launcher needs to know where that
# top edge sits on every frame of the launch animation. Reading it from the
# sprite sheet keeps the motion in sync even though the animation repeats its
# first frame (which would otherwise shift every timing by one).
func _build_spring_profile() -> void:
	_spring_tops.clear()

	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(&"launch"):
		return

	for i in range(anim.sprite_frames.get_frame_count(&"launch")):
		_spring_tops.append(_top_edge_of_frame(i))

	_release_frame = _find_release_frame()


func _top_edge_of_frame(frame: int) -> float:
	var texture := anim.sprite_frames.get_frame_texture(&"launch", frame) as AtlasTexture
	if texture == null or texture.atlas == null:
		return 0.0

	var image := texture.atlas.get_image()
	if image == null:
		return 0.0

	var region := texture.region
	var left := int(region.position.x)
	var right := left + int(region.size.x)
	var top := int(region.position.y)
	var bottom := top + int(region.size.y)

	for y in range(top, bottom):
		for x in range(left, right):
			if image.get_pixel(x, y).a > 0.1:
				return float(y - top)

	return 0.0


# The spring squashes before it throws, so the launch frame is the highest
# point it reaches after the deepest compression.
func _find_release_frame() -> int:
	if _spring_tops.is_empty():
		return 14

	var deepest := 0
	for i in range(_spring_tops.size()):
		if _spring_tops[i] > _spring_tops[deepest]:
			deepest = i

	var highest := deepest
	for i in range(deepest, _spring_tops.size()):
		if _spring_tops[i] < _spring_tops[highest]:
			highest = i

	return highest


# The launcher is created before the level has restored its ball count, so the
# spawn in _ready() is skipped on every level after the first: balls_left is
# still 0 from the level that was just finished. Catch up as soon as the new
# ball set arrives.
func _on_balls_changed(left: int) -> void:
	if left <= 0:
		return

	if _waiting_ball != null or _pending_ball != null:
		return

	_spawn_waiting_ball()


func _process(delta: float) -> void:
	_update_trajectory()

	if not _can_launch or _waiting_ball == null or GameStats.balls_left <= 0:
		return

	if Input.is_action_pressed(charge_up_action):
		_power = clampf(_power + charge_rate * delta, 0.0, 1.0)
		meter.set_power(_power)
	elif Input.is_action_pressed(charge_down_action):
		_power = clampf(_power - charge_rate * delta, 0.0, 1.0)
		meter.set_power(_power)

	if Input.is_action_just_pressed(launch_action):
		_confirm_launch()


# Dotted preview of where the ball will fly. Circle-casts the real table so the
# line follows the ball's radius and bounces, then stops at a pin or bumper.
func _update_trajectory() -> void:
	if _trajectory == null:
		return

	var ready := _waiting_ball != null and _can_launch and GameStats.balls_left > 0
	if not ready:
		if _last_traj_ready:
			_trajectory.set_path(PackedVector2Array())
			_last_traj_ready = false
			_last_traj_power = -1.0
		return

	if _last_traj_ready and absf(_power - _last_traj_power) < 0.02:
		return

	_last_traj_ready = true
	_last_traj_power = _power

	var speed := lerpf(min_speed, max_speed, _power) * GameStats.speed_multiplier
	var gravity := Vector2.DOWN * (980.0 * 0.3 * GameStats.gravity_multiplier)
	var restitution := 0.8
	var damping := 0.1
	var radius := 16.0
	var step := 0.008
	var spacing := 14.0
	var max_dots := 120

	var circle := CircleShape2D.new()
	circle.radius = radius

	var exclude: Array[RID] = []
	exclude.append_array(_one_way_rids)
	if _waiting_ball != null:
		exclude.append(_waiting_ball.get_rid())

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.collision_mask = 1
	params.exclude = exclude

	var space := get_world_2d().direct_space_state
	var pos := spawn.global_position
	var vel := Vector2.UP * speed
	var points := PackedVector2Array()
	var run_up := PackedVector2Array()
	var bounced := false
	var travelled := 0.0
	var next_mark := spacing

	for i in range(700):
		# Bumpers are Area2D sensors, not bodies, so check them separately.
		params.transform = Transform2D(0.0, pos)
		params.motion = Vector2.ZERO
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var area_hits := space.intersect_shape(params, 4)
		params.collide_with_areas = false
		params.collide_with_bodies = true

		var hit_bumper := false
		for area_hit in area_hits:
			var area_collider = area_hit.collider
			if area_collider is Node and (area_collider as Node).is_in_group("scoreable"):
				hit_bumper = true
				break

		if hit_bumper:
			if not bounced:
				points.append_array(run_up)
				run_up.clear()
			points.append(pos - global_position)
			break

		var motion := vel * step
		params.transform = Transform2D(0.0, pos)
		params.motion = motion

		var cast := space.cast_motion(params)
		var safe: float = cast[0]

		if safe < 0.999:
			var contact := pos + motion * safe
			var direction := motion.normalized()
			# get_rest_info only reports a normal when the shape overlaps a
			# little, so probe just past the contact point.
			params.transform = Transform2D(0.0, contact + direction * 2.0)
			params.motion = Vector2.ZERO
			var rest := space.get_rest_info(params)

			if not rest.has("normal"):
				points.append(contact - global_position)
				break

			var collider = rest.get("collider", null)
			var is_object := collider is Node and (collider as Node).is_in_group("scoreable")

			if is_object:
				if not bounced:
					points.append_array(run_up)
					run_up.clear()
				points.append(contact - global_position)
				break

			var normal: Vector2 = rest.normal
			pos = contact + normal * 0.5

			if not bounced:
				bounced = true
				points.append_array(run_up)
				run_up.clear()
				travelled = 0.0
				next_mark = spacing

			points.append(pos - global_position)

			var normal_speed := vel.dot(normal)
			vel -= (1.0 + restitution) * normal_speed * normal
			vel += gravity * step
			vel *= 1.0 - damping * step

			if points.size() >= max_dots:
				break
			continue

		pos += motion
		vel += gravity * step
		vel *= 1.0 - damping * step

		if bounced:
			travelled += motion.length()
			if travelled >= next_mark:
				points.append(pos - global_position)
				next_mark += spacing
				if points.size() >= max_dots:
					break
		else:
			run_up.append(pos - global_position)
			if run_up.size() > 5:
				run_up.remove_at(0)

		if pos.y > 1150.0 or pos.x < -50.0 or pos.x > 1120.0:
			break

	_trajectory.set_path(points)


func _confirm_launch() -> void:
	if _waiting_ball == null:
		return

	if not GameStats.use_ball():
		return

	_can_launch = false

	_pending_ball = _waiting_ball
	_waiting_ball = null
	_pending_power = _power

	_pending_extras.clear()
	for i in range(GameStats.multiball_extra):
		_pending_extras.append(_make_pending_ball(i + 1))
		GameStats.active_balls += 1

	anim.play("launch")
	SFX_Spring.play()

	await anim.animation_finished

	meter.set_power(0.0)
	anim.play("default")

	if GameStats.balls_left > 0:
		await _spawn_waiting_ball()

	_can_launch = true

func _spawn_waiting_ball() -> void:
	if _waiting_ball != null or GameStats.balls_left <= 0:
		return

	var ball = ball_scene.instantiate()
	ball.freeze = true
	ball.sleeping = true

	_waiting_layer = ball.collision_layer
	_waiting_mask = ball.collision_mask
	ball.collision_layer = 0
	ball.collision_mask = 0

	_waiting_ball = ball

	# Defer the add until the level has finished setting up children.
	get_parent().add_child.call_deferred(ball)
	await ball.tree_entered

	ball.global_position = spawn.global_position
	_power = 0.0
	meter.set_power(0.0)




func _on_spring_frame_changed() -> void:
	if _pending_ball == null:
		return
	if anim.animation != &"launch":
		return

	_follow_spring(anim.frame)

	if anim.frame >= _release_frame:
		_launch_pending_ball()


# Keeps the ball sitting on the spring as it squashes and springs back, so the
# launch reads as the spring throwing the ball instead of the ball teleporting.
func _follow_spring(frame: int) -> void:
	if _spring_tops.size() < 2:
		return

	var index := clampi(frame, 0, _spring_tops.size() - 1)
	var dip := (_spring_tops[index] - _spring_tops[0]) * anim.scale.y
	var resting := spawn.global_position + Vector2.DOWN * dip

	if _pending_ball != null:
		_pending_ball.global_position = resting

	for i in range(_pending_extras.size()):
		_pending_extras[i].global_position = resting + Vector2(0, EXTRA_BALL_OFFSET * (i + 1))


func _launch_pending_ball() -> void:
	var primary := _pending_ball
	_pending_ball = null

	var extras := _pending_extras.duplicate()
	_pending_extras.clear()

	if primary != null:
		_launch_ball(primary)

	# Fire the extras from just above the one-way gate, a few frames apart, and
	# slightly right of the spawn so they do not rub the lane wall.
	for i in range(extras.size()):
		await get_tree().create_timer(0.08 * (i + 1)).timeout
		var ball = extras[i]
		if is_instance_valid(ball):
			_launch_ball(ball, Vector2(10.0, -80.0))


func _launch_ball(ball: RigidBody2D, offset: Vector2 = Vector2.ZERO) -> void:
	ball.global_position = spawn.global_position + offset
	ball.tree_exited.connect(GameStats.ball_drained, CONNECT_ONE_SHOT)
	ball.freeze = false
	ball.sleeping = false
	ball.collision_layer = _waiting_layer
	ball.collision_mask = _waiting_mask
	# The spring sets the timing; how hard it throws is still the power meter.
	ball.linear_velocity = Vector2.UP * lerpf(min_speed, max_speed, _pending_power) \
		* GameStats.speed_multiplier
	_watch_ball(ball)


# Safety net: if a launched ball is still in the narrow launch lane after a
# moment, move it into the playfield so no ball can stay stuck in the track.
func _watch_ball(ball: RigidBody2D) -> void:
	await get_tree().create_timer(0.8, true).timeout
	if not is_instance_valid(ball) or ball.freeze:
		return

	if ball.global_position.x < 230.0 and ball.global_position.y > 250.0:
		ball.global_position = Vector2(320.0, 320.0)
		ball.linear_velocity = Vector2(250.0, 300.0)


# Extra balls for the MULTIBALL upgrade. They stack below the first one and are
# released at the same moment, so they never start wedged in the one-way gate.
func _make_pending_ball(stack_index: int) -> RigidBody2D:
	var ball = ball_scene.instantiate()
	ball.freeze = true
	ball.sleeping = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	get_parent().add_child(ball)
	ball.global_position = spawn.global_position + Vector2(0, EXTRA_BALL_OFFSET * stack_index)
	return ball


func arm() -> void:
	_can_launch = true
	_spawn_waiting_ball()
