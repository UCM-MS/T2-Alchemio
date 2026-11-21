extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.collection_map.set_physics_process(false)
	for id in [0,1,2]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0,1,1)
	main.preview_page.board.connect_atoms(2,1,1)
	main.preview_page.finalize_assembly()
	main.discovery_notice.clear()
	main._new_collection()
	await process_frame
	main.collection_map.set_physics_process(false)
	for id in [0,2]:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	var board = main.preview_page.board
	board.connect_atoms(0,2,1)
	await process_frame
	await process_frame
	check(main.discovery_notice.current_id == "hydrogen", "Notice retains identity of newly discovered substance")
	check(main.discovery_notice.z_index > board.z_index, "Rebuilt assembly cannot occlude notice")
	await screenshot("notice-second-cycle")
	var before: Dictionary = board.graph.preview().duplicate(true)
	await click_control(main.discovery_notice.read_button)
	check(main.laboratory.discovery.visible and main.laboratory.discovery.current_id == "hydrogen", "Read button opens matching card from assembly")
	check(not main.laboratory.visible and main.preview_page.visible, "Reading does not switch phase")
	check(main.discovery_notice.timer.paused, "Notice timer pauses while reading")
	check(board.graph.preview() == before and not board.graph.finalized, "Reading preserves unfinished graph")
	await screenshot("notice-read-from-assembly")
	main.laboratory.discovery.get_ok_button().pressed.emit()
	check(not main.discovery_notice.timer.paused, "Closing card resumes notice timer")
	await click_control(main.preview_page.collection_button)
	check(main.laboratory.discovery.visible and main.laboratory.discovery.current_id.is_empty(), "Assembly collection button opens list")
	check(board.graph.preview() == before, "Collection preserves assembly")
	main.laboratory.discovery.show_substance("water")
	check(main.laboratory.discovery.current_id == "water", "Previously discovered substance can be read")
	main.laboratory.discovery.get_ok_button().pressed.emit()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("NOTICE PASS: second-cycle overlay, mouse read action, shared collection, paused timer and preserved graph")
	quit(0 if failures.is_empty() else 1)

func click_control(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size / 2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

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
