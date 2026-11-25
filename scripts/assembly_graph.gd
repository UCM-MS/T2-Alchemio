extends RefCounted
## Chemical graph only; collection attachments and screen positions never enter it.
const Catalog = preload("res://scripts/catalog.gd")
const VALENCE_LIMITS := {"H": 1, "O": 2, "N": 3, "C": 4}
var atoms: Dictionary = {}
var bonds: Dictionary = {}
var finalized := false
var templates: Array = []

func _init() -> void:
	configure_elements(["H", "O"])

func configure_elements(elements: Array) -> void:
	templates.clear()
	for substance in Catalog.load_data()["substances"]:
		var available: bool = substance.get("assembly", true)
		for symbol in substance.atoms:
			if symbol not in elements:
				available = false
		if available:
			templates.append(substance)

func add_atoms(records: Array[Dictionary]) -> void:
	if finalized:
		return
	for record in records:
		var id := int(record["id"])
		if not atoms.has(id):
			atoms[id] = record.duplicate(true)

func edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

func set_bond(a: int, b: int, order: int) -> bool:
	if finalized or a == b or not atoms.has(a) or not atoms.has(b) or order not in [1, 2, 3]:
		return false
	var key := edge_key(a, b)
	bonds[key] = {"a": mini(a, b), "b": maxi(a, b), "order": order}
	return true

func invalid_bonds() -> Dictionary:
	var totals: Dictionary = {}
	for bond in bonds.values():
		for id in [bond.a, bond.b]:
			totals[id] = int(totals.get(id, 0)) + int(bond.order)
	var invalid: Dictionary = {}
	for key in bonds:
		var bond: Dictionary = bonds[key]
		if bond.order == 3 and _is_carbon_oxygen_pair(bond.a, bond.b):
			if totals[bond.a] == 3 and totals[bond.b] == 3:
				continue
			invalid[key] = true
		for id in [bond.a, bond.b]:
			if int(totals[id]) > int(VALENCE_LIMITS.get(atoms[id].element, 0)):
				invalid[key] = true
	return invalid

func _is_carbon_oxygen_pair(a: int, b: int) -> bool:
	var first: String = atoms[a].element
	var second: String = atoms[b].element
	return (first == "C" and second == "O") or (first == "O" and second == "C")

func remove_bond(key: String) -> bool:
	if finalized:
		return false
	return bonds.erase(key)

func order_between(a: int, b: int) -> int:
	return int(bonds.get(edge_key(a, b), {}).get("order", 0))

func components() -> Array:
	var groups: Array = []
	var visited: Dictionary = {}
	for id in atoms:
		if visited.has(id):
			continue
		var group: Array = []
		var pending: Array = [id]
		visited[id] = true
		while not pending.is_empty():
			var current: int = pending.pop_back()
			group.append(current)
			for bond in bonds.values():
				var neighbor := -1
				if bond.a == current:
					neighbor = bond.b
				elif bond.b == current:
					neighbor = bond.a
				if neighbor >= 0 and not visited.has(neighbor):
					visited[neighbor] = true
					pending.append(neighbor)
		groups.append(group)
	return groups

func recognize() -> Array:
	var result: Array = []
	for group in components():
		var match_data: Dictionary = {}
		for template in templates:
			if group.size() == template["atoms"].size() and _match(group, template, []):
				match_data = template
				break
		result.append({"atom_ids": group, "substance": match_data})
	return result

func _match(group: Array, template: Dictionary, mapping: Array) -> bool:
	# Compare every edge, including absent edges, to distinguish structural isomers.
	var index := mapping.size()
	if index == group.size():
		return true
	for id in group:
		if id in mapping or atoms[id]["element"] != template["atoms"][index]:
			continue
		var compatible := true
		for previous in index:
			var expected := 0
			for bond in template["bonds"]:
				if (bond[0] == previous and bond[1] == index) or (bond[1] == previous and bond[0] == index):
					expected = int(bond[2])
			if order_between(id, mapping[previous]) != expected:
				compatible = false
				break
		if compatible:
			var next := mapping.duplicate()
			next.append(id)
			if _match(group, template, next):
				return true
	return false

func preview() -> Dictionary:
	var products: Dictionary = {}
	var discarded: Array[Dictionary] = []
	var used: Array[int] = []
	for group in recognize():
		if group.substance.is_empty():
			for id in group.atom_ids:
				discarded.append(atoms[id].duplicate(true))
		else:
			var id: String = group.substance["id"]
			products[id] = int(products.get(id, 0)) + 1
			for atom_id in group.atom_ids:
				used.append(atom_id)
	return {"products": products, "discarded_atoms": discarded, "used_atom_ids": used}

func finalize() -> Dictionary:
	if finalized:
		return {}
	var result := preview()
	finalized = true
	# The result owns independent copies; no atoms remain spendable in this graph.
	atoms.clear()
	bonds.clear()
	return result
