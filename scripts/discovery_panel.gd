extends AcceptDialog
const Catalog = preload("res://scripts/catalog.gd")
var research: RefCounted
var body: VBoxContainer
var current_id := ""
var pending: Array[String] = []

func _ready() -> void:
	exclusive = true
	ok_button_text = "Zavrieť"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(570, 330)
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)

func _clear() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func show_collection() -> void:
	_clear()
	current_id = ""
	title = "Kolekcia"
	_label("Objavené látky · %d" % research.researched.size(), 24)
	if research.researched.is_empty():
		_label("Zatiaľ žiadne. Zostav správny model alebo vytvor látku reakciou.", 18)
	for substance in Catalog.load_data().substances:
		if research.researched.has(substance.id):
			var button := Button.new()
			button.text = "%s · %s" % [substance.display_formula, substance.name]
			button.pressed.connect(show_substance.bind(substance.id, false))
			body.add_child(button)
	_label("Dostupné prvky", 23)
	for element in Catalog.load_data().elements:
		if element.id in research.available_elements:
			var button := Button.new()
			button.text = "%s · %s" % [element.symbol, element.name]
			button.pressed.connect(show_element.bind(element.id))
			body.add_child(button)
	popup_centered()

func show_substance(id: String, first := false) -> void:
	if not research.researched.has(id):
		return
	for substance in Catalog.load_data().substances:
		if substance.id != id:
			continue
		_clear()
		current_id = id
		title = "Nový objav" if first else "Objavená látka"
		_label("%s · %s" % [substance.display_formula, substance.name], 30)
		_label(substance.fact, 20)
		_label("Model väzieb: " + substance.model, 23)
		_label("Pridané do kolekcie" if first else "Objavené", 17)
		_collection_back()
		popup_centered()
		return

func show_element(id: String) -> void:
	if id not in research.available_elements:
		return
	for element in Catalog.load_data().elements:
		if element.id != id:
			continue
		_clear()
		current_id = id
		title = "Prvok"
		_label("%s · %s" % [element.symbol, element.name], 30)
		_label("Atómové číslo: %d\nRelatívna atómová hmotnosť: približne %s\nSkupina: %d · Perióda: %d" % [element.atomic_number, str(element.relative_atomic_mass), element.group, element.period], 20)
		if element.discoveries_required > 0:
			_label("Zberač teraz rozpoznáva prvok %s. Nájdeš ho pri ďalšom zbere." % element.symbol, 18)
		_collection_back()
		popup_centered()
		return

func _collection_back() -> void:
	if not pending.is_empty():
		return
	var back := Button.new()
	back.text = "Kolekcia"
	back.pressed.connect(show_collection)
	body.add_child(back)

func _label(text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	body.add_child(label)
