extends Node2D

# Dotted preview of the ball's launch path, drawn in the launcher's local space.

var points: PackedVector2Array = []
var dot_radius := 3.5
var dot_color := Color(1.0, 1.0, 1.0, 0.6)


func set_path(path: PackedVector2Array) -> void:
	points = path
	queue_redraw()


func _draw() -> void:
	var count := points.size()
	if count == 0:
		return

	var denominator := float(maxi(1, count - 1))
	for i in range(count):
		var t := float(i) / denominator
		var color := dot_color
		color.a *= 1.0 - t * 0.65
		draw_circle(points[i], dot_radius, color)
