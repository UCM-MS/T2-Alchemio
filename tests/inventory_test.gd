extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	for cycle in 2:
		main.collection_map.set_physics_process(false)
		for id in 6:
			main.collection_map.collect_atom(id)
		main.finish_button.pressed.emit()
		var panel = main.preview_page
		panel.board.connect_atoms(0, 1, 1)
		panel.board.connect_atoms(2, 1, 1)
		panel.board.connect_atoms(3, 5, 2)
		panel.board.pack_atom(0)
		panel.board.pack_atom(3)
		panel.finalize_assembly()
		check(main.laboratory.visible and not panel.visible, "Completion enters laboratory")
		check(main.inventory.stock.hydrogen == 0 and main.inventory.stock.oxygen == cycle + 1 and main.inventory.stock.water == cycle + 1, "Rewards accumulate once per cycle")
		main._assembly_completed(main.last_assembly_result)
		panel.finalize_assembly()
		check(main.inventory.stock.water == cycle + 1, "Repeated completion cannot credit twice")
		check(not main.laboratory.rows.hydrogen.row.visible, "Uncollected substance is hidden")
		await process_frame
		await process_frame
		if cycle == 0 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/a3-reagent-cards.png")
			for child in main.laboratory.get_children():
				if child is AcceptDialog:
					child.popup_centered(Vector2i(760, 420))
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/a3-help.png")
					child.hide()
		var card: Control = main.laboratory.rows.water.button
		await drag_card(card, Vector2(10, 10))
		check(main.inventory.stock.water == cycle + 1 and main.inventory.sample.is_empty(), "Cancelled drag preserves stock")
		await drag_card(card, main.laboratory.flask.get_global_rect().get_center())
		check(main.inventory.stock.water == cycle and main.inventory.sample.water == 1, "Mouse drag transfers one portion")
		check(main.laboratory.rows.water.row.visible == (cycle > 0), "Exhausted stock card disappears")
		main.laboratory.rows.oxygen.button.pressed.emit()
		check(main.inventory.sample == {"water": 1, "oxygen": 1}, "Mixture retains both substances")
		if cycle == 0 and DisplayServer.get_name() != "headless":
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/a3-laboratory.png")
		main.laboratory.return_button.pressed.emit()
		main.laboratory.return_button.pressed.emit()
		check(main.inventory.sample.is_empty() and main.inventory.stock.water == cycle + 1, "Repeated return preserves total")
		check(not main.inventory.add_to_sample("hydrogen"), "Empty stock cannot go negative")
		main.inventory.credit({"H": 2})
		main.laboratory.refresh()
		var atom_card: Control = main.laboratory.rows.H.button
		main.laboratory.cards_area.ensure_control_visible(atom_card)
		await process_frame
		await process_frame
		await drag_card(atom_card, main.laboratory.waste_bin.get_global_rect().get_center())
		check(main.inventory.stock.H == 1 and main.inventory.stock.hydrogen == 0, "Bin removes a single H atom")
		var water_card: Control = main.laboratory.rows.water.button
		main.laboratory.cards_area.ensure_control_visible(water_card)
		await process_frame
		await drag_card(water_card, main.laboratory.waste_bin.get_global_rect().get_center())
		check(main.inventory.stock.water == cycle and main.research.researched.has("water"), "Bin removes one portion and preserves discovery")
		main.inventory.credit({"water":1})
		main.inventory.take_from_stock("H")
		main.laboratory.refresh()
		main.laboratory.rows.water.button.pressed.emit()
		main.laboratory.new_collection_requested.emit()
		await process_frame
		check(main.inventory.sample.is_empty() and main.inventory.stock.water == cycle + 1, "Leaving laboratory returns sample")
		check(main.collection_map.active and main.collection_map.cargo.is_empty(), "New cycle starts empty and active")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("A3 PASS: two complete cycles, single credit, transfers, mixtures, return, empty stock, automatic return on exit")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func drag_card(card: Control, destination: Vector2) -> void:
	var start := card.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = start
	root.push_input(motion, true)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = start
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	for point in [start + Vector2(24, 0), destination]:
		motion = InputEventMouseMotion.new()
		motion.position = point
		motion.relative = point - start
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	var up := InputEventMouseButton.new()
	up.position = destination
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up, true)
	await process_frame
