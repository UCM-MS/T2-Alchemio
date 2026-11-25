extends SceneTree
const Save = preload("res://scripts/save_service.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Research = preload("res://scripts/research.gd")
const PATH := "user://lab-save-test.json"
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
		check(restored.research.researched.size() == 2 and restored.research.completed_experiments.size() == 2 and "C" in restored.research.available_elements, "Separate process restores research and C")
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
	check(main.research.researched.size() == 2 and "C" not in main.research.available_elements, "Discovery ledger does not unlock C")
	check(main.laboratory.experiment.mode == "off" and main.laboratory.experiment.temperature == 20, "Reload resets thermal state")
	await screenshot("a7-restored")
	main.laboratory.rows.water.button.pressed.emit()
	main.laboratory.research_button.pressed.emit()
	check(main.research.researched.size() == 2 and main.laboratory.discovery.pending.is_empty(), "Reload cannot award repeated discovery")
	main.laboratory.discovery.hide()
	main.laboratory.return_button.pressed.emit()
	main.inventory.credit({"hydrogen": 2})
	main.laboratory.refresh()
	main.laboratory.rows.hydrogen.button.pressed.emit()
	main.laboratory.rows.hydrogen.button.pressed.emit()
	main.laboratory.rows.oxygen.button.pressed.emit()
	main.laboratory.action_buttons.ignite.pressed.emit()
	check(service.load_progress().data.completed_experiments.is_empty(), "Pending reaction is not saved as completed")
	main.laboratory.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	var checkpoint: Dictionary = service.load_progress().data
	check(checkpoint.inventory.water == 3 and checkpoint.inventory.hydrogen == 0 and checkpoint.inventory.oxygen == 0, "Reaction saves uncollected products and consumed reagents")
	check(checkpoint.completed_experiments == {"hydrogen_combustion": true}, "Reaction is saved together with its products")
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
	await check_legacy_saves()
	# Leave a known checkpoint for the second OS-process read test.
	var inventory = Inventory.new()
	var research = Research.new()
	inventory.credit({"water":2})
	inventory.add_to_sample("water")
	research.investigate({"water":1})
	research.investigate({"oxygen":1})
	research.complete_experiment("hydrogen_combustion")
	research.complete_experiment("electrolysis")
	check(service.save_progress(inventory,research), "Write cross-process fixture")
	finish()

func check_legacy_saves() -> void:
	for version in [1, 2]:
		for researched in [[], ["water"], ["water", "oxygen", "methane", "nitrogen", "ammonia"]]:
			var inventory := {"nitrogen": 3, "ammonia": 4} if researched.size() > 2 else {}
			for id in researched:
				if not inventory.has(id):
					inventory[id] = 2
			write_raw(JSON.stringify({"version": version, "researched": researched, "inventory": inventory}))
			var main = new_main()
			var expected_elements := ["H", "O", "C"] if researched.size() >= 2 else ["H", "O"]
			check(main.laboratory.visible and not main.discovery_notice.visible, "Legacy load is silent")
			check(main.research.available_elements == expected_elements, "Preserve prior carbon unlock")
			check(main.research.completed_experiments.is_empty(), "Migration does not invent reaction history")
			check(not main.inventory.stock.has("nitrogen") and not main.research.researched.has("ammonia"), "Remove retired substances from old saves")
			for id in ["water", "oxygen", "methane"]:
				check(main.inventory.stock[id] == inventory.get(id, 0), "Preserve legacy stock for " + id)
			main.laboratory.new_collection_requested.emit()
			check(main.collection_map.free_atoms.size() == (72 if "C" in expected_elements else 48), "Migrated collection map matches progression")
			main.queue_free()
			await process_frame
			main = new_main()
			check(main.research.available_elements == expected_elements, "Rewritten save preserves migration outcome")
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
