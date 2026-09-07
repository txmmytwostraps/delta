extends PanelContainer
## One problem: prompt, the code as it stands (starter or draft), Run with
## the judge's results, and the note. Opened by App.open_problem(); Back
## closes it.

var problem_id := ""
## Opened from the review slot: the first verdict decides the review.
var review := false

@onready var back: Button = $Margin/Column/TopBar/Back
@onready var meta: Label = $Margin/Column/TopBar/Meta
@onready var title: Label = $Margin/Column/Scroll/Body/Title
@onready var status: Label = $Margin/Column/Scroll/Body/Status
@onready var prompt: Label = $Margin/Column/Scroll/Body/Prompt
@onready var code: Label = $Margin/Column/Scroll/Body/CodePanel/CodeScroll/Code
@onready var run_button: Button = $Margin/Column/Scroll/Body/Run
@onready var results: VBoxContainer = $Margin/Column/Scroll/Body/Results
@onready var verdict: Label = $Margin/Column/Scroll/Body/Results/Verdict
@onready var count: Label = $Margin/Column/Scroll/Body/Results/Count
@onready var verdict_note: Label = $Margin/Column/Scroll/Body/Results/VerdictNote
@onready var tests: VBoxContainer = $Margin/Column/Scroll/Body/Results/Tests
@onready var output_label: Label = $Margin/Column/Scroll/Body/Results/OutputLabel
@onready var output: Label = $Margin/Column/Scroll/Body/Results/Output
@onready var errors_label: Label = $Margin/Column/Scroll/Body/Results/ErrorsLabel
@onready var errors: Label = $Margin/Column/Scroll/Body/Results/Errors
@onready var note: TextEdit = $Margin/Column/Scroll/Body/Note
@onready var resolved: Button = $Margin/Column/Scroll/Body/NoteRow/Resolved
@onready var saved: Label = $Margin/Column/Scroll/Body/NoteRow/Saved

var _save_timer: Timer
var _loading := true
## What Submission needs to remember across the runs of this visit.
var _visit := {}


func _ready() -> void:
	_visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	back.pressed.connect(close)
	run_button.pressed.connect(_on_run)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.0
	_save_timer.timeout.connect(_save_note)
	add_child(_save_timer)
	note.text_changed.connect(func() -> void:
		if not _loading:
			saved.text = "typing…"
			_save_timer.start())
	resolved.toggled.connect(func(on: bool) -> void:
		resolved.text = "[x] RESOLVED" if on else "[ ] RESOLVED"
		if not _loading:
			_save_note())
	Sync.state_changed.connect(_update_saved)
	render()


func render() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		title.text = "UNKNOWN PROBLEM"
		return
	_loading = true
	meta.text = "%s · D%d%s" % [Bank.topic_title(p.concept).to_upper(), int(p.get("difficulty", 0)), " · REVIEW" if review else ""]
	title.text = str(p.title).to_upper()
	prompt.text = str(p.prompt)
	_render_status()
	# Labels swallow tabs, so show each as four spaces.
	code.text = current_code().replace("\t", "    ")
	var n := Notes.get_note(problem_id)
	note.text = str(n.get("text", ""))
	resolved.button_pressed = bool(n.get("resolved", false))
	resolved.text = "[x] RESOLVED" if resolved.button_pressed else "[ ] RESOLVED"
	_update_saved()
	_loading = false


func _render_status() -> void:
	var when: Variant = Progress.solved().get(problem_id, null)
	var fails := int(Progress.fails().get(problem_id, 0))
	status.visible = when != null or fails > 0
	if when != null:
		status.text = "SOLVED · %s" % Streak.day_key(str(when))
	elif fails > 0:
		status.text = "%d MISS%s SO FAR" % [fails, "" if fails == 1 else "ES"]


## The draft when there is one, else the starter.
func current_code() -> String:
	var p := Bank.problem(problem_id)
	return str(Progress.draft(problem_id).get("code", p.get("starter", "")))


# ---- running ----

func _on_run() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty() or Grader.busy:
		return
	run_button.disabled = true
	results.visible = true
	verdict.theme_type_variation = &"Muted"
	verdict.text = "Running…"
	count.text = ""
	verdict_note.text = ""
	_clear(tests)
	output_label.visible = false
	output.visible = false
	errors_label.visible = false
	errors.visible = false

	var reply: Dictionary = await Grader.run(current_code(), p)
	if not is_inside_tree():
		return
	var outcome := Submission.record(p, reply, _visit)
	_render_result(p, reply, outcome)
	_render_status()
	run_button.disabled = false


