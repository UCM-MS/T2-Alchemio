extends SceneTree
var failures: Array[String] = []
var discoveries: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.collection_map.set_physics_process(false)
	main.research.discovered.connect(func(id: String): discoveries.append(id))
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	var board = main.preview_page.board
	board.connect_atoms(0,1,1)
	check(discoveries.is_empty(), "Incomplete model does not discover water")
	board.connect_atoms(2,1,1)
	check(discoveries == ["water"] and main.research.researched.has("water"), "Correct model discovers immediately before finish")
	check(main.inventory.stock.water == 0 and not board.graph.finalized, "Discovery does not grant portions or finalize graph")
	check(main.discovery_notice.visible and not main.laboratory.discovery.visible, "Notice is non-modal")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/automatic-discovery-assembly.png")
	board.graph.remove_bond(board.graph.edge_key(0,1))
	board._refresh()
	board.connect_atoms(0,1,1)
	check(discoveries == ["water"], "Breaking and rebuilding does not repeat discovery")
	board.connect_atoms(3,5,2)
	check(discoveries == ["water","oxygen"] and "C" not in main.research.available_elements, "Two models do not unlock carbon")
	check(main.discovery_notice.pending.size() == 1, "Only the second substance was queued")
	main.preview_page.finalize_assembly()
	check(main.inventory.stock.water == 1 and discoveries.size() == 2, "Finish gives portions without repeating discoveries")
	main.laboratory.rows.water.button.pressed.emit()
	main.laboratory.research_button.pressed.emit()
	check(main.laboratory.discovery.current_id == "water" and discoveries.size() == 2, "Optional button only displays known card")
	main.laboratory.discovery.hide()
	main.laboratory.return_button.pressed.emit()
	main.inventory.credit({"hydrogen_peroxide": 2})
	var lab = main.laboratory
	lab._select_station("liquid")
	lab.rows.hydrogen_peroxide.button.pressed.emit()
	lab.rows.hydrogen_peroxide.button.pressed.emit()
	main.discovery_notice.clear()
	lab.action_buttons.catalyst.pressed.emit()
	lab.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	check(discoveries == ["water", "oxygen"] and main.research.completed_experiments.has("peroxide_decomposition"), "A completed reaction is recorded when products are already known")
	check(main.inventory.outlets == {"water": 2, "oxygen": 1}, "Reaction product portions remain correct")
	lab._return_sample()
	lab._select_instrument("electrodes")
	lab.rows.water.button.pressed.emit()
	lab.rows.water.button.pressed.emit()
	lab.action_buttons.current.pressed.emit()
	lab.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	check(discoveries == ["water", "oxygen", "hydrogen"], "Reaction discovers only the new product")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("DISCOVERY PASS: immediate models, no premature portions, non-modal queue, deduplication, automatic unlock, reaction products")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
