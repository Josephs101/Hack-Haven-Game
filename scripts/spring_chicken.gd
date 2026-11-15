extends Node2D

## Menu mascot: sits in its idle loop, springs up now and then, and settles
## back. The SpringChicken scene ships both animations but nothing ever played
## the "Spring" one, so this drives them in a loop.

@export var idle_time := 1.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _timer: Timer = null


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_idle_finished)
	add_child(_timer)

	sprite.animation_finished.connect(_on_animation_finished)

	_start_idle()


func _start_idle() -> void:
	if not sprite.sprite_frames.has_animation(&"idle"):
		return

	sprite.play(&"idle")
	_timer.start(idle_time)


func _on_idle_finished() -> void:
	if sprite.sprite_frames.has_animation(&"Spring"):
		sprite.play(&"Spring")
	else:
		_start_idle()


func _on_animation_finished() -> void:
	# "Spring" is a one-shot; go back to idling when it lands.
	if sprite.animation == &"Spring":
		_start_idle()
