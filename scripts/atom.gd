extends Node2D
## A collectible particle in the world or the collection bag.
const RADIUS := 17.0
const FONT = preload("res://assets/fonts/NotoSans.ttf")
var atom_id: int
var element_id: String
var tint: Color
var relative_mass: float
var velocity := Vector2.ZERO
var suction_cooldown := 0.0

func configure(id: int, element: Dictionary) -> void:
	atom_id = id
	element_id = element["id"]
	tint = Color(element["color"])
	relative_mass = float(element["relative_atomic_mass"])
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 3), RADIUS + 3, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, RADIUS, tint.darkened(0.78))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 40, tint, 1.5, true)
	var width := FONT.get_string_size(element_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(FONT, Vector2(-width / 2, 6), element_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)
