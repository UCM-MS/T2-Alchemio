extends Node2D
signal cargo_changed(atoms: Array[Dictionary], capacity: int)
signal collection_finished(atoms: Array[Dictionary])
const Catalog = preload("res://scripts/catalog.gd")
const Atom = preload("res://scripts/atom.gd")
const Collector = preload("res://scripts/collector.gd")
const Ball = preload("res://scripts/collection_ball.gd")
const Bag = preload("res://scripts/collection_bag.gd")
const Abilities = preload("res://scripts/robot_abilities.gd")
const WORLD_SIZE := Vector2(2600, 1800)
const GAS_SPEED := 155.0
const ESCAPE_COOLDOWN := 0.85
var collector: Collector
var camera: Camera2D
var free_atoms: Dictionary = {}
var cargo: Array[Dictionary] = []
var capacity: int
var active := true
var following_mouse := false
var pointer_position := Vector2.ZERO
var available_elements: Array[String] = ["H", "O"]
var balls: Array[Ball] = []
var ball_spawn_in: float
var robot_module := ""
var controls_blocked := false
var ability_cooldown := 0.0
var boost_left := 0.0
var shield_left := 0.0
var pulse_left := 0.0
var hook_tip := Vector2.ZERO
var hook_direction := Vector2.ZERO
var hook_distance_left := 0.0
var hook_width := 0.0
var hook_hits_left := 0
var hook_targets: Array[int] = []

func _ready() -> void:
	var data: Dictionary = Catalog.load_data()
	capacity = int(data["collection"]["capacity"])
	collector = Collector.new()
	collector.name = "Collector"
	add_child(collector)
	collector.position = WORLD_SIZE / 2
	collector.z_index = 1
	ball_spawn_in = randf_range(4.0, 6.0)
	get_window().focus_exited.connect(func(): following_mouse = false)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	collector.add_child(camera)
	# Spawn in world coordinates, independently of the window and camera.
	for i in 48:
		var atom := Atom.new()
		atom.configure(i, data["elements"][i % 2])
		atom.position = Vector2(220 + (i % 8) * 305, 200 + floori(i / 8.0) * 280)
		# Lighter particles drift faster at the same temperature.
		var speed := GAS_SPEED * randf_range(0.85, 1.15) / sqrt(atom.relative_mass)
		atom.velocity = Vector2.from_angle(randf_range(0.0, TAU)) * speed
		add_child(atom)
		free_atoms[i] = atom
	# One nearby choice of each element; neither touches the starting collector.
	free_atoms[0].position = collector.position + Vector2(110, -15)
	free_atoms[1].position = collector.position + Vector2(-110, 15)
	free_atoms[0].velocity = Vector2(0.16, -1.0).normalized() * free_atoms[0].velocity.length()
	free_atoms[1].velocity = Vector2(-0.16, 1.0).normalized() * free_atoms[1].velocity.length()
	for element in data.elements:
		if element.id != "C" or element.id not in available_elements:
			continue
		var origin := Vector2(330, 325)
		var first_id := free_atoms.size()
		for i in 24:
			var atom := Atom.new()
			atom.configure(first_id + i, element)
			atom.position = origin + Vector2((i % 8) * 290, floori(i / 8.0) * 430)
			add_child(atom)
			free_atoms[first_id + i] = atom
		free_atoms[first_id].position = collector.position + Vector2(0, 130)
	cargo_changed.emit(cargo.duplicate(true), capacity)
	queue_redraw()

func handle_map_input(event: InputEvent) -> void:
	if not active or controls_blocked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		following_mouse = event.pressed and not event.canceled
		pointer_position = event.position
	elif event is InputEventMouseMotion and following_mouse:
		pointer_position = event.position
		following_mouse = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		if active and not controls_blocked and not robot_module.is_empty():
			collector.aim_at(get_global_mouse_position())
			activate_ability()
			get_viewport().set_input_as_handled()

