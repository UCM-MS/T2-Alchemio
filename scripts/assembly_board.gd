extends Control
signal changed
signal feedback(message: String)
signal bond_selection_changed(has_selection: bool)
const UI = preload("res://scripts/workspace_ui.gd")
const Graph = preload("res://scripts/assembly_graph.gd")
const FONT = preload("res://assets/fonts/NotoSans.ttf")
const RADIUS := 25.0
const CLICK_DRAG_THRESHOLD := 5.0
const ELECTRON_COLOR := Color("ff555f")
const SHARED_ELECTRON_COLOR := Color("62afff")
const ELECTRON_ORBIT_SECONDS := 6.0
var graph = Graph.new()
var positions: Dictionary = {}
var selected_bond := ""
var bond_mode := false
var drawing_bond := false
var bond_cursor := Vector2.ZERO
var dragging := -1
var drag_origin := Vector2.ZERO
var drag_start_positions: Dictionary = {}
var drag_offset := Vector2.ZERO
var drag_moved := false
var double_click := false
var inspected_atom := -1
var show_all_shells := false
var electron_orbit_phase := 0.0
var recognized: Array = []
var element_colors := {}
var element_shells := {}

func _ready() -> void:
	for element in AlphaCatalog.load_data().elements:
		element_colors[element.symbol] = UI.tint(element.symbol)
		var atomic_number := int(element.atomic_number)
		element_shells[element.symbol] = element.get("electron_shells", _shells_for(atomic_number))
	custom_minimum_size = Vector2(600, 300)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	resized.connect(_clamp_positions)

func _process(delta: float) -> void:
	if inspected_atom < 0 or not is_visible_in_tree():
		return
	electron_orbit_phase = fposmod(electron_orbit_phase + TAU * delta / ELECTRON_ORBIT_SECONDS, TAU)
	queue_redraw()

func load_atoms(records: Array[Dictionary]) -> void:
	graph.add_atoms(records)
	for id in graph.atoms:
		if not positions.has(id):
			var index := positions.size()
			positions[id] = _free_position(Vector2(70 + (index % 6) * 95, 100 + floori(index / 6.0) * 130))
	_clamp_positions()
	_refresh()

func connect_atoms(a: int, b: int, order: int) -> bool:
	var accepted: bool = graph.set_bond(a, b, order)
	if accepted:
		_refresh()
	return accepted

func delete_selected_bond() -> void:
	if graph.remove_bond(selected_bond):
		_select_bond("")
		_refresh()
	else:
		feedback.emit("Najprv klikni na väzbu.")

func _select_bond(key: String) -> void:
	selected_bond = key
	bond_selection_changed.emit(not key.is_empty())

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
	return point.clamp(Vector2(59, 80), size - Vector2(59, 59))

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
			_select_bond("" if id >= 0 else _bond_at(event.position))
			dragging = id
			drag_moved = false
			drawing_bond = bond_mode and id >= 0
			double_click = event.double_click and id >= 0 and id == inspected_atom
			if id < 0:
				inspected_atom = -1
			else:
				drag_origin = positions[id]
				bond_cursor = event.position
				drag_offset = drag_origin - event.position
				if not drawing_bond:
					drag_start_positions = {id: drag_origin}
					if id != inspected_atom:
						for group in recognized:
							if not group.substance.is_empty() and id in group.atom_ids:
								for member in group.atom_ids:
									drag_start_positions[member] = positions[member]
								break
		else:
			var target_id := _atom_at(event.position)
			if drawing_bond and drag_moved and target_id >= 0 and target_id != dragging:
				var order: int = graph.order_between(dragging, target_id)
				if order < 3:
					connect_atoms(dragging, target_id, order + 1)
			elif dragging >= 0 and not drag_moved and target_id == dragging:
				if inspected_atom != dragging:
					electron_orbit_phase = 0.0
				inspected_atom = dragging
				show_all_shells = double_click
			_end_drag()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging >= 0:
		var target: Vector2 = event.position + drag_offset
		if drag_moved or target.distance_to(drag_origin) >= CLICK_DRAG_THRESHOLD:
			drag_moved = true
			if drawing_bond:
				bond_cursor = event.position
			else:
				_move_dragged_atoms(target - drag_origin)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed("delete_bond"):
		delete_selected_bond()
		accept_event()

func _move_dragged_atoms(offset: Vector2) -> void:
	var top_left := Vector2(INF, INF)
	var bottom_right := Vector2(-INF, -INF)
	for original: Vector2 in drag_start_positions.values():
		top_left = top_left.min(original)
		bottom_right = bottom_right.max(original)
	var bounded_offset := offset.clamp(_bounded(Vector2.ZERO) - top_left, _bounded(size) - bottom_right)
	for id in drag_start_positions:
		positions[id] = drag_start_positions[id] + bounded_offset

func _end_drag() -> void:
	if drag_moved and _drag_overlaps_other_atoms():
		for id in drag_start_positions:
			positions[id] = drag_start_positions[id]
		feedback.emit("Atómy polož vedľa seba, nie cez seba.")
	dragging = -1
	drawing_bond = false
	drag_start_positions.clear()

