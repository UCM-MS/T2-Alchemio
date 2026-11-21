extends SceneTree
const Save = preload("res://scripts/save_service.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Research = preload("res://scripts/research.gd")
const PATH := "res://artifacts/a7-test-save.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func new_main():
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_service.path = PATH
	root.add_child(main)
	main.collection_map.set_physics_process(false)
	main.laboratory.set_process(false)
	return main

func run_checks() -> void:
	var service = Save.new()
	service.path = PATH
	var args := OS.get_cmdline_user_args()
	if "--read" in args:
		var restored = new_main()
		check(restored.inventory.stock.water == 2 and restored.inventory.sample.is_empty(), "Separate process restores combined water")
		check(restored.research.researched.size() == 2 and "C" in restored.research.available_elements, "Separate process restores research and C")
		check(restored.laboratory.visible and restored.laboratory.discovery.pending.is_empty(), "Restart opens lab without replaying rewards")
		restored.queue_free()
		await process_frame
		finish()
		return
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(PATH + suffix)
	var main = new_main()
	check(main.map_page.visible and not FileAccess.file_exists(PATH), "Fresh game starts on map")
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0,1,1)
	main.preview_page.board.connect_atoms(2,1,1)
	check(service.load_progress().data.researched.has("water") and service.load_progress().data.inventory.water == 0, "Immediate discovery saves before assembly grants portions")
	main.preview_page.board.connect_atoms(3,5,2)
	main.preview_page.finalize_assembly()
	check(service.load_progress().data.inventory.water == 1, "Assembly auto-saves")
	main.laboratory.rows.water.button.pressed.emit()
	main.laboratory.research_button.pressed.emit()
	main.laboratory.discovery.hide()
	check(service.load_progress().data.inventory.water == 1 and main.inventory.stock.water == 0, "Flask is saved once without mutating live stock")
	main.laboratory.return_button.pressed.emit()
	main.laboratory.rows.oxygen.button.pressed.emit()
	main.laboratory.research_button.pressed.emit()
	main.laboratory.discovery.hide()
	main.queue_free()
	await process_frame
	main = new_main()
	check(main.inventory.stock.water == 1 and main.inventory.stock.oxygen == 1 and main.inventory.sample.is_empty(), "Reload returns sample without doubling")
	check(main.research.researched.size() == 2 and "C" in main.research.available_elements, "C derives from unique discoveries")
	check(main.laboratory.experiment.mode == "off" and main.laboratory.experiment.temperature == 20, "Reload resets thermal state")
	await screenshot("a7-restored")
	main.laboratory.rows.water.button.pressed.emit()
	main.laboratory.research_button.pressed.emit()
	check(main.research.researched.size() == 2 and main.laboratory.discovery.pending.is_empty(), "Reload cannot award repeated discovery")
	main.laboratory.discovery.hide()
	main.laboratory.return_button.pressed.emit()
	main.inventory.credit({"methane":1,"oxygen":1})
	main.laboratory.refresh()
	main.laboratory.rows.methane.button.pressed.emit()
	main.laboratory.rows.oxygen.button.pressed.emit()
	main.laboratory.rows.oxygen.button.pressed.emit()
	main.laboratory._set_tool("heat")
	main.laboratory.experiment.step(14, main.inventory.sample)
	var saved: Dictionary = service.load_progress().data.inventory
	check(saved.water == 3 and saved.carbon_dioxide == 1 and saved.methane == 0 and saved.oxygen == 0, "Reaction saves products and consumed reactants")
	main.laboratory.new_collection_requested.emit()
	for id in [0,1]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0,1,1)
	main.queue_free()
	await process_frame
	main = new_main()
	check(main.assembly_atoms.is_empty() and main.preview_page.board.graph.atoms.is_empty() and main.inventory.stock.water == 3, "Unfinished graph is excluded while stock survives")
	main._request_new_game()
	check(main.reset_confirmation.visible, "Reset requires confirmation")
	await screenshot("a7-reset-confirmation")
	main.reset_confirmation.get_cancel_button().pressed.emit()
	check(main.inventory.stock.water == 3, "Cancel preserves progress")
	main._request_new_game()
	main.reset_confirmation.get_ok_button().pressed.emit()
	check(main.map_page.visible and main.research.researched.is_empty() and main.inventory.stock.water == 0, "Confirmed reset clears game and restarts map")
	check(service.load_progress().data.researched.is_empty(), "Reset persists empty checkpoint")
	main.queue_free()
	await process_frame
	# Validation and recovery use only this isolated test file.
	for invalid in [{}, {"version":"future","inventory":{},"researched":[]}, {"version":1,"inventory":{"water":-1},"researched":[]}, {"version":1,"inventory":{"water":1.5},"researched":[]}, {"version":1,"inventory":{"unknown":1},"researched":[]}]:
		check(service.validate(invalid).is_empty(), "Reject malformed save")
	write_raw("{")
	check(service.load_progress().status == "recovered", "Damaged primary recovers backup")
	write_raw('{"version":999,"inventory":{},"researched":[]}')
	check(service.load_progress().status == "invalid", "Future save is not downgraded")
	check(not service.save_progress(Inventory.new(),Research.new()), "Invalid save remains protected")
	check(service.reset_progress(Inventory.new(),Research.new()), "Explicit reset unblocks invalid save")
	var legacy_inventory = Inventory.new()
	legacy_inventory.credit({"water":1})
	check(service.save_progress(legacy_inventory,Research.new()), "Prepare legacy stock without manual research")
	var migrated = new_main()
	check(migrated.research.researched.has("water") and migrated.inventory.stock.water == 1, "Legacy owned substance becomes discovered without adding portions")
	migrated.queue_free()
	await process_frame
	migrated = new_main()
	check(not migrated.discovery_notice.visible and migrated.research.researched.has("water"), "Migrated discovery is saved and not notified twice")
	migrated.queue_free()
	await process_frame
	await check_a8_thresholds()
	await check_nitrogen_cycle()
	await check_reaction_cycle()
	# Leave a known checkpoint for the second OS-process read test.
	var inventory = Inventory.new()
	var research = Research.new()
	inventory.credit({"water":2})
	inventory.add_to_sample("water")
	research.investigate({"water":1})
	research.investigate({"oxygen":1})
	check(service.save_progress(inventory,research), "Write cross-process fixture")
	finish()

