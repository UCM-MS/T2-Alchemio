extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
const VERSION := 4
const REMOVED_SUBSTANCES := ["nitrogen", "ammonia"]
const MAX_PORTIONS := 1000000000
var path := "user://progress.json"
var write_blocked := false

func snapshot(inventory: RefCounted, research: RefCounted) -> Dictionary:
	var totals: Dictionary = inventory.stock.duplicate(true)
	for container in [inventory.sample, inventory.outlets]:
		for id in container:
			totals[id] += container[id]
	return {
		"version": VERSION,
		"inventory": totals,
		"researched": research.researched.keys(),
		"completed_experiments": research.completed_experiments.keys(),
		"legacy_carbon_unlocked": research.legacy_carbon_unlocked,
	}

func validate(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var version: Variant = value.get("version")
	if not (version is int or version is float) or (version != 1 and version != 2 and version != 3 and version != VERSION):
		return {}
	if not value.get("inventory") is Dictionary or not value.get("researched") is Array:
		return {}
	var legacy: bool = version < 3
	var known: Dictionary = {}
	var catalog := Catalog.load_data()
	for substance in Catalog.stock_items(catalog):
		known[substance.id] = substance
	var totals: Dictionary = {}
	for id in known:
		totals[id] = 0
	for id in value.inventory:
		var count: Variant = value.inventory[id]
		if not (count is int or count is float):
			return {}
		if not is_finite(float(count)) or count < 0 or count > MAX_PORTIONS or float(count) != floorf(float(count)):
			return {}
		if legacy and id in REMOVED_SUBSTANCES:
			continue
		if not known.has(id):
			return {}
		totals[id] = int(count)
	var researched: Dictionary = {}
	var old_discoveries := {}
	for id in value.researched:
		if legacy and id in REMOVED_SUBSTANCES:
			old_discoveries[id] = true
			continue
		if not id is String or not known.has(id) or known[id].get("is_atom", false):
			return {}
		researched[id] = true
		old_discoveries[id] = true
	var completed := {}
	var legacy_carbon: bool = old_discoveries.size() >= 2 if legacy else value.get("legacy_carbon_unlocked", false) == true
	if not legacy:
		if not value.get("completed_experiments") is Array or not value.get("legacy_carbon_unlocked", false) is bool:
			return {}
		for id in value.completed_experiments:
			if not id is String or not catalog.experiments.has(id) or catalog.experiments[id].products.is_empty():
				return {}
			completed[id] = true
	var available := Catalog.unlocked_elements(catalog.progression, completed, legacy_carbon)
	for id in completed:
		var required: String = catalog.experiments[id].get("requires_element", "")
		if not required.is_empty() and required not in available:
			return {}
	for id in known:
		if totals[id] > 0 or researched.has(id):
			for symbol in known[id].atoms:
				if symbol not in available:
					return {}
	return {
		"inventory": totals,
		"researched": researched,
		"available_elements": available,
		"completed_experiments": completed,
		"legacy_carbon_unlocked": legacy_carbon,
	}

func _read(file_path: String) -> Variant:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func load_progress() -> Dictionary:
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(path + ".bak"):
			return {"status": "missing"}
	else:
		var raw: Variant = _read(path)
		var data := validate(raw)
		if not data.is_empty():
			return {"status": "loaded", "data": data}
		# Never downgrade or overwrite a save created by a future game version.
		if raw is Dictionary and (raw.get("version") is int or raw.get("version") is float) and raw.version > VERSION:
			write_blocked = true
			return {"status": "invalid"}
	var backup := validate(_read(path + ".bak"))
	if not backup.is_empty():
		# Preserve the valid backup while replacing a damaged primary on next write.
		return {"status": "recovered", "data": backup}
	write_blocked = true
	return {"status": "invalid"}

func save_progress(inventory: RefCounted, research: RefCounted, rotate_backup := true) -> bool:
	if write_blocked:
		return false
	var data := snapshot(inventory, research)
	if validate(data).is_empty():
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	if rotate_backup and FileAccess.file_exists(path) and not validate(_read(path)).is_empty():
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(temporary, path) == OK

func reset_progress(inventory: RefCounted, research: RefCounted) -> bool:
	# Save a valid empty checkpoint before changing the live game.
	var old_blocked := write_blocked
	write_blocked = false
	var backup := FileAccess.open(path + ".bak", FileAccess.WRITE)
	if backup == null:
		write_blocked = old_blocked
		return false
	backup.store_string(JSON.stringify(snapshot(inventory, research)))
	backup.flush()
	var error := backup.get_error()
	backup.close()
	if error != OK or not save_progress(inventory, research, false):
		write_blocked = old_blocked
		return false
	return true
