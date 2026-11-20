extends Button
var substance_id: String
var formula: String
var inventory: RefCounted

func _get_drag_data(_position: Vector2) -> Variant:
	if inventory.stock.get(substance_id, 0) <= 0:
		return null
	var preview := Label.new()
	preview.text = "  %s · 1 porcia  " % formula
	preview.add_theme_font_size_override("font_size", 24)
	preview.modulate = Color("8fe4d3")
	set_drag_preview(preview)
	return {"type": "laboratory_portion", "id": substance_id, "inventory": inventory}