func check_a8_thresholds() -> void:
	var ids := ["water", "oxygen", "carbon_dioxide", "methane", "hydrogen"]
	for count in [0, 2, 3, 4, 5]:
		var discoveries := ids.slice(0, count)
		var stock := {}
		for id in discoveries:
			stock[id] = 2
		write_raw(JSON.stringify({"version": 1, "researched": discoveries, "inventory": stock}))
		for attempt in 2:
			var main = new_main()
			check(main.laboratory.visible and not main.discovery_notice.visible, "A8 resumes silently at %d discoveries" % count)
			check(("C" in main.research.available_elements) == (count >= 2) and ("N" in main.research.available_elements) == (count >= 4), "A8 restores both thresholds at %d discoveries" % count)
			check(main.research.researched.size() == count and main.inventory.sample.is_empty(), "Reload preserves collection size and returns a clean flask")
			for id in main.inventory.stock:
				check(main.inventory.stock[id] == stock.get(id, 0) and main.research.researched.has(id) == stock.has(id), "Reload preserves discoveries and exact stock: " + id)
			main._new_collection()
			check(main.collection_map.free_atoms.has(72) == (count >= 4), "Migrated game spawns the correct next map")
			main.queue_free()
			await process_frame

func check_nitrogen_cycle() -> void:
	write_raw(JSON.stringify({"version": 1, "researched": ["water", "oxygen", "carbon_dioxide", "methane"], "inventory": {}}))
	var main = new_main()
	var found: Array[String] = []
	main.research.discovered.connect(func(id: String): found.append(id))
	var expected_stock := 0
	for batches: int in [1, 2]:
		main.laboratory.new_collection_requested.emit()
		var arena = main.collection_map
		arena.set_physics_process(false)
		# Each group needs three N and three H for one N₂ and one NH₃.
		for i in range(3 * batches):
			check(arena.collect_atom(72 + i) and arena.collect_atom(2 * i), "Collect nitrogen and hydrogen for both models")
		if batches == 2:
			await screenshot("beta3-nitrogen-map")
		main.finish_button.pressed.emit()
		var board = main.preview_page.board
		if batches == 2:
			await screenshot("beta3-nitrogen-board")
		for i in batches:
			var first_n := 72 + i * 3
			board.connect_atoms(first_n, first_n + 1, 3)
			for h in 3:
				board.connect_atoms(first_n + 2, 2 * (3 * i + h), 1)
		check(board.graph.preview().products == {"nitrogen": batches, "ammonia": batches}, "Recognize distinct nitrogen models on one board")
		check(found == ["nitrogen", "ammonia"], "Discover each nitrogen substance once, even on repeat assembly")
		for id in ["nitrogen", "ammonia"]:
			check(main.inventory.stock[id] == expected_stock, "Discovery adds no stock before finishing")
		main.preview_page.finish_button.pressed.emit()
		expected_stock += batches
		for id in ["nitrogen", "ammonia"]:
			var stock_before: int = main.inventory.stock[id]
			check(stock_before == expected_stock, "Finished assembly credits each molecule exactly once")
			main.laboratory.rows[id].button.pressed.emit()
			check(main.inventory.sample == {id: 1}, "Move one portion into an empty flask")
			main.laboratory.research_button.pressed.emit()
			check(main.laboratory.discovery.current_id == id, "Open card for the flask contents")
			main.laboratory.discovery.hide()
			main.laboratory.return_button.pressed.emit()
			check(main.inventory.sample.is_empty() and main.inventory.stock[id] == stock_before, "Return portion without duplication")
	main.laboratory.rows.ammonia.button.pressed.emit()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(saved.version == 2 and saved.inventory.ammonia == 3, "Beta checkpoint marks extended catalog and includes flask contents")
	main.queue_free()
	await process_frame
	main = new_main()
	check(main.inventory.sample.is_empty() and not main.discovery_notice.visible, "Reload returns sample without replaying a discovery")
	for id in ["nitrogen", "ammonia"]:
		check(main.research.researched.has(id) and main.inventory.stock[id] == 3, "Restore nitrogen collection and exact stock")
		main.laboratory.discovery.show_substance(id)
		check(main.laboratory.discovery.current_id == id, "Read restored substance card")
	main.queue_free()
	await process_frame

