extends SceneTree
const Catalog = preload("res://scripts/catalog.gd")
const Graph = preload("res://scripts/assembly_graph.gd")
var failures: Array[String] = []
var unlocks: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	test_models()
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.collection_map.set_physics_process(false)
	main.laboratory.set_process(false)
	main.research.element_unlocked.connect(func(id: String): unlocks.append(id))
	check(main.collection_map.free_atoms.size() == 48, "Initial map only has H/O")
	for id in [0, 2, 4, 6, 1, 3]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	var board = main.preview_page.board
	board.connect_atoms(0, 2, 1)
	board.connect_atoms(4, 6, 1)
	board.connect_atoms(1, 3, 2)
	check(board.graph.preview().products == {"hydrogen": 2, "oxygen": 1}, "Assemble reagents from collected atoms")
	main.preview_page.finalize_assembly()
	var lab = main.laboratory
	check(main.research.researched.size() == 2 and unlocks.is_empty(), "Collecting two substances does not advance reaction progression")
	check(not _select(lab, "tube"), "Solid combustion apparatus hidden before unlock")
	lab._select_station("liquid")
	check(lab.station_buttons.liquid.button_pressed and not lab.station_buttons.combustion.button_pressed, "Only the current laboratory mode is active")
	check(_select(lab, "beaker"), "Physical comparison available in the beaker")
	main.inventory.credit({"water": 1, "hydrogen_peroxide": 2})
	lab.refresh()
	lab.rows.water.button.pressed.emit()
	lab.heat_button.button_pressed = true
	lab.heat_button.pressed.emit()
	lab.experiment.step(10, main.inventory.sample, main.inventory.outlets)
	check(lab.experiment.boiling and main.research.stage_progress() == Vector2i(0, 2), "Boiling gives no progress")
	lab.return_button.pressed.emit()
	check(main.inventory.stock.water == 1 and lab.experiment.instrument_id == "beaker", "Reuse the beaker after returning the boiling sample")
	_run(main, "catalyst", {"hydrogen_peroxide": 2}, {"water": 2, "oxygen": 1})
	check(main.research.stage_progress() == Vector2i(0, 2), "Optional peroxide does not replace core experiments")
	lab.outlet_buttons.water.pressed.emit()
	check(main.inventory.stock.water == 3 and main.inventory.outlets == {"oxygen": 1}, "Products are collected individually")
	lab._select_station("combustion")
	check(main.inventory.outlets.is_empty() and main.inventory.stock.oxygen == 2, "Changing station returns unclaimed products")
	_run(main, "ignite", {"hydrogen": 2, "oxygen": 1}, {"water": 2})
	check(main.research.stage_progress() == Vector2i(1, 2), "Reaction counts even when water is known")
	check(not main.research.complete_experiment("hydrogen_combustion"), "One completion per reaction")
	lab._select_station("liquid")
	check(_select(lab, "electrodes"), "Select electrolysis in liquid station")
	_run(main, "current", {"water": 2}, {"hydrogen": 2, "oxygen": 1})
	check(unlocks == ["C"] and main.research.stage_progress() == Vector2i(0, 3), "Core reactions open second stage")
	check(main.collection_map.free_atoms.size() == 42, "Current collection map is unchanged")
	check(main.discovery_notice.pending.filter(func(item): return item.id == "C").size() == 1, "One carbon notice")
	lab.new_collection_requested.emit()
	await process_frame
	main.collection_map.set_physics_process(false)
	check(main.collection_map.free_atoms.size() == 72, "Next map includes carbon and only three elements")
	for id in [48, 49]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	check(main.preview_page.board.graph.preview().products == {"solid_carbon": 2}, "Carbon tokens become a solid sample")
	main.preview_page.finalize_assembly()
	lab._select_station("combustion")
	check(_select(lab, "tube"), "Tube furnace unlocked")
	_run(main, "furnace", {"solid_carbon": 2, "oxygen": 1}, {"carbon_monoxide": 2})
	check(main.research.stage_progress() == Vector2i(1, 3), "First carbon experiment counts")
	main.inventory.credit({"solid_carbon": 1, "oxygen": 3, "methane": 1})
	lab.return_button.pressed.emit()
	check(lab.experiment.instrument_id == "tube", "Compare complete combustion on the same fixture")
	_run(main, "furnace", {"solid_carbon": 1, "oxygen": 1}, {"carbon_dioxide": 1})
	lab._select_station("liquid")
	check(_select(lab, "beaker"), "Carbonation unlocked")
	_run(main, "gas", {"carbon_dioxide": 1, "water": 1}, {"carbonated_water": 1})
	check(main.research.stage_progress() == Vector2i(3, 3) and lab.goals_label.text.begins_with("Etapa dokončená"), "Stage ends after three experiments")
	lab._select_station("combustion")
	check(_select(lab, "burner"), "Use the same burner for methane")
	_run(main, "ignite", {"methane": 1, "oxygen": 2}, {"water": 2, "carbon_dioxide": 1})
	check(main.research.available_elements == ["H", "O", "C"] and unlocks == ["C"], "No nitrogen progression")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PROGRESSION PASS: playable models, two stages, station switching, products and carbon gating")
	quit(0 if failures.is_empty() else 1)

func _select(lab: Control, id: String) -> bool:
	for index in lab.instrument_select.item_count:
		if lab.instrument_select.get_item_metadata(index) == id:
			lab.instrument_select.select(index)
			lab.instrument_select.item_selected.emit(index)
			return true
	return false

func _run(main: Control, action: String, reagents: Dictionary, products: Dictionary) -> void:
	var lab = main.laboratory
	lab.refresh()
	for id in reagents:
		for portion in reagents[id]:
			lab.rows[id].button.pressed.emit()
	check(not lab.action_buttons[action].disabled, "Ready to run: " + action)
	lab.action_buttons[action].pressed.emit()
	lab.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	check(main.inventory.outlets == products, "Visible output from " + action)

func test_models() -> void:
	for template in Catalog.load_data().substances:
		var graph = Graph.new()
		graph.configure_elements(["H", "O", "C"])
		var records: Array[Dictionary] = []
		for i in template.atoms.size():
			records.push_front({"id": 100 - i * 3, "element": template.atoms[i]})
		graph.add_atoms(records)
		for bond in template.bonds:
			graph.set_bond(100 - int(bond[0]) * 3, 100 - int(bond[1]) * 3, int(bond[2]))
		if not template.get("assembly", true):
			check(not graph.preview().products.has(template.id), "Solution can only come from experiment")
			continue
		check(graph.preview().products == {template.id: 1}, "Recognize permuted " + template.id)
		if not template.bonds.is_empty():
			var first_bond: Array = template.bonds[0]
			graph.remove_bond(graph.edge_key(100 - int(first_bond[0]) * 3, 100 - int(first_bond[1]) * 3))
			check(not graph.preview().products.has(template.id), "Reject incomplete " + template.id)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
