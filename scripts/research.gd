extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
signal discovered(id: String)
signal element_unlocked(id: String)
var researched: Dictionary = {}
var completed_experiments: Dictionary = {}
var legacy_carbon_unlocked := false
var catalog := Catalog.load_data()
var available_elements := Catalog.unlocked_elements(catalog.progression, completed_experiments)

func is_available(substance: Dictionary) -> bool:
	for symbol in substance.atoms:
		if symbol not in available_elements:
			return false
	return true

func stage_id() -> String:
	return "carbon" if "C" in available_elements else "water"

func stage_progress() -> Vector2i:
	var required: Array = catalog.progression[stage_id()].required
	var count := 0
	for id in required:
		if completed_experiments.has(id):
			count += 1
	return Vector2i(count, required.size())

func assembly_goal() -> String:
	var targets: Array = catalog.progression[stage_id()].assembly_targets
	var names := PackedStringArray()
	for id in targets:
		for substance in catalog.substances:
			if substance.id == id:
				names.append(substance.display_formula)
				break
	return "Cieľ skladania: " + ", ".join(names)

func complete_experiment(id: String) -> bool:
	if completed_experiments.has(id) or not catalog.experiments.has(id):
		return false
	var recipe: Dictionary = catalog.experiments[id]
	var required: String = recipe.get("requires_element", "")
	if recipe.products.is_empty() or (not required.is_empty() and required not in available_elements):
		return false
	completed_experiments[id] = true
	for symbol in Catalog.unlocked_elements(catalog.progression, completed_experiments, legacy_carbon_unlocked):
		if symbol not in available_elements:
			available_elements.append(symbol)
			element_unlocked.emit(symbol)
	return true

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
	return discover(sample_id(sample))

func discover(id: String) -> bool:
	if id.is_empty() or researched.has(id):
		return false
	for substance in catalog.substances:
		if substance.id == id and is_available(substance):
			researched[id] = true
			discovered.emit(id)
			return true
	return false
