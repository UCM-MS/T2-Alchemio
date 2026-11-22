extends SceneTree
const Experiment = preload("res://scripts/lab_experiment.gd")
var failures: Array[String] = []
var events: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var lab = Experiment.new()
	lab.process_changed.connect(func(id: String): events.append(id))
	lab.instrument_id = "beaker"
	var water := {"water": 2}
	lab.set_mode("heat", water)
	lab.step(20, water)
	check(lab.boiling and lab.temperature == 100, "Water reaches boiling temperature")
	lab.step(1000, water)
	check(lab.temperature == 100 and events == ["boiling"] and water == {"water": 2}, "Boiling preserves all water")
	lab.set_mode("cool", water)
	lab.step(0.1, water)
	check(not lab.boiling and events == ["boiling", "cooled"], "Cooling stops boiling")
	lab.step(100, water)
	check(lab.temperature == 20 and lab.mode == "off", "Cooling stops at reference temperature")
	check(not lab.start("catalyst", water, {}), "Pure water does not react with the catalytic option")
	lab.set_mode("heat", {"water": 1, "oxygen": 1})
	check(lab.mode == "off", "Boiling rejects a mixed sample")

	lab.available_elements.append("C")
	for id in lab.catalog.experiments:
		if id == "boiling":
			continue
		lab.reset()
		var recipe: Dictionary = lab.catalog.experiments[id]
		lab.instrument_id = recipe.apparatus
		var action: String = recipe.action
		var sample := {}
		var expected := {}
		for reagent in recipe.reactants:
			sample[reagent] = int(recipe.reactants[reagent])
		for product in recipe.products:
			expected[product] = int(recipe.products[product])
		check(atoms_in(lab.catalog, sample) == atoms_in(lab.catalog, expected), "Atom balance: " + id)
		var input: Dictionary = sample.duplicate()
		var outlet := {}
		check(not lab.start(action, {}, outlet), "Reject empty sample: " + id)
		check(not lab.start(action, sample, {"water": 1}), "Reject full output: " + id)
		check(lab.start(action, sample, outlet) and not lab.start(action, sample, outlet), "One start per pending reaction: " + id)
		lab.step(0.5, sample, outlet)
		check(sample == input and outlet.is_empty(), "Wait for animation before consuming: " + id)
		lab.step(2, sample, outlet)
		check(sample.is_empty() and outlet == expected and lab.result.id == id, "Select the right reaction and commit: " + id)
		lab.step(2, sample, outlet)
		check(outlet == expected, "Idle step does not duplicate products: " + id)

	lab.instrument_id = "burner"
	var excess := {"hydrogen": 3, "oxygen": 1}
	var product := {}
	check(lab.start("ignite", excess, product), "Excess fuel supported")
	lab.step(2, excess, product)
	check(excess == {"hydrogen": 1} and product == {"water": 2}, "Spare hydrogen is returned as a reactant")
	check(not lab.start("ignite", {"hydrogen": 2, "methane": 1, "oxygen": 3}, {}), "Mixed fuels require separating the sample")
	lab.instrument_id = "tube"
	var carbon := {"solid_carbon": 2, "oxygen": 2}
	var carbon_out := {}
	check(lab.start("furnace", carbon, carbon_out), "Complete carbon accepts both portions")
	lab.step(2, carbon, carbon_out)
	check(carbon.is_empty() and carbon_out == {"carbon_dioxide": 2}, "Complete carbon consumes both portions")
	var mixed := {"solid_carbon": 3, "oxygen": 2}
	var mixture_out := {}
	check(lab.start("furnace", mixed, mixture_out), "Intermediate oxygen quantity is supported")
	lab.step(2, mixed, mixture_out)
	check(mixed.is_empty() and mixture_out == {"carbon_dioxide": 1, "carbon_monoxide": 2}, "Intermediate oxygen gives balanced mixed products")
	check(lab.result.id == "carbon_incomplete" and lab.result_equation() == "3 C + 2 O₂ → 2 CO + CO₂", "Record incomplete combustion and show the actual formula")
	var limited := {"solid_carbon": 3, "oxygen": 1}
	var limited_out := {}
	check(lab.start("furnace", limited, limited_out), "Low oxygen starts on the same apparatus")
	lab.step(2, limited, limited_out)
	check(limited == {"solid_carbon": 1} and limited_out == {"carbon_monoxide": 2}, "Oxygen shortage leaves solid carbon")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("EXPERIMENTS PASS: seven balanced reactions, boiling, validation, timed commit and carbon comparison")
	quit(0 if failures.is_empty() else 1)

func atoms_in(catalog: Dictionary, portions: Dictionary) -> Dictionary:
	var atoms := {}
	for substance in catalog.substances:
		for symbol in substance.atoms:
			var count: int = portions.get(substance.id, 0)
			if count > 0:
				atoms[symbol] = atoms.get(symbol, 0) + count
	return atoms

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
