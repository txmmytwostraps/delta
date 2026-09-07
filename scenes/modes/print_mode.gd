extends VBoxContainer
## What does this print: the solution, read-only, one of its tests, and four
## answers as radio rows. Pick one, then Run grades it: the right answer
## fills accent, a wrong pick fills error. The right one is what the judge
## got from the solution; the wrong ones come from buggy versions of it.

signal instruction_changed
## The pick changed (so Run can be enabled).
signal changed

const ANSWERS := 4

var _problem: Dictionary = {}
var _test_index := 0
var _print_only := false
var _answers: Array = []
var _correct := -1
var _reply: Dictionary = {}
var selected := -1
var graded := false


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
	return "%s The judge calls %s%s. Pick an answer, then Run." % ["What does this print?" if _print_only else "What does this return?", frames, Fmt.call_str(_problem, t.get("args", []))]


func code() -> String:
	return str(_problem.get("solution", ""))


func reset() -> void:
	selected = -1
	graded = false
	render()


func pick(i: int) -> void:
	if graded:
		return
	selected = i
	render()
	changed.emit()


## Grades the pick. Returns { "correct": bool, "reply": Dictionary } with a
## reply in the judge's shape for recording; {} when nothing is picked.
func grade() -> Dictionary:
	if selected < 0 or graded:
		return {}
	graded = true
	var correct := selected == _correct
	render()
	var reply: Dictionary = _reply.duplicate(true)
	if not correct:
		reply.result["passed"] = 0
		for r in reply.result.results:
			r["pass"] = false
	return {"correct": correct, "reply": reply}


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 16)
	add_child(UI.code_view(code()))
	var rtype := Fmt.return_type(str(_problem.get("signature", "")))
	for i in _answers.size():
		var state := ""
		if graded and i == _correct:
			state = "right"
		elif graded and i == selected:
			state = "wrong"
		elif i == selected:
			state = "on"
		var button := UI.choice(_answer_text(_answers[i], rtype), state)
		button.disabled = graded
		button.pressed.connect(func() -> void: pick(i))
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
		return " ⏎ ".join(strings)
	return Fmt.fmt_typed(v, rtype)
