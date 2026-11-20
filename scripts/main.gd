extends Control
const MapScene = preload("res://scenes/collection_map.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Research = preload("res://scripts/research.gd")
const LabScene = preload("res://scenes/laboratory.tscn")
var inventory = Inventory.new()
var research = Research.new()
var laboratory: Control
var reward_claimed := false
const AssemblyPanel = preload("res://scripts/assembly_panel.gd")
var collection_map: Node2D
var assembly_atoms: Array[Dictionary] = []
var cargo_label: Label
var hint_label: Label
var finish_button: Button
var map_page: Control
var preview_page: VBoxContainer
var last_assembly_result: Dictionary = {}
var screen: Control
var preview_background: ColorRect

func _ready() -> void:
	TranslationServer.set_locale("sk")
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = Theme.new()
	screen.theme.default_font = load("res://assets/fonts/NotoSans.ttf")
	screen.theme.default_font_size = 18
	hud.add_child(screen)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("244c50")
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	screen.theme.set_stylebox("normal", "Button", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("326b68")
	screen.theme.set_stylebox("hover", "Button", hover)
	screen.theme.set_stylebox("pressed", "Button", hover)
	map_page = Control.new()
	map_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(map_page)
	cargo_label = add_label(map_page, "", 22)
	cargo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cargo_label.offset_left = -360
	cargo_label.offset_right = -28
	cargo_label.offset_top = 24
	cargo_label.offset_bottom = 64
	cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label = add_label(map_page, "", 16, Color("a5b4cb"))
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 28
	hint_label.offset_top = -94
	hint_label.offset_bottom = -24
	finish_button = Button.new()
	finish_button.text = "K skladaniu  →"
	finish_button.focus_mode = Control.FOCUS_NONE
	map_page.add_child(finish_button)
	finish_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	finish_button.offset_left = -226
	finish_button.offset_right = -28
	finish_button.offset_top = -78
	finish_button.offset_bottom = -28
	_build_preview(screen)
	laboratory = LabScene.instantiate()
	screen.add_child(laboratory)
	laboratory.setup(inventory, research)
	laboratory.new_collection_requested.connect(_new_collection)
	laboratory.hide()
	collection_map = MapScene.instantiate()
	collection_map.available_elements = research.available_elements.duplicate()
	collection_map.cargo_changed.connect(_update_cargo)
	collection_map.collection_finished.connect(_show_handoff)
	finish_button.pressed.connect(collection_map.finish_collection)
	add_child(collection_map)

func _build_preview(target: Control) -> void:
	if preview_background == null:
		preview_background = ColorRect.new()
		preview_background.color = Color("09101a")
		preview_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_background.hide()
		target.add_child(preview_background)
	preview_page = AssemblyPanel.new()
	preview_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_page.offset_left = 28
	preview_page.offset_right = -28
	preview_page.offset_top = 20
	preview_page.offset_bottom = -20
	preview_page.hide()
	target.add_child(preview_page)
	preview_page.board.graph.configure_elements(research.available_elements)
	preview_page.return_requested.connect(_return_to_map)
	preview_page.completed.connect(_assembly_completed)
	preview_page.new_collection_requested.connect(_new_collection)

func _assembly_completed(result: Dictionary) -> void:
	if reward_claimed or not preview_page.board.graph.finalized:
		return
	reward_claimed = true
	inventory.credit(result.products)
	last_assembly_result = result.duplicate(true)
	assembly_atoms.clear()
	collection_map.cargo.clear()
	collection_map.collector.carried.clear()
	collection_map.collector.offsets.clear()
	collection_map.collector.parents.clear()
	collection_map.collector.queue_redraw()
	preview_page.hide()
	laboratory.show()
	laboratory.refresh()

func _new_collection() -> void:
	if not preview_page.board.graph.finalized:
		return
	laboratory._reset_experiment()
	inventory.return_sample()
	laboratory.hide()
	reward_claimed = false
	remove_child(collection_map)
	collection_map.queue_free()
	screen.remove_child(preview_page)
	preview_page.queue_free()
	preview_background.hide()
	_build_preview(screen)
	map_page.show()
	collection_map = MapScene.instantiate()
	collection_map.available_elements = research.available_elements.duplicate()
	collection_map.cargo_changed.connect(_update_cargo)
	collection_map.collection_finished.connect(_show_handoff)
	for connection in finish_button.pressed.get_connections():
		finish_button.pressed.disconnect(connection.callable)
	finish_button.pressed.connect(collection_map.finish_collection)
	add_child(collection_map)

func _update_cargo(atoms: Array[Dictionary], capacity: int) -> void:
	var counts := {"H": 0, "O": 0, "C": 0}
	for atom in atoms:
		counts[atom["element"]] += 1
	cargo_label.text = "H  %d    O  %d     |     %d / %d" % [counts.H, counts.O, atoms.size(), capacity]
	if "C" in research.available_elements:
		cargo_label.text = "H %d  O %d  C %d  |  %d / %d" % [counts.H, counts.O, counts.C, atoms.size(), capacity]
	finish_button.disabled = atoms.is_empty()
	hint_label.text = "WASD / šípky · Pohyb a zber dotykom\nTyčky sú uchytenia, nie chemické väzby."
	if atoms.size() >= capacity:
		hint_label.text += "\nZberač je plný. Pokračuj k skladaniu."

func _show_handoff(atoms: Array[Dictionary]) -> void:
	assembly_atoms = atoms.duplicate(true)
	map_page.hide()
	preview_background.show()
	preview_page.show()
	preview_page.begin(assembly_atoms)

func _return_to_map() -> void:
	preview_page.hide()
	preview_background.hide()
	map_page.show()
	assembly_atoms.clear()
	collection_map.resume_collection()

func add_label(parent: Node, text: String, size: int, color := Color("edf3fc")) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("09101a"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


