extends Node2D
signal cargo_changed(atoms: Array[Dictionary], capacity: int)
signal collection_finished(atoms: Array[Dictionary])
const Catalog = preload("res://scripts/catalog.gd")
const Atom = preload("res://scripts/atom.gd")
const Collector = preload("res://scripts/collector.gd")
const WORLD_SIZE := Vector2(2600, 1800)
var collector: Node2D
var camera: Camera2D
var free_atoms: Dictionary = {}
var cargo: Array[Dictionary] = []
var capacity := 12
var active := true
var available_elements: Array[String] = ["H", "O"]

func _ready() -> void:
	var data: Dictionary = Catalog.load_data()
	capacity = int(data["collection"]["capacity"])
	collector = Collector.new()
	collector.name = "Collector"
	for element in data["elements"]:
		collector.colors[element["id"]] = Color(element["color"])
	add_child(collector)
	collector.position = WORLD_SIZE / 2
	collector.z_index = 1
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	collector.add_child(camera)
	# Fixed world coordinates: resize and camera movement never relocate atoms.
	for i in 48:
		var atom := Atom.new()
		atom.configure(i, data["elements"][i % 2])
		atom.position = Vector2(220 + (i % 8) * 305, 200 + floori(i / 8.0) * 280)
		add_child(atom)
		free_atoms[i] = atom
	# One nearby choice of each element; neither touches the starting collector.
	free_atoms[0].position = collector.position + Vector2(110, -15)
	free_atoms[1].position = collector.position + Vector2(-110, 15)
	for element in data.elements:
		if element.discoveries_required == 0 or element.id not in available_elements:
			continue
		var is_carbon: bool = element.id == "C"
		var origin := Vector2(330, 325) if is_carbon else Vector2(125, 270)
		var first_id := free_atoms.size()
		for i in 24:
			var atom := Atom.new()
			atom.configure(first_id + i, element)
			atom.position = origin + Vector2((i % 8) * 290, floori(i / 8.0) * 430)
			add_child(atom)
			free_atoms[first_id + i] = atom
		free_atoms[first_id].position = collector.position + Vector2(0, 130 if is_carbon else -130)
	cargo_changed.emit(cargo.duplicate(true), capacity)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return
	collector.move_in_arena(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta, WORLD_SIZE)
	if cargo.size() >= capacity:
		return
	for id in free_atoms.keys():
		if collector.touches(free_atoms[id].position, Atom.RADIUS):
			collect_atom(id)

func collect_atom(id: int) -> bool:
	if not active or cargo.size() >= capacity or not free_atoms.has(id):
		return false
	var atom: Node2D = free_atoms[id]
	var record := {"id": id, "element": atom.element_id}
	cargo.append(record)
	collector.add_atom(record, atom.position)
	collector.move_in_arena(Vector2.ZERO, 0, WORLD_SIZE)
	free_atoms.erase(id)
	atom.hide()
	atom.queue_free()
	cargo_changed.emit(cargo.duplicate(true), capacity)
	return true

func finish_collection() -> void:
	if not active or cargo.is_empty():
		return
	active = false
	collection_finished.emit(cargo.duplicate(true))

func resume_collection() -> void:
	active = true
	cargo_changed.emit(cargo.duplicate(true), capacity)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("101d2b"))
	for x in range(20, int(WORLD_SIZE.x), 48):
		for y in range(20, int(WORLD_SIZE.y), 48):
			draw_circle(Vector2(x, y), 1, Color(0.42, 0.59, 0.68, 0.16))
