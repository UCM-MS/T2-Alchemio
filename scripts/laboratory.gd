extends MarginContainer
signal new_collection_requested
signal progress_changed
signal new_game_requested
signal robot_requested
signal experiment_completed(id: String, products: Dictionary)

const UI = preload("res://scripts/workspace_ui.gd")
const WasteBin = preload("res://scripts/laboratory_bin.gd")
const ReagentCard = preload("res://scripts/reagent_card.gd")
const Apparatus = preload("res://scripts/laboratory_apparatus.gd")
const DiscoveryPanel = preload("res://scripts/discovery_panel.gd")
const HelpDialog = preload("res://scripts/help_dialog.gd")
const Experiment = preload("res://scripts/lab_experiment.gd")

var experiment = Experiment.new()
var inventory: RefCounted
var research: RefCounted
var waste_bin: Control
var flask: Control
var help_dialog: AcceptDialog
var discovery: AcceptDialog
var station_buttons := {}
var station := "combustion"
var selected_instruments := {}
var instrument_select: OptionButton
var heat_button: Button
var cool_button: Button
var action_buttons := {}
var equation_label: Label
var temperature_label: Label
var process_notice: Label
var result_message := ""
var output_row: HFlowContainer
var outlet_buttons := {}
var research_button: Button
var collection_button: Button
var rows: Dictionary = {}
var sample_label: Label
var summary: Label
var return_button: Button
var empty_label: Label
var cards_area: ScrollContainer
var progress_label: Label
var progress_bar: ProgressBar
var goals_label: Label
var next_button: Button

