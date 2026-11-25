extends RefCounted
signal process_changed(id: String)
signal reaction_completed(products: Dictionary, excess: Dictionary)

const INITIAL_TEMPERATURE := 20.0
const BOILING_TEMPERATURE := 100.0
const REACTION_DURATION := 1.3

var catalog := AlphaCatalog.load_data()
var formulas := {}
var instrument_id := "burner"
var instrument: Dictionary:
	get: return catalog.instruments[instrument_id]
var available_elements: Array[String] = ["H", "O"]
var result := {}
var pending := {}
var temperature := INITIAL_TEMPERATURE
var mode := "off"
var boiling := false
var time_remaining := 0.0

func _init() -> void:
	for substance in AlphaCatalog.stock_items(catalog):
		formulas[substance.id] = substance.display_formula

func quantities(portions: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in portions:
		var count := int(portions[id])
		parts.append(("%d " % count if count > 1 else "") + str(formulas[id]))
	return " + ".join(parts)

func result_equation() -> String:
	if result.is_empty():
		return ""
	var recipe: Dictionary = catalog.experiments[result.id]
	if result.products.size() > recipe.products.size():
		return quantities(result.consumed) + " → " + quantities(result.products)
	return recipe.get("equation", quantities(recipe.reactants) + " → " + quantities(recipe.products))

func reset() -> void:
	temperature = INITIAL_TEMPERATURE
	mode = "off"
	boiling = false
	time_remaining = 0.0
	pending.clear()
	result.clear()

func is_running() -> bool:
	return time_remaining > 0.0

func is_available(tool: Dictionary) -> bool:
	return not tool.has("requires_element") or tool.requires_element in available_elements

func can_heat_water(sample: Dictionary) -> bool:
	return instrument_id == "beaker" and sample.size() == 1 and sample.get("water", 0) > 0

func set_mode(value: String, sample: Dictionary) -> void:
	if not is_running() and can_heat_water(sample) and value in ["heat", "cool", "off"]:
		mode = value
		if value != "off":
			result.clear()

func prepare(action: String, sample: Dictionary) -> Dictionary:
	if action not in instrument.actions or not is_available(instrument) or not is_available(catalog.actions[action]):
		return {"issue": "Tento nástroj nie je dostupný."}
	if action == "furnace":
		return _plan_carbon(sample)
	if sample.is_empty():
		return {"issue": "Najprv vlož vzorku."}
	var candidates: Array[Dictionary] = []
	for id in catalog.experiments:
		var recipe: Dictionary = catalog.experiments[id]
		if recipe.apparatus != instrument_id or recipe.get("action", "") != action or not is_available(recipe):
			continue
		var compatible := true
		for reagent in sample:
			if not recipe.reactants.has(reagent):
				compatible = false
				break
		if compatible:
			candidates.append({"id": id, "recipe": recipe})
	if candidates.is_empty():
		return {"issue": "Táto vzorka sa na zvolený postup nehodí."}
	if candidates.size() > 1:
		return {"issue": "Pridaj jeden druh plynného paliva."}
	var candidate: Dictionary = candidates[0]
	var shortage := {}
	for reagent in candidate.recipe.reactants:
		var deficit := int(candidate.recipe.reactants[reagent]) - int(sample.get(reagent, 0))
		if deficit > 0:
			shortage[reagent] = deficit
	if not shortage.is_empty():
		return {"issue": "Ešte pridaj: %s." % quantities(shortage)}
	return {"id": candidate.id, "consumed": candidate.recipe.reactants, "products": candidate.recipe.products}

func _plan_carbon(sample: Dictionary) -> Dictionary:
	var carbon: int = sample.get("solid_carbon", 0)
	var oxygen: int = sample.get("oxygen", 0)
	var supported_count := int(carbon > 0) + int(oxygen > 0)
	if sample.size() > supported_count:
		return {"issue": "Pec v tejto etape spracúva tuhý uhlík s kyslíkom."}
	if carbon <= 0 or oxygen <= 0:
		return {"issue": "Vlož tuhý uhlík (C) a kyslík (O₂)."}
	# Balance the products in whole portions. Leave surplus reactants in the sample.
	if oxygen >= carbon:
		return {"id": "carbon_combustion", "consumed": {"solid_carbon": carbon, "oxygen": carbon}, "products": {"carbon_dioxide": carbon}}
	var consumed_carbon := mini(carbon, 2 * oxygen)
	var dioxide := 2 * oxygen - consumed_carbon
	var products := {"carbon_monoxide": consumed_carbon - dioxide}
	if dioxide > 0:
		products["carbon_dioxide"] = dioxide
	return {"id": "carbon_incomplete", "consumed": {"solid_carbon": consumed_carbon, "oxygen": oxygen}, "products": products}

func start(action: String, sample: Dictionary, outlets: Dictionary) -> bool:
	if is_running() or not outlets.is_empty():
		return false
	var plan := prepare(action, sample)
	if plan.has("issue"):
		return false
	result.clear()
	pending = plan
	mode = "off"
	boiling = false
	time_remaining = REACTION_DURATION
	return true

func step(delta: float, sample: Dictionary, outlets: Dictionary = {}) -> void:
	if is_running():
		time_remaining = maxf(0, time_remaining - delta)
		if not is_running():
			_finish_reaction(sample, outlets)
	elif instrument_id == "beaker":
		_step_boiling(delta, sample)

func _step_boiling(delta: float, sample: Dictionary) -> void:
	if not can_heat_water(sample):
		return
	match mode:
		"heat":
			temperature = minf(BOILING_TEMPERATURE, temperature + delta * 20.0)
		"cool":
			temperature = maxf(INITIAL_TEMPERATURE, temperature - delta * 20.0)
		_:
			temperature = maxf(INITIAL_TEMPERATURE, temperature - delta * 2.0)
	var now_boiling := temperature >= BOILING_TEMPERATURE
	if now_boiling != boiling:
		boiling = now_boiling
		process_changed.emit("boiling" if boiling else "cooled")
	if temperature <= INITIAL_TEMPERATURE and mode == "cool":
		mode = "off"

func _finish_reaction(sample: Dictionary, outlets: Dictionary) -> void:
	var plan := pending
	pending = {}
	if not outlets.is_empty():
		return
	for id in plan.consumed:
		if sample.get(id, 0) < plan.consumed[id]:
			return
	for id in plan.consumed:
		sample[id] -= int(plan.consumed[id])
		if sample[id] == 0:
			sample.erase(id)
	outlets.merge(plan.products)
	for id in outlets:
		outlets[id] = int(outlets[id])
	result = plan
	reaction_completed.emit(outlets.duplicate(), sample.duplicate())
