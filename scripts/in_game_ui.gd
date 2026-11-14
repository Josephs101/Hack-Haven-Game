extends Control

@onready var score_value: Label = %ScoreValue
@onready var boss_bar: ProgressBar = %BossBar
@onready var balls_value: Label = %BallsValue


func _ready() -> void:
	GameStats.score_changed.connect(_on_score_changed)
	GameStats.boss_health_changed.connect(_on_boss_health_changed)
	GameStats.balls_changed.connect(_on_balls_changed)

	_on_score_changed(GameStats.score)
	_on_boss_health_changed(GameStats.boss_hp, GameStats.boss_max_hp)
	_on_balls_changed(GameStats.balls_left)


func _on_score_changed(value: int) -> void:
	score_value.text = str(value)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = hp


func _on_balls_changed(left: int) -> void:
	balls_value.text = str(left)
