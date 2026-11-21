extends RefCounted
signal process_changed(id: String)
signal reaction_completed(products: Dictionary, excess: Dictionary)
const INITIAL_TEMPERATURE := 20.0
const BOILING_TEMPERATURE := 100.0
const MAX_TEMPERATURE := 600.0
var catalog := AlphaCatalog.load_data()
var formulas := {}
var instrument := "flask"
var recipe: Dictionary:
	get: return catalog.reactions[instrument]
var temperature := INITIAL_TEMPERATURE
var mode := "off"
var boiling := false

func _init() -> void:
	for substance in catalog.substances:
		formulas[substance.id] = substance.display_formula

func quantities(portions: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in portions:
		var n := int(portions[id])
		parts.append(("%d " % n if n > 1 else "") + str(formulas[id]))
	return " + ".join(parts)

func equation() -> String:
	var arrow := " ⇌ " if recipe.get("reversible", false) else " → "
	return quantities(recipe.reactants) + arrow + quantities(recipe.products)

func is_water(sample: Dictionary) -> bool:
	return sample.size() == 1 and sample.get("water", 0) > 0

func reset() -> void:
	temperature = INITIAL_TEMPERATURE
	mode = "off"
	boiling = false

func set_mode(value: String, sample: Dictionary) -> void:
	if recipe.trigger != "heat" or sample.is_empty() or value not in ["heat", "cool", "off"]:
		mode = "off"
		return
	mode = value

func step(delta: float, sample: Dictionary) -> void:
	if recipe.trigger != "heat":
		return
	if sample.is_empty():
		reset()
		return
	if mode == "heat":
		var limit := BOILING_TEMPERATURE if is_water(sample) else MAX_TEMPERATURE
		if can_react(sample):
			limit = float(recipe.temperature)
		temperature = minf(limit, temperature + maxf(delta, 0) * (8.0 if is_water(sample) else 20.0))
	elif mode == "cool":
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 10.0)
	else:
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 2.0)
	if mode == "heat" and temperature >= float(recipe.temperature):
		react(sample)
	var now_boiling := is_water(sample) and temperature >= BOILING_TEMPERATURE
	if now_boiling != boiling:
		boiling = now_boiling
		process_changed.emit("boiling" if boiling else "cooled")
	if temperature <= INITIAL_TEMPERATURE and mode == "cool":
		mode = "off"

func ingredient_issue(sample: Dictionary) -> String:
	for id in sample:
		if not recipe.reactants.has(id):
			return "Vzorka obsahuje prímes %s. Vráť obsah a vyber látky podľa rovnice." % formulas.get(id, id)
	var missing := {}
	for id in recipe.reactants:
		var deficit := int(recipe.reactants[id]) - int(sample.get(id, 0))
		if deficit > 0:
			missing[id] = deficit
	return "" if missing.is_empty() else "Doplň do prístroja: %s." % quantities(missing)

func can_react(sample: Dictionary) -> bool:
	return ingredient_issue(sample).is_empty()

func react(sample: Dictionary, trigger := "heat", outlets: Variant = null) -> bool:
	if trigger != recipe.trigger or not can_react(sample):
		return false
	if trigger == "heat" and (mode != "heat" or temperature < float(recipe.temperature)):
		return false
	var destination := sample
	if recipe.get("separate_outputs", false):
		if not outlets is Dictionary or not outlets.is_empty():
			return false
		destination = outlets
	for id in recipe.reactants:
		sample[id] -= int(recipe.reactants[id])
		if sample[id] == 0:
			sample.erase(id)
	var excess := sample.duplicate()
	var products := {}
	for id in recipe.products:
		products[id] = int(recipe.products[id])
		destination[id] = destination.get(id, 0) + products[id]
	mode = "off"
	boiling = false
	reaction_completed.emit(products, excess)
	process_changed.emit(recipe.id)
	return true
