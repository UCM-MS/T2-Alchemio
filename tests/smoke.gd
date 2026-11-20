extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var data := Catalog.load_data()
	check(data.get("schema_version") == 1, "Catalog schema")
	check(data.get("elements", []).size() == 3, "Three elements")
	check(data.get("substances", []).size() == 10, "Ten substances")
	var valences := {"H": 1, "O": 2, "C": 4}
	var ids: Array[String] = []
	for substance in data.get("substances", []):
		check(not ids.has(substance["id"]), "Unique substance ID")
		ids.append(substance["id"])
		var atoms: Array = substance["atoms"]
		if substance.id == "carbon_monoxide":
			check(substance.formal_charges.size() == 2 and int(substance.formal_charges[0]) == -1 and int(substance.formal_charges[1]) == 1, "CO formal charges belong to C and O")
		var sums: Array[int] = []
		sums.resize(atoms.size())
		sums.fill(0)
		for bond in substance["bonds"]:
			var a := int(bond[0])
			var b := int(bond[1])
			var order := int(bond[2])
			check(a >= 0 and b >= 0 and a < atoms.size() and b < atoms.size() and a != b, "Bond endpoints")
			if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size() or a == b:
				continue
			check(order in [1, 2, 3], "Alpha bond order")
			sums[a] += order
			sums[b] += order
		for i in atoms.size():
			check(sums[i] == (3 if substance.id == "carbon_monoxide" else valences.get(atoms[i], -1)), "Alpha model valence: " + substance["id"])
	for action in ["move_left", "move_right", "move_up", "move_down", "delete_bond"]:
		check(InputMap.has_action(action), "Input action: " + action)
	var expected_keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "delete_bond": [KEY_DELETE]}
	for action in expected_keys:
		var actual: Array[int] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				actual.append(event.physical_keycode)
		check(actual == expected_keys[action], "Physical keys: %s expected %s actual %s" % [action, expected_keys[action], actual])
	check(ResourceLoader.exists("res://scenes/main.tscn"), "Main scene")
	var font := load("res://assets/fonts/NotoSans.ttf") as Font
	check(font != null and font.has_char(0x2082), "Bundled font supports subscript two")
	if failures.is_empty():
		print("A0 smoke PASS: catalog, model valences, input actions, main scene, formula font")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

