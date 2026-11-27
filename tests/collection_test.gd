extends SceneTree
## Integration checks for A1: real map, input, pickup and handoff controls.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	var arena = main.collection_map
	arena.set_physics_process(false)
	await process_frame
	await process_frame
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
	check_airflow(arena)
	# Keep the explicit pickup fixtures clear of the steering tests.
	for id in 3:
		arena.free_atoms[id].position = Vector2(80 + id * 45, 105)
	var initial: Vector2 = arena.collector.position
	arena.camera.force_update_scroll()
	var center: Vector2 = arena.get_global_transform_with_canvas() * initial
	map_click(center + Vector2(0, 100), true)
	arena._physics_process(0.1)
	check(arena.collector.position.is_equal_approx(initial + Vector2(0, 25.5)), "Holding left on the map steers at collection speed")
	var motion := InputEventMouseMotion.new()
	motion.position = arena.get_global_transform_with_canvas() * (arena.collector.position + Vector2(5, 0))
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	arena._physics_process(0.1)
	check(arena.collector.position.is_equal_approx(initial + Vector2(5, 25.5)), "Moving the cursor redirects steering without overshoot")
	map_click(motion.position, false)
	arena.collector.position = initial
	arena._physics_process(0.1)
	check(arena.collector.position == initial, "Releasing the mouse stops steering")
	map_click(Vector2(55, 45), true)
	arena._physics_process(0.1)
	check(arena.collector.position == initial, "Pressing the reset button does not steer")
	map_click(Vector2(55, 45), false)
	main.reset_confirmation.hide()
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
	var margin := Vector2.ONE * float(arena.collector.WORLD_MARGIN)
	check(arena.collector.position == margin, "Top and left bounds leave room for the bag")
	arena.collector.move_in_arena(Vector2(1, 1), 100, arena.WORLD_SIZE)
	check(arena.collector.position == arena.WORLD_SIZE - margin, "Bottom and right bounds leave room for the bag")
	# The intake follows the cursor even while the player stands still.
	arena.collector.position = Vector2(315, 295)
	arena.camera.force_update_scroll()
	arena._physics_process(0)
	var forward := Vector2.from_angle(arena.collector.heading)
	arena.free_atoms[0].position = arena.collector.position + forward * 32.0
	arena._physics_process(0)
	check(arena.cargo.size() == 1 and not arena.free_atoms.has(0), "Intake pickup removes free atom")
	check(not arena.collect_atom(0), "Duplicate pickup rejected")
	check(not main.finish_button.disabled, "Finish enabled after pickup")
	arena.free_atoms[1].position = arena.collector.position - forward * 32.0
	arena._physics_process(0)
	check(arena.cargo.size() == 1, "Back of the vacuum does not collect atoms")
	arena.free_atoms[1].position = arena.collector.position + forward * 32.0
	arena._physics_process(0)
	check(arena.cargo.size() == 2, "Intake picks up a second atom")
	var bag = arena.collector.bag
	var particle = bag.atoms[0]
	var original_offset: Vector2 = particle.position
	arena.collector.aim_at(arena.collector.position - forward * 100.0)
	check(bag.position.is_equal_approx(arena.collector.BAG_OFFSET.rotated(arena.collector.heading)), "Bag follows the rear of the vacuum as it aims")
	arena._advance_bag(0.04)
	check(particle.get_parent() == bag and particle.position != original_offset, "Collected atom moves freely inside the bag")
	for id in range(1, 12):
		arena.collect_atom(id)
	check(arena.cargo.size() == 12 and arena.free_atoms.size() == 36, "Capacity preserves total atom count")
	check(not arena.collect_atom(12) and arena.free_atoms.has(12), "Full collector leaves extra atom on map")
	check(not arena.collector.suction_enabled, "Full collector stops pulling atoms")
	check_bag_impact(arena)
	arena.collector.move_in_arena(Vector2(-1, -1), 100, arena.WORLD_SIZE)
	check(bag.global_position.x >= bag.RADIUS and bag.global_position.y >= bag.RADIUS, "Bag stays within the map when the player reaches an edge")
	arena.collector.position = arena.WORLD_SIZE / 2
	await process_frame
	arena.camera.force_update_scroll()
	var hud_before: Vector2 = main.cargo_label.get_global_transform_with_canvas().origin
	var camera_before: Vector2 = arena.camera.get_screen_center_position()
	var atom_before: Vector2 = arena.free_atoms[12].position
	arena.collector.position += Vector2(180, 0)
	arena.camera.force_update_scroll()
	check(arena.camera.get_screen_center_position().x > camera_before.x, "Camera follows movement")
	check(main.cargo_label.get_global_transform_with_canvas().origin == hud_before, "HUD stays fixed as camera moves")
	check(arena.free_atoms[12].position == atom_before, "Camera does not relocate world atoms")
	await screenshot("res://artifacts/a1-map.png")
	main.finish_button.pressed.emit()
	check(not arena.active and main.preview_page.visible, "Button enters handoff and freezes map")
	arena._physics_process(0.1)
	check(arena.cargo.size() == 12 and arena.free_atoms.size() == 36, "Handoff preserves collection state")
	check(main.assembly_atoms == arena.cargo and main.assembly_atoms.size() == 12, "All IDs and elements survive handoff")
	main.assembly_atoms[0]["element"] = "test"
	check(arena.cargo[0]["element"] == "H", "Handoff is an independent deep copy")
	main.assembly_atoms[0]["element"] = "H"
	arena.finish_collection()
	check(main.assembly_atoms.size() == 12, "Repeated handoff does not duplicate atoms")
	check(not arena.collect_atom(12), "Cannot collect during preview")
	await screenshot("res://artifacts/a1-handoff.png")
	main._return_to_map()
	check(arena.active and arena.cargo.size() == 12 and arena.free_atoms.size() == 36, "Return preserves map and cargo")
	main.finish_button.pressed.emit()
	check(main.assembly_atoms.size() == 12 and main.preview_page.board.graph.atoms.size() == 12, "Second visit does not duplicate assembly atoms")
	if failures.is_empty():
		print("A1 PASS: input, gas drift, suction, bag collisions, tears, escape, capacity, handoff")
	else:
		for failure in failures:
			push_error(failure)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check_airflow(arena: Node2D) -> void:
	var collector = arena.collector
	var origin: Vector2 = collector.position
	collector.aim_at(origin + Vector2.RIGHT)
	var near: Vector2 = collector.suction_velocity(origin + Vector2(70, 0))
	var far: Vector2 = collector.suction_velocity(origin + Vector2(150, 0))
	check(near.x < far.x and far.x < 0.0, "Suction is stronger near the intake")
	check(collector.suction_velocity(origin + Vector2(50, 90)) == Vector2.ZERO, "Suction only applies inside the invisible cone")
	collector.aim_at(origin + Vector2.LEFT)
	check(collector.suction_velocity(origin + Vector2(70, 0)) == Vector2.ZERO, "Suction direction changes when the intake turns")
	collector.aim_at(origin + Vector2.RIGHT)
	var atom = arena.free_atoms[2]
	atom.position = origin + Vector2(112, 40)
	atom.velocity = Vector2(0, 75)
	var drift_only: Vector2 = atom.position + atom.velocity * 0.02
	arena._advance_free_atoms(0.02)
	check(atom.position.x < drift_only.x and atom.position.y < drift_only.y, "Suction bends a drifting atom's path toward the intake")
	atom.position = origin + Vector2(-100, -80)
	var unobstructed: Vector2 = atom.position + atom.velocity * 0.02
	arena._advance_free_atoms(0.02)
	check(atom.position.is_equal_approx(unobstructed), "Atoms outside the cone still drift")

