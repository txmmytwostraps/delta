extends PanelContainer
## One problem, in one of the tap modes: put the lines in order, fix the
## bug, or say what it prints. Run sends the assembled code to the judge;
## the results panel and the note are below. Opened by App.open_problem();
## Back closes it.

const OrderMode := preload("res://scenes/modes/order_mode.gd")
const BugMode := preload("res://scenes/modes/bug_mode.gd")
const PrintMode := preload("res://scenes/modes/print_mode.gd")
const MODES := ["order", "bug", "print"]
const MODE_LABELS := {"order": "ORDER", "bug": "BUG", "print": "PRINT"}

var problem_id := ""
## Opened from the review slot: the first verdict decides the review.
var review := false

@onready var back: Button = $Margin/Column/TopBar/Back
@onready var meta: Label = $Margin/Column/TopBar/Meta
@onready var title: Label = $Margin/Column/Scroll/Body/Title
@onready var status: Label = $Margin/Column/Scroll/Body/Status
@onready var prompt: Label = $Margin/Column/Scroll/Body/Prompt
@onready var mode_bar: HBoxContainer = $Margin/Column/Scroll/Body/ModeBar
@onready var mode_host: VBoxContainer = $Margin/Column/Scroll/Body/ModeHost
@onready var preparing: Label = $Margin/Column/Scroll/Body/Preparing
@onready var actions: HBoxContainer = $Margin/Column/Scroll/Body/Actions
@onready var run_button: Button = $Margin/Column/Scroll/Body/Actions/Run
@onready var reset_button: Button = $Margin/Column/Scroll/Body/Actions/Reset
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

var mode := ""
var _widget: Control
var _save_timer: Timer
var _loading := true
## What Submission needs to remember across the runs of this visit.
var _visit := {}
var _switching := 0


func _ready() -> void:
	_visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	back.pressed.connect(close)
	run_button.pressed.connect(_on_run)
	reset_button.pressed.connect(_on_reset)
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
	set_mode(default_mode())


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


# ---- modes ----

## A review alternates like the site: order on odd review steps, bug on the
## others. Otherwise the problem id picks one, so a problem always opens the
## same way.
func default_mode() -> String:
	if review and Reviews.is_in_review(problem_id):
		return "order" if int(Reviews.rows()[problem_id].get("step", 0)) % 2 == 1 else "bug"
	return MODES[Modes.seeded_order(problem_id + ":mode", MODES.size())[0]]


func set_mode(name: String) -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		return
	mode = name
	_switching += 1
	var token := _switching
	_render_mode_bar()
	_clear_results()
	_clear(mode_host)
	_widget = null
	preparing.visible = name != "order"
	actions.visible = false

	# The widget joins the tree before its setup, hidden, so the setup can
	# tell when the page went away while it was waiting on the judge.
	var widget: Control
	match name:
		"order":
			widget = OrderMode.new()
		"bug":
			widget = BugMode.new()
		"print":
			widget = PrintMode.new()
	widget.visible = false
	mode_host.add_child(widget)
	var ok := true
	if name == "order":
		widget.setup(p)
	else:
		ok = await widget.setup(p)
	if not is_inside_tree() or token != _switching:
		if is_instance_valid(widget):
			widget.queue_free()
		return
	preparing.visible = false
	if not ok:
		widget.queue_free()
		if name != "order":
			set_mode("order")
			_show_note_only("[!] No %s version of this problem" % ("bug" if name == "bug" else "print"), "Showing it as lines to order instead.")
		return
	_widget = widget
	widget.visible = true
	if widget.has_signal("answered"):
		widget.answered.connect(_on_answered)
	actions.visible = true
	run_button.visible = name != "print"
	reset_button.visible = true


func _render_mode_bar() -> void:
	_clear(mode_bar)
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.text = "TRY AS"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_bar.add_child(label)
	for m in MODES:
		if m == mode:
			var active := Label.new()
			active.theme_type_variation = &"Accent"
			active.text = MODE_LABELS[m]
			active.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			active.custom_minimum_size = Vector2(0, 88)
			active.add_theme_constant_override("outline_size", 0)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 8)
			pad.add_theme_constant_override("margin_right", 8)
			pad.add_child(active)
			mode_bar.add_child(pad)
		else:
			var button := Button.new()
			button.theme_type_variation = &"Link"
			button.custom_minimum_size = Vector2(0, 88)
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.text = MODE_LABELS[m]
			button.pressed.connect(func() -> void: set_mode(m))
			mode_bar.add_child(button)
	var typed := Label.new()
	typed.theme_type_variation = &"Dim"
	typed.text = "TYPE · SOON"
	typed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_bar.add_child(typed)


## The code the current mode has assembled.
func current_code() -> String:
	if _widget and _widget.has_method("code"):
		return _widget.code()
	var p := Bank.problem(problem_id)
	return str(Progress.draft(problem_id).get("code", p.get("starter", "")))


func _on_reset() -> void:
	if _widget and _widget.has_method("reset"):
		_widget.reset()
	_clear_results()


# ---- running ----

func _on_run() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty() or Grader.busy:
		return
	run_button.disabled = true
	_clear_results()
	results.visible = true
	verdict.theme_type_variation = &"Muted"
	verdict.text = "Running…"

	var reply: Dictionary = await Grader.run(current_code(), p)
	if not is_inside_tree():
		return
	var outcome := Submission.record(p, reply, _visit)
	_render_result(p, reply, outcome, true)
	_render_status()
	run_button.disabled = false


## A pick in the print mode: recorded like a run, shown without test rows.
func _on_answered(correct: bool, reply: Dictionary) -> void:
	var p := Bank.problem(problem_id)
	var outcome := Submission.record(p, reply, _visit)
	if outcome.verdict.begins_with("[x] All tests pass"):
		outcome.verdict = "[x] Right · solved"
	elif outcome.verdict.begins_with("[x] Not yet"):
		outcome.verdict = "[x] Not that one · " + Submission.miss_text(problem_id)
	_clear_results()
	results.visible = true
	_render_result(p, reply, outcome, false)
	if not correct:
		verdict_note.visible = true
		verdict_note.text = "The right answer is marked. Reset to try again." if outcome.note == "" else outcome.note
	_render_status()


func _clear_results() -> void:
	results.visible = false
	count.text = ""
	verdict_note.text = ""
	verdict_note.visible = false
	_clear(tests)
	output_label.visible = false
	output.visible = false
	errors_label.visible = false
	errors.visible = false


func _show_note_only(text: String, detail: String) -> void:
	results.visible = true
	verdict.theme_type_variation = &"Amber"
	verdict.text = text
	verdict_note.visible = true
	verdict_note.text = detail


func _render_result(p: Dictionary, reply: Dictionary, outcome: Dictionary, with_rows: bool) -> void:
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
	if not with_rows:
		return
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
