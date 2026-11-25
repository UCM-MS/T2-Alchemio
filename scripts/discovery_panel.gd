extends AcceptDialog

const UI = preload("res://scripts/workspace_ui.gd")
const Catalog = preload("res://scripts/catalog.gd")

var research: RefCounted
var current_id := ""
var pending: Array[String] = []
var origin_tab := "Laboratórium"
var catalog := Catalog.load_data()
var tabs: Dictionary
var detail: VBoxContainer
var entries: VBoxContainer
var counter: Label
var search: LineEdit
var sections := {"Prvky": true, "Látky": true}
var selected := ""
var selected_buttons := {}

func _ready() -> void:
	theme = UI.theme()
	exclusive = true
	borderless = true
	title = "Kolekcia"
	ok_button_text = "Späť do hry"
	add_theme_stylebox_override("panel", UI.box(UI.BG, UI.BG, 0, 0, 0))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	tabs = UI.nav(layout, "Kolekcia")
	for key in ["Hracia plocha", "Skladanie", "Laboratórium"]:
		tabs[key].pressed.connect(hide)
	var page := UI.page(layout)
	var columns := UI.row(page, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UI.column(columns, 38)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.85
	UI.heading(left, "ZÁPISNÍK OBJAVOV", "Objavené látky")
	var card := UI.panel(left, UI.CANVAS, 18)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := UI.panel(card, UI.CANVAS, 20, 16)
	detail = UI.column(inner, 12)
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	var right := UI.panel(columns)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var library := UI.column(right, 12)
	var bar := UI.row(library, 6)
	UI.label(bar, "KOLEKCIA", 13, UI.MUTED, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter = UI.label(bar, "", 13, UI.MUTED)
	search = LineEdit.new()
	search.placeholder_text = "Hľadať v kolekcii"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_value: String): _refresh_list())
	library.add_child(search)
	entries = UI.scroll_column(library)
	get_parent().get_viewport().size_changed.connect(_fit_window)

func _fit_window() -> void:
	if visible:
		position = Vector2i.ZERO
		size = Vector2i(get_parent().get_viewport().get_visible_rect().size)

func _open() -> void:
	for key in ["Hracia plocha", "Skladanie", "Laboratórium"]:
		tabs[key].disabled = key != origin_tab
	if not visible:
		popup(Rect2i(Vector2i.ZERO, Vector2i(get_parent().get_viewport().get_visible_rect().size)))
	_fit_window()

func _clear(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _refresh_list() -> void:
	_clear(entries)
	selected_buttons.clear()
	counter.text = "%d / %d objavené" % [research.researched.size() + research.available_elements.size(), catalog.substances.size() + catalog.elements.size()]
	var matches := 0
	var query := search.text.strip_edges()
	for group in sections:
		var is_element: bool = group == "Prvky"
		var items: Array = []
		for record in (catalog.elements if is_element else catalog.substances):
			if record.id not in (research.available_elements if is_element else research.researched):
				continue
			var formula: String = record.get("symbol", record.get("display_formula", ""))
			var terms := "%s %s %s" % [record.name, formula, record.get("formula", "")]
			if query.is_empty() or terms.containsn(query):
				items.append(record)
		matches += items.size()
		var expanded: bool = sections[group] or not query.is_empty()
		if items.is_empty() and not query.is_empty():
			continue
		var section := UI.button(entries, "%s   %s   ·   %d" % ["⌄" if expanded else "›", group.to_upper(), items.size()])
		section.alignment = HORIZONTAL_ALIGNMENT_LEFT
		section.disabled = items.is_empty() or not query.is_empty()
		section.pressed.connect(_toggle_group.bind(group))
		if expanded:
			for item in items:
				_entry(item, is_element)
	if matches == 0:
		UI.label(entries, "Žiadne výsledky", 15, UI.MUTED)

func _toggle_group(group: String) -> void:
	sections[group] = not sections[group]
	_refresh_list()

func _entry(item: Dictionary, is_element: bool) -> void:
	var symbol: String = item.symbol if is_element else item.display_formula
	var button := UI.button(entries, "")
	button.custom_minimum_size.y = 51
	button.tooltip_text = item.name
	button.toggle_mode = true
	button.set_pressed_no_signal(item.id == selected)
	selected_buttons[item.id] = button
	var line := UI.row(button, 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 10
	line.offset_right = -10
	UI.badge(line, symbol, 34)
	var text := UI.column(line, 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.label(text, item.name, 15, UI.TEXT, true)
	UI.label(text, "%s · prvok %03d" % [symbol, item.atomic_number] if is_element else symbol, 12, UI.MUTED)
	button.pressed.connect(_select_entry.bind(item, is_element))

func _select_entry(item: Dictionary, is_element: bool) -> void:
	current_id = item.id
	_display(item, is_element)

func _display(item: Dictionary, is_element: bool, first := false) -> void:
	selected = item.id
	for id in selected_buttons:
		selected_buttons[id].set_pressed_no_signal(id == selected)
	_clear(detail)
	var line := UI.row(detail, 16)
	var symbol: String = item.symbol if is_element else item.display_formula
	var image := CenterContainer.new()
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(image)
	UI.badge(image, symbol, 172)
	var divider := VSeparator.new()
	divider.custom_minimum_size.y = 230
	divider.add_theme_stylebox_override("separator", UI.box(UI.EDGE, UI.EDGE, 1, 1))
	line.add_child(divider)
	var info := UI.column(line, 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.label(info, "NOVÝ OBJAV" if first else "ZÁZNAM V KOLEKCII", 13, UI.ACCENT, true)
	var name_label := UI.label(info, item.name, 28, UI.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var metadata: String
	var description: String
	if is_element:
		metadata = "Prvok · Atómové číslo %d" % item.atomic_number
		description = "Relatívna atómová hmotnosť: približne %s\nSkupina: %d · Perióda: %d" % [item.relative_atomic_mass, item.group, item.period]
		if item.id == "C":
			description += "\nZberač teraz rozpoznáva prvok C. Nájdeš ho pri ďalšom zbere."
	else:
		metadata = "Model väzieb: " + item.model
		description = item.fact
	for value in [metadata, description]:
		var label := UI.label(info, value, 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func show_collection() -> void:
	current_id = ""
	search.clear()
	_refresh_list()
	for item in catalog.elements:
		if item.id in research.available_elements:
			_display(item, true)
			break
	_open()

func show_substance(id: String, first := false) -> void:
	if id not in research.researched:
		return
	for item in catalog.substances:
		if item.id == id:
			current_id = id
			search.clear()
			sections["Látky"] = true
			_refresh_list()
			_display(item, false, first)
			_open()
			return

func show_element(id: String) -> void:
	if id not in research.available_elements:
		return
	for item in catalog.elements:
		if item.id == id:
			current_id = id
			search.clear()
			sections["Prvky"] = true
			_refresh_list()
			_display(item, true)
			_open()
			return
