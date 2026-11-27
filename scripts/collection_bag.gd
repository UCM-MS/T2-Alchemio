extends Node2D

const Atom = preload("res://scripts/atom.gd")
const RADIUS := 53.0
const ATOM_SCALE := 0.49
const ATOM_RADIUS := Atom.RADIUS * ATOM_SCALE
const INNER_RADIUS := RADIUS - ATOM_RADIUS - 3.0
const TEAR_HALF_ANGLE := 0.42
const IMPACT_DURATION := 0.32

var atoms: Array[Atom] = []
var tears: Array[Vector2] = []
var impact_direction := Vector2.ZERO
var impact_time := 0.0

func insert_atom(atom: Atom) -> void:
	atom.reparent(self)
	atom.position = _entry_position()
	atom.rotation = -global_rotation
	atom.scale = Vector2.ONE * ATOM_SCALE
	atom.velocity = Vector2.LEFT.rotated(randf_range(-0.55, 0.55)) * 105.0 / sqrt(atom.relative_mass)
	atoms.append(atom)

func clear_contents() -> void:
	for atom in atoms:
		atom.hide()
		atom.queue_free()
	atoms.clear()
	tears.clear()
	impact_time = 0.0
	queue_redraw()

func step(delta: float) -> Array[Atom]:
	if impact_time > 0.0:
		impact_time = maxf(0.0, impact_time - delta)
		queue_redraw()
	for atom in atoms:
		atom.position += atom.velocity * delta
		atom.rotation = -global_rotation

	var escaped: Array[Atom] = []
	for i in range(atoms.size() - 1, -1, -1):
		var atom := atoms[i]
		if atom.position.length_squared() <= INNER_RADIUS * INNER_RADIUS:
			continue
		var normal := atom.position.normalized()
		var outward_speed := atom.velocity.dot(normal)
		if outward_speed > 0.0 and _is_torn(normal):
			escaped.append(atom)
			atoms.remove_at(i)
			continue
		atom.position = normal * INNER_RADIUS
		if outward_speed > 0.0:
			atom.velocity -= normal * (2.0 * outward_speed)
	return escaped

func puncture(world_point: Vector2) -> void:
	var direction := to_local(world_point).normalized()
	if direction.is_zero_approx():
		direction = Vector2.LEFT
	if not _is_torn(direction):
		tears.append(direction)
	impact_direction = direction
	impact_time = IMPACT_DURATION
	var contact := direction * INNER_RADIUS
	for atom in atoms:
		var distance := atom.position.distance_to(contact)
		if distance < 40.0:
			atom.velocity += direction * (1.0 - distance / 40.0) * 76.0
	queue_redraw()

func _is_torn(direction: Vector2) -> bool:
	for tear in tears:
		if tear.dot(direction) >= cos(TEAR_HALF_ANGLE):
			return true
	return false

func _entry_position() -> Vector2:
	var best := Vector2(32.0, 0.0)
	var best_clearance := -1.0
	for index in 18:
		var radius := 32.0 if index < 12 else 14.0
		var divisions := 12 if index < 12 else 6
		var candidate := Vector2.from_angle(TAU * index / divisions) * radius
		var clearance := INF
		for atom in atoms:
			clearance = minf(clearance, atom.position.distance_squared_to(candidate))
		if clearance >= (ATOM_RADIUS * 2.0 + 2.0) ** 2:
			return candidate
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
	return best

func _draw() -> void:
	draw_rect(Rect2(RADIUS - 5.0, -12.0, 17.0, 24.0), Color("2e505b"))
	draw_rect(Rect2(RADIUS - 1.0, -8.0, 15.0, 16.0), Color("6d9a9d"))
	draw_circle(Vector2(1, 3), RADIUS + 2.0, Color(0.02, 0.05, 0.10, 0.52), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS - 1.4, Color("142c3b"), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS - 7.0, Color("1b3948"), true, -1.0, true)
	for i in 96:
		var start := Vector2.from_angle(TAU * i / 96)
		var end := Vector2.from_angle(TAU * (i + 1) / 96)
		if _is_torn((start + end).normalized()):
			continue
		draw_line(start * RADIUS, end * RADIUS, Color("77a7ac"), 2.4, true)
		if i % 2 == 0:
			draw_line(start * (RADIUS - 4.5), end * (RADIUS - 4.5), Color("426a76"), 1.0, true)
	for tear in tears:
		for side in [-1.0, 1.0]:
			var lip := tear.rotated(TEAR_HALF_ANGLE * side)
			var tip := tear.rotated(TEAR_HALF_ANGLE * side * 0.65)
			draw_line(lip * RADIUS, tip * (RADIUS - 6.0), Color("ffad73"), 2.0, true)
			draw_line(tip * (RADIUS - 6.0), lip * (RADIUS - 10.0), Color("b94d3b"), 1.5, true)
	if impact_time > 0.0:
		var fade := impact_time / IMPACT_DURATION
		var contact := impact_direction * RADIUS
		draw_arc(contact, 6.0 + (1.0 - fade) * 24.0, 0.0, TAU, 32, Color(1, 0.74, 0.42, fade), 1.8, true)
