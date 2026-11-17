extends StaticBody2D

## A peg that changes colour every time the ball hits it. Once it has cycled
## through every colour in rainbow_pins.png the peg breaks: the sprite fades
## out and the hitbox is switched off, so the ball flies through the gap it
## used to fill.
##
## Only the sprite is ever animated, never the collision shape, so a jiggling
## peg never changes how the ball bounces off it.

@export var pop_scale := 1.28
@export var wobble_degrees := 12.0
@export var pop_time := 0.07
@export var settle_time := 0.22

## Size of one colour cell inside rainbow_pins.png.
@export var frame_size := Vector2(16, 16)
## How many colours the sheet holds. The peg breaks after this many hits plus
## GameStats.peg_extra_hits, which endless levels raise.
@export var colour_count := 8

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var _base_scale := Vector2.ONE
var _tween: Tween = null
var _colour := 0
var _broken := false
var _max_hits := 8


func _ready() -> void:
	_max_hits = colour_count + GameStats.peg_extra_hits
	_base_scale = sprite.scale
	sprite.region_enabled = true
	_apply_colour()


# Called by the ball on every contact: step to the next colour, or break once
# the last one has been used.
func hit() -> void:
	if _broken:
		return

	_colour += 1
	GameStats.peg_hit.emit(GameStats.combo)

	if _colour >= _max_hits:
		_break()
		return

	_apply_colour()
	jiggle()


func is_broken() -> bool:
	return _broken


func _apply_colour() -> void:
	var frame := _colour % maxi(1, colour_count)
	sprite.region_rect = Rect2(Vector2(frame, 0) * frame_size, frame_size)


func _break() -> void:
	_broken = true

	# This runs inside a body_entered callback, so physics changes are deferred.
	remove_from_group(&"scoreable")
	shape.set_deferred("disabled", true)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Quick pop-and-fade so the break reads as a hit rather than a glitch.
	sprite.rotation = 0.0

	var tween := create_tween()
	tween.tween_property(sprite, "scale", _base_scale * 1.5, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.14)
	tween.tween_callback(sprite.hide)


func jiggle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	sprite.scale = _base_scale
	sprite.rotation = 0.0

	var wobble := deg_to_rad(wobble_degrees)

	_tween = create_tween()
	_tween.tween_property(sprite, "scale", _base_scale * pop_scale, pop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(sprite, "rotation", wobble, pop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.chain().tween_property(sprite, "scale", _base_scale, settle_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(sprite, "rotation", 0.0, settle_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
