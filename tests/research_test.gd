extends SceneTree
var failures: Array[String] = []
var discoveries: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.collection_map.set_physics_process(false)
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0, 1, 1)
	main.preview_page.board.connect_atoms(2, 1, 1)
	main.preview_page.board.connect_atoms(3, 5, 2)
	main.preview_page.finalize_assembly()
	var lab = main.laboratory
	main.research.discovered.connect(func(id: String): discoveries.append(id))
	check(lab.research_button.disabled, "Empty flask disables research")
	lab._investigate()
	check(main.research.researched.is_empty(), "Empty research has no effect")
	lab.collection_button.pressed.emit()
	check(lab.discovery.current_id.is_empty(), "Collection starts empty")
	lab.discovery.hide()
	lab.rows.water.button.pressed.emit()
	check(not lab.research_button.disabled and lab.rows.water.status.text == "Nepreskúmané", "Collected is not researched")
	lab.research_button.pressed.emit()
	check(main.research.researched == {"water": true} and discoveries == ["water"], "First research adds one unique discovery")
	check(main.inventory.sample == {"water": 1}, "Research does not consume sample")
	check(lab.discovery.visible and lab.discovery.current_id == "water", "First research opens substance card")
	await screenshot("a4-discovery")
	lab.discovery.hide()
	lab.research_button.pressed.emit()
	check(discoveries == ["water"] and main.research.researched.size() == 1, "Repeated research has no new reward")
	lab.discovery.hide()
	lab.rows.oxygen.button.pressed.emit()
	check(lab.research_button.disabled and not lab.research_hint.text.is_empty(), "Mixture disables research with explanation")
	lab._investigate()
	check(main.research.researched.size() == 1, "Mixture cannot add discovery through direct action")
	await screenshot("a4-laboratory")
	lab.return_button.pressed.emit()
	main.inventory.credit({"oxygen": 1})
	lab.refresh()
	lab.rows.oxygen.button.pressed.emit()
	lab.rows.oxygen.button.pressed.emit()
	lab.research_button.pressed.emit()
	check(main.research.researched.size() == 2 and discoveries == ["water", "oxygen"], "Several portions of one substance can be researched")
	check(main.inventory.sample == {"oxygen": 2}, "Multiple portions remain intact")
	lab.discovery.hide()
	lab.return_button.pressed.emit()
	lab.collection_button.pressed.emit()
	check(main.research.researched.size() == 2, "Return does not erase collection")
	await screenshot("a4-collection")
	lab.discovery.show_substance("water")
	check(lab.discovery.current_id == "water", "Collection reopens researched card without sample")
	lab.discovery.hide()
	lab.new_collection_requested.emit()
	await process_frame
	check(main.research.researched.size() == 2 and main.inventory.stock.oxygen == 2, "Discoveries and portions survive next collection")
	check(not main.research.investigate({"unknown": 1}), "Unknown substance cannot be researched")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("A4 PASS: unique discovery, repeated research, mixtures, multiple portions, no consumption, collection replay and cycle retention")
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

