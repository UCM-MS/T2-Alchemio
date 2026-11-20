extends Node2D
## Sticks are collection attachments, never chemical bonds.
const FONT = preload("res://assets/fonts/NotoSans.ttf")
const RADIUS := 22.0
const SPEED := 255.0
const SPACING := 60.0
var carried: Array[Dictionary] = []
var colors: Dictionary = {}
var offsets: Array[Vector2] = []
var parents: Array[int] = []

func add_atom(record: Dictionary, incoming: Vector2) -> void:
	if carried.is_empty():
		offsets.append(Vector2.ZERO)
		parents.append(-1)
	else:
		var best := Vector2.ZERO
		var best_parent := 0
		var best_score := INF
		for p in offsets.size():
			var preferred := (incoming - position - offsets[p]).angle()
			for step in 24:
				var candidate := offsets[p] + Vector2.from_angle(preferred + step * TAU / 24) * SPACING
				var clear := true
				for existing in offsets:
					if existing.distance_to(candidate) < RADIUS * 2 + 8:
						clear = false
						break
				var score := candidate.distance_squared_to(incoming - position)
				if clear and score < best_score:
					best = candidate
					best_parent = p
					best_score = score
		offsets.append(best)
		parents.append(best_parent)
	carried.append(record.duplicate(true))
	queue_redraw()

func touches(point: Vector2, radius: float) -> bool:
	if offsets.is_empty():
		return position.distance_to(point) <= RADIUS + radius
	for offset in offsets:
		if (position + offset).distance_to(point) <= RADIUS + radius:
			return true
	return false

func movement_bounds(world_size: Vector2) -> Rect2:
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	for offset in offsets:
		low = low.min(offset)
		high = high.max(offset)
	var minimum := Vector2.ONE * (RADIUS + 8) - low
	var maximum := world_size - Vector2.ONE * (RADIUS + 8) - high
	return Rect2(minimum, maximum - minimum)

func move_in_arena(direction: Vector2, delta: float, world_size: Vector2) -> void:
	position += direction.limit_length() * SPEED * delta
	var bounds := movement_bounds(world_size)
	position = position.clamp(bounds.position, bounds.end)

func _draw() -> void:
	for i in range(1, offsets.size()):
		var direction := (offsets[i] - offsets[parents[i]]).normalized()
		draw_line(offsets[parents[i]] + direction * RADIUS, offsets[i] - direction * RADIUS, Color("789197"), 3, true)
	if carried.is_empty():
		draw_circle(Vector2.ZERO, RADIUS, Color("244c50"))
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color("7ed9c3"), 2, true)
		draw_circle(Vector2.ZERO, 4, Color("baf5e5"))
	else:
		for i in carried.size():
			var symbol: String = carried[i]["element"]
			var tint: Color = colors[symbol]
			draw_circle(offsets[i], RADIUS, tint.darkened(0.78))
			draw_arc(offsets[i], RADIUS, 0, TAU, 40, tint, 2, true)
			var width := FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(FONT, offsets[i] + Vector2(-width / 2, 8), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tint)
	# Ring identifies the controlled root without adding a second atom.
	draw_arc(Vector2.ZERO, RADIUS + 5, 0, TAU, 48, Color("7ed9c3"), 1, true)
