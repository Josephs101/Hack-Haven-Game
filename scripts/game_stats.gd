extends Node

signal score_changed(new_score: int)
signal combo_changed(combo: int, multiplier: float)
signal boss_health_changed(hp: int, max_hp: int)
signal boss_name_changed(new_name: String)
signal balls_changed(left: int)
signal rounds_changed(left: int)
signal ball_set_finished(damage_dealt: int, boss_hp: int)
signal boss_defeated

const BASE_HIT_POINTS := 10
const MULTIPLIER_PER_COMBO := 0.1
const POINTS_PER_DAMAGE := 10
const COMBO_WINDOW := 2.0

# Add new levels here. No scoring code needs to change.
const LEVELS := {
	1: {"name": "john bounceback slime", "max_hp": 10, "balls": 3, "rounds": 1},
	2: {"name": "basketclops", "max_hp": 150, "balls": 3, "rounds": 2},
	3: {"name": "john bounceback slime jr.", "max_hp": 200, "balls": 4, "rounds": 2},
}

var current_level := 1
var balls_per_set := 3
var rounds_per_boss := 1
var rounds_left := 1

var score := 0
var combo := 0
var multiplier := 1.0

var boss_name := "john bounceback slime"
var boss_max_hp := 100
var boss_hp := 100

var balls_left := 3
var active_balls := 0
var pending_points := 0
var upgrades: Array[Dictionary] = []

var _combo_time := 0.0
var _boss_down_emitted := false


func _ready() -> void:
	start_run(1)


func _process(delta: float) -> void:
	if combo <= 0:
		return

	_combo_time -= delta
	if _combo_time <= 0.0:
		break_combo()


# Call this when starting a brand-new run.
func start_run(level_number: int = 1) -> void:
	score = 0
	start_level(level_number)


# Call this when moving to the next level/boss.
# Score is preserved between levels.
func start_level(level_number: int) -> void:
	var data: Dictionary = LEVELS.get(level_number, LEVELS[1])

	current_level = level_number
	balls_per_set = int(data["balls"])
	rounds_per_boss = int(data.get("rounds", 1))
	rounds_left = rounds_per_boss

	boss_name = str(data["name"])
	boss_max_hp = int(data["max_hp"])
	boss_hp = boss_max_hp
	_boss_down_emitted = false

	start_ball_set()

	boss_name_changed.emit(boss_name)
	boss_health_changed.emit(boss_hp, boss_max_hp)
	rounds_changed.emit(rounds_left)


func start_ball_set() -> void:
	balls_left = balls_per_set
	active_balls = 0
	pending_points = 0
	combo = 0
	multiplier = 1.0
	_combo_time = 0.0
	score = 0

	score_changed.emit(score)
	combo_changed.emit(combo, multiplier)
	balls_changed.emit(balls_left)


# Restart current level with a clean run score.
func reset() -> void:
	start_run(current_level)


func register_hit(base_points: int = BASE_HIT_POINTS) -> void:
	if boss_hp <= 0:
		return

	combo += 1
	multiplier = 1.0 + float(combo - 1) * MULTIPLIER_PER_COMBO
	_combo_time = COMBO_WINDOW

	var gained := int(round(float(base_points) * multiplier))
	score += gained
	pending_points += gained

	score_changed.emit(score)
	combo_changed.emit(combo, multiplier)


func use_ball() -> bool:
	if balls_left <= 0:
		return false

	set_balls(balls_left - 1)
	active_balls += 1
	return true


func ball_drained() -> void:
	active_balls = maxi(0, active_balls - 1)

	if balls_left <= 0 and active_balls == 0:
		finish_ball_set()


# Use one round. Returns true and starts a new ball set if a round remains.
func consume_round() -> bool:
	rounds_left -= 1
	rounds_changed.emit(rounds_left)

	if rounds_left > 0:
		start_ball_set()
		return true
	return false


func finish_ball_set() -> void:
	var damage := pending_points / POINTS_PER_DAMAGE
	pending_points = 0

	break_combo()

	if damage > 0:
		set_boss_health(boss_hp - damage, boss_max_hp)

	ball_set_finished.emit(damage, boss_hp)


func set_boss_health(value: int, maximum: int = -1) -> void:
	if maximum > 0:
		boss_max_hp = maximum

	boss_hp = clampi(value, 0, boss_max_hp)
	boss_health_changed.emit(boss_hp, boss_max_hp)

	if boss_hp <= 0 and not _boss_down_emitted:
		_boss_down_emitted = true
		boss_defeated.emit()


func break_combo() -> void:
	if combo == 0 and is_equal_approx(multiplier, 1.0):
		return

	combo = 0
	multiplier = 1.0
	_combo_time = 0.0
	combo_changed.emit(combo, multiplier)


func set_balls(value: int) -> void:
	balls_left = maxi(0, value)
	balls_changed.emit(balls_left)


func apply_upgrade(upgrade: Dictionary) -> void:
	upgrades.append(upgrade)
