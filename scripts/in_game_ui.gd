extends Control

@onready var score_value: Label = %ScoreValue
@onready var boss_bar: ProgressBar = %BossBar
@onready var balls_value: Label = %BallsValue
@onready var boss_value: Label = %BossHealthLabel
@onready var boss_sprite: AnimatedSprite2D = %AnimatedSprite2D
@export var min_jump_interval: float = 2.0
@export var max_jump_interval: float = 5.0

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	GameStats.score_changed.connect(_on_score_changed)
	GameStats.boss_health_changed.connect(_on_boss_health_changed)
	GameStats.balls_changed.connect(_on_balls_changed)

	_on_score_changed(GameStats.score)
	_on_boss_health_changed(GameStats.boss_hp, GameStats.boss_max_hp)
	_on_balls_changed(GameStats.balls_left)
	
	rng.randomize()
	boss_sprite.animation_finished.connect(_on_boss_animation_finished)
	boss_sprite.play("idle")
	_schedule_boss_jump()


func _on_score_changed(value: int) -> void:
	score_value.text = str(value)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = hp
	boss_value.text = "%d / %d" % [hp, max_hp]

func _on_balls_changed(left: int) -> void:
	balls_value.text = str(left)
	
func _schedule_boss_jump() -> void:
	var wait_time = rng.randf_range(
		min_jump_interval,
		max_jump_interval
	)

	await get_tree().create_timer(wait_time).timeout

	boss_sprite.play("bouncy")


func _on_boss_animation_finished() -> void:
	if boss_sprite.animation == "bouncy":
		boss_sprite.play("idle")
		_schedule_boss_jump()
