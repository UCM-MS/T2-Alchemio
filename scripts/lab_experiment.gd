extends RefCounted
signal process_changed(id: String)
const INITIAL_TEMPERATURE := 20.0
const BOILING_TEMPERATURE := 100.0
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
	if not is_water(sample) or value not in ["heat", "cool", "off"]:
		mode = "off"
		return
	mode = value

func step(delta: float, sample: Dictionary) -> void:
	if not is_water(sample):
		reset()
		return
	if mode == "heat":
		temperature = minf(BOILING_TEMPERATURE, temperature + maxf(delta, 0) * 8.0)
	elif mode == "cool":
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 10.0)
	else:
		temperature = maxf(INITIAL_TEMPERATURE, temperature - maxf(delta, 0) * 2.0)
	var now_boiling := temperature >= BOILING_TEMPERATURE
	if now_boiling != boiling:
		boiling = now_boiling
		process_changed.emit("boiling" if boiling else "cooled")
	if temperature <= INITIAL_TEMPERATURE and mode == "cool":
		mode = "off"

func can_react(sample: Dictionary) -> bool:
	# One supported complete-combustion batch; other substances are not simulated.
	return sample.size() == 2 and sample.get("methane", 0) >= 1 and sample.get("oxygen", 0) >= 2

func react(sample: Dictionary) -> bool:
	if not can_react(sample):
		return false
	for id in ["methane", "oxygen"]:
		sample[id] -= 1 if id == "methane" else 2
		if sample[id] == 0:
			sample.erase(id)
	sample["carbon_dioxide"] = sample.get("carbon_dioxide", 0) + 1
	sample["water"] = sample.get("water", 0) + 2
	reset()
	process_changed.emit("combustion")
	return true
