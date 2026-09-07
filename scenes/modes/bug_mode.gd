extends VBoxContainer
## Fix the bug: a working solution with one small change planted in it, in
## one block of code. Tap a line to see other ways to write it, and pick
## one. The judge decides.

signal changed
signal instruction_changed

const MENU_SIZE := 8
const OPEN := Color("#7ef0c2", 0.12)

## What the bug is, for the hint ("an operator", ...). "" until setup found one.
var kind := ""

var _problem: Dictionary = {}
var _lines: Array = []       # the code as it stands
var _start: Array = []       # the code with the bug
var _original: Array = []    # the solution
var _open := -1              # the line whose menu is open


## Finds the bug for a problem, like the site: the first candidate that
## compiles and fails a test. {} when none exists. Slow (a few judge runs),
## so callers keep the answer.
static func find(problem: Dictionary) -> Dictionary:
	for c in Modes.candidates(str(problem.solution), str(problem.id)).slice(0, 12):
		var reply: Dictionary = await Grader.run(c.code, problem)
		var result: Dictionary = reply.result
		if result.status == "ok" and int(result.passed) < int(result.total):
			return c
	return {}


## found: the bug from find(), or {} to look it up now. Returns false when
## there is none.
func setup(problem: Dictionary, found: Dictionary = {}) -> bool:
	_problem = problem
	_original = Array(str(problem.solution).split("\n"))
	var c := found
	if c.is_empty():
		c = await find(problem)
	if c.is_empty() or not is_inside_tree():
		return false
	kind = c.kind
	_start = Array(str(c.code).split("\n"))
	_lines = _start.duplicate()
	render()
	return true


func instruction() -> String:
	if _open >= 0:
		return "Pick another way to write that line, or leave it."
	return "One line has a bug. Tap a line to change it."


func code() -> String:
	return "\n".join(_lines)


func reset() -> void:
	_lines = _start.duplicate()
	_open = -1
	render()


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var parts := UI.code_block()
	parts.rows.add_theme_constant_override("separation", 8)
	for i in _lines.size():
		parts.rows.add_child(_row(i))
		if i == _open:
			parts.rows.add_child(_menu(i))
	add_child(parts.block)
	instruction_changed.emit()


func _row(i: int) -> Control:
	var holder := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = OPEN if i == _open else Color(0, 0, 0, 0)
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.content_margin_left = 4
	box.content_margin_right = 4
	holder.add_theme_stylebox_override("panel", box)
	holder.custom_minimum_size.y = 88
	var parts := UI.code_line(i + 1, _lines[i], false, false)
	if _lines[i] != _start[i]:
		# A line the user changed: marked at its number.
		parts.row.get_child(0).theme_type_variation = &"Accent"
	holder.add_child(parts.row)
	holder.add_child(UI.tap_area(func() -> void:
		_open = -1 if _open == i else i
		render()))
	return holder


## The replacements for line i: every one-step change, the fix among them,
## in a fixed order for this problem, at most MENU_SIZE of them.
func options_for(i: int) -> Array:
	var line: String = _lines[i]
	var options := Modes.line_variants(line, _lines)
	var fix: String = _original[i] if i < _original.size() else ""
	if fix != "" and fix != line and not options.has(fix):
		options.append(fix)
	var order := Modes.seeded_order("%s:%d:%s" % [_problem.id, i, line], options.size())
	var shuffled := []
	for k in order:
		shuffled.append(options[k])
	if shuffled.size() > MENU_SIZE:
		var fix_at := shuffled.find(fix)
		shuffled = shuffled.slice(0, MENU_SIZE)
		if fix_at >= MENU_SIZE:
			shuffled[order[0] % MENU_SIZE] = fix
	return shuffled


func _menu(i: int) -> Control:
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	var options := options_for(i)
	if options.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"Dim"
		none.text = "Nothing to change on this line."
		menu.add_child(none)
	for option in options:
		var button := UI.choice(str(option).lstrip("\t"))
		button.pressed.connect(func() -> void: _apply(i, option))
		menu.add_child(button)
	var leave := Button.new()
	leave.theme_type_variation = &"Link"
	leave.custom_minimum_size.y = 88
	leave.mouse_filter = Control.MOUSE_FILTER_PASS
	leave.text = "LEAVE IT AS IT IS"
	leave.pressed.connect(func() -> void:
		_open = -1
		render())
	menu.add_child(leave)
	return menu


func _apply(i: int, option: String) -> void:
	_lines[i] = option
	_open = -1
	render()
	changed.emit()
