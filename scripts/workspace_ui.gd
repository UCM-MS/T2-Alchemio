extends RefCounted

const BG := Color("#0f1a26")
const PANEL := Color("#101e2b")
const CANVAS := Color("#132430")
const CARD := Color("#192c37")
const EDGE := Color("#263d49")
const TEXT := Color("#e1e6e8")
const MUTED := Color("#9aaeb8")
const MINT := Color("#92f0d6")
const ACCENT := Color("#36b999")
const ACTIVE := Color("#20473f")
const FONT = preload("res://assets/fonts/NotoSans.ttf")

static func box(fill: Color, border: Color, radius: int, padding: int, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 16
	style.set_content_margin_all(padding)
	return style

static func theme() -> Theme:
	var skin := Theme.new()
	skin.default_font = FONT
	skin.default_font_size = 15
	for kind in ["Button", "OptionButton", "LineEdit"]:
		skin.set_stylebox("normal", kind, box(CARD, EDGE, 11, 9))
		skin.set_stylebox("hover", kind, box(Color("#233b45"), Color("#486876"), 11, 9))
		skin.set_stylebox("pressed", kind, box(ACTIVE, ACCENT, 11, 9))
		skin.set_stylebox("disabled", kind, box(PANEL, EDGE, 11, 9))
		var focus := box(Color.TRANSPARENT, MINT, 11, 0, 2)
		focus.draw_center = false
		skin.set_stylebox("focus", kind, focus)
		skin.set_color("font_color", kind, TEXT)
		skin.set_color("font_disabled_color", kind, MUTED.darkened(0.14))
		skin.set_color("font_pressed_color", kind, MINT)
	skin.set_color("font_color", "Label", TEXT)
	return skin

static func label(parent: Control, value: String, points: int, color := TEXT, bold := false) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", points)
	node.add_theme_color_override("font_color", color)
	if bold:
		var face := FontVariation.new()
		face.base_font = FONT
		face.variation_embolden = 0.65
		node.add_theme_font_override("font", face)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Control, value: String) -> Button:
	var node := Button.new()
	node.text = value
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	return node

static func primary(node: Button) -> void:
	node.add_theme_stylebox_override("normal", box(ACCENT, ACCENT, 10, 9))
	node.add_theme_stylebox_override("hover", box(MINT, MINT, 10, 9))
	node.add_theme_color_override("font_color", BG)
	node.add_theme_color_override("font_hover_color", BG)

static func column(parent: Control, gap: int) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

static func row(parent: Control, gap: int) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

static func panel(parent: Control, fill := PANEL, padding := 16, radius := 22) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(fill, EDGE, radius, padding, 2))
	parent.add_child(node)
	return node

static func page(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32 if side == "top" else 20)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(margin)
	return column(margin, 18)

static func nav(parent: Control, active: String) -> Dictionary:
	var bar := panel(parent, PANEL, 14, 0)
	var strip := row(bar, 18)
	var brand := label(strip, "ALCHEMIO", 24, TEXT, true)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tabs := {}
	for title in ["Hracia plocha", "Skladanie", "Laboratórium", "Kolekcia"]:
		var tab := button(strip, title.to_upper())
		tab.add_theme_font_size_override("font_size", 17)
		tab.custom_minimum_size.y = 44
		tab.flat = true
		tab.disabled = true
		if title == active:
			tab.flat = false
			tab.add_theme_stylebox_override("disabled", box(ACTIVE, ACTIVE, 12, 9))
			tab.add_theme_color_override("font_disabled_color", MINT)
		tabs[title] = tab
	return tabs

static func heading(parent: Control, kicker: String, title: String) -> Label:
	var stack := column(parent, 2)
	label(stack, kicker, 14, ACCENT)
	return label(stack, title, 36, TEXT, true)

static func scroll_column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content := column(scroll, 7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

static func tint(symbol: String) -> Color:
	match symbol:
		"H", "H₂": return Color("#e0e3e5")
		"O", "O₂": return Color("#ff7474")
		"C": return Color("#bac3cd")
	return MINT

static func pigment(symbol: String) -> Color:
	match symbol:
		"H", "H₂": return Color("#56636d")
		"O", "O₂": return Color("#542f39")
		"C": return Color("#303c47")
	return ACTIVE

static func badge(parent: Control, symbol: String, diameter: int) -> Label:
	var node := label(parent, symbol, maxi(12, int(diameter * 0.39 / maxf(1, symbol.length() / 2.3))), tint(symbol), true)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.add_theme_stylebox_override("normal", box(pigment(symbol), tint(symbol).darkened(0.2), diameter / 2, 0))
	return node
