extends VBoxContainer
signal return_requested
signal completed(result: Dictionary)
signal new_collection_requested
signal collection_requested
const UI = preload("res://scripts/workspace_ui.gd")
const BoardScene = preload("res://scenes/assembly_board.tscn")
const HelpDialog = preload("res://scripts/help_dialog.gd")
const CONTROLS_HELP := """Klik na atóm ukáže vonkajšiu vrstvu, dvojklik všetky vrstvy. S nástrojom Vytvoriť väzbu potiahni z jedného atómu na druhý. Rovnakým ťahom pridáš druhú a tretiu čiaru.

Kliknutím na čiaru vyberieš väzbu. Odstrániš ju tlačidlom Odstrániť väzbu alebo klávesom Delete. S nástrojom Presunúť atóm potiahni rozkliknutý atóm, ak chceš pohnúť iba ním. Potiahnutím nerozkliknutého atómu presunieš celú rozpoznanú molekulu.

Zelený obrys označuje rozpoznaný model. Hra kontroluje, ktoré atómy sú spojené a akými väzbami. Polohu atómov môžeš meniť.

Dokončiť skladanie pridá rozpoznané látky do zásoby a otvorí laboratórium."""
const DUET_IMAGE = preload("res://assets/hydrogen_duet.svg")
const BOND_HELP := """Vľavo má každý vodík vo svojej jedinej vrstve jeden elektrón. Vpravo ich vodíky zdieľajú ako spoločný pár. Každý si započíta oba elektróny (duet). Jeden spoločný pár tvorí jednu jednoduchú kovalentnú väzbu H–H.

Pri skladaní spočítaj červené bodky na vonkajšej vrstve. Vodík potrebuje do duetu 2 elektróny. Pri kyslíku, dusíku a uhlíku pomáha pravidlo oktetu (8 elektrónov): kyslíku zvyčajne chýbajú 2, dusíku 3 a uhlíku 4. Dvojitá väzba zdieľa dva páry, trojitá tri."""
var board: Control
var status: Label
var notice: Label
var workspace: HBoxContainer
var stock: VBoxContainer
var controls: VBoxContainer
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
	add_theme_constant_override("separation", 0)
	var tabs := UI.nav(self, "Skladanie")
	collection_button = tabs["Kolekcia"]
	collection_button.disabled = false
	collection_button.pressed.connect(func(): board.cancel_interaction(); collection_requested.emit())
	var back: Button = tabs["Hracia plocha"]
	back.disabled = false
	back.pressed.connect(func(): board.cancel_interaction(); return_requested.emit())
	var page := UI.page(self)
	page.add_theme_constant_override("separation", 38)
	var header := UI.row(page, 12)
	heading = UI.heading(header, "PRACOVNÁ PLOCHA", "Skladanie molekúl")
	heading.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var help := UI.button(header, "Pomoc")
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	workspace = UI.row(page, 12)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stock_panel := UI.panel(workspace)
	stock_panel.custom_minimum_size.x = 242
	var tray := UI.column(stock_panel, 16)
	UI.label(tray, "ZÁSOBA ATÓMOV", 13, UI.MUTED, true)
	stock = UI.scroll_column(tray)
	var canvas := UI.panel(workspace, UI.CANVAS)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := UI.column(canvas, 0)
	UI.label(center, "MOLEKULÁRNA PLOCHA", 13, UI.MUTED, true)
	var sidebar := UI.panel(workspace)
	sidebar.custom_minimum_size.x = 246
	controls = UI.column(sidebar, 8)
	UI.label(controls, "NÁSTROJE", 13, UI.MUTED, true)
	var move_button := UI.button(controls, "⊕    Presunúť atóm")
	bonds_button = UI.button(controls, "═    Vytvoriť väzbu")
	for tool in [move_button, bonds_button]:
		tool.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tool.custom_minimum_size.y = 46
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
		instructions.text = "Potiahni medzi atómami. Opakovaním vytvoríš dvojitú alebo trojitú väzbu."
	)
	delete_button = UI.button(controls, "×    Odstrániť väzbu")
	delete_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	delete_button.hide()
	delete_button.pressed.connect(func(): board.delete_selected_bond())
	instructions = UI.label(controls, "Potiahni atóm alebo molekulu. Na tvorbu väzieb vyber Vytvoriť väzbu.", 14, UI.MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help_dialog := HelpDialog.new()
	add_child(help_dialog)
	help_dialog.illustration.texture = DUET_IMAGE
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
	center.add_child(board)
	notice = UI.label(center, "", 14, UI.MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	UI.label(controls, "VÝSLEDOK", 13, UI.MUTED, true)
	status = UI.label(controls, "", 16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finish_button = UI.button(controls, "Dokončiť skladanie")
	UI.primary(finish_button)
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
	page.add_child(result_page)

func begin(records: Array[Dictionary]) -> void:
	board.load_atoms(records)
	for child in stock.get_children():
		stock.remove_child(child)
		child.queue_free()
	var counts := {}
	for atom in records:
		counts[atom.element] = counts.get(atom.element, 0) + 1
	for element in AlphaCatalog.load_data().elements:
		if not counts.has(element.symbol):
			continue
		var card := UI.panel(stock, UI.CARD, 12, 20)
		card.custom_minimum_size.y = 87
		var line := UI.row(card, 8)
		UI.badge(line, element.symbol, 50)
		UI.label(line, element.name, 18, UI.TEXT, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.label(line, "×%d" % counts[element.symbol], 18, UI.MUTED)

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
	var recognized := ", ".join(descriptions) if not descriptions.is_empty() else "Zatiaľ bez molekuly"
	status.text = "%s\nZvyšné atómy: %d" % [recognized, preview.discarded_atoms.size()]
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
	workspace.hide()
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
