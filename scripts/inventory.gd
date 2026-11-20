extends RefCounted
## Session stock and temporarily transferred laboratory portions.
const Catalog = preload("res://scripts/catalog.gd")
var stock: Dictionary = {}
var sample: Dictionary = {}

func _init() -> void:
	for substance in Catalog.load_data().substances:
		stock[substance.id] = 0

func credit(products: Dictionary) -> void:
	for id in stock:
		var count: int = products.get(id, 0)
		if count > 0:
			stock[id] += count

func add_to_sample(id: String) -> bool:
	if stock.get(id, 0) <= 0:
		return false
	stock[id] -= 1
	sample[id] = sample.get(id, 0) + 1
	return true

func return_sample() -> void:
	credit(sample)
	sample.clear()