func _ready() -> void:
	var layout := UI.column(self, 0)
	var tabs := UI.nav(layout, "Laboratórium")
	collection_button = tabs["Kolekcia"]
	collection_button.disabled = false
	collection_button.pressed.connect(func(): discovery.show_collection())
	next_button = tabs["Hracia plocha"]
	next_button.tooltip_text = "Nový zber"
	next_button.pressed.connect(func(): new_collection_requested.emit())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var page := UI.page(scroll)
	page.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := UI.row(page, 10)
	var heading := UI.heading(header, "POKUSY A REAKCIE", "Laboratórium")
	heading.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var progress := UI.column(header, 4)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_label = UI.label(progress, "", 14, UI.MUTED)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(150, 6)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", UI.box(UI.EDGE, UI.EDGE, 3, 0))
	progress_bar.add_theme_stylebox_override("fill", UI.box(UI.ACCENT, UI.ACCENT, 3, 0))
	progress.add_child(progress_bar)
	var new_game := UI.button(header, "Nová hra")
	new_game.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	new_game.pressed.connect(func(): new_game_requested.emit())
	var robot := UI.button(header, "Robot")
	robot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	robot.pressed.connect(func(): robot_requested.emit())
	discovery = DiscoveryPanel.new()
	add_child(discovery)
	var help := UI.button(header, "Pomoc")
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help_dialog = HelpDialog.new()
	var dialog = help_dialog
	add_child(dialog)

	help.pressed.connect(func(): dialog.open("Ako používať laboratórium", "\n\n".join([
		"POKUS\nVyber Kvapaliny alebo Spaľovanie a potom prístroj. Klikni na kartu látky alebo ju potiahni na stojan. Každá karta pridá jednu porciu. Výsledok závisí od vzorky a použitého nástroja.",
		"VÝSLEDOK\nPo pokuse odober produkty z výstupov. Vrátiť obsah presunie do zásoby aj zvyšné reaktanty. Pri zmene prístroja sa všetok obsah vráti do zásoby.",
		"POSTUP\nUhlík odomkne prvé úspešné spaľovanie vodíka a prvá elektrolýza vody. V druhej etape dokonči oba pokusy s tuhým uhlíkom a over vplyv CO₂ na vodu. Doplnkové pokusy môžeš skúšať kedykoľvek po ich sprístupnení.",
		"ULOŽENIE\nZásoba, objavy a dokončené pokusy sa ukladajú. Po načítaní sú všetky porcie späť v zásobe."
	])))
	UI.label(page, "SPÔSOB POKUSU", 13, UI.MUTED, true)
	var station_row := UI.row(page, 10)
	var station_group := ButtonGroup.new()
	for id in ["combustion", "liquid"]:
		var button := Button.new()
		button.text = "Kvapaliny a roztoky" if id == "liquid" else "Spaľovanie"
		button.custom_minimum_size = Vector2(294, 56)
		button.add_theme_font_size_override("font_size", 18)
		button.toggle_mode = true
		button.button_group = station_group
		button.pressed.connect(_select_station.bind(id))
		station_row.add_child(button)
		station_buttons[id] = button
	var workspace := UI.row(page, 12)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stock_panel := UI.panel(workspace)
	stock_panel.custom_minimum_size.x = 242
	var tray := UI.column(stock_panel, 8)
	UI.label(tray, "ZÁSOBA LÁTOK", 14, UI.MUTED, true)
	summary = UI.label(tray, "", 13, UI.MUTED)
	empty_label = UI.label(tray, "Prázdna zásoba", 16)
	var cards := UI.scroll_column(tray)
	cards_area = cards.get_parent()
	waste_bin = WasteBin.new()
	tray.add_child(waste_bin)
	waste_bin.portion_dropped.connect(_discard_stock)
	var canvas := UI.panel(workspace, UI.CANVAS)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := UI.column(canvas, 5)
	UI.label(center, "POKUSNÁ PLOCHA", 13, UI.MUTED, true)
	flask = Apparatus.new()
	flask.experiment = experiment
	flask.custom_minimum_size = Vector2(300, 174)
	flask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flask.portion_dropped.connect(_add)
	center.add_child(flask)
	sample_label = UI.label(center, "", 15)
	sample_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := UI.row(center, 8)
	return_button = UI.button(actions, "Vrátiť obsah")
	return_button.pressed.connect(_return_sample)
	research_button = UI.button(actions, "Karta látky")
	research_button.pressed.connect(_investigate)
	output_row = HFlowContainer.new()
	center.add_child(output_row)
	for substance in experiment.catalog.substances:
		var outlet := UI.button(output_row, "")
		outlet.tooltip_text = "Odobrať produkt do zásoby"
		outlet.pressed.connect(_collect_outlet.bind(substance.id))
		outlet.hide()
		outlet_buttons[substance.id] = outlet
	goals_label = UI.label(center, "", 13, UI.MUTED)
	goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var settings_panel := UI.panel(workspace)
	settings_panel.custom_minimum_size.x = 282
	var settings := UI.column(settings_panel, 8)
	UI.label(settings, "NASTAVENIE POKUSU", 13, UI.MUTED, true)
	UI.label(settings, "Pomôcka", 14, UI.MUTED)
	instrument_select = OptionButton.new()
	instrument_select.fit_to_longest_item = false
	instrument_select.item_selected.connect(_choose_instrument)
	settings.add_child(instrument_select)
	var details := UI.scroll_column(settings)
	details.get_parent().custom_minimum_size.y = 78
	UI.label(details, "Reakcia", 14, UI.MUTED)
	equation_label = UI.label(details, "", 17, UI.MINT, true)
	equation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	temperature_label = UI.label(details, "", 15)
	process_notice = UI.label(details, "", 15)
	process_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tool_buttons := UI.column(settings, 4)
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
	for id in experiment.catalog.actions:
		var button := Button.new()
		button.text = experiment.catalog.actions[id].name
		button.pressed.connect(_run_action.bind(id))
		tool_buttons.add_child(button)
		UI.primary(button)
		action_buttons[id] = button
	experiment.process_changed.connect(_process_notice)
	experiment.reaction_completed.connect(_reaction_completed)

	for substance in AlphaCatalog.stock_items(experiment.catalog):
		var button := ReagentCard.new()
		button.substance_id = substance.id
		button.formula = substance.display_formula
		button.tooltip_text = "Kliknutie alebo presunutie pridá jednu porciu do prístroja"
		button.custom_minimum_size.y = 84
		button.pressed.connect(_add.bind(substance.id))
		cards.add_child(button)
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 9
		line.offset_right = -9
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(line)
		UI.badge(line, substance.display_formula, 50)
		var content := UI.column(line, 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := UI.label(content, substance.name, 16, UI.TEXT, true)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var status := UI.label(content, "", 11, UI.MUTED)
		var count := UI.label(line, "", 15)
		rows[substance.id] = {"row": button, "label": count, "button": button, "data": substance, "status": status}


func setup(state: RefCounted, research_state: RefCounted) -> void:
	inventory = state
	research = research_state
	discovery.research = research
	flask.inventory = state
	waste_bin.inventory = state
	for row in rows.values():
		row.button.inventory = state
	station = "combustion"
	experiment.instrument_id = "burner"
	selected_instruments = {"combustion": "burner", "liquid": "beaker"}
	_reset_experiment()
	refresh()

func _add(id: String) -> void:
	if experiment.is_running():
		return
	if inventory.add_to_sample(id):
		_reset_experiment()
		progress_changed.emit()
	refresh()

func _discard_stock(id: String) -> void:
	if not experiment.is_running() and inventory.take_from_stock(id):
		refresh()
		progress_changed.emit()

func _return_sample() -> void:
	inventory.return_sample()
	_reset_experiment()
	refresh()
	progress_changed.emit()

func _reset_experiment() -> void:
	experiment.reset()
	result_message = ""
	flask.elapsed = 0.0

func _select_station(id: String) -> void:
	if experiment.is_running() or station == id:
		return
	station = id
	_select_instrument(selected_instruments[id])

func _choose_instrument(index: int) -> void:
	_select_instrument(instrument_select.get_item_metadata(index))

func _select_instrument(id: String) -> void:
	if experiment.is_running() or id == experiment.instrument_id or not experiment.is_available(experiment.catalog.instruments[id]):
		return
	experiment.instrument_id = id
	selected_instruments[station] = id
	_return_sample()

func _collect_outlet(id: String) -> void:
	if inventory.collect_outlet(id):
		refresh()
		progress_changed.emit()

func _run_action(id: String) -> void:
	if experiment.start(id, inventory.sample, inventory.outlets):
		result_message = ""
		flask.elapsed = 0.0
		refresh()

func _reaction_completed(products: Dictionary, excess: Dictionary) -> void:
	var id: String = experiment.result.id
	var recipe: Dictionary = experiment.catalog.experiments[id]
	result_message = "%s\n%s\nProdukty: %s. Zvyšok: %s." % [
		recipe.name, recipe.explanation, experiment.quantities(products),
		"žiadny" if excess.is_empty() else experiment.quantities(excess)]
	experiment_completed.emit(id, products)
	refresh()
	progress_changed.emit()

func _set_tool(value: String) -> void:
	experiment.set_mode(value, inventory.sample)
	if not experiment.boiling:
		result_message = ""
	_update_experiment()

func _process_notice(id: String) -> void:
	if id == "boiling":
		result_message = "Bubliny obsahujú vodnú paru. Voda zostáva H₂O."
	else:
		result_message = "Var sa zastavil. Voda zostala H₂O."

func _process(delta: float) -> void:
	if inventory == null or not is_visible_in_tree():
		return
	flask.elapsed += delta
	if experiment.is_running() or experiment.can_heat_water(inventory.sample):
		experiment.step(delta, inventory.sample, inventory.outlets)
		_update_experiment()
	elif experiment.instrument_id == "beaker" or flask.last_products.has("water"):
		flask.queue_redraw()

func _update_experiment() -> void:
	var running: bool = experiment.is_running()
	var busy: bool = running or not inventory.outlets.is_empty()
	var can_heat: bool = experiment.can_heat_water(inventory.sample) and not busy
	temperature_label.visible = experiment.instrument_id == "beaker"
	temperature_label.text = "Teplota · %.0f °C" % experiment.temperature if can_heat else "Teplota · —"
	heat_button.visible = temperature_label.visible
	cool_button.visible = temperature_label.visible
	heat_button.disabled = not can_heat
	cool_button.disabled = not can_heat
	heat_button.tooltip_text = "Vlož čistú vodu." if not can_heat else ""
	cool_button.tooltip_text = heat_button.tooltip_text
	heat_button.set_pressed_no_signal(experiment.mode == "heat")
	cool_button.set_pressed_no_signal(experiment.mode == "cool")
	var guidance: String = experiment.instrument.instruction
	for id in action_buttons:
		var button: Button = action_buttons[id]
		var available: bool = id in experiment.instrument.actions and experiment.is_available(experiment.catalog.actions[id])
		button.visible = available
		if not available:
			continue
		var plan: Dictionary = experiment.prepare(id, inventory.sample)
		var issue: String = plan.get("issue", "")
		if not inventory.outlets.is_empty():
			issue = "Pred ďalším pokusom odober produkty."
		button.disabled = busy or not issue.is_empty()
		button.tooltip_text = issue
		if not inventory.sample.is_empty() and experiment.instrument.actions.size() == 1 and not issue.is_empty():
			guidance += "\n" + issue
	var equation: String = experiment.result_equation()
	if experiment.boiling or (can_heat and not result_message.is_empty() and equation.is_empty()):
		equation = "H₂O (kvapalina) ⇄ H₂O (para)"
	equation_label.text = equation
	equation_label.visible = not equation.is_empty()
	process_notice.text = result_message if not result_message.is_empty() else guidance
	if running:
		process_notice.text = "Prebieha pokus…"
	flask.last_products = experiment.result.get("products", {})
	flask.queue_redraw()

func _refresh_choices() -> void:
	experiment.available_elements = research.available_elements
	instrument_select.clear()
	for id in experiment.catalog.instruments:
		var tool: Dictionary = experiment.catalog.instruments[id]
		if tool.station != station or not experiment.is_available(tool):
			continue
		instrument_select.add_item(tool.name)
		var index := instrument_select.item_count - 1
		instrument_select.set_item_metadata(index, id)
		if id == experiment.instrument_id:
			instrument_select.select(index)
	instrument_select.disabled = experiment.is_running()
	for id in station_buttons:
		station_buttons[id].set_pressed_no_signal(id == station)
		station_buttons[id].disabled = experiment.is_running()

func _investigate() -> void:
	var id: String = research.sample_id(inventory.sample)
	if research.researched.has(id):
		discovery.show_substance(id)

func refresh() -> void:
	_refresh_choices()
	var total := 0
	var contents := PackedStringArray()
	var has_stock := false
	for id in rows:
		var row: Dictionary = rows[id]
		var stock: int = inventory.stock[id]
		row.row.visible = stock > 0
		has_stock = has_stock or row.row.visible
		row.label.text = "×%d" % stock
		row.status.text = "Atóm" if id in research.available_elements else ("Objavené" if research.researched.has(id) else "")
		row.button.disabled = experiment.is_running() or stock == 0
		var count: int = inventory.sample.get(id, 0)
		var output: int = inventory.outlets.get(id, 0)
		total += stock + count + output
		if count > 0:
			contents.append("%s × %d" % [row.data.display_formula, count])
		if id in outlet_buttons:
			outlet_buttons[id].visible = output > 0
			outlet_buttons[id].text = "Odobrať %s × %d" % [row.data.display_formula, output]
	empty_label.visible = not has_stock
	summary.text = "Celková zásoba: " + _portions(total)
	sample_label.text = "Vzorka: " + (", ".join(contents) if not contents.is_empty() else "prázdna")
	return_button.disabled = experiment.is_running() or (contents.is_empty() and inventory.outlets.is_empty())
	research_button.disabled = not research.researched.has(research.sample_id(inventory.sample))
	next_button.disabled = experiment.is_running()
	var progress: Vector2i = research.stage_progress()
	progress_bar.max_value = progress.y
	progress_bar.value = progress.x
	var stage: String = research.stage_id()
	progress_label.text = ("Etapa 1 · Odomkni C" if stage == "water" else "Etapa 2 · Uhlík") + " · %d/%d" % [progress.x, progress.y]
	goals_label.text = "Etapa dokončená. " if stage == "carbon" and progress.x == progress.y else ""
	goals_label.text += research.assembly_goal()
	var next_experiments := PackedStringArray()
	for id in research.catalog.progression[stage].required:
		if not research.completed_experiments.has(id):
			next_experiments.append(experiment.catalog.experiments[id].name)
	if not next_experiments.is_empty():
		goals_label.text += "\nZostáva: " + " · ".join(next_experiments)
	_update_experiment()

func _portions(count: int) -> String:
	return "%d %s" % [count, "porcia" if count == 1 else ("porcie" if count >= 2 and count <= 4 else "porcií")]

func close_dialogs() -> void:
	help_dialog.hide()
	discovery.hide()
	discovery.pending.clear()
