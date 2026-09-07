class_name UI
## Small builders for pieces several screens share.

## Rows and cards are at least this tall (56 points), so a thumb hits them.
const ROW_HEIGHT := 112


## A full-width tappable row: text on the left, a short note on the right.
## Long text wraps when `wrap` is true; otherwise it is cut with an ellipsis.
## Either way a row never pushes the screen wider than the phone.
static func row(left: String, right: String = "", dim: bool = false, wrap: bool = false) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Row"
	button.custom_minimum_size.y = ROW_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let the touch reach the list behind, so a drag that starts on a row
	# scrolls (the button cancels its own press when the scroll begins).
	button.mouse_filter = Control.MOUSE_FILTER_PASS

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_right = -28
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 20)
	button.add_child(box)

	var text := Label.new()
	text.text = left
	if wrap:
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# The button grows with the wrapped text.
		text.resized.connect(func() -> void:
			button.custom_minimum_size.y = maxf(ROW_HEIGHT, text.get_minimum_size().y + 40))
	else:
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		text.theme_type_variation = &"Dim"
	box.add_child(text)

	if right != "":
		var note := Label.new()
		note.text = right
		note.theme_type_variation = &"Dim" if dim else &"Muted"
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note)
	return button


## A line of code as a card: indentation guides, the text wrapping as needed,
## and a fixed column on the right for whatever controls the caller adds.
## Returns { "card": PanelContainer, "right": VBoxContainer, "text": Label }.
static func code_card(line: String, active: bool = false, changed: bool = false) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = ROW_HEIGHT
	if active:
		card.theme_type_variation = &"PanelActive"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var depth := line.length() - line.lstrip("\t").length()
	if depth > 0:
		var guides := Label.new()
		guides.theme_type_variation = &"Dim"
		guides.text = "│ ".repeat(depth)
		guides.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		guides.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(guides)
	var text := Label.new()
	text.theme_type_variation = &"Accent" if changed else &"Code"
	text.text = line.lstrip("\t")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(right)
	return {"card": card, "right": right, "text": text}


## An invisible full-size button over a card, so a tap anywhere on it acts.
## right_margin keeps the controls column to itself.
static func tap_area(on_press: Callable, right_margin: int = 0) -> Button:
	var tap := Button.new()
	tap.flat = true
	tap.mouse_filter = Control.MOUSE_FILTER_PASS
	tap.focus_mode = Control.FOCUS_NONE
	for box_name in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(box_name, StyleBoxEmpty.new())
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.offset_right = -right_margin
	tap.pressed.connect(on_press)
	return tap
