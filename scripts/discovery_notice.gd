extends PanelContainer
## Non-modal, queued notices never stop bond editing or consume the sample.
signal open_requested(id: String)
var pending: Array[Dictionary] = []
var current_id := ""
var read_button: Button
var text_label: Label
var timer: Timer

func _ready() -> void:
	# Assembly pages are recreated after every collection and may be later siblings.
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -420
	offset_right = -28
	offset_top = 86
	var style := StyleBoxFlat.new()
	style.bg_color = Color("173e42")
	style.border_color = Color("7ed9c3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	add_child(row)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_label)
	var actions := VBoxContainer.new()
	row.add_child(actions)
	read_button = Button.new()
	read_button.text = "Čítať"
	read_button.pressed.connect(func(): open_requested.emit(current_id))
	actions.add_child(read_button)
	var close := Button.new()
	close.text = "OK"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_next)
	actions.add_child(close)
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 5
	timer.timeout.connect(_next)
	add_child(timer)
	mouse_filter = Control.MOUSE_FILTER_PASS
	hide()

func enqueue(message: String, id := "") -> void:
	pending.append({"message": message, "id": id})
	if not visible:
		_next()

func clear() -> void:
	pending.clear()
	timer.stop()
	hide()

func _next() -> void:
	if pending.is_empty():
		timer.stop()
		hide()
		return
	var item: Dictionary = pending.pop_front()
	current_id = item.id
	text_label.text = item.message
	read_button.visible = not current_id.is_empty()
	show()
	timer.start()
