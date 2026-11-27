extends Node2D

const RADIUS := 16.0
var velocity := Vector2.ZERO

func _draw() -> void:
	var tail := -velocity.normalized()
	draw_line(tail * 36.0, tail * 12.0, Color(0.53, 0.61, 0.67, 0.3), 3.0, true)
	draw_circle(Vector2(1, 2), RADIUS + 2.0, Color("0a1019"), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS, Color("080b10"), true, -1.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color("657585"), 1.6, true)
	draw_arc(Vector2.ZERO, RADIUS - 4.0, PI * 1.12, PI * 1.65, 18, Color("3d4a56"), 2.4, true)