func activate_ability() -> bool:
	if not active or controls_blocked or ability_cooldown > 0.0 or not Abilities.MODULES.has(robot_module):
		return false
	var ability: Dictionary = Abilities.MODULES[robot_module]
	var forward := Vector2.from_angle(collector.heading)
	ability_cooldown = Abilities.COOLDOWN
	match ability.mode:
		"hook":
			hook_tip = collector.position + forward * Collector.INTAKE_OFFSET
			hook_direction = forward
			hook_distance_left = ability.reach
			hook_width = ability.width
			hook_hits_left = ability.count
		"pulse":
			pulse_left = 0.32
			collector.pulse_radius = ability.radius
			for atom: Atom in free_atoms.values():
				if collector.position.distance_squared_to(atom.position) <= ability.radius ** 2:
					if atom.velocity.is_zero_approx():
						atom.velocity = collector.position.direction_to(atom.position) * 115.0
						if atom.velocity.is_zero_approx():
							atom.velocity = forward * 115.0
					else:
						atom.velocity = atom.velocity.rotated(ability.turn) * ability.speed
			for ball in balls:
				if collector.position.distance_squared_to(ball.position) <= ability.radius ** 2:
					ball.velocity = ball.velocity.rotated(ability.turn) * ability.speed
					ball.queue_redraw()
		"boost":
			boost_left = ability.duration
			collector.suction_multiplier = ability.suction
		"blink":
			collector.position += forward * float(ability.reach)
			collector.move_in_arena(Vector2.ZERO, 0.0, WORLD_SIZE)
			shield_left = ability.get("shield", 0.0)
			collector.shielded = shield_left > 0.0
			pulse_left = 0.16
			collector.pulse_radius = 64.0
	_refresh_ability_effects()
	return true

func _advance_hook(delta: float) -> void:
	if cargo.size() >= capacity:
		hook_targets.clear()
	if hook_distance_left <= 0.0:
		return
	var distance := minf(hook_distance_left, delta * 850.0)
	var start := hook_tip
	hook_tip += hook_direction * distance
	hook_distance_left -= distance
	var hits: Array[Atom] = []
	for atom: Atom in free_atoms.values():
		if atom.atom_id in hook_targets or atom.suction_cooldown > 0.0:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(atom.position, start, hook_tip)
		if closest.distance_squared_to(atom.position) <= (hook_width + Atom.RADIUS) ** 2:
			hits.append(atom)
	hits.sort_custom(func(first: Atom, second: Atom) -> bool:
		return start.distance_squared_to(first.position) < start.distance_squared_to(second.position))
	for i in mini(hits.size(), hook_hits_left):
		hook_targets.append(hits[i].atom_id)
		hook_hits_left -= 1
	if hook_hits_left == 0:
		hook_distance_left = 0.0

func _refresh_ability_effects() -> void:
	collector.hook_points.clear()
	if hook_distance_left > 0.0:
		collector.hook_points.append(to_global(hook_tip))
	for id in hook_targets:
		if free_atoms.has(id):
			collector.hook_points.append(free_atoms[id].global_position)
	collector.pulse_fraction = pulse_left / 0.32
	collector.queue_redraw()

func _physics_process(delta: float) -> void:
	if not active or controls_blocked:
		return
	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	boost_left = maxf(0.0, boost_left - delta)
	shield_left = maxf(0.0, shield_left - delta)
	pulse_left = maxf(0.0, pulse_left - delta)
	collector.shielded = shield_left > 0.0
	if boost_left <= 0.0:
		collector.suction_multiplier = 1.0
	var speed_multiplier := 2.0 if boost_left > 0.0 else 1.0
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if following_mouse and direction.is_zero_approx() and delta > 0.0:
		# The camera moves under a held cursor, even between mouse motion events.
		var target := get_global_transform_with_canvas().affine_inverse() * pointer_position
		var offset: Vector2 = target - collector.position
		direction = (offset / (Collector.SPEED * delta * speed_multiplier)).limit_length()
	collector.move_in_arena(direction, delta * speed_multiplier, WORLD_SIZE)
	collector.aim_at(get_global_mouse_position())
	if delta > 0.0:
		_advance_hook(delta)
		_advance_free_atoms(delta)
		_advance_balls(delta)
		_advance_bag(delta)
		_refresh_ability_effects()
	if cargo.size() >= capacity:
		return
	for id in free_atoms.keys():
		if collector.reaches_intake(free_atoms[id].position, Atom.RADIUS):
			collect_atom(id)

func _advance_free_atoms(delta: float) -> void:
	for atom: Atom in free_atoms.values():
		atom.suction_cooldown = maxf(0.0, atom.suction_cooldown - delta)
		if atom.atom_id in hook_targets:
			var goal := collector.position + Vector2.from_angle(collector.heading) * (Collector.INTAKE_OFFSET + 6.0)
			atom.position = atom.position.move_toward(goal, 720.0 * delta)
			_reflect_at_walls(atom)
			continue
		var airflow := Vector2.ZERO if atom.suction_cooldown > 0.0 else collector.suction_velocity(atom.position)
		atom.position += (atom.velocity + airflow) * delta
		_reflect_at_walls(atom)
		if atom.element_id not in ["H", "O"]:
			atom.velocity = atom.velocity.move_toward(Vector2.ZERO, 155.0 * delta)

