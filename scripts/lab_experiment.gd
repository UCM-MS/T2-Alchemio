extends RefCounted
signal process_changed(id: String)
const INITIAL_TEMPERATURE := 20.0
const BOILING_TEMPERATURE := 100.0
# Deliberate gameplay condition, not a measured methane autoignition temperature.
const REACTION_TEMPERATURE := 300.0
const MAX_TEMPERATURE := 600.0
var temperature := INITIAL_TEMPERATURE
var mode := "off"
var boiling := false

func is_water(sample: Dictionary) -> bool:
	return sample.size() == 1 and sample.get("water", 0) > 0

func reset() -> void:
	temperature = INITIAL_TEMPERATURE
	mode = "off"
	boiling = false

func set_mode(value: String, sample: Dictionary) -> void:
	if sample.is_empty() or value not in ["heat", "cool", "off"]:
		mode = "off"
		return
	mode = value

func step(delta: float, sample: Dictionary) -> void:
	if sample.is_empty():
		reset()
		return
	if mode == "heat":
		var limit := BOILING_TEMPERATURE if is_water(sample) else MAX_TEMPERATURE
		if can_react(sample):
			limit = REACTION_TEMPERATURE
		temperature = minf(limit, temperature + maxf(delta, 0) * (8.0 if is_water(sample) else 20.0))
	elif mode == "cool":
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 10.0)
	else:
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 2.0)
	if mode == "heat" and temperature >= REACTION_TEMPERATURE:
		react(sample)
	var now_boiling := is_water(sample) and temperature >= BOILING_TEMPERATURE
	if now_boiling != boiling:
		boiling = now_boiling
		process_changed.emit("boiling" if boiling else "cooled")
	if temperature <= INITIAL_TEMPERATURE and mode == "cool":
		mode = "off"

func can_react(sample: Dictionary) -> bool:
	# One supported complete-combustion batch; other substances are not simulated.
	return sample.size() == 2 and sample.get("methane", 0) >= 1 and sample.get("oxygen", 0) >= 2

func react(sample: Dictionary) -> bool:
	if mode != "heat" or temperature < REACTION_TEMPERATURE or not can_react(sample):
		return false
	for id in ["methane", "oxygen"]:
		sample[id] -= 1 if id == "methane" else 2
		if sample[id] == 0:
			sample.erase(id)
	sample["carbon_dioxide"] = sample.get("carbon_dioxide", 0) + 1
	sample["water"] = sample.get("water", 0) + 2
	mode = "off"
	boiling = false
	process_changed.emit("combustion")
	return true
