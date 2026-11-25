extends VBoxContainer
signal return_requested
signal completed(result: Dictionary)
signal new_collection_requested
signal collection_requested
const BoardScene = preload("res://scenes/assembly_board.tscn")
const HelpDialog = preload("res://scripts/help_dialog.gd")
const CONTROLS_HELP := """Klik na atóm ukáže vonkajšiu vrstvu, dvojklik všetky vrstvy. V režime Väzby potiahni z jedného atómu na druhý. Rovnakým ťahom pridáš druhú a tretiu čiaru.

Kliknutím na čiaru vyberieš väzbu. Odstrániš ju žltým tlačidlom Zrušiť väzbu alebo klávesom Delete. V režime Presun potiahni rozkliknutý atóm, ak chceš pohnúť iba ním. Potiahnutím nerozkliknutého atómu presunieš celú rozpoznanú molekulu.

Zelený obrys označuje rozpoznaný model. Hra kontroluje, ktoré atómy sú spojené a akými väzbami. Polohu atómov môžeš meniť.

Dokončiť skladanie pridá rozpoznané látky do zásoby a otvorí laboratórium."""
const DUET_IMAGE = preload("res://assets/hydrogen_duet.svg")
const BOND_HELP := """Vľavo má každý vodík vo svojej jedinej vrstve jeden elektrón. Vpravo ich vodíky zdieľajú ako spoločný pár. Každý si započíta oba elektróny (duet). Jeden spoločný pár tvorí jednu jednoduchú kovalentnú väzbu H–H.

Pri skladaní spočítaj červené bodky na vonkajšej vrstve. Vodík potrebuje do duetu 2 elektróny. Pri kyslíku, dusíku a uhlíku pomáha pravidlo oktetu (8 elektrónov): kyslíku zvyčajne chýbajú 2, dusíku 3 a uhlíku 4. Dvojitá väzba zdieľa dva páry, trojitá tri."""
var board: Control
var status: Label
var notice: Label
var controls: HBoxContainer
var finish_button: Button
var confirmation: ConfirmationDialog
var result_page: VBoxContainer
var delete_button: Button
var bonds_button: Button
var result: Dictionary = {}
var heading: Label
var instructions: Label
var collection_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	add_child(header)
	heading = _label(header, "Zostav molekuly", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_button = _button(header, "Kolekcia")
	collection_button.pressed.connect(func(): board.cancel_interaction(); collection_requested.emit())
	instructions = _label(self, "Potiahni atóm alebo molekulu na iné miesto. Na tvorbu väzieb vyber Väzby.", 17)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	add_child(controls)
	var move_button := _button(controls, "Presun")
	bonds_button = _button(controls, "Väzby")
	var modes := ButtonGroup.new()
	for button in [move_button, bonds_button]:
		button.toggle_mode = true
		button.button_group = modes
	move_button.button_pressed = true
	move_button.pressed.connect(func():
		board.set_bond_mode(false)
		instructions.text = "Potiahni atóm alebo molekulu na iné miesto."
	)
	bonds_button.pressed.connect(func():
		board.set_bond_mode(true)
		instructions.text = "Potiahni z jedného atómu na druhý. Opakovaním zvýšiš násobnosť väzby."
	)
	delete_button = _button(controls, "Zrušiť väzbu")
	var yellow := StyleBoxFlat.new()
	yellow.bg_color = Color("f5d28b")
	yellow.set_corner_radius_all(5)
	yellow.content_margin_left = 10
	yellow.content_margin_right = 10
	for state in ["normal", "hover", "pressed"]:
		delete_button.add_theme_stylebox_override(state, yellow)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		delete_button.add_theme_color_override(color_name, Color("101d2b"))
	delete_button.hide()
	delete_button.pressed.connect(func(): board.delete_selected_bond())
	var help_dialog := HelpDialog.new()
	add_child(help_dialog)
	help_dialog.illustration.texture = DUET_IMAGE
	var help := _button(controls, "? Pomoc")
	var help_arrow := help_dialog.add_button("Kovalentná väzba →", true)
	help.pressed.connect(func():
		help_arrow.text = "Kovalentná väzba →"
		help_dialog.illustration.hide()
		help_dialog.open("Skladanie molekúl", CONTROLS_HELP)
	)
	help_arrow.pressed.connect(func():
		var show_bonds := help_dialog.title != "Kovalentná väzba"
		help_arrow.text = "← Ovládanie" if show_bonds else "Kovalentná väzba →"
		help_dialog.title = "Kovalentná väzba" if show_bonds else "Skladanie molekúl"
		help_dialog.text_label.text = BOND_HELP if show_bonds else CONTROLS_HELP
		help_dialog.illustration.visible = show_bonds
		help_dialog.scroll.scroll_vertical = 0
	)
	board = BoardScene.instantiate()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.changed.connect(_update_status)
	board.feedback.connect(_show_notice)
	board.bond_selection_changed.connect(func(has_selection: bool): delete_button.visible = has_selection)
	add_child(board)
	status = _label(self, "", 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = _label(self, "Zopakuj ťah medzi rovnakými atómami pre dvojitú alebo trojitú väzbu.", 16)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.modulate = Color("a5b4cb")
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 20)
	add_child(footer)
	var back := _button(footer, "Späť na mapu")
	back.pressed.connect(func(): board.cancel_interaction(); return_requested.emit())
	finish_button = _button(footer, "Dokončiť skladanie")
	finish_button.pressed.connect(request_finish)
	confirmation = ConfirmationDialog.new()
	confirmation.exclusive = true
	confirmation.title = "Dokončiť skladanie?"
	confirmation.ok_button_text = "Dokončiť"
	confirmation.cancel_button_text = "Ešte upraviť"
	confirmation.confirmed.connect(finalize_assembly)
	add_child(confirmation)
	result_page = VBoxContainer.new()
	result_page.add_theme_constant_override("separation", 20)
	result_page.hide()
	add_child(result_page)

func begin(records: Array[Dictionary]) -> void:
	board.load_atoms(records)

func _show_notice(message: String) -> void:
	notice.text = message

func _update_status() -> void:
	if status == null:
		return
	var preview: Dictionary = board.graph.preview()
	var descriptions: Array[String] = []
	for template in board.graph.templates:
		var count: int = preview.products.get(template.id, 0)
		if count > 0:
			descriptions.append("%s × %d" % [template.display_formula, count])
	var recognized := ", ".join(descriptions) if not descriptions.is_empty() else "zatiaľ žiadna"
	status.text = "Rozpoznané látky: %s   |   Zvyšné atómy: %d" % [recognized, preview.discarded_atoms.size()]
	finish_button.disabled = board.graph.atoms.is_empty() or board.graph.finalized

func request_finish() -> void:
	if board.graph.finalized or board.graph.atoms.is_empty():
		return
	board.cancel_interaction()
	var preview: Dictionary = board.graph.preview()
	if not preview.discarded_atoms.is_empty():
		confirmation.dialog_text = "Zvyšné atómy (%d) sa odhodia. Zachovajú sa iba rozpoznané modely." % preview.discarded_atoms.size()
		confirmation.popup_centered(Vector2i(540, 180))
	else:
		finalize_assembly()

func finalize_assembly() -> void:
	if board.graph.finalized:
		return
	result = board.graph.finalize()
	confirmation.hide()
	controls.hide()
	board.hide()
	status.hide()
	notice.hide()
	get_node("Footer").hide()
	result_page.show()
	heading.text = "Výsledok skladania"
	instructions.hide()
	var any_products := false
	for template in board.graph.templates:
		var count: int = result.products.get(template.id, 0)
		if count > 0:
			any_products = true
			var unit := "porcia" if count == 1 else ("porcie" if count < 5 else "porcií")
			_label(result_page, "%s · %s   —   %d %s" % [template.name, template.display_formula, count, unit], 23)
	if not any_products:
		_label(result_page, "Nebol rozpoznaný žiadny model.", 21)
	_label(result_page, "Odhodené atómy: %d" % result.discarded_atoms.size(), 18)
	_label(result_page, "Porcie boli pridané do zásoby.", 17)
	var next := _button(result_page, "Nový zber")
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next.pressed.connect(func(): new_collection_requested.emit())
	completed.emit(result.duplicate(true))

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button
