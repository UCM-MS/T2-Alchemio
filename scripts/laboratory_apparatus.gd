extends "res://scripts/flask_drop_target.gd"

const FRAME := Color("a5cddc")
const METAL := Color("496779")
const AQUA := Color("4895aa")
const AMBER := Color("ffad60")

var experiment: RefCounted
var last_products := {}
var elapsed := 0.0

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("173e42") if highlighted else Color("101f2e")
	frame.border_color = Color("8fe4d3") if highlighted else Color("315064")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(14)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	if experiment == null or inventory == null:
		return
	draw_line(Vector2(43, 30), Vector2(43, 153), METAL, 5, true)
	draw_line(Vector2(43, 70), Vector2(101, 70), METAL, 3, true)
	draw_rect(Rect2(23, 151, 254, 7), METAL)
	match experiment.instrument_id:
		"beaker":
			_draw_beaker()
		"electrodes":
			_draw_electrolysis()
		"burner":
			_draw_burner()
		"tube":
			_draw_furnace()

func _draw_beaker() -> void:
	var id: String = experiment.pending.get("id", experiment.result.get("id", ""))
	if id.is_empty():
		if inventory.sample.has("hydrogen_peroxide"):
			id = "peroxide_decomposition"
		elif inventory.sample.has("carbon_dioxide"):
			id = "carbonation"
	var running: bool = experiment.is_running()
	var has_liquid: bool = inventory.sample.has("water") or inventory.sample.has("hydrogen_peroxide") or not last_products.is_empty()
	var fluid := AQUA
	if id == "carbonation":
		fluid = Color("d7b956") if last_products.has("carbonated_water") else Color("64a780")
		draw_polyline(PackedVector2Array([Vector2(246, 45), Vector2(153, 45), Vector2(153, 113)]), FRAME, 3, true)
		_caption("CO₂", Vector2(218, 37))
	elif id == "peroxide_decomposition":
		draw_line(Vector2(192, 41), Vector2(154, 68), FRAME, 6, true)
		draw_circle(Vector2(192, 41), 6, METAL)
		if running:
			draw_circle(Vector2(151, 76 + fmod(elapsed * 38, 20)), 3, FRAME)
		_caption("Katalyzátor", Vector2(198, 64), 12)
	else:
		draw_rect(Rect2(105, 141, 100, 9), METAL)
		if experiment.mode == "heat":
			draw_line(Vector2(112, 140), Vector2(198, 140), AMBER, 3, true)
	if has_liquid:
		draw_rect(Rect2(113, 91, 84, 45), fluid)
	draw_polyline(PackedVector2Array([Vector2(102, 72), Vector2(110, 79), Vector2(110, 137), Vector2(200, 137), Vector2(200, 72)]), FRAME, 3, true)
	for y in [84, 100, 116]:
		draw_line(Vector2(187, y), Vector2(199, y), FRAME, 1, true)
	if running or experiment.boiling:
		_bubbles(Vector2(127, 129), 6, 30, 38, Color("dbf6f7"))
	elif id == "peroxide_decomposition" and inventory.sample.has("hydrogen_peroxide") and last_products.is_empty():
		_bubbles(Vector2(153, 128), 1, 8, 34, FRAME)

func _draw_electrolysis() -> void:
	var running: bool = experiment.is_running()
	var has_water: bool = inventory.sample.has("water") or running or not last_products.is_empty()
	if has_water:
		draw_rect(Rect2(101, 112, 104, 32), AQUA.darkened(0.22))
	draw_polyline(PackedVector2Array([Vector2(98, 103), Vector2(98, 146), Vector2(208, 146), Vector2(208, 103)]), FRAME, 3, true)
	var progress := 0.0
	if running:
		progress = clampf(elapsed / experiment.REACTION_DURATION, 0, 1)
	elif not last_products.is_empty():
		progress = 1.0
	for i in 2:
		var x := 129.0 + i * 48
		var volume := (42.0 if i == 0 else 21.0) * progress
		if has_water:
			draw_rect(Rect2(x - 12, 51 + volume, 24, 80 - volume), AQUA)
		draw_polyline(PackedVector2Array([Vector2(x - 13, 132), Vector2(x - 13, 49), Vector2(x + 13, 49), Vector2(x + 13, 132)]), FRAME, 2, true)
		draw_line(Vector2(x, 134), Vector2(x, 119), AMBER, 2, true)
		_caption("H₂ (−)" if i == 0 else "O₂ (+)", Vector2(x - 18, 38), 12)
		if running:
			_bubbles(Vector2(x - 5, 123), 4 if i == 0 else 2, 32, 39, FRAME)

