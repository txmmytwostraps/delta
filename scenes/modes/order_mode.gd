extends VBoxContainer
## Put the lines in order: the solution's lines, shuffled. Tap a line, then
## tap where it should go; or use the arrows. Indentation stays with each
## line and is shown as guides. The assembled code goes through the judge.

signal changed

var _lines: Array = []
var _start: Array = []
var _selected := -1


func setup(problem: Dictionary) -> void:
	_start = Modes.parsons_lines(str(problem.solution), str(problem.id))
	_lines = _start.duplicate()
	render()


func code() -> String:
	return "\n".join(_lines)


func reset() -> void:
	_lines = _start.duplicate()
	_selected = -1
	render()


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.theme_type_variation = &"Small"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "PUT THE LINES IN ORDER · TAP A LINE, THEN WHERE IT GOES, OR USE THE ARROWS" if _selected < 0 else "NOW TAP THE LINE WHOSE PLACE IT SHOULD TAKE"
	add_child(hint)
	for i in _lines.size():
		add_child(_row(i))


func _row(i: int) -> Control:
	var panel := PanelContainer.new()
	if i == _selected:
		panel.theme_type_variation = &"PanelActive"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var line: String = _lines[i]
	var depth := line.length() - line.lstrip("\t").length()
	if depth > 0:
		var guides := Label.new()
		guides.theme_type_variation = &"Dim"
		guides.text = "│ ".repeat(depth)
		guides.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(guides)
	var text := Label.new()
	text.theme_type_variation = &"Code"
	text.text = line.lstrip("\t")
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)

	var up := _arrow("▲", i > 0, func() -> void: _move(i, i - 1))
	var down := _arrow("▼", i < _lines.size() - 1, func() -> void: _move(i, i + 1))
	box.add_child(up)
	box.add_child(down)

	var tap := Button.new()
	tap.flat = true
	tap.mouse_filter = Control.MOUSE_FILTER_PASS
	for box_name in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(box_name, StyleBoxEmpty.new())
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.offset_right = -196   # leave the arrows to themselves
	tap.pressed.connect(func() -> void: _tap(i))
	panel.add_child(tap)
	return panel


func _arrow(glyph: String, enabled: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Link"
	button.custom_minimum_size = Vector2(88, 88)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = glyph
	button.disabled = not enabled
	button.pressed.connect(on_press)
	return button


func _tap(i: int) -> void:
	if _selected < 0:
		_selected = i
		render()
	elif _selected == i:
		_selected = -1
		render()
	else:
		_move(_selected, i)


func _move(from: int, to: int) -> void:
	if to < 0 or to >= _lines.size() or from == to:
		return
	var line = _lines.pop_at(from)
	_lines.insert(to, line)
	_selected = -1
	render()
	changed.emit()
