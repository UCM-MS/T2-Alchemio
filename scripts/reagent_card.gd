extends Button
const UI = preload("res://scripts/workspace_ui.gd")
var substance_id: String
var formula: String
var inventory: RefCounted

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or inventory == null or inventory.stock.get(substance_id, 0) <= 0:
		return null
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.MINT, 12, 8, 2))
	var row := UI.row(preview, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.badge(row, formula, 40)
	UI.label(row, "1 porcia", 15, UI.TEXT)
	set_drag_preview(preview)
	return {"type": "laboratory_portion", "id": substance_id, "inventory": inventory}
