extends ColorRect

## Impact frame on high combos: a one-beat white flash plus a very short
## hitstop, played whenever a peg is hit while the combo is high enough.
##
## Added to the UI layer of every level by level_screen.gd, so it sits still
## while the camera shakes and zooms underneath it.

@export var combo_threshold := 12
@export var flash_alpha := 0.28
@export var flash_time := 0.07
@export var hitstop_time := 0.025
## Shortest real gap between two impact frames, so a burst of peg hits cannot
## freeze the game over and over.
@export var min_interval := 0.25

var _tween: Tween = null
var _stopping := false
var _last_impact := -1000.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 1.0, 0.0)

	GameStats.peg_hit.connect(_on_peg_hit)


func _exit_tree() -> void:
	# Never leave the game stuck in slow motion if the level changes mid-hitstop.
	Engine.time_scale = 1.0


func _on_peg_hit(combo: int) -> void:
	if combo < combo_threshold:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_impact < min_interval:
		return

	_last_impact = now
	_flash()
	_hitstop()


func _flash() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	color.a = flash_alpha

	_tween = create_tween()
	# The flash has to fade in real time, or the hitstop that follows would
	# stretch it out into a long white screen.
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(self, "color:a", 0.0, flash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hitstop() -> void:
	if _stopping:
		return

	_stopping = true
	Engine.time_scale = 0.05

	await get_tree().create_timer(hitstop_time, true, false, true).timeout

	Engine.time_scale = 1.0
	_stopping = false
