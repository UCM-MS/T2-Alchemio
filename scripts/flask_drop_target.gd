extends Control
signal portion_dropped(id: String)
var inventory: RefCounted
var highlighted := false

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var accepted: bool = data is Dictionary and data.get("type") == "laboratory_portion" and data.get("inventory") == inventory and inventory.stock.get(data.get("id"), 0) > 0
	if highlighted != accepted:
		highlighted = accepted
		queue_redraw()
	return accepted

func _drop_data(position: Vector2, data: Variant) -> void:
	if _can_drop_data(position, data):
		portion_dropped.emit(data.id)
	highlighted = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		highlighted = false
		queue_redraw()
