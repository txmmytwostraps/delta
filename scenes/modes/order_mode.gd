extends VBoxContainer
## Put the lines in order: the solution's lines, shuffled, in one block of
## code. Each line has a grip on the left and arrows on the right. Tap a
## line, then tap where it should go; or use the arrows. The assembled code
## goes through the judge.

signal changed
## The text for the instruction area changed (a line was picked up or put down).
signal instruction_changed

const SELECTED := Color("#7ef0c2", 0.12)

var _lines: Array = []
var _start: Array = []
var _selected := -1


func setup(problem: Dictionary) -> void:
	_start = Modes.parsons_lines(str(problem.solution), str(problem.id))
	_lines = _start.duplicate()
	render()


func instruction() -> String:
	if _selected >= 0:
		return "Now tap the line whose place it should take."
	return "Put the lines in order. Tap a line, then the line whose place it should take, or use the arrows."


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
	var parts := UI.code_block()
	parts.rows.add_theme_constant_override("separation", 8)
	for i in _lines.size():
		parts.rows.add_child(_row(i))
	add_child(parts.block)
	instruction_changed.emit()


func _row(i: int) -> Control:
	var holder := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = SELECTED if i == _selected else Color(0, 0, 0, 0)
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.content_margin_left = 4
	box.content_margin_right = 4
	holder.add_theme_stylebox_override("panel", box)
	holder.custom_minimum_size.y = 88
	var parts := UI.code_line(i + 1, _lines[i], true, i == _selected)
	var row: HBoxContainer = parts.row
	row.add_child(_arrow("▲", i > 0, func() -> void: _move(i, i - 1)))
	row.add_child(_arrow("▼", i < _lines.size() - 1, func() -> void: _move(i, i + 1)))
	holder.add_child(row)
	holder.add_child(UI.tap_area(func() -> void: _tap(i), 176))
	return holder


func _arrow(glyph: String, enabled: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"Link"
	button.custom_minimum_size = Vector2(88, 88)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.focus_mode = Control.FOCUS_NONE
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
