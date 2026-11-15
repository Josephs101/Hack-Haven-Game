extends Node

signal score_changed(new_score: int)
signal combo_changed(combo: int, multiplier: float)
signal boss_health_changed(hp: int, max_hp: int)
signal boss_name_changed(new_name: String)
signal balls_changed(left: int)
signal rounds_changed(left: int)
signal ball_set_finished(damage_dealt: int, boss_hp: int)
signal boss_defeated
signal boss_visual_changed(frames_path: String)
signal upgrades_changed

const BASE_HIT_POINTS := 10
const MULTIPLIER_PER_COMBO := 0.1
const POINTS_PER_DAMAGE := 10
const COMBO_WINDOW := 2.0

# Boss HP grows by this fraction of its base value every time the level list
# wraps back around to the first boss. Set to 0.0 for identical repeat runs.
const LOOP_HP_GROWTH := 0.25

# Add new levels here. No scoring code needs to change.
# "boss_frames" is optional: a SpriteFrames resource that replaces the boss art
# baked into InGameUI.tscn. Leave it out to keep the default slime.
const LEVELS := {
	1: {"name": "john bounceback slime", "max_hp": 10, "balls": 3, "rounds": 1},
	2: {
		"name": "basketclops",
		"max_hp": 150,
		"balls": 3,
		"rounds": 2,
		"boss_frames": "res://assets/sprites/cyclops_frames.tres",
	},
	# TODO: drop the third boss sheet into assets/sprites, copy
	# cyclops_frames.tres for it and point "boss_frames" at the copy.
	3: {"name": "john bounceback slime jr.", "max_hp": 200, "balls": 4, "rounds": 2},
}

# Upgrade catalogue. "icon" is the PNG you drop into assets/icons/.
# "color" is used as a fallback if the icon file is missing.
const UPGRADES := {
	"extra_ball": {
		"name": "EXTRA BALL",
		"desc": "+1 ball every round",
		"icon": "res://assets/icons/extra_ball.png",
		"color": Color(0.35, 0.8, 1.0),
	},
	"heavy_bones": {
		"name": "HEAVY BONES",
		"desc": "+50% boss damage",
		"icon": "res://assets/sprites/heavy_bones.png",
	},
	"low_gravity": {
		"name": "LOW GRAVITY",
		"desc": "Balls fall slower",
		"icon": "res://assets/sprites/low_gravity.png",
		"color": Color(0.6, 0.5, 1.0),
	},
	"ultraspeed": {
		"name": "ULTRASPEED",
		"desc": "+50% launch speed",
		"icon": "res://assets/icons/ultraspeed.png",
		"color": Color(1.0, 0.85, 0.2),
	},
	"multiball": {
		"name": "MULTIBALL",
		"desc": "+1 ball per launch",
		"icon": "res://assets/icons/multiball.png",
		"color": Color(1.0, 0.4, 0.7),
	},
}

var current_level := 1
var loop_index := 0
var balls_per_set := 3
var rounds_per_boss := 1
var rounds_left := 1
var boss_frames_path := ""

var score := 0
var combo := 0
var multiplier := 1.0

var boss_name := "john bounceback slime"
var boss_max_hp := 100
var boss_hp := 100

var balls_left := 3
var active_balls := 0
var pending_points := 0
var level_damage := 0
var upgrades: Array[Dictionary] = []

# Run-wide modifiers applied by upgrades.
var extra_balls := 0
var damage_multiplier := 1.0
var gravity_multiplier := 1.0
var speed_multiplier := 1.0
var multiball_enabled := false

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
	loop_index = 0
	_reset_upgrades()
	start_level(level_number)


# Call this when moving to the next level/boss.
# Score and damage reset at the start of each level.
func start_level(level_number: int) -> void:
	var level := wrap_level(level_number)
	var data: Dictionary = LEVELS[level]

	current_level = level
	balls_per_set = int(data["balls"])
	rounds_per_boss = int(data.get("rounds", 1))
	rounds_left = rounds_per_boss

	score = 0
	pending_points = 0
	level_damage = 0

	boss_name = str(data["name"])
	boss_max_hp = _scaled_hp(int(data["max_hp"]))
	boss_hp = boss_max_hp
	boss_frames_path = str(data.get("boss_frames", ""))
	_boss_down_emitted = false

	start_ball_set()

	boss_name_changed.emit(boss_name)
	boss_visual_changed.emit(boss_frames_path)
	boss_health_changed.emit(boss_hp, boss_max_hp)
	rounds_changed.emit(rounds_left)


func start_ball_set() -> void:
	balls_left = balls_per_set + extra_balls
	active_balls = 0
	combo = 0
	multiplier = 1.0
	_combo_time = 0.0

	score_changed.emit(score)
	combo_changed.emit(combo, multiplier)
	balls_changed.emit(balls_left)


# Returns every level number in play order (1, 2, 3, ...).
func level_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for key in LEVELS.keys():
		numbers.append(int(key))
	numbers.sort()
	return numbers


func first_level() -> int:
	return level_numbers()[0]


func last_level() -> int:
	var numbers := level_numbers()
	return numbers[numbers.size() - 1]


# Folds any number into the defined levels: after the last boss it wraps back
# to the first (4 -> 1, 5 -> 2, ...). Pure: it never changes loop_index.
func wrap_level(level_number: int) -> int:
	var numbers := level_numbers()

	if numbers.has(level_number):
		return level_number

	return numbers[posmod(level_number - numbers[0], numbers.size())]


# Called when a boss is beaten and the upgrade has been picked.
# Returns the level that should be loaded next, wrapping past the last boss.
func advance_level() -> int:
	var next := current_level + 1

	if next > last_level():
		next = first_level()
		loop_index += 1

	current_level = next
	return next


func _scaled_hp(base_hp: int) -> int:
	return int(round(float(base_hp) * (1.0 + LOOP_HP_GROWTH * float(loop_index))))


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
	var total_damage := int(round(pending_points / float(POINTS_PER_DAMAGE) * damage_multiplier))
	var damage_this_set := total_damage - level_damage
	level_damage = total_damage

	break_combo()

	if damage_this_set > 0:
		set_boss_health(boss_hp - damage_this_set, boss_max_hp)

	ball_set_finished.emit(level_damage, boss_hp)


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


func apply_upgrade(id: String) -> void:
	if not UPGRADES.has(id):
		return

	var data: Dictionary = UPGRADES[id].duplicate()
	data["id"] = id
	upgrades.append(data)

	match id:
		"extra_ball":
			extra_balls += 1
		"heavy_bones":
			damage_multiplier += 0.5
		"low_gravity":
			gravity_multiplier = 0.5
		"ultraspeed":
			speed_multiplier += 0.2
		"multiball":
			multiball_enabled = true

	upgrades_changed.emit()


func has_upgrade(id: String) -> bool:
	for u in upgrades:
		if u.get("id", "") == id:
			return true
	return false


func get_upgrades() -> Array[Dictionary]:
	return upgrades


func _reset_upgrades() -> void:
	upgrades.clear()
	extra_balls = 0
	damage_multiplier = 1.0
	gravity_multiplier = 1.0
	speed_multiplier = 1.0
	multiball_enabled = false
	upgrades_changed.emit()
