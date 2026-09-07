class_name UI
## Small builders for pieces several screens share. Each role has one look:
## rows to tap, blocks of code, lines of code inside a block, choices.

## Rows and cards are at least this tall (56 points), so a thumb hits them.
const ROW_HEIGHT := 112
const DIM := Color("#4e5a66")


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


## A block of code: a panel with an accent bar down its left edge, holding
## one line per row. Returns { "block": PanelContainer, "rows": VBoxContainer }
## so a caller can fill the rows itself (orderable lines, a bug's menu).
static func code_block() -> Dictionary:
	var block := PanelContainer.new()
	block.theme_type_variation = &"CodeBlock"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	block.add_child(rows)
	return {"block": block, "rows": rows}


## A read-only block of code, numbered and coloured.
static func code_view(code: String) -> PanelContainer:
	var parts := code_block()
	var lines := code.split("\n")
	while lines.size() > 1 and lines[-1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	for i in lines.size():
		parts.rows.add_child(code_line(i + 1, lines[i]).row)
	return parts.block


## One line of code inside a block: its number in dim, indentation guides,
## the text coloured. handle: a "≡" grip on the left, for orderable lines.
## Returns { "row": HBoxContainer, "text": RichTextLabel, "handle": Label }.
static func code_line(number: int, line: String, handle: bool = false, active: bool = false) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grip: Label = null
	if handle:
		grip = Label.new()
		grip.theme_type_variation = &"Accent" if active else &"Dim"
		grip.text = "≡"
		grip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grip.custom_minimum_size.x = 28
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(grip)
	var n := Label.new()
	n.theme_type_variation = &"Dim"
	n.text = str(number)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.custom_minimum_size.x = 40
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(n)
	var depth := line.length() - line.lstrip("\t").length()
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = "[color=#4e5a66]%s[/color]%s" % ["│ ".repeat(depth), Highlight.line(line.lstrip("\t"))]
	row.add_child(text)
	return {"row": row, "text": text, "handle": grip}


## An answer to pick: a radio row. state: "" | "on" | "right" | "wrong".
static func choice(text: String, state: String = "") -> Button:
	var button := Button.new()
	button.theme_type_variation = {"": &"Choice", "on": &"ChoiceOn", "right": &"ChoiceRight", "wrong": &"ChoiceWrong"}[state]
	button.custom_minimum_size.y = 96
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = ("○  " if state == "" else "●  ") + text
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


## The week as seven small squares: a tick on an active day (or a day a
## rest day covered), today outlined, blank for a miss; then the rest-day
## token when one is held. week comes from Streak.compute().
static func week_row(week: Array, token: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var accent := Color("#7ef0c2")
	var line := Color("#2a323b")
	for d in week:
		var square := PanelContainer.new()
		square.custom_minimum_size = Vector2(48, 48)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(0)
		var on: bool = d.active or d.covered
		box.bg_color = accent if d.active else (Color(accent, 0.35) if d.covered else Color(0, 0, 0, 0))
		box.border_color = accent if (on or d.today) else line
		box.set_border_width_all(3 if d.today else 2)
		square.add_theme_stylebox_override("panel", box)
		var mark := Label.new()
		mark.text = "✓" if on else ""
		mark.theme_type_variation = &"Small"
		mark.add_theme_color_override("font_color", Color("#0b0d10") if d.active else accent)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		square.add_child(mark)
		row.add_child(square)
	if token:
		var held := Label.new()
		held.theme_type_variation = &"Amber"
		held.text = "◆ rest day"
		held.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(held)
	return row


## "LEVEL 3 · 1240 XP" with a thin bar to the next level. x from
## Progress.xp_info(). detail: a second line with the XP to the next level.
static func xp_block(x: Dictionary, detail: bool = false) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.text = "LEVEL %d · %d XP" % [int(x.level), int(x.xp)]
	block.add_child(label)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.custom_minimum_size.y = 6
	var done := ColorRect.new()
	done.color = Color("#7ef0c2")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.size_flags_stretch_ratio = maxf(0.001, float(x.into))
	bar.add_child(done)
	var left := ColorRect.new()
	left.color = Color("#2a323b")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = maxf(0.001, float(x.to_next))
	bar.add_child(left)
	block.add_child(bar)
	if detail:
		var line := Label.new()
		line.theme_type_variation = &"Detail"
		line.text = "%d XP to level %d" % [int(x.to_next), int(x.level) + 1]
		block.add_child(line)
	return block


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
