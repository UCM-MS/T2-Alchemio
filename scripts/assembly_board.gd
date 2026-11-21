extends Control
signal changed
signal feedback(message: String)
const Graph = preload("res://scripts/assembly_graph.gd")
const FONT = preload("res://assets/fonts/NotoSans.ttf")
const RADIUS := 25.0
var graph = Graph.new()
var positions: Dictionary = {}
var mode := 0 # 0: move/select; 1–3: bond order
var selected_atom := -1
var selected_bond := ""
var dragging := -1
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
var recognized: Array = []
var element_colors := {}

func _ready() -> void:
	for element in AlphaCatalog.load_data().elements:
		element_colors[element.symbol] = Color(element.color)
	custom_minimum_size = Vector2(600, 300)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	resized.connect(_clamp_positions)

func load_atoms(records: Array[Dictionary]) -> void:
	graph.add_atoms(records)
	for id in graph.atoms:
		if not positions.has(id):
			var index := positions.size()
			positions[id] = _free_position(Vector2(70 + (index % 6) * 95, 100 + floori(index / 6.0) * 130))
	_clamp_positions()
	_refresh()

func set_mode(value: int) -> void:
	mode = value
	selected_atom = -1
	selected_bond = ""
	dragging = -1
	queue_redraw()

func connect_atoms(a: int, b: int, order: int) -> bool:
	var accepted: bool = graph.set_bond(a, b, order)
	if accepted:
		_refresh()
	return accepted

func delete_selected_bond() -> void:
	if graph.remove_bond(selected_bond):
		selected_bond = ""
		_refresh()
	else:
		feedback.emit("Najprv vyber väzbu v režime Presun.")

func _refresh() -> void:
	recognized = graph.recognize()
	queue_redraw()
	changed.emit()

func _clamp_positions() -> void:
	if size.x < 100 or size.y < 100:
		return
	for id in positions:
		positions[id] = _bounded(positions[id])
	queue_redraw()

func _bounded(point: Vector2) -> Vector2:
	return point.clamp(Vector2(36, 55), size - Vector2(36, 36))

func _free_position(preferred: Vector2) -> Vector2:
	var candidates: Array[Vector2] = [preferred]
	for y in range(75, maxi(300, int(size.y)) - 30, 70):
		for x in range(55, maxi(600, int(size.x)) - 30, 70):
			candidates.append(Vector2(x, y))
	for point in candidates:
		var clear := true
		for existing in positions.values():
			if point.distance_to(existing) < RADIUS * 2 + 6:
				clear = false
				break
		if clear:
			return point
	return preferred

func _atom_at(point: Vector2) -> int:
	for id in positions:
		if positions[id].distance_to(point) <= RADIUS:
			return id
	return -1

func _bond_at(point: Vector2) -> String:
	for key in graph.bonds:
		var bond: Dictionary = graph.bonds[key]
		var nearest := Geometry2D.get_closest_point_to_segment(point, positions[bond.a], positions[bond.b])
		if nearest.distance_to(point) < 12:
			return key
	return ""

func _gui_input(event: InputEvent) -> void:
	if graph.finalized:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			var id := _atom_at(event.position)
			if mode == 0:
				selected_bond = "" if id >= 0 else _bond_at(event.position)
				dragging = id
				if id >= 0:
					drag_origin = positions[id]
					drag_offset = positions[id] - event.position
			elif id >= 0:
				if selected_atom < 0:
					selected_atom = id
				elif selected_atom == id:
					selected_atom = -1
				else:
					connect_atoms(selected_atom, id, mode)
					selected_atom = -1
		else:
			_end_drag()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging >= 0:
		positions[dragging] = _bounded(event.position + drag_offset)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed("delete_bond"):
		delete_selected_bond()
		accept_event()

func _end_drag() -> void:
	if dragging >= 0:
		for id in positions:
			if id != dragging and positions[id].distance_to(positions[dragging]) < RADIUS * 2 + 6:
				positions[dragging] = drag_origin
				feedback.emit("Atómy polož vedľa seba, nie cez seba.")
				break
	dragging = -1

func cancel_interaction() -> void:
	_end_drag()
	selected_atom = -1
	selected_bond = ""
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d2b"))
	for x in range(20, int(size.x), 40):
		for y in range(20, int(size.y), 40):
			draw_circle(Vector2(x, y), 1, Color(0.4, 0.6, 0.7, 0.12))
	for key in graph.bonds:
		var bond: Dictionary = graph.bonds[key]
		var a: Vector2 = positions[bond.a]
		var b: Vector2 = positions[bond.b]
		var direction := (b - a).normalized()
		var normal := direction.orthogonal() * 4
		var color := Color("f5d28b") if key == selected_bond else Color("a5b4cb")
		if bond.order == 1:
			draw_line(a + direction * RADIUS, b - direction * RADIUS, color, 3, true)
		else:
			var offsets := [-1, 1] if bond.order == 2 else [-2, 0, 2]
			for sign_value in offsets:
				draw_line(a + direction * RADIUS + normal * sign_value, b - direction * RADIUS + normal * sign_value, color, 3, true)
	var matched: Dictionary = {}
	var formal_symbols: Dictionary = {}
	for group in recognized:
		if group.substance.is_empty():
			continue
		var origin := Vector2(INF, INF)
		for id in group.atom_ids:
			matched[id] = true
			if group.substance.id == "carbon_monoxide":
				formal_symbols[id] = "C⁻" if graph.atoms[id].element == "C" else "O⁺"
			origin = origin.min(positions[id])
		draw_string(FONT, Vector2(origin.x - 20, maxf(22, origin.y - 38)), group.substance.display_formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("7ed9c3"))
	for id in graph.atoms:
		var symbol: String = graph.atoms[id]["element"]
		var tint: Color = element_colors.get(symbol, Color.WHITE)
		symbol = formal_symbols.get(id, symbol)
		var point: Vector2 = positions[id]
		draw_circle(point, RADIUS, tint.darkened(0.8))
		draw_arc(point, RADIUS, 0, TAU, 48, tint, 2, true)
		if matched.has(id) or selected_atom == id:
			draw_arc(point, RADIUS + 5, 0, TAU, 48, Color("f5d28b") if selected_atom == id else Color("7ed9c3"), 2, true)
		var width := FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(FONT, point + Vector2(-width / 2, 8), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tint)
