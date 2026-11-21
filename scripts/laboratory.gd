extends MarginContainer
signal new_collection_requested
signal progress_changed
signal new_game_requested
signal products_created(products: Dictionary)
const Catalog = preload("res://scripts/catalog.gd")
const ReagentCard = preload("res://scripts/reagent_card.gd")
const FlaskTarget = preload("res://scripts/flask_drop_target.gd")
const DiscoveryPanel = preload("res://scripts/discovery_panel.gd")
const HelpDialog = preload("res://scripts/help_dialog.gd")
var help_dialog: AcceptDialog
const Experiment = preload("res://scripts/lab_experiment.gd")
var experiment = Experiment.new()
var heat_button: Button
var cool_button: Button
var instrument_select: OptionButton
var run_button: Button
var outlet_buttons := {}
var temperature_label: Label
var process_notice: Label
var animation_time := 0.0
var inventory: RefCounted
var research: RefCounted
var discovery: AcceptDialog
var research_button: Button
var research_hint: Label
var collection_button: Button
var rows: Dictionary = {}
var sample_label: Label
var summary: Label
var return_button: Button
var flask: Control
var empty_label: Label
var cards_area: ScrollContainer
var progress_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keep the same content width when labels or the stock tray change height.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4)
	scroll.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := _label(header, "Laboratórium", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_button = Button.new()
	collection_button.text = "Kolekcia"
	collection_button.pressed.connect(func(): discovery.show_collection())
	header.add_child(collection_button)
	var new_game := Button.new()
	new_game.text = "Nová hra"
	new_game.pressed.connect(func(): new_game_requested.emit())
	header.add_child(new_game)
	discovery = DiscoveryPanel.new()
	add_child(discovery)
	var help := Button.new()
	help.text = "? Pomoc"
	header.add_child(help)
	help_dialog = HelpDialog.new()
	var dialog = help_dialog
	add_child(dialog)
	help.pressed.connect(func(): dialog.open("Ako používať laboratórium", "\n\n".join([
		"VZORKA\nVyber prístroj. Klikni na kartu látky alebo ju presuň na obrázok prístroja. Jedna karta pridá jednu porciu. Pri zmene prístroja sa vložená vzorka prenesie a plyny z výstupov sa vrátia do zásoby.",
		"BANKA S OHREVOM\nČistá voda pri tlaku 1 atm vrie približne pri 100 °C. Pri ochladení var prestane a voda zostane vodou. Pri zmesi metánu a kyslíka sleduj rovnicu a herný prah ohrevu. Hodnota prahu slúži iba pre hru.",
		"ELEKTROLYZÉR\nPridaj vodu a zapni prúd. Vodík a kyslík sa zhromaždia oddelene. Kliknutím na výstup odoberieš všetky jeho porcie.",
		"ĎALŠÍ PRÍSTROJ\nPostupne odomkneš aj ďalší prístroj. Pri výbere uvidíš rovnicu, podmienky a počet chýbajúcich porcií.",
		"OBJAVY A ULOŽENIE\nPrvýkrát získaný produkt sa pridá do kolekcie. Vrátiť obsah vráti do zásoby látky zo vzorky aj z výstupov. Po načítaní hry sú všetky porcie v zásobe. Rozpracovaný zber a skladanie sa neukladajú."
	])))
	summary = _label(page, "", 16)
	summary.modulate = Color("a5b4cb")
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 18)
	page.add_child(progress_row)
	progress_label = _label(progress_row, "", 16)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(160, 12)
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("29404f")
	track.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7ed9c3")
	fill.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_row.add_child(progress_bar)
	var instrument_label := _label(progress_row, "Prístroj", 16)
	instrument_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	instrument_select = OptionButton.new()
	instrument_select.tooltip_text = "Vzorka sa presunie do zvoleného prístroja. Plyny z výstupov sa vrátia do zásoby."
	progress_row.add_child(instrument_select)
	for id in experiment.catalog.reactions:
		instrument_select.add_item(experiment.catalog.reactions[id].instrument_name)
		instrument_select.set_item_metadata(instrument_select.item_count - 1, id)
	instrument_select.item_selected.connect(_select_instrument)
	var workspace := VBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 4)
	page.add_child(workspace)
	var experience_row := HBoxContainer.new()
	experience_row.add_theme_constant_override("separation", 24)
	experience_row.alignment = BoxContainer.ALIGNMENT_CENTER
	workspace.add_child(experience_row)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	experience_row.add_child(center)
	flask = FlaskTarget.new()
	flask.custom_minimum_size = Vector2(300, 170)
	flask.portion_dropped.connect(_add)
	flask.draw.connect(_draw_flask)
	center.add_child(flask)
	var slot := 0
	for id in experiment.catalog.reactions.electrolyzer.products:
		var outlet := Button.new()
		outlet.position = Vector2(8 + slot * 144, 120)
		outlet.size = Vector2(138, 42)
		outlet.tooltip_text = "Presunúť plyn z výstupu do zásoby"
		outlet.pressed.connect(_collect_outlet.bind(id))
		flask.add_child(outlet)
		outlet_buttons[id] = outlet
		slot += 1
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 380
	tools.add_theme_constant_override("separation", 8)
	experience_row.add_child(tools)
	temperature_label = _label(tools, "", 20)
	var tool_buttons := HBoxContainer.new()
	tools.add_child(tool_buttons)
	heat_button = Button.new()
	heat_button.text = "Nahriať"
	heat_button.toggle_mode = true
	heat_button.pressed.connect(func(): _set_tool("heat" if heat_button.button_pressed else "off"))
	tool_buttons.add_child(heat_button)
	cool_button = Button.new()
	cool_button.text = "Ochladiť"
	cool_button.toggle_mode = true
	cool_button.pressed.connect(func(): _set_tool("cool" if cool_button.button_pressed else "off"))
	tool_buttons.add_child(cool_button)
	run_button = Button.new()
	tool_buttons.add_child(run_button)
	run_button.pressed.connect(_run_instrument)
	process_notice = _label(tools, "", 15)
	process_notice.custom_minimum_size = Vector2(380, 70)
	experiment.process_changed.connect(_process_notice)
	experiment.reaction_completed.connect(_reaction_completed)
	sample_label = _label(workspace, "", 18)
	sample_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	workspace.add_child(actions)
	return_button = Button.new()
	return_button.text = "Vrátiť obsah"
	return_button.pressed.connect(_return_sample)
	actions.add_child(return_button)
	research_button = Button.new()
	research_button.text = "Karta látky"
	research_button.pressed.connect(_investigate)
	actions.add_child(research_button)
	research_hint = _label(workspace, "", 15)
	research_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	research_hint.modulate = Color("a5b4cb")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(spacer)
	var stock_header := HBoxContainer.new()
	page.add_child(stock_header)
	var stock_title := _label(stock_header, "Zásoba", 21)
	stock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := _label(stock_header, "Klikni na kartu alebo ju potiahni do prístroja", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.modulate = Color("a5b4cb")
	empty_label = _label(page, "Prázdna zásoba", 17)
	var card_scroll := ScrollContainer.new()
	cards_area = card_scroll
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.custom_minimum_size.y = 162
	page.add_child(card_scroll)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	card_scroll.add_child(cards)
	for substance in Catalog.load_data().substances:
		var row := VBoxContainer.new()
		cards.add_child(row)
		var button := ReagentCard.new()
		button.substance_id = substance.id
		button.formula = substance.display_formula
		button.tooltip_text = "Kliknutie alebo presunutie pridá jednu porciu do prístroja"
		button.custom_minimum_size = Vector2(190, 148)
		button.pressed.connect(_add.bind(substance.id))
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("19333e") if state == "normal" else Color("24514f")
			style.border_color = Color("365767") if state == "normal" else Color("8fe4d3")
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			button.add_theme_stylebox_override(state, style)
		row.add_child(button)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 8
		content.offset_bottom = -8
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(content)
		var formula := _label(content, substance.display_formula, 30)
		formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var name_label := _label(content, substance.name, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label := _label(content, "", 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color("8fe4d3")
		var status := _label(content, "", 13)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows[substance.id] = {"row": row, "label": label, "button": button, "data": substance, "status": status}
	var next := Button.new()
	next.text = "Nový zber"
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next.pressed.connect(func(): new_collection_requested.emit())
	next.pressed.connect(_reset_experiment)
	page.add_child(next)

func setup(state: RefCounted, research_state: RefCounted) -> void:
	inventory = state
	research = research_state
	instrument_select.select(0)
	experiment.instrument = "flask"
	_reset_experiment()
	discovery.research = research
	flask.inventory = state
	for row in rows.values():
		row.button.inventory = state

func _add(id: String) -> void:
	if inventory.add_to_sample(id):
		_reset_experiment()
		progress_changed.emit()
	refresh()

func _return_sample() -> void:
	inventory.return_sample()
	_reset_experiment()
	refresh()
	progress_changed.emit()

func _reset_experiment() -> void:
	experiment.reset()
	process_notice.text = ""

func _select_instrument(index: int) -> void:
	var id: String = instrument_select.get_item_metadata(index)
	var required: String = experiment.catalog.reactions[id].get("requires_element", "")
	if not required.is_empty() and required not in research.available_elements:
		return
	for gas in inventory.outlets.keys():
		inventory.collect_outlet(gas)
	experiment.instrument = id
	_reset_experiment()
	refresh()
	progress_changed.emit()

func _collect_outlet(id: String) -> void:
	if inventory.collect_outlet(id):
		process_notice.text = ""
		refresh()
		progress_changed.emit()

func _run_instrument() -> void:
	if experiment.recipe.trigger != "heat":
		experiment.react(inventory.sample, experiment.recipe.trigger, inventory.outlets)

func _reaction_completed(products: Dictionary, excess: Dictionary) -> void:
	var details := "Spotreba: %s. Produkty: %s. Zvyšok: %s.\n%s" % [
		experiment.quantities(experiment.recipe.reactants), experiment.quantities(products),
		"žiadny" if excess.is_empty() else experiment.quantities(excess), experiment.recipe.explanation]
	process_notice.text = experiment.equation() + "\n" + details if experiment.recipe.trigger == "heat" else details
	products_created.emit(products)
	refresh()
	progress_changed.emit()

func _set_tool(value: String) -> void:
	experiment.set_mode(value, inventory.sample)
	process_notice.text = ""
	if experiment.boiling:
		_process_notice("boiling")
	_update_experiment()

func _process_notice(id: String) -> void:
	match id:
		"boiling":
			process_notice.text = "Var · pri 1 atm približne 100 °C. Bubliny obsahujú vodnú paru. Biely oblak tvoria kvapôčky; samotná para je neviditeľná. Voda zostáva H₂O."
		"cooled":
			process_notice.text = "Ochladenie pod 100 °C zastavilo var. Nevznikla nová látka. Úplné odparenie ani kondenzáciu tu nemodelujeme."

func _process(delta: float) -> void:
	if inventory == null or not is_visible_in_tree():
		return
	animation_time += delta
	if experiment.recipe.trigger == "heat":
		experiment.step(delta, inventory.sample)
		_update_experiment()

func _update_experiment() -> void:
	var water: bool = experiment.is_water(inventory.sample)
	var empty: bool = inventory.sample.is_empty()
	var thermal: bool = experiment.recipe.trigger == "heat"
	heat_button.visible = thermal
	cool_button.visible = thermal
	run_button.visible = not thermal
	if not thermal:
		run_button.text = experiment.recipe.action
		var reason: String = experiment.ingredient_issue(inventory.sample)
		if not inventory.outlets.is_empty():
			reason = "Najprv odober plyny z výstupov."
		run_button.disabled = not reason.is_empty()
		run_button.tooltip_text = reason
		temperature_label.text = experiment.equation()
		if process_notice.text.is_empty():
			process_notice.text = "%s\n%s" % [experiment.recipe.condition, reason if not reason.is_empty() else "Prístroj je pripravený."]
		for id in outlet_buttons:
			var outlet: Button = outlet_buttons[id]
			outlet.visible = experiment.recipe.get("separate_outputs", false)
			outlet.text = "%s × %d" % [experiment.formulas[id], inventory.outlets.get(id, 0)]
			outlet.disabled = not inventory.outlets.has(id)
		flask.queue_redraw()
		return
	for outlet in outlet_buttons.values():
		outlet.hide()
	heat_button.disabled = empty
	cool_button.disabled = empty
	heat_button.set_pressed_no_signal(experiment.mode == "heat")
	cool_button.set_pressed_no_signal(experiment.mode == "cool")
	temperature_label.text = ("%.0f °C · 1 atm" if water else "%.0f °C · model") % experiment.temperature if not empty else "Teplota · —"
	if process_notice.text.is_empty():
		if water:
			process_notice.text = {"heat": "Ohrev vody · 1 atm. Sleduj teplotu a zmenu pri 100 °C.", "cool": "Chladenie vody · teplota klesá k 20 °C."}.get(experiment.mode, "Čistá voda · zapni horák alebo chladenie.")
		elif "C" in research.available_elements:
			var issue: String = experiment.ingredient_issue(inventory.sample)
			process_notice.text = "%s\nHerný prah pri ohreve: %d °C. %s" % [experiment.equation(), int(experiment.recipe.temperature), issue if not issue.is_empty() else "Zmes je pripravená."]
		elif empty:
			process_notice.text = "Vlož vzorku do banky."
		else:
			process_notice.text = "Mení sa modelová teplota. Pre túto vzorku nemáme ďalší podporovaný recept; nové látky nevznikajú."
	flask.queue_redraw()

func _investigate() -> void:
	var id: String = research.sample_id(inventory.sample)
	if id.is_empty() or not research.researched.has(id):
		return
	discovery.show_substance(id)

func refresh() -> void:
	for i in instrument_select.item_count:
		var rule: Dictionary = experiment.catalog.reactions[instrument_select.get_item_metadata(i)]
		var required: String = rule.get("requires_element", "")
		var locked: bool = not required.is_empty() and required not in research.available_elements
		instrument_select.set_item_disabled(i, locked)
		instrument_select.set_item_text(i, "Uzamknutý prístroj" if locked else str(rule.instrument_name))
	var total := 0
	var contents: Array[String] = []
	var has_stock := false
	for id in rows:
		var row: Dictionary = rows[id]
		row.row.visible = inventory.stock[id] > 0
		has_stock = has_stock or row.row.visible
		row.label.text = _portions(inventory.stock[id])
		row.status.text = "Objavené" if research.researched.has(id) else ""
		row.button.text = ""
		row.button.disabled = inventory.stock[id] == 0
		var count: int = inventory.sample.get(id, 0)
		total += inventory.stock[id] + count + inventory.outlets.get(id, 0)
		if count > 0:
			contents.append("%s × %d%s" % [row.data.display_formula, count, " (plyn)" if row.data.state_at_room_conditions == "gas" else ""])
	empty_label.visible = true
	empty_label.custom_minimum_size.y = 24
	empty_label.text = "" if has_stock else "Prázdna zásoba"
	# Keep the bottom tray's height even when the last card moves into the flask.
	cards_area.visible = true
	summary.text = "Spolu: " + _portions(total)
	sample_label.text = "Vzorka: " + (", ".join(contents) if not contents.is_empty() else "prázdna")
	return_button.disabled = contents.is_empty() and inventory.outlets.is_empty()
	var sample_id: String = research.sample_id(inventory.sample)
	research_button.disabled = sample_id.is_empty() or not research.researched.has(sample_id)
	research_button.text = "Karta látky"
	research_hint.text = "Nové látky sa pridávajú do kolekcie automaticky." if contents.is_empty() else ""
	collection_button.text = "Kolekcia · %d" % research.researched.size()
	var progress: Vector2i = research.progress_to_next_element()
	progress_bar.visible = progress.y > 0
	if progress_bar.visible:
		progress_bar.max_value = progress.y
		progress_bar.value = progress.x
		progress_label.text = "K novému prvku · %d/%d" % [progress.x, progress.y]
	else:
		progress_label.text = "Všetky dostupné prvky sú odomknuté"
	_update_experiment()
	flask.queue_redraw()

func _portions(count: int) -> String:
	return "%d %s" % [count, "porcia" if count == 1 else ("porcie" if count >= 2 and count <= 4 else "porcií")]

func _draw_flask() -> void:
	var center := flask.size.x / 2
	var tint := Color("8fe4d3") if flask.highlighted else Color("a5cddc")
	flask.draw_style_box(_drop_style(flask.highlighted), Rect2(Vector2.ZERO, flask.size))
	if experiment.instrument == "electrolyzer":
		for id in outlet_buttons:
			var x: float = outlet_buttons[id].position.x + outlet_buttons[id].size.x / 2
			flask.draw_rect(Rect2(x - 30, 26, 60, 72), tint, false, 3)
			flask.draw_line(Vector2(x, 98), Vector2(x, 118), tint, 3)
			flask.draw_string(get_theme_default_font(), Vector2(x - 60, 67), rows[id].data.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, tint)
		return
	if experiment.instrument == "reactor":
		flask.draw_rect(Rect2(center - 82, 32, 164, 83), tint, false, 4)
		flask.draw_line(Vector2(center - 118, 72), Vector2(center - 82, 72), tint, 4)
		flask.draw_line(Vector2(center + 82, 72), Vector2(center + 118, 72), tint, 4)
		flask.draw_string(get_theme_default_font(), Vector2(center - 80, 79), "Katalyzátor", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, tint)
		flask.draw_string(get_theme_default_font(), Vector2(0, 151), "Priemyselný reaktor", HORIZONTAL_ALIGNMENT_CENTER, flask.size.x, 17, tint)
		return
	var points := PackedVector2Array([Vector2(center - 20, 8), Vector2(center - 20, 45), Vector2(center - 68, 128), Vector2(center + 68, 128), Vector2(center + 20, 45), Vector2(center + 20, 8)])
	flask.draw_polyline(points, tint, 4, true)
	flask.draw_line(Vector2(center - 28, 8), Vector2(center + 28, 8), tint, 4)
	flask.draw_string(get_theme_default_font(), Vector2(center - 34, 155), "Pusti kartu", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
	if inventory != null and inventory.sample.get("water", 0) > 0 and (experiment.temperature < 100.0 or experiment.is_water(inventory.sample)):
		flask.draw_colored_polygon(PackedVector2Array([Vector2(center - 38, 83), Vector2(center - 61, 124), Vector2(center + 61, 124), Vector2(center + 38, 83)]), Color("367990"))
	if experiment.boiling:
		for i in 7:
			var height := fmod(animation_time * 30 + i * 7, 35)
			flask.draw_arc(Vector2(center - 30 + i * 10, 121 - height), 2 + i % 3, 0, TAU, 16, Color("a4e5ed"), 1.5, true)
	if experiment.mode == "heat":
		var flicker := sin(animation_time * 12) * 3
		flask.draw_colored_polygon(PackedVector2Array([Vector2(center + 90, 130), Vector2(center + 103, 100 + flicker), Vector2(center + 116, 130)]), Color("ffb45c"))
	elif experiment.mode == "cool":
		for angle in 3:
			var direction := Vector2.from_angle(angle * PI / 3) * 13
			flask.draw_line(Vector2(center + 103, 115) - direction, Vector2(center + 103, 115) + direction, Color("80d4ff"), 2, true)

func _drop_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("173e42") if active else Color("101f2e")
	style.border_color = Color("8fe4d3") if active else Color("315064")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func close_dialogs() -> void:
	help_dialog.hide()
	discovery.hide()
	discovery.pending.clear()
