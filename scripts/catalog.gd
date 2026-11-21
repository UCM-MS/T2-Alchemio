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

static func unlocked_elements(elements: Array, discovery_count: int) -> Array[String]:
	var result: Array[String] = []
	for element in elements:
		if discovery_count >= int(element.discoveries_required):
			result.append(element.id)
	return result
