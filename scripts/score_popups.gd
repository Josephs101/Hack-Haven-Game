extends Control

## Floating "+N" popups for every score gain.
##
## The amount comes from watching GameStats.score rather than from the hit
## itself, so it always matches what the score counter actually gained — even
## when one contact scores through more than one path. Positions come from the
## ball as it hits something; gains that arrive without one fall back to a spot
## under the score readout.

const FONT := preload("res://assets/font(s)/Minecraft.ttf")

const POPUP_COLOR := Color(1.0, 0.9, 0.35, 1.0)
const OUTLINE_COLOR := Color(0.12, 0.07, 0.01, 1.0)
const FALLBACK_POSITION := Vector2(536.0, 150.0)

@export var rise := 46.0
@export var lifetime := 0.75
@export var font_size := 26
@export var max_popups := 24

var _last_score := 0
var _pending := 0
var _pending_position := FALLBACK_POSITION
var _has_position := false
var _active := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_last_score = GameStats.score

	GameStats.score_changed.connect(_on_score_changed)
	GameStats.points_awarded.connect(_on_points_awarded)


func _on_points_awarded(_amount: int, world_position: Vector2) -> void:
	_pending_position = world_position
	_has_position = true


func _on_score_changed(new_score: int) -> void:
	# The level resets the score; that is not a gain.
	if new_score < _last_score:
		_last_score = new_score
		return

	_pending += new_score - _last_score
	_last_score = new_score


# Flush once per frame, so several scoring paths for one contact become a
# single popup with the correct total.
func _process(_delta: float) -> void:
	if _pending <= 0:
		return

	var amount := _pending
	_pending = 0

	var position := _pending_position if _has_position else FALLBACK_POSITION
	_has_position = false

	_spawn(amount, position)


func _spawn(amount: int, world_position: Vector2) -> void:
	if _active >= max_popups:
		return

	var screen_position: Vector2 = get_viewport().get_canvas_transform() * world_position

	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", POPUP_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text_size := label.get_theme_font("font").get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	label.size = text_size
	label.position = screen_position - Vector2(text_size.x * 0.5, text_size.y)

	add_child(label)
	_active += 1

	# Rise and fade, then clean up.
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - rise, lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, lifetime * 0.5) \
		.set_delay(lifetime * 0.5)
	tween.chain().tween_callback(_release.bind(label))


func _release(label: Label) -> void:
	_active = maxi(0, _active - 1)

	if is_instance_valid(label):
		label.queue_free()
