extends AcceptDialog
signal module_changed

const UI = preload("res://scripts/workspace_ui.gd")
const Abilities = preload("res://scripts/robot_abilities.gd")
const ReagentCard = preload("res://scripts/reagent_card.gd")

var inventory: RefCounted
var modules: Array
var module_text: Label
var module_details: Label
var remove_button: Button
var stocks: VBoxContainer

func _ready() -> void:
	title = "Robot"
	exclusive = true
	get_ok_button().text = "Zavrieť"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	UI.label(body, "Slot na molekulu", 18, UI.MINT, true)
	var slot := UI.panel(body, UI.CANVAS, 14, 12)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.set_drag_forwarding(Callable(), _can_drop_module, _drop_module)
	var slot_content := UI.column(slot, 5)
	slot_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	module_text = UI.label(slot_content, "", 18, UI.TEXT, true)
	module_details = UI.label(slot_content, "", 14, UI.MUTED)
	module_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	remove_button = UI.button(body, "Vrátiť molekulu do zásoby")
	remove_button.pressed.connect(_remove_module)
	var instructions := UI.label(body, "Molekulu potiahni do slotu alebo klikni na jej kartu. Schopnosť používaš medzerníkom.", 14, UI.MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 174.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	stocks = UI.column(scroll, 5)
	stocks.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func show_for(stock: RefCounted, catalog: Dictionary) -> void:
	inventory = stock
	modules = catalog.substances
	_refresh()
	popup_centered(Vector2i(590, 465))

func _refresh() -> void:
	var id: String = inventory.robot_module
	var current: Dictionary = Abilities.MODULES.get(id, {})
	module_text.text = "Prázdny slot"
	module_details.text = "Vlož jednu molekulu zo zásoby."
	remove_button.disabled = id.is_empty()
	for item in modules:
		if item.id == id:
			module_text.text = "%s  ·  %s" % [item.display_formula, current.name]
			module_details.text = current.description + " Obnova 5 sekúnd."
			break

	for child in stocks.get_children():
		stocks.remove_child(child)
		child.queue_free()
	for item in modules:
		if not Abilities.MODULES.has(item.id) or inventory.stock.get(item.id, 0) <= 0 or item.id == id:
			continue
		var ability: Dictionary = Abilities.MODULES[item.id]
		var card := ReagentCard.new()
		card.substance_id = item.id
		card.formula = item.display_formula
		card.inventory = inventory
		card.text = "%s   %s   ·   %s" % [item.display_formula, item.name, ability.name]
		card.tooltip_text = ability.description
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.pressed.connect(_equip_module.bind(item.id))
		stocks.add_child(card)
	if stocks.get_child_count() == 0:
		UI.label(stocks, "V zásobe nemáš ďalšiu vhodnú molekulu. Poskladaj ju a vlož do zásoby.", 14, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _can_drop_module(_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary and data.get("type") == "laboratory_portion"
		and data.get("inventory") == inventory
		and Abilities.MODULES.has(data.get("id", ""))
		and inventory.stock.get(data.id, 0) > 0
		and data.id != inventory.robot_module
	)

func _drop_module(position: Vector2, data: Variant) -> void:
	if _can_drop_module(position, data):
		_equip_module(data.id)

func _equip_module(id: String) -> void:
	if inventory.equip_robot_module(id):
		_refresh()
		module_changed.emit()

func _remove_module() -> void:
	if inventory.unequip_robot_module():
		_refresh()
		module_changed.emit()
