extends SceneTree
const Graph = preload("res://scripts/assembly_graph.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func make_graph(symbols: Array):
	var graph = Graph.new()
	var records: Array[Dictionary] = []
	for i in symbols.size():
		records.append({"id": i + 10, "element": symbols[i]})
	graph.add_atoms(records)
	return graph

func run_checks() -> void:
	var graph = make_graph(["H", "H", "H", "O", "O", "O"])
	check(not graph.set_bond(10, 10, 1), "Self-bond rejected")
	check(not graph.set_bond(10, 99, 1), "Missing atom rejected")
	check(not graph.set_bond(10, 11, 4), "Unsupported order rejected")
	graph.set_bond(10, 13, 1)
	graph.set_bond(11, 13, 1)
	graph.set_bond(14, 15, 1)
	check(graph.preview().products == {"water": 1}, "Oxygen requires double bond")
	graph.set_bond(15, 14, 2)
	check(graph.bonds.size() == 3, "Order update does not duplicate edge")
	var result: Dictionary = graph.preview()
	check(result.products == {"water": 1, "oxygen": 1}, "HHHOOO yields water and oxygen")
	check(result.discarded_atoms == [{"id": 12, "element": "H"}], "Correct leftover atom identity")
	check(graph.set_bond(12, 13, 1), "Oxygen can display a third single bond")
	check(graph.invalid_bonds().size() == 3, "All bonds at overloaded oxygen are flagged")
	check(graph.preview().products == {"oxygen": 1}, "Invalid component is not recognized")
	graph.remove_bond(graph.edge_key(12, 13))
	check(graph.invalid_bonds().is_empty(), "Repair clears invalid flags")
	check(graph.finalize() == result, "Final result equals preview")
	check(graph.finalize().is_empty() and graph.atoms.is_empty(), "Finalize consumes atoms exactly once")
	check(not graph.set_bond(10, 11, 1), "Finalized graph cannot be edited")
	var wrong = make_graph(["H", "H", "O"])
	wrong.set_bond(10, 11, 2)
	check(wrong.invalid_bonds().has(wrong.edge_key(10, 11)), "Hydrogen double bond is flagged")
	wrong.set_bond(10, 11, 1)
	wrong.set_bond(11, 12, 1)
	check(wrong.preview().products.is_empty(), "H-H-O is not recognized")
	for symbols in [["H", "O", "H"], ["O", "H", "H"], ["H", "H", "O"]]:
		var permutation = make_graph(symbols)
		var oxygen_id: int = symbols.find("O") + 10
		for id in permutation.atoms:
			if id != oxygen_id:
				permutation.set_bond(id, oxygen_id, 1)
		check(permutation.preview().products == {"water": 1}, "Recognition independent of ID order")
	var multiple = make_graph(["H", "H", "H", "H"])
	multiple.set_bond(10, 11, 1)
	multiple.set_bond(12, 13, 1)
	check(multiple.preview().products == {"hydrogen": 2}, "Two separate molecules yield two portions")
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	main.collection_map.set_physics_process(false)
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	await process_frame
	await process_frame
	var panel = main.preview_page
	var board = panel.board
	check(board.graph.atoms.size() == 6 and board.graph.bonds.is_empty(), "Cargo arrives without collection attachments")
	# Real viewport mouse events exercise dragging and selecting bonds.
	var initial: Vector2 = board.positions[0]
	await drag_board(board, initial, initial + Vector2(0, 90))
	check(board.positions[0].distance_to(initial + Vector2(0, 90)) < 1, "Mouse drags atom")
	await click_board(board, board.positions[0])
	await drag_board(board, board.positions[0], initial)
	check(board.positions[0].distance_to(initial) < 1 and board.graph.bonds.is_empty(), "Move mode drags an inspected atom")
	await click_control(panel.bonds_button)
	await click_board(board, board.positions[0])
	await drag_board(board, board.positions[0], board.positions[1])
	await click_board(board, board.positions[2])
	await drag_board(board, board.positions[2], board.positions[1])
	await click_board(board, board.positions[3])
	await drag_board(board, board.positions[3], board.positions[5])
	await drag_board(board, board.positions[3], board.positions[5])
	check(board.graph.preview().products == {"water": 1, "oxygen": 1}, "Mouse builds both molecules")
	await drag_board(board, board.positions[3], board.positions[5])
	await drag_board(board, board.positions[3], board.positions[5])
	check(board.graph.order_between(3, 5) == 3, "Repeated gestures stop at a triple bond")
	board.connect_atoms(3, 5, 2)
	await click_board(board, (board.positions[0] + board.positions[1]) / 2)
	check(panel.delete_button.visible, "Bond selection exposes the delete button")
	await click_control(panel.delete_button)
	check(board.graph.order_between(0, 1) == 0 and not panel.delete_button.visible, "Button removes bond and hides")
	board.connect_atoms(0, 1, 1)
	await click_board(board, (board.positions[0] + board.positions[1]) / 2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_DELETE
	key.pressed = true
	root.push_input(key, true)
	key = InputEventKey.new()
	key.physical_keycode = KEY_DELETE
	key.pressed = false
	root.push_input(key, true)
	await process_frame
	check(board.graph.order_between(0, 1) == 0, "Delete removes selected bond through GUI")
	board.connect_atoms(0, 1, 1)
	# Separate molecules spatially to inspect green outlines, formulas and lines.
	board.positions = {0: Vector2(150, 180), 1: Vector2(260, 140), 2: Vector2(370, 180), 3: Vector2(650, 160), 4: Vector2(480, 290), 5: Vector2(790, 160)}
	board.queue_redraw()
	check(board.graph.preview().products == {"water": 1, "oxygen": 1}, "Positions do not change chemistry")
	main._return_to_map()
	main.collection_map.collect_atom(6)
	main.finish_button.pressed.emit()
	check(board.graph.atoms.size() == 7 and board.graph.bonds.size() == 3, "Return and new cargo preserve assembly work")
	await screenshot("res://artifacts/a2-assembly.png")
	await click_control(panel.finish_button)
	check(panel.confirmation.visible and not board.graph.finalized, "Leftovers require finish confirmation")
	panel.confirmation.canceled.emit()
	panel.confirmation.hide()
	check(board.graph.atoms.size() == 7, "Cancel keeps all atoms")
	panel.request_finish()
	panel.confirmation.confirmed.emit()
	check(main.last_assembly_result.products == {"water": 1, "oxygen": 1}, "Completion delivers products")
	check(main.last_assembly_result.discarded_atoms.size() == 2, "Completion reports leftovers")
	check(main.collection_map.cargo.is_empty() and board.graph.atoms.is_empty(), "No reusable spent cargo")
	var saved: Dictionary = main.last_assembly_result.duplicate(true)
	panel.finalize_assembly()
	check(main.last_assembly_result == saved, "Double finish cannot duplicate rewards")
	await screenshot("res://artifacts/a2-result.png")
	main._new_collection()
	await process_frame
	check(main.collection_map.cargo.is_empty() and main.collection_map.free_atoms.size() == 72, "New collection includes automatically unlocked carbon")
	check(main.preview_page.board.graph.atoms.is_empty(), "New batch has no old atoms")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("A2 PASS: graph matching, invalid structures, mouse editing, deletion, leftover confirmation, single-use completion, new cycle")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func click_control(control: Control) -> void:
	await click_at(control.get_global_transform_with_canvas() * (control.size / 2))

func click_board(board: Control, point: Vector2) -> void:
	await click_at(board.get_global_transform_with_canvas() * point)

func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func drag_board(board: Control, from: Vector2, to: Vector2) -> void:
	var transform := board.get_global_transform_with_canvas()
	var down := InputEventMouseButton.new()
	down.position = transform * from
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = transform * to
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = transform * to
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up, true)
	await process_frame

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
