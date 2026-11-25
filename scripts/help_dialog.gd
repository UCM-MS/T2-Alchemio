extends AcceptDialog
var text_label: Label
var scroll: ScrollContainer
var illustration: TextureRect

func _ready() -> void:
	exclusive = true
	ok_button_text = "Rozumiem"
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.custom_minimum_size.y = 144
	illustration.hide()
	content.add_child(illustration)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text_label)

func open(heading: String, text: String) -> void:
	title = heading
	text_label.text = text
	var viewport := get_tree().root.get_visible_rect().size
	scroll.custom_minimum_size = Vector2(minf(760, viewport.x - 100), minf(440, viewport.y - 150))
	size = Vector2i.ZERO
	scroll.scroll_vertical = 0
	popup_centered()
