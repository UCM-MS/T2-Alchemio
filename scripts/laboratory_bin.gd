extends "res://scripts/flask_drop_target.gd"

const UI = preload("res://scripts/workspace_ui.gd")

func _ready() -> void:
	custom_minimum_size.y = 48
	tooltip_text = "Potiahni sem kartu zo zásoby a zahodíš jednu porciu."
	var text := UI.label(self, "Zahodiť 1 porciu", 14)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 42
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _draw() -> void:
	var color := Color("#ffa39a") if highlighted else UI.MUTED
	draw_style_box(UI.box(Color("#503335") if highlighted else UI.CARD, color, 10, 0), Rect2(Vector2.ZERO, size))
	var origin := Vector2(14, size.y * 0.5 - 9)
	draw_set_transform(origin)
	draw_line(Vector2(0, 4), Vector2(19, 4), color, 2, true)
	draw_line(Vector2(6, 1), Vector2(13, 1), color, 2, true)
	draw_polyline(PackedVector2Array([Vector2(3, 6), Vector2(4, 18), Vector2(15, 18), Vector2(16, 6)]), color, 2, true)
