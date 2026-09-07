extends VBoxContainer
## What does this print: the solution, read-only, one of its tests, and four
## answers. The right one is what the judge got from the solution; the wrong
## ones come from buggy versions of it, so they look plausible.

## correct: the pick was right. reply: what to record, in the judge's shape.
signal answered(correct: bool, reply: Dictionary)

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


func code() -> String:
	return str(_problem.get("solution", ""))


func reset() -> void:
	_done = false
	render()


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	var hint := Label.new()
	hint.theme_type_variation = &"Small"
	hint.text = "WHAT DOES THIS PRINT?" if _print_only else "WHAT DOES THIS RETURN?"
	add_child(hint)

	var panel := PanelContainer.new()
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := Label.new()
	text.theme_type_variation = &"Code"
	text.text = code().replace("\t", "    ")
	scroll.add_child(text)
	panel.add_child(scroll)
	add_child(panel)

	var t: Dictionary = _problem.tests[_test_index]
	var call := Label.new()
	call.theme_type_variation = &"Muted"
	call.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var frames: String = "after %d frame%s, " % [int(t.frames), "" if int(t.frames) == 1 else "s"] if t.has("frames") else ""
	call.text = "The judge calls %s%s" % [frames, Fmt.call_str(_problem, t.get("args", []))]
	add_child(call)

	var rtype := Fmt.return_type(str(_problem.get("signature", "")))
	for i in _answers.size():
		var button := Button.new()
		button.custom_minimum_size.y = 88
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _answer_text(_answers[i], rtype)
		button.disabled = _done
		button.pressed.connect(func() -> void: _pick(i))
		add_child(button)


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
	for k in get_child_count():
		var child := get_child(k)
		if child is Button:
			child.disabled = true
	# Mark the pick and the right answer on the buttons.
	var buttons := []
	for child in get_children():
		if child is Button:
			buttons.append(child)
	if i < buttons.size():
		buttons[i].text = ("✓ " if correct else "✗ ") + buttons[i].text
	if not correct and _correct < buttons.size():
		buttons[_correct].text = "✓ " + buttons[_correct].text
	var reply: Dictionary = _reply.duplicate(true)
	if not correct:
		reply.result["passed"] = 0
		for r in reply.result.results:
			r["pass"] = false
	answered.emit(correct, reply)
