extends VBoxContainer
signal return_requested
signal completed(result: Dictionary)
signal new_collection_requested
signal collection_requested
const UI = preload("res://scripts/workspace_ui.gd")
const DragPreview = preload("res://scripts/molecule_drag_preview.gd")
const BoardScene = preload("res://scenes/assembly_board.tscn")
const HelpDialog = preload("res://scripts/help_dialog.gd")
const CONTROLS_HELP := """Ľavé tlačidlo
Potiahni atóm alebo molekulu. Ak má atóm otvorené elektrónové vrstvy, presunie sa iba on. Klik ukáže vonkajšiu vrstvu, dvojklik všetky vrstvy.

Pravé tlačidlo
Potiahni z jedného atómu na druhý a pusť. Opakovaním pridáš druhú a tretiu čiaru väzby.

Odstránenie väzby
Klikni na čiaru a použi tlačidlo Odstrániť väzbu alebo kláves Delete.

Inventár
Potiahni voľný atóm alebo rozpoznanú molekulu do inventára vľavo. Kartu môžeš potiahnuť späť na plochu. Do laboratória sa prenesie iba obsah inventára."""
const DUET_IMAGE = preload("res://assets/hydrogen_duet.svg")
const BOND_HELP := """Vľavo má každý vodík vo svojej jedinej vrstve jeden elektrón. Vpravo ich vodíky zdieľajú ako spoločný pár. Každý si započíta oba elektróny (duet). Jeden spoločný pár tvorí jednu jednoduchú kovalentnú väzbu H–H.

Pri skladaní spočítaj červené bodky na vonkajšej vrstve. Vodík potrebuje do duetu 2 elektróny. Pri kyslíku, dusíku a uhlíku pomáha pravidlo oktetu (8 elektrónov): kyslíku zvyčajne chýbajú 2, dusíku 3 a uhlíku 4. Dvojitá väzba zdieľa dva páry, trojitá tri."""
var board: Control
var status: Label
var notice: Label
var workspace: HBoxContainer
var stock: VBoxContainer
var stock_names := {}
var controls: VBoxContainer
var finish_button: Button
var confirmation: ConfirmationDialog
var result_page: VBoxContainer
var delete_button: Button
var result: Dictionary = {}
var heading: Label
var assembly_goal: Label
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
	UI.label(tray, "INVENTÁR", 13, UI.MUTED, true)
	stock = UI.scroll_column(tray)
	for item in AlphaCatalog.stock_items(AlphaCatalog.load_data()):
		stock_names[item.id] = item.name
	var canvas := UI.panel(workspace, UI.CANVAS)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := UI.column(canvas, 0)
	UI.label(center, "MOLEKULÁRNA PLOCHA", 13, UI.MUTED, true)
	var sidebar := UI.panel(workspace)
	sidebar.custom_minimum_size.x = 246
	controls = UI.column(sidebar, 8)
	assembly_goal = UI.label(controls, "", 14, UI.MUTED)
	assembly_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_button = UI.button(controls, "×    Odstrániť väzbu")
	delete_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	delete_button.hide()
	delete_button.pressed.connect(func(): board.delete_selected_bond())
	var help_dialog := HelpDialog.new()
	add_child(help_dialog)
	help_dialog.illustration.texture = DUET_IMAGE
	var help_arrow := help_dialog.add_button("Kovalentná väzba →", true)
	help.pressed.connect(func():
		help_arrow.text = "Kovalentná väzba →"
		help_dialog.illustration.hide()
		help_dialog.open("Ovládanie", CONTROLS_HELP)
	)
	help_arrow.pressed.connect(func():
		var show_bonds := help_dialog.title != "Kovalentná väzba"
		help_arrow.text = "← Ovládanie" if show_bonds else "Kovalentná väzba →"
		help_dialog.title = "Kovalentná väzba" if show_bonds else "Ovládanie"
		help_dialog.text_label.text = BOND_HELP if show_bonds else CONTROLS_HELP
		help_dialog.illustration.visible = show_bonds
		help_dialog.scroll.scroll_vertical = 0
	)
	board = BoardScene.instantiate()
	board.inventory_target = stock_panel
	board.inventory_changed.connect(_refresh_stock)
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
	_refresh_stock()

func _refresh_stock() -> void:
	for child in stock.get_children():
		stock.remove_child(child)
		child.queue_free()
	if board.graph.packed_items.is_empty():
		var hint := UI.label(stock, "Ľavým tlačidlom sem potiahni atóm alebo molekulu, ktorú chceš vziať do laboratória.", 15, UI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var stacks := {}
	for id in board.graph.packed_items:
		var item: Dictionary = board.graph.packed_items[id]
		if not stacks.has(item.stock_id):
			stacks[item.stock_id] = []
		stacks[item.stock_id].append(id)
	for stock_id in stacks:
		var first: int = stacks[stock_id][0]
		var formula: String = board.graph.packed_items[first].formula
		var card := UI.panel(stock, UI.CARD, 10, 18)
		card.custom_minimum_size.y = 72
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		card.tooltip_text = "Potiahni jednu položku späť na voľné miesto na ploche."
		card.set_drag_forwarding(_drag_stored.bind(first, card), Callable(), Callable())
		var line := UI.row(card, 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.badge(line, formula, 42)
		var title := UI.label(line, stock_names[stock_id], 15, UI.TEXT, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.label(line, "×%d" % stacks[stock_id].size(), 16, UI.MUTED)

func _drag_stored(_point: Vector2, id: int, card: Control) -> Variant:
	if not board.graph.packed_items.has(id):
		return null
	var preview := DragPreview.new(board.graph.packed_items[id], board.positions, board.RADIUS)
	card.set_drag_preview(preview)
	return {"board": board, "id": id}

func _show_notice(message: String) -> void:
	notice.text = message

func _update_status() -> void:
	if status == null:
		return
	var counts := {}
	for item in board.graph.packed_items.values():
		counts[item.formula] = counts.get(item.formula, 0) + 1
	var portions := PackedStringArray()
	for formula in counts:
		portions.append("%s × %d" % [formula, counts[formula]])
	status.text = ("Do laboratória: " + ", ".join(portions) if not portions.is_empty() else "Inventár je prázdny.") + "\nAtómy na ploche: %d" % board.graph.atoms.size()
	finish_button.disabled = (board.graph.atoms.is_empty() and board.graph.packed_items.is_empty()) or board.graph.finalized

func request_finish() -> void:
	if board.graph.finalized or (board.graph.atoms.is_empty() and board.graph.packed_items.is_empty()):
		return
	board.cancel_interaction()
	if not board.graph.atoms.is_empty():
		confirmation.dialog_text = "Na ploche zostáva %d atómov vrátane atómov v molekulách. Zahodia sa. Do laboratória prenesieš iba položky v inventári (%d)." % [board.graph.atoms.size(), board.graph.packed_items.size()]
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
	for id in result.products:
		_label(result_page, "%s × %d" % [stock_names[id], result.products[id]], 23)
	if result.products.is_empty():
		_label(result_page, "Inventár bol prázdny.", 21)
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
