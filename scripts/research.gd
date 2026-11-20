extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
signal discovered(id: String)
signal element_unlocked(id: String)
var researched: Dictionary = {}
var available_elements: Array[String] = ["H", "O"]

func is_available(substance: Dictionary) -> bool:
	for symbol in substance.atoms:
		if symbol not in available_elements:
			return false
	return true

func threshold() -> int:
	return int(Catalog.load_data().progression.unique_research_to_unlock_carbon)

func sample_id(sample: Dictionary) -> String:
	var id := ""
	for key in sample:
		if not sample[key] is int or sample[key] <= 0:
			continue
		if not id.is_empty():
			return ""
		id = key
	for substance in Catalog.load_data().substances:
		if substance.id == id and is_available(substance):
			return id
	return ""

func investigate(sample: Dictionary) -> bool:
	var id := sample_id(sample)
	if id.is_empty() or researched.has(id):
		return false
	researched[id] = true
	discovered.emit(id)
	if researched.size() >= threshold() and "C" not in available_elements:
		available_elements.append("C")
		element_unlocked.emit("C")
	return true
