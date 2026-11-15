extends Node2D

@export var ball_scene: PackedScene = preload("res://scenes/gameplay/PinBall.tscn")
@export var min_speed := 1700.0
@export var max_speed := 3200.0
@export var charge_speed := 1.2
@export var launch_action := "launch"

@onready var meter: PowerMeter = $PowerMeter
@onready var spawn: Marker2D = $BallSpawn
@onready var anim: AnimatedSprite2D = $Spring

var _waiting_ball: RigidBody2D = null
var _waiting_layer := 1
var _waiting_mask := 1
var _charging := false
var _charge_time := 0.0
var _power := 0.0
var _can_launch := true
var _pending_ball: RigidBody2D = null
var _pending_power := 0.0
var _spring_tops: Array[float] = []
var _release_frame := 14

func _ready() -> void:
	anim.frame_changed.connect(_on_spring_frame_changed)
	GameStats.balls_changed.connect(_on_balls_changed)
	_build_spring_profile()
	_spawn_waiting_ball()


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
	if not _can_launch or _waiting_ball == null or GameStats.balls_left <= 0:
		return

	if Input.is_action_just_pressed(launch_action):
		if _charging:
			_confirm_launch()
		else:
			_start_charge()

	if _charging:
		_charge_time += delta
		var cycle := fmod(_charge_time * charge_speed, 2.0)
		_power = cycle if cycle <= 1.0 else 2.0 - cycle
		meter.set_power(_power)


func _start_charge() -> void:
	_charging = true
	_charge_time = 0.0
	_power = 0.0
	meter.set_power(0.0)


func _confirm_launch() -> void:
	if _waiting_ball == null:
		return

	_charging = false

	if not GameStats.use_ball():
		return

	_can_launch = false

	_pending_ball = _waiting_ball
	_waiting_ball = null
	_pending_power = _power

	anim.play("launch")

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

	_pending_ball.global_position = spawn.global_position + Vector2.DOWN * dip


func _launch_pending_ball() -> void:
	var ball := _pending_ball
	_pending_ball = null

	ball.tree_exited.connect(GameStats.ball_drained, CONNECT_ONE_SHOT)

	ball.freeze = false
	ball.sleeping = false
	ball.collision_layer = _waiting_layer
	ball.collision_mask = _waiting_mask
	# The spring sets the timing; how hard it throws is still the power meter.
	ball.linear_velocity = Vector2.UP * lerpf(min_speed, max_speed, _pending_power)


func arm() -> void:
	_can_launch = true
	_spawn_waiting_ball()
