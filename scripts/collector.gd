extends Node2D

const Bag = preload("res://scripts/collection_bag.gd")
const RADIUS := 22.0
const SPEED := 255.0
const INTAKE_OFFSET := 19.0
const INTAKE_HALF_WIDTH := 11.0
const SUCTION_RANGE := 168.0
const SUCTION_HALF_ANGLE := PI / 4.0
const BAG_OFFSET := Vector2(-77.0, 0.0)
const WORLD_MARGIN := 133.0

var heading := 0.0
var suction_enabled := true
var suction_multiplier := 1.0
var hook_points: PackedVector2Array = []
var pulse_radius := 0.0
var pulse_fraction := 0.0
var shielded := false
var bag: Bag

func _ready() -> void:
	bag = Bag.new()
	bag.position = BAG_OFFSET
	bag.show_behind_parent = true
	add_child(bag)

func aim_at(point: Vector2) -> void:
	var offset := point - position
	if not offset.is_zero_approx():
		heading = offset.angle()
		bag.position = BAG_OFFSET.rotated(heading)
		bag.rotation = heading
		queue_redraw()

func suction_velocity(point: Vector2) -> Vector2:
	if not suction_enabled:
		return Vector2.ZERO
	var forward := Vector2.from_angle(heading)
	var offset := point - (position + forward * INTAKE_OFFSET)
	var distance := offset.length()
	if distance == 0.0 or distance > SUCTION_RANGE:
		return Vector2.ZERO
	var direction := offset / distance
	if direction.dot(forward) < cos(SUCTION_HALF_ANGLE):
		return Vector2.ZERO
	var proximity := 1.0 - distance / SUCTION_RANGE
	return -direction * lerpf(30.0, 660.0, proximity * proximity) * suction_multiplier

func reaches_intake(point: Vector2, radius: float) -> bool:
	var forward := Vector2.from_angle(heading)
	var offset := point - position
	return (
		offset.dot(forward) >= INTAKE_OFFSET - radius * 0.5
		and offset.distance_squared_to(forward * INTAKE_OFFSET) <= (INTAKE_HALF_WIDTH + radius) ** 2
	)

func move_in_arena(direction: Vector2, delta: float, world_size: Vector2) -> void:
	position += direction.limit_length() * SPEED * delta
	# Leave room for the rear bag at every aiming angle.
	var padding := Vector2.ONE * WORLD_MARGIN
	position = position.clamp(padding, world_size - padding)

func _draw() -> void:
	if pulse_fraction > 0.0:
		draw_arc(Vector2.ZERO, lerpf(pulse_radius, 22.0, pulse_fraction), 0.0, TAU, 96, Color(0.53, 0.96, 0.88, pulse_fraction), 2.5, true)
	for point in hook_points:
		var tip := point - global_position
		draw_line(Vector2.from_angle(heading) * INTAKE_OFFSET, tip, Color("8de9da"), 2.5, true)
		draw_circle(tip, 5.0, Color("e4fffb"), true, -1.0, true)
	if shielded:
		draw_arc(bag.position, Bag.RADIUS + 5.0, 0.0, TAU, 64, Color("72eac5"), 2.5, true)
	draw_circle(Vector2(1, 3), RADIUS + 2.0, Color(0.02, 0.04, 0.08, 0.65), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, heading)
	# Low circular chassis, side brush and raised navigation sensor.
	for side in [-1.0, 1.0]:
		var hub := Vector2(9.0, side * 20.0)
		for step in 3:
			var bristle := Vector2.from_angle(side * PI / 2.0 + (step - 1) * 0.65)
			draw_line(hub, hub + bristle * 7.0, Color("8f9da0"), 1.5, true)
		draw_circle(hub, 3.0, Color("46596a"), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS, Color("172835"), true, -1.0, true)
	draw_circle(Vector2(-1, -1), RADIUS - 3.0, Color("cfdfdf"), true, -1.0, true)
	draw_arc(Vector2(-1, -1), RADIUS - 4.0, PI * 0.65, PI * 1.43, 32, Color("f3faf2"), 1.5, true)
	draw_circle(Vector2(-7, -2), 8.0, Color("586d76"), true, -1.0, true)
	draw_circle(Vector2(-7, -3), 6.1, Color("223a46"), true, -1.0, true)
	draw_circle(Vector2(-9, -5), 2.0, Color("a0c9c6"), true, -1.0, true)
	draw_line(Vector2(4, -6), Vector2(4, 6), Color("738c94"), 1.0, true)
	draw_circle(Vector2(3.5, 0), 2.4, Color("7df4d7") if suction_enabled else Color("849299"), true, -1.0, true)

	# The amber grille alone shows the direction of the invisible suction zone.
	var grille := Rect2(INTAKE_OFFSET - 6.0, -INTAKE_HALF_WIDTH, 8.0, INTAKE_HALF_WIDTH * 2.0)
	draw_rect(grille, Color("162432"))
	var light := Color("ff9d45") if suction_enabled else Color("b28764")
	for y in range(-8, 9, 4):
		draw_line(Vector2(16.0, y), Vector2(20.0, y), light, 1.5, true)
	draw_line(Vector2(21.0, -9.0), Vector2(21.0, 9.0), light, 2.0, true)
