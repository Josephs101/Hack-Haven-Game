extends StaticBody2D

## Squash-and-wobble played when the ball hits this peg.
##
## Only the sprite is animated, never the collision shape, so a jiggling peg
## never changes how the ball bounces off it.

@export var pop_scale := 1.28
@export var wobble_degrees := 12.0
@export var pop_time := 0.07
@export var settle_time := 0.22

@onready var sprite: Sprite2D = $Sprite2D

var _base_scale := Vector2.ONE
var _tween: Tween = null


func _ready() -> void:
	_base_scale = sprite.scale


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
