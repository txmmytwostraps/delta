class_name UI
## Small builders for pieces several screens share. Each role has one look:
## rows to tap, blocks of code, lines of code inside a block, choices.

## Rows and cards are at least this tall (56 points), so a thumb hits them.
const ROW_HEIGHT := 112
const DIM := Color("#6b7885")


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
	text.text = "[color=#6b7885]%s[/color]%s" % ["│ ".repeat(depth), Highlight.line(line.lstrip("\t"))]
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
	var line := Color("#344050")
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
	left.color = Color("#344050")
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


## A list row, 52 points tall: marker · title · a trailing value in muted.
## current: the accent bar down the left edge and the panel background.
static func list_row(marker: String, title: String, trailing: String = "", current: bool = false, dim: bool = false) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"RowCurrent" if current else &"Row"
	button.custom_minimum_size.y = 104
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	button.add_child(box)
	if marker != "":
		var m := Label.new()
		m.text = marker
		m.theme_type_variation = &"Dim" if dim else (&"Accent" if current or marker == "✓" else &"Muted")
		m.custom_minimum_size.x = 44
		m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(m)
	var text := Label.new()
	text.text = title
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		text.theme_type_variation = &"Dim"
	box.add_child(text)
	if trailing != "":
		var note := Label.new()
		note.text = trailing
		note.theme_type_variation = &"Dim" if dim else &"Muted"
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note)
	return button


## A section header: 11 points, uppercase, muted.
static func section(title: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.text = title.to_upper()
	label.custom_minimum_size.y = 44
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## A row with a value and a − / + stepper on the right.
static func stepper_row(title: String, value: String, on_less: Callable, on_more: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 104
	row.add_theme_constant_override("separation", 8)
	var pad := Control.new()
	pad.custom_minimum_size.x = 16
	row.add_child(pad)
	var text := Label.new()
	text.text = title
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var less := Button.new()
	less.custom_minimum_size = Vector2(80, 80)
	less.mouse_filter = Control.MOUSE_FILTER_PASS
	less.text = "−"
	less.pressed.connect(on_less)
	row.add_child(less)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.custom_minimum_size.x = 96
	row.add_child(v)
	var more := Button.new()
	more.custom_minimum_size = Vector2(80, 80)
	more.mouse_filter = Control.MOUSE_FILTER_PASS
	more.text = "+"
	more.pressed.connect(on_more)
	row.add_child(more)
	var line := HSeparator.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.add_child(row)
	column.add_child(line)
	var wrap := HBoxContainer.new()
	wrap.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrap


## A row with a segmented choice on the right (S / M / L).
static func segment_row(title: String, options: Array, current: String, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 104
	row.add_theme_constant_override("separation", 8)
	var pad := Control.new()
	pad.custom_minimum_size.x = 16
	row.add_child(pad)
	var text := Label.new()
	text.text = title
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	for option in options:
		var seg := Button.new()
		seg.theme_type_variation = &"Segment"
		seg.custom_minimum_size = Vector2(80, 72)
		seg.mouse_filter = Control.MOUSE_FILTER_PASS
		seg.toggle_mode = true
		seg.button_pressed = str(option) == current
		seg.text = str(option)
		seg.pressed.connect(func() -> void: on_pick.call(str(option)))
		row.add_child(seg)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	column.add_child(HSeparator.new())
	return column


## A row with an ON / OFF switch on the right.
static func toggle_row(title: String, on: bool, on_toggle: Callable) -> Button:
	var row := list_row("", title, "ON" if on else "OFF")
	row.pressed.connect(on_toggle)
	return row


## A thin progress bar: done of total, accent over line.
static func bar(done: float, total: float, height: int = 6) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = height
	var a := ColorRect.new()
	a.color = Color("#7ef0c2")
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_stretch_ratio = maxf(0.001, done)
	row.add_child(a)
	var b := ColorRect.new()
	b.color = Color("#344050")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = maxf(0.001, total - done)
	row.add_child(b)
	return row


## A tile: a label above a big number.
static func tile(label: String, value: String, accent: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var k := Label.new()
	k.theme_type_variation = &"Detail"
	k.text = label.to_lower()
	column.add_child(k)
	var v := Label.new()
	v.theme_type_variation = &"Number"
	v.text = value
	v.clip_text = true
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if accent:
		v.add_theme_color_override("font_color", Color("#7ef0c2"))
	column.add_child(v)
	return panel


## A text link in a row of actions, e.g. ANY PROBLEM · DRILL.
static func link(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Link"
	button.custom_minimum_size.y = 72
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.pressed.connect(on_press)
	return button


## An answer to pick whose text is more than one line: the radio marker,
## then the lines stacked in a block, never joined onto one line (printed
## output reads the way the results panel writes it).
## state: "" | "on" | "right" | "wrong".
static func choice_block(lines: Array, state: String = "") -> Button:
	var button := Button.new()
	button.theme_type_variation = {"": &"Choice", "on": &"ChoiceOn", "right": &"ChoiceRight", "wrong": &"ChoiceWrong"}[state]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 16
	row.offset_bottom = -16
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	button.add_child(row)
	var marker := Label.new()
	marker.text = "○" if state == "" else "●"
	marker.theme_type_variation = &"Code"
	marker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "right" or state == "wrong":
		marker.add_theme_color_override("font_color", Color("#0b0d10"))
	row.add_child(marker)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	for line in lines:
		var text := Label.new()
		text.theme_type_variation = &"Code"
		text.text = str(line)
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state == "right" or state == "wrong":
			text.add_theme_color_override("font_color", Color("#0b0d10"))
		elif str(line).begins_with("…"):
			text.theme_type_variation = &"Dim"
		column.add_child(text)
	# The button grows with the stack.
	column.resized.connect(func() -> void:
		button.custom_minimum_size.y = maxf(96.0, column.get_minimum_size().y + 32.0))
	button.custom_minimum_size.y = maxf(96.0, 40.0 * lines.size() + 32.0)
	return button


## One rung of the hints ladder: a square on the left holding its number (a
## filled ✓ once opened), the name in sentence case, and the state on the
## right — "open ›" in accent for the one that may open next, "opened", or
## the reason it is locked, dimmed.
## state: "open" | "opened" | "locked".
static func help_row(square: String, title: String, state_text: String, state: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Row"
	button.custom_minimum_size.y = 96
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.disabled = state == "locked"
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_right = -4
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 20)
	button.add_child(box)

	var sq := PanelContainer.new()
	sq.theme_type_variation = &"SquareOn" if state == "opened" else &"Square"
	sq.custom_minimum_size = Vector2(44, 44)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Label.new()
	glyph.text = square
	glyph.theme_type_variation = &"Detail"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "opened":
		glyph.add_theme_color_override("font_color", Color("#0b0d10"))
	sq.add_child(glyph)
	box.add_child(sq)

	var text := Label.new()
	text.text = title
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "locked":
		text.theme_type_variation = &"Muted"
	box.add_child(text)

	if state_text != "":
		var note := Label.new()
		note.text = state_text
		note.theme_type_variation = &"Detail"
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state == "open":
			note.add_theme_color_override("font_color", Color("#7ef0c2"))
		elif state == "locked":
			note.add_theme_color_override("font_color", DIM)
		box.add_child(note)
	return button
