extends VBoxContainer
signal return_requested
signal completed(result: Dictionary)
signal new_collection_requested
const BoardScene = preload("res://scenes/assembly_board.tscn")
var board: Control
var status: Label
var notice: Label
var controls: HBoxContainer
var finish_button: Button
var confirmation: ConfirmationDialog
var result_page: VBoxContainer
var mode_buttons: Array[Button] = []
var result: Dictionary = {}
var heading: Label
var instructions: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	heading = _label(self, "Zostav molekuly", 28)
	instructions = _label(self, "Presuň atómy. Pre väzbu vyber jej typ a klikni na dva atómy.", 17)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	add_child(controls)
	var group := ButtonGroup.new()
	for i in 4:
		var button := _button(controls, ["Presun", "Jednoduchá", "Dvojitá", "Trojitá"][i])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == 0
		button.pressed.connect(_set_mode.bind(i))
		mode_buttons.append(button)
	var delete_button := _button(controls, "Odstrániť väzbu")
	delete_button.pressed.connect(func(): board.delete_selected_bond())
	board = BoardScene.instantiate()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.changed.connect(_update_status)
	board.feedback.connect(_show_notice)
	add_child(board)
	status = _label(self, "", 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = _label(self, "Presun: ťahaj atóm. Kliknutím na čiaru vyber väzbu; Delete ju odstráni.", 16)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.modulate = Color("a5b4cb")
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 20)
	add_child(footer)
	var back := _button(footer, "← Späť na mapu")
	back.pressed.connect(func(): board.cancel_interaction(); return_requested.emit())
	finish_button = _button(footer, "Dokončiť skladanie →")
	finish_button.pressed.connect(request_finish)
	confirmation = ConfirmationDialog.new()
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

func _set_mode(value: int) -> void:
	board.set_mode(value)
	_show_notice("Ťahaj atómy. Klikni na väzbu a stlač Delete." if value == 0 else "Klikni na prvý a potom na druhý atóm. Rovnaká dvojica zmení typ väzby.")

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
		confirmation.dialog_text = "Zvyšné atómy (%d) sa odhodia. Zachovajú sa iba rozpoznané molekuly." % preview.discarded_atoms.size()
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
		_label(result_page, "Nebola rozpoznaná žiadna molekula.", 21)
	_label(result_page, "Odhodené atómy: %d" % result.discarded_atoms.size(), 18)
	_label(result_page, "Porcie boli pridané do zásoby.", 17)
	var next := _button(result_page, "Nový zber →")
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

