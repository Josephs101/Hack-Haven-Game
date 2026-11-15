extends Node2D

@export var ball_scene: PackedScene = preload("res://scenes/gameplay/PinBall.tscn")
@export var min_speed := 1700.0
@export var max_speed := 3200.0
@export var charge_speed := 1.2   # full up/down cycles per second
@export var launch_action := "launch"

@onready var meter: Control = $PowerMeter
@onready var spawn: Marker2D = $BallSpawn
@onready var anim: AnimatedSprite2D = $Spring

var _charging := false
var _charge_time := 0.0
var _power := 0.0
var _can_launch := true


func _process(delta: float) -> void:
	if not _can_launch or GameStats.balls_left <= 0:
		return

	if Input.is_action_just_pressed(launch_action):
		_charging = true
		_charge_time = 0.0
		_power = 0.0
		meter.set_power(0.0)

	if not _charging:
		return

	_charge_time += delta

	# 0 → 1 → 0 → 1 ...
	var cycle := fmod(_charge_time * charge_speed, 2.0)
	_power = cycle if cycle <= 1.0 else 2.0 - cycle
	meter.set_power(_power)

	if Input.is_action_just_released(launch_action):
		_release()


func _release() -> void:
	_charging = false
	_can_launch = false

	if not GameStats.use_ball():
		_can_launch = true
		return

	anim.play("launch")
	await anim.animation_finished

	_fire(_power)
	meter.set_power(0.0)


func _fire(power: float) -> void:
	var ball = ball_scene.instantiate()
	get_parent().add_child(ball)

	ball.global_position = spawn.global_position
	ball.linear_velocity = Vector2.UP * lerpf(min_speed, max_speed, power)

	ball.tree_exited.connect(_on_ball_gone)


func _on_ball_gone() -> void:
	_can_launch = true
