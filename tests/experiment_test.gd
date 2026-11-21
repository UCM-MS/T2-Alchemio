extends SceneTree
const Experiment = preload("res://scripts/lab_experiment.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures: Array[String] = []
var events: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	check_device_rules()
	var demo = Experiment.new()
	demo.process_changed.connect(func(id: String): events.append(id))
	var water := {"water": 2}
	demo.set_mode("heat", water)
	demo.step(20, water)
	check(demo.boiling and demo.temperature == 100, "Water reaches capped boiling temperature")
	demo.step(1000, water)
	check(demo.temperature == 100 and events == ["boiling"] and water == {"water":2}, "Boiling does not repeat notices or consume portions")
	demo.set_mode("cool", water)
	check(demo.mode == "cool", "Cooling replaces burner")
	demo.step(0.1, water)
	check(not demo.boiling and events == ["boiling","cooled"], "Cooling crosses boiling transition once")
	demo.step(100, water)
	check(demo.temperature == 20 and demo.mode == "off", "Cooling stops at reference temperature")
	demo.set_mode("heat", {"water":1,"oxygen":1})
	check(demo.mode == "heat", "Every nonempty sample can heat")
	for sample in [{}, {"methane":1}, {"methane":1,"oxygen":1}, {"methane":1,"oxygen":2,"water":1}]:
		var before: Dictionary = sample.duplicate(true)
		check(not demo.react(sample) and sample == before, "Invalid reaction leaves contents unchanged")
	var mixture := {"methane":3,"oxygen":7}
	var elements_before := atoms_in(mixture)
	demo.reset()
	demo.set_mode("heat",mixture)
	demo.step(13.9,mixture)
	check(mixture == {"methane":3,"oxygen":7}, "No reaction below model threshold")
	demo.step(0.1,mixture)
	check(mixture == {"methane":2,"oxygen":5,"carbon_dioxide":1,"water":2}, "One batch consumes only stoichiometric amounts and retains excess")
	check(atoms_in(mixture) == elements_before, "Reaction conserves H/O/C atoms")
	var once: Dictionary = mixture.duplicate(true)
	check(not demo.react(mixture) and mixture == once, "Product-containing mixture cannot rerun recipe")
	var unsupported := {"methane":1,"oxygen":1}
	var other = Experiment.new()
	other.set_mode("heat",unsupported)
	other.step(100,unsupported)
	check(other.temperature == 600 and unsupported == {"methane":1,"oxygen":1}, "Unsupported mixture heats to model cap without creating substances")
	var ready := {"methane":1,"oxygen":2}
	other.set_mode("cool",ready)
	other.step(1,ready)
	check(ready == {"methane":1,"oxygen":2}, "Cooling above threshold cannot trigger reaction")
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	await process_frame
	main.collection_map.set_physics_process(false)
	for id in 3:
		main.collection_map.collect_atom(id)
	main.finish_button.pressed.emit()
	main.preview_page.board.connect_atoms(0,1,1)
	main.preview_page.board.connect_atoms(2,1,1)
	main.preview_page.finalize_assembly()
	var lab = main.laboratory
	lab.set_process(false)
	await process_frame
	await process_frame
	var flask_rect: Rect2 = lab.flask.get_global_rect()
	lab.rows.water.button.pressed.emit()
	await process_frame
	await process_frame
	check(lab.flask.get_global_rect() == flask_rect, "Adding last stock portion does not move or resize flask")
	lab.heat_button.button_pressed = true
	lab.heat_button.pressed.emit()
	lab.experiment.step(15, main.inventory.sample)
	lab._update_experiment()
	check(lab.heat_button.button_pressed and not lab.cool_button.button_pressed, "Only burner is active")
	check(main.research.researched.size() == 1 and main.inventory.sample == {"water":1}, "Physical process creates no discoveries or products")
	await screenshot("a6-boiling")
	lab._set_tool("cool")
	lab.experiment.step(1, main.inventory.sample)
	lab._update_experiment()
	check(lab.cool_button.button_pressed and not lab.heat_button.button_pressed, "Only cooling is active")
	await screenshot("a6-cooling")
	lab.return_button.pressed.emit()
	await process_frame
	await process_frame
	check(lab.flask.get_global_rect() == flask_rect, "Returning sample does not move or resize flask")
	check(lab.experiment.mode == "off" and lab.experiment.temperature == 20, "Return resets experiment")
	main.research.investigate({"water":1})
	main.research.investigate({"oxygen":1})
	main.inventory.credit({"methane":1,"oxygen":2})
	lab.refresh()
	lab.rows.methane.button.pressed.emit()
	lab.rows.oxygen.button.pressed.emit()
	await process_frame
	await process_frame
	check(lab.flask.get_global_rect() == flask_rect, "Gas mixture and different hints keep flask bounds stable")
	lab._set_tool("heat")
	lab.experiment.step(20,main.inventory.sample)
	check(main.inventory.sample == {"methane":1,"oxygen":1}, "Heating without enough oxygen does not react")
	lab.rows.oxygen.button.pressed.emit()
	check(not lab.heat_button.disabled and not lab.cool_button.disabled, "Valid sample allows heating and cooling")
	await screenshot("a6-reaction-ready")
	lab._set_tool("heat")
	lab.experiment.step(14, main.inventory.sample)
	check(main.inventory.sample == {"carbon_dioxide":1,"water":2}, "UI reaction produces correct sample")
	check(lab.experiment.temperature == 300 and lab.experiment.mode == "off", "Automatic reaction retains temperature and switches off heating")
	lab._update_experiment()
	await screenshot("temperature-reaction-result")
	await process_frame
	check(lab.flask.get_global_rect() == flask_rect, "Reaction result and longer explanation preserve flask bounds")
	var products: Dictionary = main.inventory.sample.duplicate(true)
	lab._set_tool("cool")
	lab.experiment.step(2,main.inventory.sample)
	check(lab.experiment.temperature < 300 and main.inventory.sample == products, "Cooling products does not reverse chemistry")
	check(main.research.researched.size() == 3 and main.research.researched.has("carbon_dioxide"), "Reaction discovers a new product automatically")
	lab._set_tool("heat")
	lab.experiment.step(14, main.inventory.sample)
	check(main.inventory.sample == {"carbon_dioxide":1,"water":2}, "Repeated ignition does not duplicate products")
	await screenshot("a6-reaction-result")
	lab.new_collection_requested.emit()
	await process_frame
	check(main.inventory.stock.water == 3 and main.inventory.stock.carbon_dioxide == 1 and main.inventory.sample.is_empty(), "Leaving returns reaction products without recreating reactants")
	check(lab.experiment.mode == "off", "Exit turns tools off")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("A6 PASS: heating, capped boiling, cooling, transition notices, supported recipe, atom conservation, excess, invalid recipes, UI transfer and exit")
	quit(0 if failures.is_empty() else 1)

func check_device_rules() -> void:
	for id in ["electrolyzer", "reactor"]:
		var demo = Experiment.new()
		demo.instrument = id
		var inputs: Dictionary = {"water": 2} if id == "electrolyzer" else {"nitrogen": 1, "hydrogen": 3}
		var products: Dictionary = {"hydrogen": 2, "oxygen": 1} if id == "electrolyzer" else {"ammonia": 2}
		var trigger := "current" if id == "electrolyzer" else "synthesis"
		var wrong := "synthesis" if id == "electrolyzer" else "current"
		var outlets := {}
		var sample := inputs.duplicate()
		demo.set_mode("heat", sample)
		demo.step(60, sample)
		check(sample == inputs and not demo.react(sample, wrong, outlets), "Wrong action leaves inputs intact: " + id)
		for key in inputs:
			var short_sample := inputs.duplicate()
			short_sample[key] -= 1
			var before := short_sample.duplicate()
			check(not demo.react(short_sample, trigger, outlets) and short_sample == before and outlets.is_empty(), "Shortage rejected: " + key)
		var impure := inputs.duplicate()
		impure.methane = 1
		var before_impure := impure.duplicate()
		check(not demo.react(impure, trigger, outlets) and impure == before_impure and outlets.is_empty(), "Impurity rejected: " + id)
		var extra: String = inputs.keys()[0]
		sample[extra] += 1
		var atoms_before := atoms_in(sample)
		check(demo.react(sample, trigger, outlets), "Run one batch: " + id)
		var total := sample.duplicate()
		total.merge(outlets)
		check(atoms_in(total) == atoms_before and sample[extra] == 1, "Conserve atoms and excess: " + id)
		for key in products:
			check(total.get(key, 0) == products[key], "Correct product yield: " + key)
		var sample_after := sample.duplicate()
		var outlets_after := outlets.duplicate()
		check(not demo.react(sample, trigger, outlets) and sample == sample_after and outlets == outlets_after, "Repeated action cannot replay the batch: " + id)

func atoms_in(sample: Dictionary) -> Dictionary:
	var result := {}
	for substance in Catalog.load_data().substances:
		for symbol in substance.atoms:
			result[symbol] = result.get(symbol, 0) + sample.get(substance.id, 0)
	return result

func screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
