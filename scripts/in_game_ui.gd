extends Control

@onready var score_value: Label = %ScoreValue
@onready var boss_bar: ProgressBar = %BossBar
@onready var balls_value: Label = %BallsValue
@onready var rounds_value: Label = %RoundsValue
@onready var boss_value: Label = %BossHealthLabel
@onready var combo_value: Label = %ComboValue
@onready var boss_name_label: Label = %BossName

var _boss_tween: Tween = null


func _ready() -> void:
	GameStats.score_changed.connect(_on_score_changed)
	GameStats.combo_changed.connect(_on_combo_changed)
	GameStats.boss_health_changed.connect(_on_boss_health_changed)
	GameStats.boss_name_changed.connect(_on_boss_name_changed)
	GameStats.balls_changed.connect(_on_balls_changed)
	GameStats.rounds_changed.connect(_on_rounds_changed)

	boss_bar.max_value = GameStats.boss_max_hp
	boss_bar.value = GameStats.boss_hp
	boss_value.text = "%d / %d" % [GameStats.boss_hp, GameStats.boss_max_hp]

	_on_score_changed(GameStats.score)
	_on_combo_changed(GameStats.combo, GameStats.multiplier)
	_on_boss_name_changed(GameStats.boss_name)
	_on_balls_changed(GameStats.balls_left)
	_on_rounds_changed(GameStats.rounds_left)


func _on_combo_changed(value: int, mult: float) -> void:
	combo_value.text = "COMBO %d  x%.1f" % [value, mult]


func _on_boss_name_changed(value: String) -> void:
	boss_name_label.text = value


func _on_score_changed(value: int) -> void:
	score_value.text = str(value)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
	boss_bar.max_value = max_hp
	boss_value.text = "%d / %d" % [hp, max_hp]

	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()

	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_bar, "value", float(hp), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	boss_bar.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var flash := create_tween()
	flash.tween_property(boss_bar, "modulate", Color.WHITE, 0.35)


func _on_balls_changed(left: int) -> void:
	balls_value.text = str(left)


func _on_rounds_changed(left: int) -> void:
	rounds_value.text = str(left)