func check_bag_impact(arena: Node2D) -> void:
	arena.collector.position = arena.WORLD_SIZE / 2.0
	var bag = arena.collector.bag
	var particle = bag.atoms[0]
	for candidate in bag.atoms:
		if candidate.position.x < particle.position.x:
			particle = candidate
	var direction := Vector2.LEFT
	particle.position = direction * (bag.INNER_RADIUS - 0.7)
	particle.velocity = direction * 100.0
	arena._advance_bag(0.025)
	check(particle.velocity.x > 0.0 and arena.cargo.size() == 12, "Intact fabric reflects particles")
	arena.ball_spawn_in = 0.0
	arena._advance_balls(0.01)
	check(arena.balls.size() == 1, "Black balls spawn and move in the collection map")
	if arena.balls.is_empty():
		return
	var ball = arena.balls[0]
	ball.global_position = bag.to_global(direction * (bag.RADIUS + ball.RADIUS - 1.0))
	arena._advance_balls(0.0)
	check(bag.tears.size() == 1 and bag.tears[0].is_equal_approx(direction) and arena.balls.is_empty(), "A hit opens the fabric at the contact angle")
	var escaped_id: int = particle.atom_id
	particle.position = direction * (bag.INNER_RADIUS - 0.7)
	particle.velocity = direction * 100.0
	arena._advance_bag(0.025)
	check(particle.get_parent() == arena and arena.free_atoms.get(escaped_id) == particle, "A particle exits only after reaching the tear")
	check(arena.cargo.size() + arena.free_atoms.size() == 48 and arena.cargo.size() < 12 and arena.collector.suction_enabled, "Escape updates cargo count and reopens the intake")
	check(not arena.collect_atom(escaped_id), "A leaking particle is not immediately sucked back in")
	var escaped_ids: Array[int] = []
	for atom in arena.free_atoms.values():
		if atom.suction_cooldown > 0.0:
			escaped_ids.append(atom.atom_id)
	arena._advance_free_atoms(arena.ESCAPE_COOLDOWN)
	for id in escaped_ids:
		check(arena.collect_atom(id), "Escaped particle can be collected again by ID")
	check(arena.cargo.size() == 12, "Recovered particles refill the bag")

func map_click(point: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	root.push_input(button, true)

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
