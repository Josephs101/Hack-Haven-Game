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
var _pending_extra: RigidBody2D = null
var _pending_power := 0.0

func _ready() -> void:
	anim.frame_changed.connect(_on_spring_frame_changed)
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

	_pending_extra = null
	if GameStats.multiball_enabled:
		_pending_extra = _make_pending_ball()
		GameStats.active_balls += 1

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
	if anim.frame < 14:
		return
	
	_launch_pending_ball()
	
func _launch_pending_ball() -> void:
	var balls: Array[RigidBody2D] = []
	if _pending_ball != null:
		balls.append(_pending_ball)
		_pending_ball = null
	if _pending_extra != null:
		balls.append(_pending_extra)
		_pending_extra = null

	for ball in balls:
		ball.tree_exited.connect(GameStats.ball_drained, CONNECT_ONE_SHOT)
		ball.freeze = false
		ball.sleeping = false
		ball.collision_layer = _waiting_layer
		ball.collision_mask = _waiting_mask
		ball.linear_velocity = Vector2.UP * lerpf(min_speed, max_speed, _pending_power) * GameStats.speed_multiplier


func _make_pending_ball() -> RigidBody2D:
	var ball = ball_scene.instantiate()
	ball.freeze = true
	ball.sleeping = true
	ball.collision_layer = 0
	ball.collision_mask = 0
	get_parent().add_child(ball)
	ball.global_position = spawn.global_position
	return ball


func arm() -> void:
	_can_launch = true
	_spawn_waiting_ball()
