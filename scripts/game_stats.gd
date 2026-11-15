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

# Fired whenever the ball touches a peg, with the combo after that hit. Used
# for the impact-frame effect; bumpers and flippers deliberately don't emit it.
signal peg_hit(combo: int)

const BASE_HIT_POINTS := 10
const MULTIPLIER_PER_COMBO := 0.1
const POINTS_PER_DAMAGE := 10
const COMBO_WINDOW := 2.0

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
	3: {
		"name": "john bounceback slime jr.",
		"max_hp": 200,
		"balls": 4,
		"rounds": 2,
		"boss_frames": "res://assets/sprites/mini_frames.tres",
	},
}

# --- Endless mode -----------------------------------------------------------
# Past the authored levels the game keeps going: the three bosses take turns
# again and again, each lap hits harder, and every layout is generated.
const ENDLESS_FIRST_LEVEL := 4
const ENDLESS_BASE_HP := 220.0
const ENDLESS_HP_GROWTH := 1.18

const ENDLESS_BOSSES := [
	{"name": "john bounceback slime", "frames": ""},
	{"name": "basketclops", "frames": "res://assets/sprites/cyclops_frames.tres"},
	{"name": "john bounceback slime jr.", "frames": "res://assets/sprites/mini_frames.tres"},
]

# Best run ever, and how many bosses the current run has cleared. The record is
# saved to disk so the title screen can show it after the game closes.
const SAVE_PATH := "user://hack_haven_save.cfg"

signal best_bosses_changed(best: int)

# Upgrade catalogue. "icon" is the PNG you drop into assets/icons/.
# "color" is used as a fallback if the icon file is missing.
const UPGRADES := {
	"extra_ball": {
		"name": "EXTRA BALL",
		"desc": "+1 ball every round",
		"icon": "res://assets/sprites/extra_ball.png",
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
	},
	"ultraspeed": {
		"name": "ULTRASPEED",
		"desc": "+50% launch speed",
		"icon": "res://assets/sprites/ultraspeed.png",
	},
	"multiball": {
		"name": "MULTIBALL",
		"desc": "+1 ball per launch",
		"icon": "res://assets/sprites/extra_ball.png",
	},
}

var current_level := 1
var balls_per_set := 3
var rounds_per_boss := 1
var rounds_left := 1
var boss_frames_path := ""

var bosses_beaten := 0
var best_bosses := 0

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
var multiball_extra := 0

var _combo_time := 0.0
var _boss_down_emitted := false


func _ready() -> void:
	_load_progress()
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
	bosses_beaten = 0
	_reset_upgrades()
	start_level(level_number)


# Call this when moving to the next level/boss.
# Score and damage reset at the start of each level.
func start_level(level_number: int) -> void:
	var level := maxi(1, level_number)
	var data: Dictionary = level_data(level)

	current_level = level
	balls_per_set = int(data["balls"])
	rounds_per_boss = int(data.get("rounds", 1))
	rounds_left = rounds_per_boss

	score = 0
	pending_points = 0
	level_damage = 0

	boss_name = str(data["name"])
	boss_max_hp = int(data["max_hp"])
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


# Stats for any level number. Levels 1-3 are hand authored; everything past
# that is generated and gets tougher every time the boss list comes round again.
func level_data(level_number: int) -> Dictionary:
	if LEVELS.has(level_number):
		return LEVELS[level_number]

	var index := level_number - ENDLESS_FIRST_LEVEL
	var boss: Dictionary = ENDLESS_BOSSES[index % ENDLESS_BOSSES.size()]
	var lap := index / ENDLESS_BOSSES.size()

	return {
		"name": "%s mk %d" % [boss["name"], lap + 2],
		"max_hp": int(round(ENDLESS_BASE_HP * pow(ENDLESS_HP_GROWTH, lap))),
		"balls": 4,
		"rounds": 2,
		"boss_frames": boss["frames"],
		"generated": true,
	}


func is_generated_level(level_number: int) -> bool:
	return level_number >= ENDLESS_FIRST_LEVEL


# Called when a boss is beaten and the upgrade has been picked.
# Returns the level that should be loaded next. Endless mode never wraps: the
# level number just keeps climbing.
func advance_level() -> int:
	current_level += 1
	return current_level


# Restart the run from the first boss. Only the title screen calls this; the
# in-game restarts call start_run(1) directly.
func reset() -> void:
	start_run(1)


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
	# Once the boss is down the level is already resolved, so a ball still
	# rolling around must not end the round a second time.
	if boss_hp <= 0 and _boss_down_emitted:
		return

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
		_record_boss_beaten()


# One more boss down for this run; a new personal best is written straight to
# disk so it survives the game closing.
func _record_boss_beaten() -> void:
	bosses_beaten += 1

	if bosses_beaten <= best_bosses:
		return

	best_bosses = bosses_beaten
	best_bosses_changed.emit(best_bosses)
	save_progress()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_bosses", best_bosses)
	config.save(SAVE_PATH)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	best_bosses = int(config.get_value("progress", "best_bosses", 0))


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
			multiball_extra += 1

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
	multiball_extra = 0
	upgrades_changed.emit()