func _render_result(p: Dictionary, reply: Dictionary, outcome: Dictionary) -> void:
	var result: Dictionary = reply.result
	verdict.theme_type_variation = &"Accent" if outcome.pass else &"Error"
	verdict.text = outcome.verdict
	verdict_note.text = outcome.note
	verdict_note.visible = outcome.note != ""
	var total: int = p.get("tests", []).size()

	if result.status != "ok":
		count.text = "0 / %d TESTS · %d MS" % [total, reply.ms]
		_show_errors(reply.errors, "Parse error" if result.status == "compile_error" else "")
		return

	count.text = "%d / %d TESTS · %d MS" % [int(result.passed), int(result.total), reply.ms]
	var rtype := Fmt.return_type(str(p.get("signature", "")))
	var print_only := Fmt.print_only(p)
	var printed := []
	for i in result.results.size():
		var r: Dictionary = result.results[i]
		var t: Dictionary = p.tests[i] if i < p.tests.size() else {}
		tests.add_child(_test_row(p, t, r, rtype, print_only))
		for line in r.get("out", []):
			printed.append("[test %d] %s" % [i + 1, line])
	if printed.size() > 0 and not print_only:
		output_label.visible = true
		output.visible = true
		output.text = "\n".join(printed)
	_show_errors(reply.errors, "")


func _test_row(p: Dictionary, t: Dictionary, r: Dictionary, rtype: String, print_only: bool) -> Control:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var head := Label.new()
	head.theme_type_variation = &"Accent" if r.pass else &"Error"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var frames: String = "after %d frame%s · " % [int(t.frames), "" if int(t.frames) == 1 else "s"] if t.has("frames") else ""
	head.text = "%s %s%s%s" % ["✓" if r.pass else "✗", (str(t.name) + " · ") if t.has("name") else "", frames, Fmt.call_str(p, r.get("args", []))]
	column.add_child(head)

	var expected := Label.new()
	expected.theme_type_variation = &"Muted"
	expected.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	expected.text = ("expected output: " if print_only else "expected: ") + _expected_text(t, rtype, print_only)
	column.add_child(expected)

	var got := Label.new()
	got.theme_type_variation = &"Code"
	got.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	got.text = ("your output: " if print_only else "yours: ") + _got_text(t, r, rtype, print_only)
	if r.has("error"):
		got.text += "\n" + str(r.error)
	column.add_child(got)
	return panel


func _expected_text(t: Dictionary, rtype: String, print_only: bool) -> String:
	if print_only:
		return _lines(t.get("out", []), "(nothing printed)")
	var text := Fmt.fmt_typed(t.get("expect", null), rtype)
	if t.has("out"):
		text += "\nprints " + _lines(t.out, "nothing")
	return text


func _got_text(t: Dictionary, r: Dictionary, rtype: String, print_only: bool) -> String:
	var out: Array = r.get("out", [])
	if print_only:
		return _lines(out, "(nothing printed)")
	var text := Fmt.fmt_typed(r.get("got", null), rtype)
	if t.has("out"):
		text += "\nprints " + _lines(out, "nothing")
	return text


func _lines(lines: Array, when_empty: String) -> String:
	if lines.is_empty():
		return when_empty
	var strings := []
	for line in lines:
		strings.append(str(line))
	return "\n".join(strings)


func _show_errors(lines: Array, fallback: String) -> void:
	var text := "\n".join(lines)
	if text == "":
		text = fallback
	errors_label.visible = text != ""
	errors.visible = text != ""
	errors.text = text


# ---- notes ----

func _save_note() -> void:
	_save_timer.stop()
	var n := Notes.get_note(problem_id)
	var text := note.text
	var is_resolved := resolved.button_pressed
	if text == str(n.get("text", "")) and is_resolved == bool(n.get("resolved", false)):
		_update_saved()
		return
	if text.strip_edges() == "" and n.is_empty():
		_update_saved()
		return
	Notes.save(problem_id, {"text": text, "resolved": is_resolved})
	_update_saved()


func _update_saved() -> void:
	if not is_inside_tree() or _save_timer.time_left > 0:
		return
	var n := Notes.get_note(problem_id)
	if n.is_empty():
		saved.text = ""
	elif Sync.pending_count() > 0:
		saved.text = "saved here · waiting to sync"
	else:
		saved.text = "saved to your account"


func close() -> void:
	if _save_timer.time_left > 0:
		_save_note()
	queue_free()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
