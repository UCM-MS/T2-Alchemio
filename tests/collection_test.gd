extends SceneTree
## Integration checks for A1: real map, input, pickup and handoff controls.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	var arena = main.collection_map
	arena.set_physics_process(false)
	check(arena.cargo.is_empty(), "Empty initial cargo")
	check(main.finish_button.disabled, "Cannot finish empty collection")
	arena.finish_collection()
	check(arena.active and main.assembly_atoms.is_empty(), "Empty handoff rejected")
	check(arena.free_atoms.size() == 48, "Guaranteed initial supply")
	var counts := {"H": 0, "O": 0}
	for atom in arena.free_atoms.values():
		check(atom.element_id in ["H", "O"], "No locked elements")
		counts[atom.element_id] += 1
	check(counts.H == 24 and counts.O == 24, "Balanced H/O supply")
	var initial: Vector2 = arena.collector.position
	Input.action_press("move_right")
	arena._physics_process(0.1)
	Input.action_release("move_right")
	check(is_equal_approx(arena.collector.position.x - initial.x, 25.5), "Actual input moves collector")
	arena.collector.position = initial
	Input.action_press("move_right")
	Input.action_press("move_down")
	arena._physics_process(0.1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(is_equal_approx(arena.collector.position.distance_to(initial), 25.5), "No diagonal speed boost")
	arena.collector.move_in_arena(Vector2(-1, -1), 100, arena.WORLD_SIZE)
	check(arena.collector.position == Vector2(30, 30), "Top and left bounds include cargo")
	arena.collector.move_in_arena(Vector2(1, 1), 100, arena.WORLD_SIZE)
	check(arena.collector.position == arena.WORLD_SIZE - Vector2(30, 30), "Bottom and right bounds include cargo")
	arena.collector.position = arena.free_atoms[0].position
	arena._physics_process(0)
	check(arena.cargo.size() == 1 and not arena.free_atoms.has(0), "Contact pickup removes free atom")
	check(arena.collector.carried.size() == 1 and arena.collector.offsets == [Vector2.ZERO], "First atom replaces root without a duplicate")
	check(not arena.collect_atom(0), "Duplicate pickup rejected")
	check(not main.finish_button.disabled, "Finish enabled after pickup")
	arena.free_atoms[1].position = arena.collector.position + Vector2(38, 0)
	arena._physics_process(0)
	check(arena.cargo.size() == 2, "Second atom attaches by contact")
	arena.free_atoms[2].position = arena.collector.position + arena.collector.offsets[1] + Vector2(38, 0)
	arena._physics_process(0)
	check(arena.cargo.size() == 3, "Touching an attached atom collects too")
	for id in range(1, 13):
		arena.collect_atom(id)
	check(arena.cargo.size() == 13 and arena.free_atoms.size() == 35, "Capacity preserves total atom count")
	check(not arena.collect_atom(13) and arena.free_atoms.has(13), "Full collector leaves extra atom on map")
	check(arena.collector.carried == arena.cargo, "Visual cargo matches data")
	for i in range(1, 13):
		var parent: int = arena.collector.parents[i]
		check(parent >= 0 and parent < i, "Attachments form a connected tree")
		check(is_equal_approx(arena.collector.offsets[i].distance_to(arena.collector.offsets[parent]), 60), "Consistent stick length")
		for j in range(i):
			check(arena.collector.offsets[i].distance_to(arena.collector.offsets[j]) >= 51.9, "Attached atoms do not overlap")
	arena.collector.move_in_arena(Vector2(-1, -1), 100, arena.WORLD_SIZE)
	for offset in arena.collector.offsets:
		check((arena.collector.position + offset).x >= 30 and (arena.collector.position + offset).y >= 30, "Entire group remains within world")
	arena.collector.position = arena.WORLD_SIZE / 2
	await process_frame
	arena.camera.force_update_scroll()
	var hud_before: Vector2 = main.cargo_label.get_global_transform_with_canvas().origin
	var camera_before: Vector2 = arena.camera.get_screen_center_position()
	var atom_before: Vector2 = arena.free_atoms[13].position
	arena.collector.position += Vector2(180, 0)
	arena.camera.force_update_scroll()
	check(arena.camera.get_screen_center_position().x > camera_before.x, "Camera follows movement")
	check(main.cargo_label.get_global_transform_with_canvas().origin == hud_before, "HUD stays fixed as camera moves")
	check(arena.free_atoms[13].position == atom_before, "Camera does not relocate world atoms")
	await screenshot("res://artifacts/a1-map.png")
	main.finish_button.pressed.emit()
	check(not arena.active and main.preview_page.visible, "Button enters handoff and freezes map")
	check(main.assembly_atoms == arena.cargo and main.assembly_atoms.size() == 13, "All IDs and elements survive handoff")
	main.assembly_atoms[0]["element"] = "test"
	check(arena.cargo[0]["element"] == "H", "Handoff is an independent deep copy")
	main.assembly_atoms[0]["element"] = "H"
	arena.finish_collection()
	check(main.assembly_atoms.size() == 13, "Repeated handoff does not duplicate atoms")
	check(not arena.collect_atom(13), "Cannot collect during preview")
	await screenshot("res://artifacts/a1-handoff.png")
	main._return_to_map()
	check(arena.active and arena.cargo.size() == 13 and arena.free_atoms.size() == 35, "Return preserves map and cargo")
	main.finish_button.pressed.emit()
	check(main.assembly_atoms.size() == 13 and main.preview_page.board.graph.atoms.size() == 13, "Second visit does not duplicate assembly atoms")
	if failures.is_empty():
		print("A1 PASS: input, bounds, pickup, capacity, identities, handoff, resume")
	else:
		for failure in failures:
			push_error(failure)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

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