func choose_instrument(lab: Control, id: String) -> void:
	for i in lab.instrument_select.item_count:
		if lab.instrument_select.get_item_metadata(i) == id:
			lab.instrument_select.select(i)
			lab.instrument_select.item_selected.emit(i)
			return
	check(false, "Missing instrument " + id)

func check_reaction_cycle() -> void:
	write_raw(JSON.stringify({"version": 2, "researched": ["water"], "inventory": {"water": 5}}))
	var main = new_main()
	var lab = main.laboratory
	var unlocks: Array[String] = []
	main.research.element_unlocked.connect(func(id: String): unlocks.append(id))
	check(lab.instrument_select.is_item_disabled(2), "Reactor locked initially")
	choose_instrument(lab, "electrolyzer")
	lab.rows.water.button.pressed.emit()
	check(lab.run_button.disabled and lab.process_notice.text.contains("H₂O"), "Show missing water before electrolysis")
	for i in 4:
		lab.rows.water.button.pressed.emit()
	lab.run_button.pressed.emit()
	check(main.inventory.sample == {"water": 3} and main.inventory.outlets == {"hydrogen": 2, "oxygen": 1}, "Two distinct outlets, excess water stays in input")
	check(unlocks == ["C"] and main.research.researched.size() == 3 and lab.progress_label.text.ends_with("1/2"), "Two products unlock carbon once and count toward nitrogen")
	lab.run_button.pressed.emit()
	check(lab.run_button.disabled and main.inventory.sample.water == 3, "Full outlets prevent a second batch despite excess input")
	await screenshot("beta4-electrolysis")
	lab.outlet_buttons.hydrogen.pressed.emit()
	lab.outlet_buttons.hydrogen.pressed.emit()
	check(main.inventory.stock.hydrogen == 2 and main.inventory.outlets == {"oxygen": 1}, "Retrieve one gas exactly once")
	main.queue_free()
	await process_frame
	main = new_main()
	lab = main.laboratory
	check(main.inventory.stock.water == 3 and main.inventory.stock.hydrogen == 2 and main.inventory.stock.oxygen == 1, "Reload counts uncollected gas and excess once")
	check(main.inventory.outlets.is_empty() and main.inventory.sample.is_empty() and not main.discovery_notice.visible, "Reload clears device without replay")
	choose_instrument(lab, "electrolyzer")
	for i in 2:
		lab.rows.water.button.pressed.emit()
	lab.run_button.pressed.emit()
	choose_instrument(lab, "flask")
	check(main.inventory.stock.hydrogen == 4 and main.inventory.stock.oxygen == 2 and main.inventory.outlets.is_empty(), "Switching device returns remaining gases")
	# Model discoveries used to prepare an unlocked reactor and one portion of N₂.
	main._discover_products({"carbon_dioxide": 1})
	main._discover_products({"nitrogen": 1})
	main.inventory.credit({"nitrogen": 1})
	lab.refresh()
	check(not lab.instrument_select.is_item_disabled(2), "Fourth discovery enables reactor")
	choose_instrument(lab, "reactor")
	lab.rows.nitrogen.button.pressed.emit()
	for i in 3:
		lab.rows.hydrogen.button.pressed.emit()
	check(not lab.run_button.disabled and not lab.heat_button.visible, "Reactor has its own action")
	lab.run_button.pressed.emit()
	check(main.inventory.sample == {"ammonia": 2} and main.research.researched.has("ammonia"), "Synthesis discovers ammonia before assembly")
	await screenshot("beta4-ammonia")
	main.queue_free()
	await process_frame
	main = new_main()
	check(main.inventory.stock.ammonia == 2 and main.inventory.stock.hydrogen == 1 and main.inventory.stock.nitrogen == 0, "Restore synthesis products and remaining stock")
	main.laboratory.new_collection_requested.emit()
	for atom_id in [72, 0, 2, 4]:
		main.collection_map.collect_atom(atom_id)
	main.finish_button.pressed.emit()
	for h in [0, 2, 4]:
		main.preview_page.board.connect_atoms(72, h, 1)
	main.preview_page.finish_button.pressed.emit()
	check(main.inventory.stock.ammonia == 3 and main.research.researched.size() == 6 and not main.discovery_notice.visible, "Assembly after synthesis gives a portion without another discovery")
	main.queue_free()
	await process_frame

func write_raw(text: String) -> void:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("A7 PASS: persistence, sample accounting, reaction products, unique research, clean reload, reset, validation and recovery")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename)
