class_name PowerMeter
extends Control

@export var low_color := Color("00FF00")
@export var high_color := Color("FF0000")

var power := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size == Vector2(44, 300)

func set_power(value: float) -> void:
	power = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_rect(outer, Color(0.03, 0.04, 0.07, 0.9))

	var inner := outer.grow(-4.0)
	var steps := 32
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var color := low_color.lerp(high_color, t)
		var y := inner.end.y - inner.size.y * t
		draw_rect(
			Rect2(inner.position.x, y, inner.size.x, inner.size.y / float(steps) + 1.0),
			color
		)

	var pointer_y := inner.position.y + inner.size.y * (1.0 - power)
	draw_line(
		Vector2(inner.position.x - 8.0, pointer_y),
		Vector2(inner.end.x + 8.0, pointer_y),
		Color.WHITE,
		3.0
	)

	draw_rect(outer, Color(0.5, 0.55, 0.7, 0.8), false, 2.0)
