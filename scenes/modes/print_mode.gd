extends VBoxContainer
## What does this print: the solution, read-only, one of its tests, and four
## answers. Pick one, then Run grades it: the right answer fills accent, a
## wrong pick fills error. The right one is what the judge got from the
## solution; the wrong ones come from buggy versions of it.
##
## Printed output is shown as stacked lines in each answer's own block, the
## way the results panel writes it, never joined onto one line: options that
## share a first line have to be told apart further down, so a long option is
## cut short around the line that tells it from the option it is most like.
##
## For output longer than four lines a shorter question is preferred: "what
## is the last line this prints?" whenever the outputs end differently, and
## "how many lines does this print?" only when they end the same way and the
## lines cannot be counted straight off the code. Either way the question
## needs four answers of its own, or the four outputs are shown after all —
## and if even those would read the same, this problem has no print version.

signal instruction_changed
## The pick changed (so Run can be enabled).
signal changed

const ANSWERS := 4
const MAX_ROWS := 4

var _problem: Dictionary = {}
var _test_index := 0
var _print_only := false
## "" full output · "last" the last line · "count" how many lines.
var _form := ""
var _answers: Array = []      # what each option offers: a value, or a short string
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
	var options: Array = [right] + wrong
	_form = Modes.short_form(options, str(problem.solution)) if _print_only else ""
	# A shorter question is asked only when it has four answers of its own;
	# otherwise the four outputs are shown stacked after all.
	while _form != "":
		var short := _short_options(options)
		if short.size() >= ANSWERS:
			options = short
			break
		_form = "count" if _form == "last" else ""
	# Four long outputs that read the same in the rows there is room for are
	# no question at all: the problem has no print version.
	if _form == "" and _print_only and not Modes.print_rows_distinct(options, MAX_ROWS):
		return false
	var order := Modes.seeded_order(str(problem.id) + ":answers", options.size())
	_answers = []
	for k in order:
		_answers.append(options[k])
	# The right answer is options[0] before the shuffle; this is where it landed.
	_correct = order.find(0)
	render()
	return true


## The options as short answers: the last line, or how many lines. What the
## buggy versions gave comes first; the rest are the misreadings a reader
## could make. Fewer than four means the question does not work here.
func _short_options(options: Array) -> Array:
	var out := []
	for o in options:
		var short := _short_of(o)
		if not out.has(short):
			out.append(short)
	var extra := []
	if _form == "count":
		for n in Modes.count_distractors(options, str(_problem.get("solution", "")), ANSWERS):
			extra.append(_count_text(int(n)))
	else:
		for alt in Modes.last_distractors(options, ANSWERS):
			extra.append(str(alt))
	for e in extra:
		if out.size() >= ANSWERS:
			break
		if not out.has(e):
			out.append(e)
	return out.slice(0, ANSWERS)


func _short_of(value: Variant) -> String:
	var lines := Modes.as_lines(value)
	if _form == "count":
		return _count_text(lines.size())
	return lines[-1] if lines.size() > 0 else "(nothing printed)"


static func _count_text(n: int) -> String:
	return "%d line%s" % [n, "" if n == 1 else "s"]


func _value_of(r: Dictionary) -> Variant:
	return r.get("out", []) if _print_only else r.get("got", null)


func instruction() -> String:
	if _problem.is_empty():
		return ""
	var t: Dictionary = _problem.tests[_test_index]
	var frames: String = "after %d frame%s, " % [int(t.frames), "" if int(t.frames) == 1 else "s"] if t.has("frames") else ""
	var question := "What does this print?"
	if _form == "last":
		question = "What is the last line this prints?"
	elif _form == "count":
		question = "How many lines does this print?"
	elif not _print_only:
		question = "What does this return?"
	if not Fmt.shows_call(_problem):
		return "%s %sPick an answer, then Run." % [question, ("After " + frames.trim_suffix(", ") + ". ") if frames != "" else ""]
	return "%s The judge calls %s%s. Pick an answer, then Run." % [question, frames, Fmt.call_str(_problem, t.get("args", []))]


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


## The right answer and the pick, on one line, for the verdict.
func right_text() -> String:
	return _one_line(_correct)


func picked_text() -> String:
	return _one_line(selected)


func _one_line(i: int) -> String:
	if i < 0:
		return ""
	if _form != "":
		return str(_answers[i])
	if not _print_only:
		return Fmt.fmt_typed(_answers[i], Fmt.return_type(str(_problem.get("signature", ""))))
	var lines := Modes.as_lines(_answers[i])
	if lines.is_empty():
		return "(nothing printed)"
	if lines.size() > MAX_ROWS:
		return "%s … %d lines" % [lines[0], lines.size()]
	return " ⏎ ".join(lines)


func print_only() -> bool:
	return _print_only


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
		var button: Button
		if _form == "" and _print_only:
			button = UI.choice_block(Modes.print_rows(_answers, i, MAX_ROWS), state)
		else:
			button = UI.choice(str(_answers[i]) if _form != "" else Fmt.fmt_typed(_answers[i], rtype), state)
		button.disabled = graded
		button.pressed.connect(func() -> void: pick(i))
		add_child(button)
	instruction_changed.emit()