func _drag_overlaps_other_atoms() -> bool:
	for member in drag_start_positions:
		for id in positions:
			if not drag_start_positions.has(id) and positions[id].distance_to(positions[member]) < RADIUS * 2 + 6:
				return true
	return false

func cancel_interaction() -> void:
	_end_drag()
	_select_bond("")
	inspected_atom = -1
	queue_redraw()

func set_bond_mode(enabled: bool) -> void:
	_end_drag()
	bond_mode = enabled
	queue_redraw()

func _draw() -> void:
	var invalid: Dictionary = graph.invalid_bonds()
	for key in graph.bonds:
		var bond: Dictionary = graph.bonds[key]
		var a: Vector2 = positions[bond.a]
		var b: Vector2 = positions[bond.b]
		var direction := (b - a).normalized()
		var normal := direction.orthogonal() * 4
		var color := Color("f5d28b") if key == selected_bond else Color("a5b4cb")
		if invalid.has(key) and key != selected_bond:
			color = ELECTRON_COLOR
		if bond.order == 1:
			draw_line(a + direction * RADIUS, b - direction * RADIUS, color, 3, true)
		else:
			var offsets := [-1, 1] if bond.order == 2 else [-2, 0, 2]
			for sign_value in offsets:
				draw_line(a + direction * RADIUS + normal * sign_value, b - direction * RADIUS + normal * sign_value, color, 3, true)
	if drawing_bond and drag_moved:
		var origin: Vector2 = positions[dragging]
		var direction := (bond_cursor - origin).normalized()
		if origin.distance_to(bond_cursor) > RADIUS:
			draw_line(origin + direction * RADIUS, bond_cursor, Color("f5d28b"), 3, true)
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
		if inspected_atom not in group.atom_ids:
			draw_string(FONT, Vector2(origin.x - 20, maxf(22, origin.y - 38)), group.substance.display_formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("7ed9c3"))
	if graph.atoms.has(inspected_atom):
		var element: String = graph.atoms[inspected_atom].element
		var shared := 0
		for bond in graph.bonds.values():
			if bond.a == inspected_atom or bond.b == inspected_atom:
				shared += int(bond.order)
		_draw_electron_shells(positions[inspected_atom], element, shared, formal_symbols.has(inspected_atom))
	for id in graph.atoms:
		var symbol: String = graph.atoms[id]["element"]
		var tint: Color = element_colors.get(symbol, Color.WHITE)
		symbol = formal_symbols.get(id, symbol)
		var point: Vector2 = positions[id]
		draw_circle(point, RADIUS, UI.pigment(graph.atoms[id].element), true, -1, true)
		draw_arc(point, RADIUS, 0, TAU, 48, tint, 2, true)
		if matched.has(id):
			draw_arc(point, RADIUS + 5, 0, TAU, 48, Color("7ed9c3"), 2, true)
		var width := FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(FONT, point + Vector2(-width / 2, 8), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tint)

func _shells_for(atomic_number: int) -> Array:
	# The first 20 neutral elements fit this filling sequence. Later elements
	# can declare their actual shell populations in the catalog.
	var shells: Array = []
	if atomic_number > 20:
		return shells
	var remaining := atomic_number
	for capacity: int in [2, 8, 8, 2]:
		if remaining <= 0:
			break
		var count := mini(remaining, capacity)
		shells.append(count)
		remaining -= count
	return shells

func _draw_electron_shells(center: Vector2, element: String, shared: int, is_carbon_monoxide: bool) -> void:
	var shells: Array = element_shells.get(element, [])
	if shells.is_empty():
		return
	var outer := shells.size() - 1
	var own: int = shells[outer]
	if is_carbon_monoxide:
		own += 1 if element == "C" else -1
	var total := own + shared
	var goal := 2 if element == "H" else 8
	var spacing := minf(10.0, 20.0 / maxf(1, shells.size() - 1))
	for layer in range(0 if show_all_shells else outer, shells.size()):
		var radius := 34.0 + (layer if show_all_shells else 0) * spacing
		draw_arc(center, radius, 0.0, TAU, 64, Color.WHITE, 1.5, true)
		var count: int = total if layer == outer else shells[layer]
		var rotation_offset := PI / 4.0 if layer % 2 == 1 else 0.0
		var orbit := -electron_orbit_phase if layer % 2 == 1 else electron_orbit_phase
		for electron in range(count):
			var angle := -PI / 2.0 + rotation_offset + orbit + TAU * electron / count
			var color := SHARED_ELECTRON_COLOR if layer == outer and electron >= own else ELECTRON_COLOR
			draw_circle(center + Vector2.from_angle(angle) * radius, minf(5.0, spacing * 0.49), color, true, -1.0, true)

	var label := "%d/%d" % [total, goal]
	var label_color := ELECTRON_COLOR if total > goal else Color("7ed9c3") if total == goal else Color.WHITE
	var label_width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var top_radius := 34.0 + (outer * spacing if show_all_shells else 0.0)
	draw_string(FONT, center + Vector2(-label_width / 2, -top_radius - 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, label_color)