func _reflect_at_walls(atom: Atom) -> void:
	var padding := Vector2.ONE * Atom.RADIUS
	var clamped := atom.position.clamp(padding, WORLD_SIZE - padding)
	var overflow := atom.position - clamped
	if overflow.x * atom.velocity.x > 0.0:
		atom.velocity.x = -atom.velocity.x
	if overflow.y * atom.velocity.y > 0.0:
		atom.velocity.y = -atom.velocity.y
	atom.position = clamped

func _advance_balls(delta: float) -> void:
	ball_spawn_in -= delta
	if ball_spawn_in <= 0.0:
		_spawn_ball()
		ball_spawn_in = randf_range(4.5, 7.2)
	var bounds := Rect2(Vector2.ZERO, WORLD_SIZE).grow(65.0)
	for index in range(balls.size() - 1, -1, -1):
		var ball := balls[index]
		ball.position += ball.velocity * delta
		var hit_bag := ball.global_position.distance_squared_to(collector.bag.global_position) <= (Bag.RADIUS + Ball.RADIUS) ** 2
		var hit_body := ball.position.distance_squared_to(collector.position) <= (Collector.RADIUS + Ball.RADIUS) ** 2
		if hit_bag and not collector.shielded:
			collector.bag.puncture(ball.global_position)
		if hit_bag or hit_body or not bounds.has_point(ball.position):
			balls.remove_at(index)
			ball.hide()
			ball.queue_free()

func _spawn_ball() -> void:
	var padding := Vector2.ONE * Ball.RADIUS
	for attempt in 6:
		var approach := Vector2.from_angle(randf_range(0.0, TAU))
		var spawn := (collector.position + approach * randf_range(380.0, 555.0)).clamp(padding, WORLD_SIZE - padding)
		if spawn.distance_squared_to(collector.position) < 325.0 ** 2:
			continue
		var target := to_local(collector.bag.global_position) + approach.orthogonal() * randf_range(-90.0, 90.0)
		var ball := Ball.new()
		ball.position = spawn
		ball.velocity = spawn.direction_to(target) * randf_range(145.0, 205.0)
		ball.z_index = 2
		add_child(ball)
		balls.append(ball)
		return

func _advance_bag(delta: float) -> void:
	var bag := collector.bag
	var escaped := bag.step(delta)
	if escaped.is_empty():
		return
	for atom in escaped:
		var direction := atom.position.normalized().rotated(bag.global_rotation)
		var exit_position := bag.global_position + direction * (Bag.RADIUS + Atom.RADIUS + 3.0)
		var exit_velocity := atom.velocity.rotated(bag.global_rotation) + direction * 58.0
		atom.reparent(self)
		atom.global_position = exit_position
		atom.global_rotation = 0.0
		atom.scale = Vector2.ONE
		atom.velocity = exit_velocity
		atom.suction_cooldown = ESCAPE_COOLDOWN
		_reflect_at_walls(atom)
		free_atoms[atom.atom_id] = atom
		for index in cargo.size():
			if cargo[index].id == atom.atom_id:
				cargo.remove_at(index)
				break
	collector.suction_enabled = true
	cargo_changed.emit(cargo.duplicate(true), capacity)

func collect_atom(id: int) -> bool:
	if not active or cargo.size() >= capacity or not free_atoms.has(id):
		return false
	var atom: Atom = free_atoms[id]
	if atom.suction_cooldown > 0.0:
		return false
	var record := {"id": id, "element": atom.element_id}
	cargo.append(record)
	free_atoms.erase(id)
	hook_targets.erase(id)
	collector.bag.insert_atom(atom)
	if cargo.size() == capacity:
		collector.suction_enabled = false
	cargo_changed.emit(cargo.duplicate(true), capacity)
	return true

func clear_cargo() -> void:
	cargo.clear()
	collector.bag.clear_contents()
	collector.suction_enabled = true
	cargo_changed.emit(cargo.duplicate(true), capacity)

func finish_collection() -> void:
	if not active or cargo.is_empty():
		return
	active = false
	following_mouse = false
	collection_finished.emit(cargo.duplicate(true))

func resume_collection() -> void:
	active = true
	cargo_changed.emit(cargo.duplicate(true), capacity)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("101d2b"))
	for x in range(20, int(WORLD_SIZE.x), 48):
		for y in range(20, int(WORLD_SIZE.y), 48):
			draw_circle(Vector2(x, y), 1, Color(0.42, 0.59, 0.68, 0.16))