func _draw_burner() -> void:
	var running: bool = experiment.is_running()
	var id: String = experiment.pending.get("id", experiment.result.get("id", ""))
	var hydrogen: bool = inventory.sample.has("hydrogen") or id == "hydrogen_combustion"
	var fuel := "Plyn"
	if hydrogen:
		fuel = "H₂"
	elif inventory.sample.has("methane") or id == "combustion":
		fuel = "CH₄"
	draw_line(Vector2(106, 137), Vector2(149, 137), METAL, 5, true)
	draw_line(Vector2(196, 137), Vector2(156, 137), METAL, 5, true)
	_caption(fuel, Vector2(75, 143))
	_caption("O₂", Vector2(200, 143))
	draw_rect(Rect2(136, 147, 36, 5), METAL)
	draw_rect(Rect2(147, 101, 14, 47), METAL)
	draw_line(Vector2(119, 56), Vector2(186, 56), FRAME, 4, true)
	if running:
		var flicker := sin(elapsed * 27) * 5
		var flame := Color("91d8ed55") if hydrogen else Color("56b9ff")
		draw_colored_polygon(PackedVector2Array([Vector2(145, 100), Vector2(154, 70 + flicker), Vector2(163, 100)]), flame)
	if running or last_products.has("water"):
		for i in 3:
			var y := 63.0 + fmod(elapsed * 16 + i * 8, 15)
			draw_circle(Vector2(135 + i * 17, y), 2, FRAME, true, -1, true)
	if last_products.has("carbon_dioxide"):
		_caption("CO₂", Vector2(223, 81))

func _draw_furnace() -> void:
	var running: bool = experiment.is_running()
	var has_carbon: bool = inventory.sample.has("solid_carbon")
	draw_rect(Rect2(89, 59, 127, 65), METAL)
	draw_rect(Rect2(63, 76, 173, 30), Color("263843"))
	draw_rect(Rect2(63, 76, 173, 30), FRAME, false, 2)
	draw_line(Vector2(236, 91), Vector2(251, 91), METAL, 3, true)
	draw_rect(Rect2(247, 71, 46, 40), Color("142631"))
	_caption("O₂", Vector2(65, 67), 13)
	draw_rect(Rect2(124, 97, 54, 4), FRAME)
	if has_carbon:
		var progress := clampf(elapsed / experiment.REACTION_DURATION, 0.0, 1.0) if running else 0.0
		var sample_color := AMBER.lerp(Color("c9483e"), progress) if running else Color("56626d")
		draw_rect(Rect2(133, 85 + progress * 4, 36 - progress * 14, 12 - progress * 4), sample_color)
	if last_products.has("carbon_monoxide"):
		_caption("CO", Vector2(252, 86), 13)
	if last_products.has("carbon_dioxide"):
		_caption("CO₂", Vector2(252, 102), 13)
	if last_products.is_empty():
		_caption("–", Vector2(262, 96), 13)

func _bubbles(origin: Vector2, count: int, speed: float, height: float, tint: Color) -> void:
	for i in count:
		var rise := fmod(elapsed * speed + i * 9, height)
		draw_arc(origin + Vector2(i * 9, -rise), 2 + i % 3, 0, TAU, 12, tint, 1.2, true)

func _caption(value: String, position: Vector2, font_size := 14) -> void:
	draw_string(get_theme_default_font(), position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, FRAME)
