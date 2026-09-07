extends VBoxContainer
## What does this print: the solution, read-only, one of its tests, and four
## answers. The right one is what the judge got from the solution; the wrong
## ones come from buggy versions of it, so they look plausible.

## correct: the pick was right. reply: what to record, in the judge's shape.
signal answered(correct: bool, reply: Dictionary)
signal instruction_changed

const ANSWERS := 4

var _problem: Dictionary = {}
var _test_index := 0
var _print_only := false
var _answers: Array = []
var _correct := -1
var _reply: Dictionary = {}
var _done := false


## Runs the solution and a few buggy versions through the judge to build the
## answers. Returns false when the solution itself does not run.
func setup(problem: Dictionary) -> bool:
	_problem = problem
	_reply = await Grader.run(str(problem.solution), problem)
	if not is_inside_tree():
		return false
	if _reply.result.status != "ok" or int(_reply.result.passed) < int(_reply.result.total):
		return false
	var tests: Array = problem.get("tests", [])
	_test_index = Modes.seeded_order(str(problem.id) + ":print", tests.size())[0]
	_print_only = Fmt.print_only(problem)
	var right: Variant = _value_of(_reply.result.results[_test_index])
	var wrong := []
	for c in Modes.candidates(str(problem.solution), str(problem.id)).slice(0, 8):
		var reply: Dictionary = await Grader.run(c.code, problem)
		if not is_inside_tree():
			return false
		if reply.result.status != "ok" or reply.result.results.size() <= _test_index:
			continue
		var v: Variant = _value_of(reply.result.results[_test_index])
		if v != right and not wrong.has(v):
			wrong.append(v)
		if wrong.size() >= ANSWERS - 1:
			break
	for v in Modes.fallback_distractors(right, ANSWERS - 1 - wrong.size()):
		if v != right and not wrong.has(v):
			wrong.append(v)
	var all := [right] + wrong
	var order := Modes.seeded_order(str(problem.id) + ":answers", all.size())
	_answers = []
	for k in order:
		_answers.append(all[k])
	_correct = _answers.find(right)
	render()
	return true


func _value_of(r: Dictionary) -> Variant:
	return r.get("out", []) if _print_only else r.get("got", null)


func instruction() -> String:
	if _problem.is_empty():
		return ""
	var t: Dictionary = _problem.tests[_test_index]
	var frames: String = "after %d frame%s, " % [int(t.frames), "" if int(t.frames) == 1 else "s"] if t.has("frames") else ""
	return "%s The judge calls %s%s." % ["What does this print?" if _print_only else "What does this return?", frames, Fmt.call_str(_problem, t.get("args", []))]


func code() -> String:
	return str(_problem.get("solution", ""))


func reset() -> void:
	_done = false
	render()


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 16)

	var panel := PanelContainer.new()
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := Label.new()
	text.theme_type_variation = &"Code"
	text.text = code().replace("\t", "    ")
	scroll.add_child(text)
	panel.add_child(scroll)
	add_child(panel)

	var rtype := Fmt.return_type(str(_problem.get("signature", "")))
	for i in _answers.size():
		var button := UI.row(_answer_text(_answers[i], rtype), "", false, true)
		button.disabled = _done
		button.pressed.connect(func() -> void: _pick(i))
		add_child(button)
	instruction_changed.emit()


func _answer_text(v: Variant, rtype: String) -> String:
	if _print_only:
		var lines: Array = v if v is Array else [v]
		if lines.is_empty():
			return "(nothing printed)"
		var strings := []
		for line in lines:
			strings.append(str(line))
		return "\n".join(strings)
	return Fmt.fmt_typed(v, rtype)


func _pick(i: int) -> void:
	if _done:
		return
	_done = true
	var correct := i == _correct
	var buttons := []
	for child in get_children():
		if child is Button:
			buttons.append(child)
	for b in buttons:
		b.disabled = true
	# Mark the pick and the right answer on the rows.
	if i < buttons.size():
		_prefix(buttons[i], "✓ " if correct else "✗ ")
	if not correct and _correct < buttons.size():
		_prefix(buttons[_correct], "✓ ")
	var reply: Dictionary = _reply.duplicate(true)
	if not correct:
		reply.result["passed"] = 0
		for r in reply.result.results:
			r["pass"] = false
	answered.emit(correct, reply)


func _prefix(button: Button, mark: String) -> void:
	for label in button.find_children("*", "Label", true, false):
		label.text = mark + label.text
		return
