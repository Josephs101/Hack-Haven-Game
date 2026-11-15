extends Camera2D

## Screen shake and a gentle zoom that both react to the combo counter.
##
## Created by level_screen.gd at runtime, so the shared LevelScreen scene does
## not need a camera node. Tuning lives in level_screen.gd's "Screen Effects"
## group, which overrides the defaults below.

var shake_threshold := 8
var max_offset := 4.5
var trauma_decay := 2.4
var zoom_per_combo := 0.0045
var max_extra_zoom := 0.05
var zoom_speed := 6.0

var _trauma := 0.0
var _target_zoom := 1.0
var _clock := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	# Centre on the playfield and keep the same framing the game had before a
	# camera existed, so nothing shifts when this is added.
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = get_viewport_rect().size * 0.5

	_noise.frequency = 0.05
	_noise.fractal_octaves = 2

	make_current()
	GameStats.combo_changed.connect(_on_combo_changed)


func _process(delta: float) -> void:
	_clock += delta

	# Trauma decays on its own, so the shake eases out when the combo breaks.
	# Squaring it makes the falloff feel snappier than a linear ramp.
	_trauma = maxf(0.0, _trauma - trauma_decay * delta)
	var strength := _trauma * _trauma

	offset = Vector2(
		_noise.get_noise_2d(_clock * 200.0, 0.0),
		_noise.get_noise_2d(0.0, _clock * 200.0)
	) * max_offset * strength

	var weight := 1.0 - exp(-zoom_speed * delta)
	zoom = zoom.lerp(Vector2.ONE * _target_zoom, weight)


func _on_combo_changed(combo: int, _multiplier: float) -> void:
	if combo >= shake_threshold:
		var over := float(combo - shake_threshold + 1)
		_trauma = minf(1.0, _trauma + clampf(over * 0.12, 0.12, 0.4))

	if combo <= 0:
		_target_zoom = 1.0
	else:
		_target_zoom = 1.0 + minf(max_extra_zoom, float(combo) * zoom_per_combo)
