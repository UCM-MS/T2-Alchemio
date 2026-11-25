extends Control
## Cursor-sized view of the exact item being carried, including bond orders.
const UI = preload("res://scripts/workspace_ui.gd")
const PADDING := 10.0
const MODEL_AREA := Vector2(160, 86)
var item: Dictionary
var points := {}
var radius: float
var background := UI.box(UI.CARD, UI.MINT, 14, 0, 2)

func _init(payload: Dictionary, positions: Dictionary, atom_radius: float) -> void:
	item = payload
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.shadow_color = Color(0, 0, 0, 0.45)
	background.shadow_size = 4
	background.shadow_offset = Vector2(0, 2)
	var bounds := Rect2(positions[item.atoms.keys()[0]], Vector2.ZERO)
	for id in item.atoms:
		bounds = bounds.expand(positions[id])
	bounds = bounds.grow(atom_radius)
	var factor := minf(0.62, minf(MODEL_AREA.x / bounds.size.x, MODEL_AREA.y / bounds.size.y))
	radius = atom_radius * factor
	size = bounds.size * factor + Vector2.ONE * PADDING * 2
	if item.atoms.size() > 1:
		size.y += 22
		size.x = maxf(size.x, UI.FONT.get_string_size(item.formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 2 * PADDING)
	var origin := Vector2((size.x - bounds.size.x * factor) * 0.5, PADDING)
	for id in item.atoms:
		points[id] = origin + (Vector2(positions[id]) - bounds.position) * factor

func _draw() -> void:
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	for bond in item.bonds.values():
		var a: Vector2 = points[bond.a]
		var b: Vector2 = points[bond.b]
		var normal := (b - a).normalized().orthogonal()
		var order: int = bond.order
		for line in order:
			var shift := normal * (line - (order - 1) * 0.5) * minf(3.2, radius * 0.34)
			draw_line(a + shift, b + shift, UI.MUTED, 1.6, true)
	for id in points:
		var symbol: String = item.atoms[id].element
		var center: Vector2 = points[id]
		var color := UI.tint(symbol)
		draw_circle(center, radius, UI.pigment(symbol), true, -1, true)
		draw_arc(center, radius, 0, TAU, 40, color, 1.5, true)
		var font_size := maxi(8, roundi(radius * 1.1))
		var baseline := center.y + (UI.FONT.get_ascent(font_size) - UI.FONT.get_descent(font_size)) / 2
		draw_string(UI.FONT, Vector2(center.x - radius, baseline), symbol, HORIZONTAL_ALIGNMENT_CENTER, 2 * radius, font_size, color)
	if item.atoms.size() > 1:
		draw_string(UI.FONT, Vector2(0, size.y - PADDING), item.formula, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, UI.TEXT)
