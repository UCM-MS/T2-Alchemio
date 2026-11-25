extends RefCounted
## Session stock and temporarily transferred laboratory portions.
const Catalog = preload("res://scripts/catalog.gd")
var stock: Dictionary = {}
var sample: Dictionary = {}
var outlets: Dictionary = {}

func _init() -> void:
	for substance in Catalog.stock_items(Catalog.load_data()):
		stock[substance.id] = 0

func credit(products: Dictionary) -> void:
	for id in stock:
		var count: int = products.get(id, 0)
		if count > 0:
			stock[id] += count

func take_from_stock(id: String) -> bool:
	if stock.get(id, 0) <= 0:
		return false
	stock[id] -= 1
	return true

func add_to_sample(id: String) -> bool:
	if not take_from_stock(id):
		return false
	sample[id] = sample.get(id, 0) + 1
	return true

func return_sample() -> void:
	credit(sample)
	sample.clear()
	credit(outlets)
	outlets.clear()

func collect_outlet(id: String) -> bool:
	if not outlets.has(id):
		return false
	stock[id] += outlets[id]
	outlets.erase(id)
	return true
