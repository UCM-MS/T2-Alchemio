extends RefCounted
## Session stock and temporarily transferred laboratory portions.
const Catalog = preload("res://scripts/catalog.gd")
const RobotAbilities = preload("res://scripts/robot_abilities.gd")
var stock: Dictionary = {}
var sample: Dictionary = {}
var outlets: Dictionary = {}
var robot_module := ""

func equip_robot_module(id: String) -> bool:
	if id == robot_module or not RobotAbilities.MODULES.has(id) or not take_from_stock(id):
		return false
	unequip_robot_module()
	robot_module = id
	return true

func unequip_robot_module() -> bool:
	if robot_module.is_empty():
		return false
	stock[robot_module] += 1
	robot_module = ""
	return true

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
