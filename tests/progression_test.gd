extends SceneTree
const Catalog = preload("res://scripts/catalog.gd")
const Graph = preload("res://scripts/assembly_graph.gd")
const Research = preload("res://scripts/research.gd")
var failures: Array[String] = []
var unlocks: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var data: Dictionary = Catalog.load_data()
	for template in data.substances:
		var graph = Graph.new()
		graph.configure_elements(["H", "O", "C"])
		var records: Array[Dictionary] = []
		for i in template.atoms.size():
			records.push_front({"id": 100 - i * 3, "element": template.atoms[i]})
		graph.add_atoms(records)
		for bond in template.bonds:
			graph.set_bond(100 - int(bond[0]) * 3, 100 - int(bond[1]) * 3, int(bond[2]))
		check(graph.preview().products == {template.id: 1}, "Recognize permuted " + template.id)
		var first_bond: Array = template.bonds[0]
		graph.remove_bond(graph.edge_key(100 - int(first_bond[0]) * 3, 100 - int(first_bond[1]) * 3))
		check(not graph.preview().products.has(template.id), "Reject incomplete " + template.id)
		check(template.atoms.size() <= data.collection.capacity, "Template fits capacity: " + template.id)
	# Same formula as ethanol, different connectivity: dimethyl ether is outside the chosen set.
	var isomer = Graph.new()
	isomer.configure_elements(["H", "O", "C"])
	var ether: Array[Dictionary] = [{"id":0,"element":"C"},{"id":1,"element":"O"},{"id":2,"element":"C"}]
	for i in 6:
		ether.append({"id":i+3,"element":"H"})
	isomer.add_atoms(ether)
	isomer.set_bond(0,1,1)
	isomer.set_bond(1,2,1)
	for i in 6:
		isomer.set_bond(0 if i < 3 else 2,i+3,1)
	check(isomer.preview().products.is_empty(), "Ethanol is not recognized from its formula alone")
	var alternative = Research.new()
	alternative.investigate({"hydrogen": 1})
	alternative.investigate({"hydrogen": 2})
	check("C" not in alternative.available_elements, "Repeat does not advance progression")
	alternative.investigate({"water": 1})
	check("C" in alternative.available_elements, "Alternative pair also unlocks element")
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	main.research.element_unlocked.connect(func(id: String): unlocks.append(id))
	main.collection_map.set_physics_process(false)
	check(main.collection_map.free_atoms.size() == 48, "Initial map has no carbon")
	check(not main.research.investigate({"methane":1}), "Locked carbon research rejected")
	check(not main.laboratory.progress_label.text.contains("C"), "Progress does not name next element")
	# Produce the initial water/oxygen pair using real collection and assembly.
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0,1,1)
	main.preview_page.board.connect_atoms(2,1,1)
	main.preview_page.board.connect_atoms(3,5,2)
	main.preview_page.finalize_assembly()
	var lab = main.laboratory
	await screenshot("a5-progress")
	lab.rows.water.button.pressed.emit()
	lab.research_button.pressed.emit()
	check(main.research.available_elements == ["H","O"], "One discovery keeps element locked")
	lab.discovery.hide()
	lab.return_button.pressed.emit()
	lab.rows.oxygen.button.pressed.emit()
	lab.research_button.pressed.emit()
	check(unlocks == ["C"], "Second unique discovery unlocks once")
	check(lab.discovery.current_id == "oxygen", "Substance card comes first")
	lab.discovery.get_ok_button().pressed.emit()
	check(lab.discovery.current_id == "progress" and lab.discovery.visible, "Progress notice comes second")
	lab.discovery.get_ok_button().pressed.emit()
	check(lab.discovery.current_id == "C" and lab.discovery.visible, "New element card comes third")
	await screenshot("a5-element")
	lab.discovery.get_ok_button().pressed.emit()
	check(not lab.discovery.visible and lab.discovery.pending.is_empty(), "Queue closes after element")
	lab._investigate()
	check(unlocks == ["C"], "Repeated research never unlocks twice")
	lab.discovery.hide()
	for template in data.substances:
		if "C" not in template.atoms:
			continue
		lab.new_collection_requested.emit()
		await process_frame
		main.collection_map.set_physics_process(false)
		check(main.collection_map.free_atoms.size() == 72, "Unlocked map guarantees carbon and H/O")
		var records: Array[Dictionary] = []
		for symbol in template.atoms:
			for id in main.collection_map.free_atoms.keys():
				if main.collection_map.free_atoms[id].element_id == symbol:
					main.collection_map.collect_atom(id)
					records.append(main.collection_map.cargo.back())
					break
		main.finish_button.pressed.emit()
		for bond in template.bonds:
			main.preview_page.board.connect_atoms(records[int(bond[0])].id, records[int(bond[1])].id, int(bond[2]))
		if template.id == "carbon_monoxide":
			var board = main.preview_page.board
			board.graph.set_bond(records[0].id, records[1].id, 2)
			check(board.graph.preview().products.is_empty(), "CO requires triple rather than double bond")
			await process_frame
			await click_at(main.preview_page.mode_buttons[3].get_global_rect().get_center())
			for record in records:
				await click_at(board.get_global_transform_with_canvas() * board.positions[record.id])
		check(main.preview_page.board.graph.preview().products == {template.id:1}, "Playable assembly: " + template.id)
		if template.id == "carbon_monoxide":
			await screenshot("a5-triple-bond")
		main.preview_page.finalize_assembly()
		check(main.inventory.stock[template.id] == 1, "Inventory receives " + template.id)
		lab.rows[template.id].button.pressed.emit()
		lab.research_button.pressed.emit()
		check(main.research.researched.has(template.id), "Can research " + template.id)
		lab.discovery.hide()
		lab.return_button.pressed.emit()
	check(unlocks == ["C"] and not lab.progress_bar.visible, "No fictitious next threshold")
	await screenshot("a5-laboratory")
	lab.collection_button.pressed.emit()
	await screenshot("a5-collection")
	lab.discovery.hide()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("A5 PASS: all 10 structures, isomer rejection, hidden element, unique unlock, card queue, alternate pair, seven carbon collection/assembly/research cycles")
	quit(0 if failures.is_empty() else 1)

func screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
