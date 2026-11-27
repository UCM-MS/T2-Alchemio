extends Control
const UI = preload("res://scripts/workspace_ui.gd")
const MapScene = preload("res://scenes/collection_map.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Research = preload("res://scripts/research.gd")
const LabScene = preload("res://scenes/laboratory.tscn")
const SaveService = preload("res://scripts/save_service.gd")
const HelpDialog = preload("res://scripts/help_dialog.gd")
const DiscoveryNotice = preload("res://scripts/discovery_notice.gd")
const RobotDialog = preload("res://scripts/robot_dialog.gd")
const Abilities = preload("res://scripts/robot_abilities.gd")
var discovery_notice: PanelContainer
var map_help: AcceptDialog
var save_service = SaveService.new()
var persistence_enabled := true
var save_label: Label
var reset_confirmation: ConfirmationDialog
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
var robot_dialog: AcceptDialog
var ability_label: Label
var ability_bar: ProgressBar

func _ready() -> void:
	TranslationServer.set_locale("sk")
	var loaded: Dictionary = save_service.load_progress() if persistence_enabled else {"status": "missing"}
	if loaded.has("data"):
		inventory.stock = loaded.data.inventory
		inventory.robot_module = loaded.data.get("robot_module", "")
		research.researched = loaded.data.researched
		research.completed_experiments = loaded.data.completed_experiments
		research.legacy_carbon_unlocked = loaded.data.legacy_carbon_unlocked
		research.available_elements = loaded.data.available_elements
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
	map_page.mouse_filter = Control.MOUSE_FILTER_STOP
	map_page.gui_input.connect(func(event: InputEvent): collection_map.handle_map_input(event))
	screen.add_child(map_page)
	cargo_label = add_label(map_page, "", 22)
	cargo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cargo_label.offset_left = -360
	cargo_label.offset_right = -28
	cargo_label.offset_top = 24
	cargo_label.offset_bottom = 64
	cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var ability_panel := UI.panel(map_page, UI.PANEL, 9, 10)
	ability_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ability_panel.offset_left = -320
	ability_panel.offset_right = -28
	ability_panel.offset_top = 64
	var ability_column := UI.column(ability_panel, 5)
	ability_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_label = UI.label(ability_column, "", 15, UI.MINT, true)
	ability_bar = ProgressBar.new()
	ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_bar.show_percentage = false
	ability_bar.max_value = Abilities.COOLDOWN
	ability_bar.custom_minimum_size.y = 5
	ability_bar.add_theme_stylebox_override("background", UI.box(UI.EDGE, UI.EDGE, 3, 0))
	ability_bar.add_theme_stylebox_override("fill", UI.box(UI.ACCENT, UI.ACCENT, 3, 0))
	ability_column.add_child(ability_bar)
	hint_label = add_label(map_page, "", 16, Color("a5b4cb"))
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 28
	hint_label.offset_top = -94
	hint_label.offset_bottom = -24
	finish_button = Button.new()
	finish_button.text = "K skladaniu"
	finish_button.focus_mode = Control.FOCUS_NONE
	map_page.add_child(finish_button)
	finish_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	finish_button.offset_left = -226
	finish_button.offset_right = -28
	finish_button.offset_top = -78
	finish_button.offset_bottom = -28
	_build_preview(screen)
	laboratory = LabScene.instantiate()
	laboratory.theme = UI.theme()
	screen.add_child(laboratory)
	laboratory.setup(inventory, research)
	# One collection window shared by assembly, notifications and the laboratory.
	laboratory.discovery.reparent(screen)
	laboratory.new_collection_requested.connect(_new_collection)
	laboratory.progress_changed.connect(_save_progress)
	laboratory.experiment_completed.connect(_complete_experiment)
	laboratory.new_game_requested.connect(_request_new_game)
	laboratory.robot_requested.connect(_show_robot)
	laboratory.hide()
	collection_map = MapScene.instantiate()
	collection_map.robot_module = inventory.robot_module
	collection_map.available_elements = research.available_elements.duplicate()
	collection_map.cargo_changed.connect(_update_cargo)
	collection_map.collection_finished.connect(_show_handoff)
	finish_button.pressed.connect(collection_map.finish_collection)
	add_child(collection_map)
	_build_save_controls()
	robot_dialog = RobotDialog.new()
	robot_dialog.theme = UI.theme()
	screen.add_child(robot_dialog)
	robot_dialog.module_changed.connect(_robot_module_changed)
	robot_dialog.visibility_changed.connect(_robot_dialog_visibility_changed)
	var notice_layer := CanvasLayer.new()
	notice_layer.layer = 20
	add_child(notice_layer)
	var notice_screen := Control.new()
	notice_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_screen.theme = screen.theme
	notice_layer.add_child(notice_screen)
	discovery_notice = DiscoveryNotice.new()
	notice_screen.add_child(discovery_notice)
	discovery_notice.open_requested.connect(_open_discovery)
	laboratory.discovery.visibility_changed.connect(func(): discovery_notice.timer.paused = laboratory.discovery.visible)
	# Existing saves can contain portions that were never manually researched.
	var owned: Dictionary = inventory.stock.duplicate(true)
	for id in owned:
		if owned[id] <= 0:
			owned.erase(id)
	_discover_products(owned)
	if loaded.has("data"):
		# A loaded checkpoint resumes in a clean laboratory, not a spent graph.
		preview_page.board.graph.finalized = true
		collection_map.active = false
		map_page.hide()
		preview_background.show()
		laboratory.show()
		laboratory.refresh()
		save_label.text = "Obnovené zo zálohy" if loaded.status == "recovered" else "Pokrok načítaný"
	elif loaded.status == "invalid":
		save_label.text = "Uloženie nemožno načítať. Súbor ostáva zachovaný; reset cez Nová hra."
	else:
		save_label.text = "Ukladá sa zásoba, objavy a pokusy; rozpracovaný zber a skladanie nie."

func _process(_delta: float) -> void:
	if not map_page.visible:
		return
	var ability: Dictionary = Abilities.MODULES.get(inventory.robot_module, {})
	ability_bar.visible = not ability.is_empty()
	if ability.is_empty():
		ability_label.text = "Robot  ·  prázdny slot"
		return
	var remaining: float = collection_map.ability_cooldown
	ability_label.text = "Medzerník  ·  %s  ·  %s" % [
		ability.name, "pripravené" if remaining <= 0.0 else "%.1f s" % remaining]
	ability_bar.value = Abilities.COOLDOWN - remaining

func _show_robot() -> void:
	robot_dialog.show_for(inventory, research.catalog)

func _robot_module_changed() -> void:
	collection_map.robot_module = inventory.robot_module
	laboratory.refresh()
	_save_progress()

func _robot_dialog_visibility_changed() -> void:
	collection_map.controls_blocked = robot_dialog.visible
	collection_map.following_mouse = false

func _build_save_controls() -> void:
	save_label = add_label(screen, "", 13, Color("a5b4cb"))
	save_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	save_label.offset_left = -700
	save_label.offset_right = -25
	save_label.offset_top = -24
	save_label.offset_bottom = -4
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var reset_button := Button.new()
	reset_button.text = "Nová hra"
	map_page.add_child(reset_button)
	reset_button.position = Vector2(28, 24)
	reset_button.pressed.connect(_request_new_game)
	map_help = HelpDialog.new()
	screen.add_child(map_help)
	var help_button := Button.new()
	help_button.text = "? Pomoc"
	help_button.position = Vector2(180, 24)
	map_page.add_child(help_button)
	var robot_button := Button.new()
	robot_button.text = "Robot"
	robot_button.focus_mode = Control.FOCUS_NONE
	robot_button.position = Vector2(320, 24)
	map_page.add_child(robot_button)
	robot_button.pressed.connect(_show_robot)
	help_button.pressed.connect(func(): map_help.open("Zber atómov", "Vysávač ovládaš pomocou WASD, šípok alebo podržaním ľavého tlačidla myši na mape. Oranžový otvor mieri za kurzorom a nasáva atómy do vrecka. Naraz ich unesie %d.\n\nČierna guľa môže vrecko roztrhnúť. Atómy, ktoré vyletia cez trhlinu, môžeš znova nazbierať.\n\nTlačidlo K skladaniu otvorí pracovnú plochu, kde spojíš atómy chemickými väzbami. Pred dokončením sa môžeš vrátiť k zberu. Rozpracovaný zber a skladanie sa po zatvorení hry neobnovia." % collection_map.capacity))
	reset_confirmation = ConfirmationDialog.new()
	reset_confirmation.exclusive = true
	reset_confirmation.title = "Nová hra?"
	reset_confirmation.dialog_text = "Vymaže sa zásoba, objavy, dokončené pokusy aj otvorené prvky.\nRozpracovaný zber a skladanie sa zahodia."
	reset_confirmation.ok_button_text = "Začať odznova"
	reset_confirmation.cancel_button_text = "Zrušiť"
	reset_confirmation.confirmed.connect(_reset_game)
	screen.add_child(reset_confirmation)

func _request_new_game() -> void:
	reset_confirmation.popup_centered(Vector2i(540, 180))

func _save_progress() -> void:
	if not persistence_enabled:
		return
	var success: bool = save_service.save_progress(inventory, research)
	save_label.text = "Uložené · rozpracovaný zber a skladanie sa neukladajú" if success else "Uloženie zlyhalo · pokrok zatiaľ iba v tejto hre"
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		save_label.text = "Prehliadač nepovolil trvalé uloženie · pokrok iba v tejto hre"

func _reset_game() -> void:
	var fresh_inventory = Inventory.new()
	var fresh_research = Research.new()
	if persistence_enabled and not save_service.reset_progress(fresh_inventory, fresh_research):
		save_label.text = "Reset sa nepodarilo uložiť. Aktuálna hra ostáva zachovaná."
		return
	inventory = fresh_inventory
	research = fresh_research
	discovery_notice.clear()
	laboratory.discovery.hide()
	laboratory.discovery.pending.clear()
	map_help.hide()
	laboratory.setup(inventory, research)
	preview_page.confirmation.hide()
	preview_page.board.graph.finalized = true
	last_assembly_result.clear()
	assembly_atoms.clear()
	_new_collection()

func _build_preview(target: Control) -> void:
	if preview_background == null:
		preview_background = ColorRect.new()
		preview_background.color = UI.BG
		preview_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_background.hide()
		target.add_child(preview_background)
	preview_page = AssemblyPanel.new()
	preview_page.theme = UI.theme()
	preview_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_page.hide()
	target.add_child(preview_page)
	preview_page.board.graph.configure_elements(research.available_elements)
	preview_page.assembly_goal.text = research.assembly_goal()
	preview_page.return_requested.connect(_return_to_map)
	preview_page.completed.connect(_assembly_completed)
	preview_page.new_collection_requested.connect(_new_collection)
	preview_page.collection_requested.connect(_open_collection)
	preview_page.board.changed.connect(_discover_assembly)

func _open_collection() -> void:
	laboratory.discovery.origin_tab = "Skladanie"
	laboratory.discovery.show_collection()

func _open_discovery(id: String) -> void:
	laboratory.discovery.origin_tab = "Hracia plocha" if map_page.visible else ("Skladanie" if preview_page.visible else "Laboratórium")
	if research.researched.has(id):
		laboratory.discovery.show_substance(id)
	elif id in research.available_elements:
		laboratory.discovery.show_element(id)

func _discover_assembly() -> void:
	if preview_page.board.graph.finalized:
		return
	_discover_products(preview_page.board.graph.preview().products)

func _complete_experiment(id: String, products: Dictionary) -> void:
	var had_carbon: bool = "C" in research.available_elements
	research.complete_experiment(id)
	_discover_products(products, false)
	if not had_carbon and "C" in research.available_elements:
		discovery_notice.enqueue("Nový prvok · Uhlík (C)\nDostupný pri ďalšom zbere.", "C")

func _discover_products(products: Dictionary, checkpoint := true) -> void:
	var changed := false
	for substance in research.catalog.substances:
		if products.get(substance.id, 0) > 0 and research.discover(substance.id):
			changed = true
			discovery_notice.enqueue("Nová látka objavená!\n%s · %s\nPridaná do kolekcie." % [substance.display_formula,substance.name], substance.id)
	if changed and checkpoint:
		laboratory.refresh()
		_save_progress()

func _assembly_completed(result: Dictionary) -> void:
	if reward_claimed or not preview_page.board.graph.finalized:
		return
	reward_claimed = true
	laboratory.discovery.origin_tab = "Laboratórium"
	inventory.credit(result.products)
	_discover_products(result.products)
	last_assembly_result = result.duplicate(true)
	assembly_atoms.clear()
	collection_map.clear_cargo()
	preview_page.hide()
	laboratory.show()
	laboratory.refresh()
	_save_progress()

func _new_collection() -> void:
	if not preview_page.board.graph.finalized:
		return
	laboratory._reset_experiment()
	laboratory.close_dialogs()
	inventory.return_sample()
	laboratory.hide()
	reward_claimed = false
	var remaining: float = collection_map.ability_cooldown
	remove_child(collection_map)
	collection_map.queue_free()
	screen.remove_child(preview_page)
	preview_page.queue_free()
	preview_background.hide()
	_build_preview(screen)
	map_page.show()
	collection_map = MapScene.instantiate()
	collection_map.robot_module = inventory.robot_module
	collection_map.ability_cooldown = remaining
	collection_map.available_elements = research.available_elements.duplicate()
	collection_map.cargo_changed.connect(_update_cargo)
	collection_map.collection_finished.connect(_show_handoff)
	for connection in finish_button.pressed.get_connections():
		finish_button.pressed.disconnect(connection.callable)
	finish_button.pressed.connect(collection_map.finish_collection)
	add_child(collection_map)
	_save_progress()

func _update_cargo(atoms: Array[Dictionary], capacity: int) -> void:
	var counts := {}
	for atom in atoms:
		counts[atom.element] = counts.get(atom.element, 0) + 1
	var parts := PackedStringArray()
	for symbol in collection_map.available_elements:
		parts.append("%s %d" % [symbol, counts.get(symbol, 0)])
	cargo_label.text = "%s  |  %d / %d" % ["  ".join(parts), atoms.size(), capacity]
	finish_button.disabled = atoms.is_empty()
	hint_label.text = "Pohyb: WASD / šípky alebo podrž ľavé tlačidlo myši.\nOranžový otvor mieri za kurzorom. Chráň vrecko pred čiernymi guľami."
	if atoms.size() >= capacity:
		hint_label.text += "\nVrecko je plné. Pokračuj k skladaniu."

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
