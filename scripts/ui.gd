class_name UI
## Small builders for pieces several screens share.


## A full-width tappable row: text on the left, a short note on the right.
## Long text is cut with an ellipsis rather than pushing the screen wider
## than the phone, which is what a plain Button with long text does.
static func row(left: String, right: String = "", dim: bool = false) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Row"
	button.custom_minimum_size.y = 88
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
