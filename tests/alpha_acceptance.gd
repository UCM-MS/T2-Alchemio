extends Node
## Runs the same acceptance journey in native Godot and a separate Web QA export.
var failures: Array[String] = []
var checks := 0
var main: Control
const SAVE_PATH := "user://alpha_acceptance_test.json"

func _ready() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.save_service.path = SAVE_PATH
	get_tree().root.add_child(main)
	main.collection_map.set_physics_process(false)
	main.laboratory.set_process(false)
	await get_tree().process_frame
	check(main.collection_map.free_atoms.size() == 48, "Start: H/O only")
	for id in 6:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	var board = main.preview_page.board
	board.connect_atoms(0,1,1)
	board.connect_atoms(2,1,1)
	board.connect_atoms(3,5,2)
	check(board.graph.preview().products == {"water":1,"oxygen":1}, "Build water and oxygen")
	main.preview_page.board.pack_atom(0)
	main.preview_page.board.pack_atom(3)
	main.preview_page.request_finish()
	check(main.preview_page.confirmation.visible, "Leftover requires confirmation")
	main.preview_page.confirmation.get_ok_button().pressed.emit()
	check(main.last_assembly_result.discarded_atoms.size() == 1, "Exactly one H discarded")
	check(main.inventory.stock.water == 1 and main.inventory.stock.oxygen == 1, "One portion each")
	var lab = main.laboratory
	check(main.research.researched.size() == 2, "Assembly discovers substances automatically")
	lab.rows.water.button.pressed.emit()
	lab.research_button.pressed.emit()
	check(main.research.researched.size() == 2 and lab.discovery.current_id == "water", "View automatically discovered water")
	lab.discovery.get_ok_button().pressed.emit()
	lab.research_button.pressed.emit()
	check(main.research.researched.size() == 2, "Repeat gives no discovery")
	lab.discovery.get_ok_button().pressed.emit()
	lab._select_station("liquid")
	lab.rows.water.button.pressed.emit()
	lab._set_tool("heat")
	lab.experiment.step(10, main.inventory.sample)
	check(lab.experiment.boiling and lab.experiment.temperature == 100, "Water boils at 100 °C")
	lab._set_tool("cool")
	lab.experiment.step(1, main.inventory.sample)
	check(not lab.experiment.boiling and main.research.researched.size() == 2, "Cooling creates no new substance")
	check("C" not in main.research.available_elements, "Discoveries alone do not unlock carbon")
	lab._select_station("combustion")
	main.inventory.credit({"hydrogen": 2})
	lab.refresh()
	lab.rows.hydrogen.button.pressed.emit()
	lab.rows.hydrogen.button.pressed.emit()
	lab.rows.oxygen.button.pressed.emit()
	lab.action_buttons.ignite.pressed.emit()
	lab.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	check(main.research.stage_progress() == Vector2i(1, 2), "First chemical experiment")
	lab._select_station("liquid")
	lab._select_instrument("electrodes")
	lab.rows.water.button.pressed.emit()
	lab.rows.water.button.pressed.emit()
	lab.action_buttons.current.pressed.emit()
	lab.experiment.step(2, main.inventory.sample, main.inventory.outlets)
	check(main.inventory.outlets == {"hydrogen": 2, "oxygen": 1}, "Electrolysis uses separate outlets")
	check(main.discovery_notice.visible and "C" in main.research.available_elements, "Two reactions unlock carbon")
	lab.new_collection_requested.emit()
	await get_tree().process_frame
	main.collection_map.set_physics_process(false)
	check(main.collection_map.free_atoms.size() == 72, "Next map has carbon")
	for id in [48,1,3]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	board = main.preview_page.board
	board.connect_atoms(48,1,2)
	board.connect_atoms(48,3,2)
	check(board.graph.preview().products == {"carbon_dioxide":1}, "Build O=C=O")
	main.preview_page.board.pack_atom(48)
	main.preview_page.request_finish()
	lab.rows.carbon_dioxide.button.pressed.emit()
	lab.research_button.pressed.emit()
	check(main.research.researched.has("carbon_dioxide"), "Research carbon dioxide")
	lab.discovery.get_ok_button().pressed.emit()
	lab.collection_button.pressed.emit()
	lab.discovery.show_substance("carbon_dioxide")
	check(lab.discovery.current_id == "carbon_dioxide", "Reopen CO2 from collection")
	lab.discovery.get_ok_button().pressed.emit()
	check(main.save_service.save_progress(main.inventory,main.research), "Save with sample in flask")
	main.queue_free()
	await get_tree().process_frame
	main = load("res://scenes/main.tscn").instantiate()
	main.save_service.path = SAVE_PATH
	get_tree().root.add_child(main)
	main.collection_map.set_physics_process(false)
	main.laboratory.set_process(false)
	lab = main.laboratory
	check(main.research.researched.has("carbon_dioxide") and "C" in main.research.available_elements and main.research.completed_experiments.size() == 2, "Reload restores discoveries, experiments and element")
	check(main.inventory.sample.is_empty() and main.inventory.stock.carbon_dioxide == 1, "Reload returns flask exactly once")
	check(main.inventory.stock.water == 1 and main.inventory.stock.oxygen == 1, "Old stock retained across journey")
	check(lab.discovery.pending.is_empty() and not lab.discovery.visible, "Reload has no reward replay")
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		for dimensions in [Vector2i(1152,648),Vector2i(960,540),Vector2i(800,800)]:
			get_tree().root.size = dimensions
			await screenshot("a8-lab-%dx%d" % [dimensions.x,dimensions.y])
		get_tree().root.size = Vector2i(1152,648)
		lab.help_dialog.open("Pomoc", "Uloženie a ovládanie\n".repeat(30))
		await screenshot("a8-scroll-help")
		lab.help_dialog.get_ok_button().pressed.emit()
		check(not lab.help_dialog.visible, "Help closes")
		lab.collection_button.pressed.emit()
		await screenshot("a8-collection")
		lab.discovery.get_ok_button().pressed.emit()
	var result := "ALPHA ACCEPTANCE PASS" if failures.is_empty() else "ALPHA ACCEPTANCE FAILED"
	print("%s · %d checks" % [result,checks])
	for failure in failures:
		push_error(failure)
	if OS.has_feature("web"):
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		var panel := PanelContainer.new()
		panel.position = Vector2(28,140)
		panel.custom_minimum_size = Vector2(640,120)
		layer.add_child(panel)
		var label := Label.new()
		label.text = "%s\n%d checks · collection / bonds / leftovers / research / boiling / cooling\nunlock queue / carbon map / CO2 / collection / save / clean reload\n%s" % [result,checks,"\n".join(failures)]
		panel.add_child(label)
	else:
		get_tree().quit(0 if failures.is_empty() else 1)

func screenshot(filename: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
