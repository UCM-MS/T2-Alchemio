extends MarginContainer
signal new_collection_requested
const Catalog = preload("res://scripts/catalog.gd")
const ReagentCard = preload("res://scripts/reagent_card.gd")
const FlaskTarget = preload("res://scripts/flask_drop_target.gd")
const DiscoveryPanel = preload("res://scripts/discovery_panel.gd")
const Experiment = preload("res://scripts/lab_experiment.gd")
var experiment = Experiment.new()
var heat_button: Button
var cool_button: Button
var reaction_button: Button
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
	add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	scroll.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := _label(header, "Laboratórium", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_button = Button.new()
	collection_button.text = "Kolekcia"
	collection_button.pressed.connect(func(): discovery.show_collection())
	header.add_child(collection_button)
	discovery = DiscoveryPanel.new()
	add_child(discovery)
	var help := Button.new()
	help.text = "? Pomoc"
	header.add_child(help)
	var dialog := AcceptDialog.new()
	dialog.title = "Ako používať laboratórium"
	dialog.ok_button_text = "Rozumiem"
	dialog.dialog_text = "ZÁSOBA A VÝSKUM\nPotiahni kartu na banku alebo klikni: pridá sa jedna porcia. Pustenie mimo nič neminie.\nPreskúmať vyžaduje jeden druh látky, neodoberá vzorku a opakovanie nepridá objav.\nKarty zostávajú v kolekcii; dva rôzne objavy otvoria nový prvok.\n\nTEPELNÝ POKUS\nHorák a chladenie fungujú iba pre čistú vodu pri 1 atm; var je v modeli pri 100 °C.\nPrístroje sa navzájom vypínajú. Bez horáka voda pomaly chladne k 20 °C.\nÚplné odparenie, zamŕzanie ani kondenzáciu nemodelujeme.\n\nREAKCIA\nZapáliť zmes spracuje jednu dávku CH₄ + 2 O₂ → CO₂ + 2 H₂O, bez ďalších látok.\nPorcie znamenajú rovnaké relatívne počty častíc, nie rovnakú hmotnosť.\nProdukty sa zobrazia po návrate na 20 °C; uvoľnené teplo nesimulujeme.\n\nVRÁTENIE A ULOŽENIE\nVrátiť obsah aj nový zber vrátia aktuálne porcie. Reakcia neobnoví spotrebované reagenty.\nZmena vzorky resetuje tepelný pokus na 20 °C. Je to reset modelu, nie návrat uniknutej pary.\nPlyny označuje text, nie farebná kvapalina. Zásoba a výskum platia do zatvorenia hry."
	add_child(dialog)
	help.pressed.connect(func(): dialog.popup_centered(Vector2i(760, 420)))
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
	var workspace := VBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 6)
	page.add_child(workspace)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(spacer)
	var experience_row := HBoxContainer.new()
	experience_row.add_theme_constant_override("separation", 24)
	experience_row.alignment = BoxContainer.ALIGNMENT_CENTER
	workspace.add_child(experience_row)
	var center := CenterContainer.new()
	experience_row.add_child(center)
	flask = FlaskTarget.new()
	flask.custom_minimum_size = Vector2(300, 170)
	flask.portion_dropped.connect(_add)
	flask.draw.connect(_draw_flask)
	center.add_child(flask)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size.x = 380
	tools.add_theme_constant_override("separation", 8)
	experience_row.add_child(tools)
	temperature_label = _label(tools, "", 20)
	var tool_buttons := HBoxContainer.new()
	tools.add_child(tool_buttons)
	heat_button = Button.new()
	heat_button.text = "Horák"
	heat_button.toggle_mode = true
	heat_button.pressed.connect(func(): _set_tool("heat" if heat_button.button_pressed else "off"))
	tool_buttons.add_child(heat_button)
	cool_button = Button.new()
	cool_button.text = "Chladenie"
	cool_button.toggle_mode = true
	cool_button.pressed.connect(func(): _set_tool("cool" if cool_button.button_pressed else "off"))
	tool_buttons.add_child(cool_button)
	reaction_button = Button.new()
	reaction_button.text = "Zapáliť zmes"
	reaction_button.pressed.connect(_react)
	tools.add_child(reaction_button)
	process_notice = _label(tools, "", 15)
	process_notice.custom_minimum_size = Vector2(380, 70)
	experiment.process_changed.connect(_process_notice)
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
	research_button.text = "Preskúmať"
	research_button.pressed.connect(_investigate)
	actions.add_child(research_button)
	research_hint = _label(workspace, "", 15)
	research_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	research_hint.modulate = Color("a5b4cb")
	spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(spacer)
	var stock_header := HBoxContainer.new()
	page.add_child(stock_header)
	var stock_title := _label(stock_header, "Zásoba", 21)
	stock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := _label(stock_header, "Potiahni do banky ↑", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.modulate = Color("a5b4cb")
	empty_label = _label(page, "Prázdna zásoba", 17)
	var card_scroll := ScrollContainer.new()
	cards_area = card_scroll
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.custom_minimum_size.y = 142
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
		button.tooltip_text = "Potiahni do banky · kliknutie pridá 1 porciu"
		button.custom_minimum_size = Vector2(180, 128)
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
		content.offset_top = 10
		content.offset_bottom = -10
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
	next.text = "← Nový zber"
	next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next.pressed.connect(func(): new_collection_requested.emit())
	next.pressed.connect(_reset_experiment)
	page.add_child(next)

func setup(state: RefCounted, research_state: RefCounted) -> void:
	inventory = state
	research = research_state
	discovery.research = research
	flask.inventory = state
	for row in rows.values():
		row.button.inventory = state

func _add(id: String) -> void:
	if inventory.add_to_sample(id):
		_reset_experiment()
	refresh()

func _return_sample() -> void:
	inventory.return_sample()
	_reset_experiment()
	refresh()

func _reset_experiment() -> void:
	experiment.reset()
	process_notice.text = ""

func _set_tool(value: String) -> void:
	experiment.set_mode(value, inventory.sample)
	_update_experiment()

func _react() -> void:
	if not experiment.react(inventory.sample):
		return
	refresh()

func _process_notice(id: String) -> void:
	match id:
		"boiling":
			process_notice.text = "Var · pri 1 atm približne 100 °C. Bubliny obsahujú vodnú paru. Biely oblak tvoria kvapôčky; samotná para je neviditeľná. Voda zostáva H₂O."
		"cooled":
			process_notice.text = "Ochladenie pod 100 °C zastavilo var. Nevznikla nová látka. Úplné odparenie ani kondenzáciu tu nemodelujeme."
		"combustion":
			process_notice.text = "CH₄ + 2 O₂ → CO₂ + 2 H₂O\nVznikli nové látky. Produkty počítame po návrate na 20 °C; horúcu paru ani uvoľnené teplo tu nesimulujeme."

func _process(delta: float) -> void:
	if inventory == null or not is_visible_in_tree():
		return
	animation_time += delta
	experiment.step(delta, inventory.sample)
	_update_experiment()

func _update_experiment() -> void:
	var water: bool = experiment.is_water(inventory.sample)
	heat_button.disabled = not water
	cool_button.disabled = not water
	heat_button.set_pressed_no_signal(experiment.mode == "heat")
	cool_button.set_pressed_no_signal(experiment.mode == "cool")
	temperature_label.text = "%.0f °C · 1 atm" % experiment.temperature if water else "Teplota · —"
	reaction_button.visible = inventory.stock.get("methane", 0) > 0 or inventory.sample.get("methane", 0) > 0 or research.researched.has("methane")
	reaction_button.disabled = not experiment.can_react(inventory.sample)
	if process_notice.text.is_empty():
		if water:
			process_notice.text = "Čistá voda · zapni horák alebo chladenie."
		elif inventory.sample.is_empty():
			process_notice.text = "Vlož vzorku do banky."
		elif inventory.sample.has("methane"):
			process_notice.text = "Na tento model horenia treba 1 CH₄ a 2 O₂, bez ďalších látok. Jeden klik = jedna reakčná dávka."
		else:
			process_notice.text = "Tento tepelný pokus zatiaľ nie je podporovaný. Neznamená to, že látky v skutočnosti nereagujú."
	flask.queue_redraw()

func _investigate() -> void:
	var id: String = research.sample_id(inventory.sample)
	if id.is_empty():
		return
	var had_carbon: bool = "C" in research.available_elements
	var first: bool = research.investigate(inventory.sample)
	refresh()
	discovery.show_research(id, first, not had_carbon and "C" in research.available_elements)

func refresh() -> void:
	var total := 0
	var contents: Array[String] = []
	var has_stock := false
	for id in rows:
		var row: Dictionary = rows[id]
		row.row.visible = inventory.stock[id] > 0
		has_stock = has_stock or row.row.visible
		row.label.text = _portions(inventory.stock[id])
		row.status.text = "Preskúmané" if research.researched.has(id) else "Nepreskúmané"
		row.button.text = ""
		row.button.disabled = inventory.stock[id] == 0
		var count: int = inventory.sample.get(id, 0)
		total += inventory.stock[id] + count
		if count > 0:
			contents.append("%s × %d%s" % [row.data.display_formula, count, " (plyn)" if row.data.state_at_room_conditions == "gas" else ""])
	empty_label.visible = not has_stock
	cards_area.visible = has_stock
	summary.text = "Spolu: " + _portions(total)
	sample_label.text = "Banka: " + (", ".join(contents) if not contents.is_empty() else "prázdna")
	return_button.disabled = contents.is_empty()
	var sample_id: String = research.sample_id(inventory.sample)
	research_button.disabled = sample_id.is_empty()
	research_button.text = "Zobraziť kartu" if research.researched.has(sample_id) else "Preskúmať"
	research_hint.text = "Vlož látku do banky." if contents.is_empty() else ("Na výskum nechaj iba jeden druh látky." if sample_id.is_empty() else "")
	collection_button.text = "Kolekcia · %d" % research.researched.size()
	progress_bar.max_value = research.threshold()
	progress_bar.value = mini(research.researched.size(), research.threshold())
	progress_label.text = "Všetky prvky alpha sú otvorené" if "C" in research.available_elements else "K novému prvku · %d/%d" % [research.researched.size(), research.threshold()]
	progress_bar.visible = "C" not in research.available_elements
	_update_experiment()
	flask.queue_redraw()

func _portions(count: int) -> String:
	return "%d %s" % [count, "porcia" if count == 1 else ("porcie" if count >= 2 and count <= 4 else "porcií")]

func _draw_flask() -> void:
	var center := flask.size.x / 2
	var tint := Color("8fe4d3") if flask.highlighted else Color("a5cddc")
	flask.draw_style_box(_drop_style(flask.highlighted), Rect2(Vector2.ZERO, flask.size))
	var points := PackedVector2Array([Vector2(center - 20, 8), Vector2(center - 20, 45), Vector2(center - 68, 128), Vector2(center + 68, 128), Vector2(center + 20, 45), Vector2(center + 20, 8)])
	flask.draw_polyline(points, tint, 4, true)
	flask.draw_line(Vector2(center - 28, 8), Vector2(center + 28, 8), tint, 4)
	flask.draw_string(get_theme_default_font(), Vector2(center - 34, 155), "Pusti kartu", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
	if inventory != null and inventory.sample.get("water", 0) > 0:
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






