extends Node

signal score_changed(new_score: int)
signal boss_health_changed(hp: int, max_hp: int)
signal balls_changed(left: int)

var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)

var boss_max_hp := 100
#PLACE HOLDER VALUE, WILL CHANGE DEPENDING ON LEVEL
var boss_hp := 100
var balls_left := 3


func reset() -> void:
	score = 0
	boss_hp = boss_max_hp
	balls_left = 3
	boss_health_changed.emit(boss_hp, boss_max_hp)
	balls_changed.emit(balls_left)


func add_score(amount: int) -> void:
	score += amount


func set_boss_health(value: int, maximum: int = -1) -> void:
	if maximum > 0:
		boss_max_hp = maximum
	boss_hp = clampi(value, 0, boss_max_hp)
	boss_health_changed.emit(boss_hp, boss_max_hp)


func set_balls(value: int) -> void:
	balls_left = maxi(0, value)
	balls_changed.emit(balls_left)
