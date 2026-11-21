extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
signal discovered(id: String)
signal element_unlocked(id: String)
var researched: Dictionary = {}
var catalog := Catalog.load_data()
var available_elements := Catalog.unlocked_elements(catalog.elements, 0)

func is_available(substance: Dictionary) -> bool:
	for symbol in substance.atoms:
		if symbol not in available_elements:
			return false
	return true

func progress_to_next_element() -> Vector2i:
	var previous := 0
	for element in catalog.elements:
		var required := int(element.discoveries_required)
		if required > researched.size():
			return Vector2i(researched.size() - previous, required - previous)
		previous = required
	return Vector2i.ZERO

func sample_id(sample: Dictionary) -> String:
	var id := ""
	for key in sample:
		if not sample[key] is int or sample[key] <= 0:
			continue
		if not id.is_empty():
			return ""
		id = key
	for substance in catalog.substances:
		if substance.id == id and is_available(substance):
			return id
	return ""

func investigate(sample: Dictionary) -> bool:
	var id := sample_id(sample)
	return discover(id)

func discover(id: String) -> bool:
	var available := false
	for substance in catalog.substances:
		if substance.id == id and is_available(substance):
			available = true
	if not available:
		return false
	if id.is_empty() or researched.has(id):
		return false
	researched[id] = true
	discovered.emit(id)
	for symbol in Catalog.unlocked_elements(catalog.elements, researched.size()):
		if symbol not in available_elements:
			available_elements.append(symbol)
			element_unlocked.emit(symbol)
	return true
