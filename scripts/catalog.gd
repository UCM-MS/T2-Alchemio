class_name AlphaCatalog
extends RefCounted
## Static alpha content. Does not hold inventory or research progress.

const PATH := "res://data/catalog.json"

static func load_data() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open alpha catalog: %s" % FileAccess.get_open_error())
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("Catalog JSON error: %s" % parser.get_error_message())
		return {}
	if not parser.data is Dictionary:
		push_error("Catalog root must be a dictionary")
		return {}
	return parser.data

# Single atoms with no substance model have their own stock ID (H versus H₂).
static func stock_items(catalog: Dictionary) -> Array:
	var items: Array = catalog.substances.duplicate()
	var modeled := {}
	for substance in catalog.substances:
		if substance.atoms.size() == 1 and substance.get("assembly", true):
			modeled[substance.atoms[0]] = true
	for element in catalog.elements:
		if element.symbol not in modeled:
			items.append({"id": element.symbol, "name": element.name, "display_formula": element.symbol, "atoms": [element.symbol], "is_atom": true})
	return items

static func unlocked_elements(progression: Dictionary, completed: Dictionary, legacy_carbon := false) -> Array[String]:
	var result: Array[String] = []
	result.assign(progression.water.elements)
	var can_unlock_carbon := true
	for id in progression.water.required:
		if not completed.has(id):
			can_unlock_carbon = false
	if legacy_carbon or can_unlock_carbon:
		result.append_array(progression.carbon.elements)
	return result
