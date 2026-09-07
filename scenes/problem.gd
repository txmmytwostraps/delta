extends PanelContainer
## One problem, in one of the tap modes: put the lines in order, fix the
## bug, or say what it prints; or typed, in the editor (the ✎ button). One
## default mode per problem: Print for print-style problems, Order
## otherwise; "Other ways" opens the rest. Inside a run the bar across the
## top says "Run · n of N". Run, a "?" for hints and ✎ live in the bottom
## bar. Opened by App.open_problem(); Back closes it.

const OrderMode := preload("res://scenes/modes/order_mode.gd")
const BugMode := preload("res://scenes/modes/bug_mode.gd")
const PrintMode := preload("res://scenes/modes/print_mode.gd")
const MODES := ["order", "bug", "print"]
const MODE_NAMES := {"order": "Order", "bug": "Bug", "print": "Print"}

var problem_id := ""
## Opened from the review slot: the first verdict decides the review.
var review := false
## Shared with the editor: misses this visit, whether the review was decided.
var visit: Dictionary = {}

@onready var back: Button = $Column/TopBand/TopMargin/TopColumn/TopBar/Back
@onready var meta: Label = $Column/TopBand/TopMargin/TopColumn/TopBar/Meta
@onready var run_bar_host: VBoxContainer = $Column/TopBand/TopMargin/TopColumn/RunBarHost
@onready var scroll: ScrollContainer = $Column/Scroll
@onready var kicker: Label = $Column/Scroll/Margin/Body/Head/Kicker
@onready var title: Label = $Column/Scroll/Margin/Body/Head/Title
@onready var status: Label = $Column/Scroll/Margin/Body/Head/Status
@onready var prompt: Label = $Column/Scroll/Margin/Body/Head/Prompt
@onready var instruction_column: VBoxContainer = $Column/Scroll/Margin/Body/Work/InstructionColumn
@onready var instruction_text: Label = $Column/Scroll/Margin/Body/Work/InstructionColumn/InstructionText
@onready var preparing: Label = $Column/Scroll/Margin/Body/Work/Preparing
@onready var mode_host: VBoxContainer = $Column/Scroll/Margin/Body/Work/ModeHost
@onready var expected: Label = $Column/Scroll/Margin/Body/Work/ExpectRow/Expected
@onready var other_ways: Button = $Column/Scroll/Margin/Body/Work/ExpectRow/OtherWays
@onready var other_menu: VBoxContainer = $Column/Scroll/Margin/Body/Work/OtherMenu
@onready var hint_drawer: PanelContainer = $Column/HintDrawer
@onready var hint_label: Label = $Column/HintDrawer/HintColumn/HintLabel
@onready var hint_text: Label = $Column/HintDrawer/HintColumn/HintText
@onready var next_hint: Button = $Column/HintDrawer/HintColumn/HintRow/NextHint
@onready var close_hint: Button = $Column/HintDrawer/HintColumn/HintRow/CloseHint
@onready var notes_drawer: PanelContainer = $Column/NotesDrawer
@onready var note: TextEdit = $Column/NotesDrawer/NotesColumn/Note
@onready var resolved: Button = $Column/NotesDrawer/NotesColumn/NoteRow/Resolved
@onready var saved: Label = $Column/NotesDrawer/NotesColumn/NoteRow/Saved
@onready var close_note: Button = $Column/NotesDrawer/NotesColumn/NoteRow/CloseNote
@onready var next_button: Button = $Column/Bar/BarMargin/Actions/Next
@onready var run_button: Button = $Column/Bar/BarMargin/Actions/Run
@onready var hint_button: Button = $Column/Bar/BarMargin/Actions/HintButton
@onready var type_button: Button = $Column/Bar/BarMargin/Actions/TypeButton

var mode := ""
var results := ResultsPanel.new()
## The verdict after a run, over the bottom bar; see VerdictPanel.
var verdict: VerdictPanel
var _widget: Control
var _save_timer: Timer
var _loading := true
var _switching := 0
## The last run, for Review and Hint once the panel has gone.
var _last: Dictionary = {}
var _hint_at := -1
var _bug_found: Variant = null   # null until probed; {} when there is none
var _in_run := false


func _ready() -> void:
	if visit.is_empty():
		visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	instruction_column.add_child(results)
	results.clear()
	verdict = VerdictPanel.attach(self)
	verdict.next_pressed.connect(_go_next)
	verdict.review_pressed.connect(_show_review)
	verdict.hint_pressed.connect(_show_hint)
	next_button.pressed.connect(_go_next)
	back.pressed.connect(close)
	run_button.pressed.connect(_on_run)
	hint_button.pressed.connect(_toggle_hints)
	next_hint.pressed.connect(func() -> void: _render_hint(true))
	close_hint.pressed.connect(func() -> void: hint_drawer.visible = false)
	type_button.pressed.connect(_open_editor)
	other_ways.pressed.connect(func() -> void:
		other_menu.visible = not other_menu.visible
		other_ways.text = "OTHER WAYS ▴" if other_menu.visible else "OTHER WAYS ▾")
	close_note.pressed.connect(_toggle_notes)

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
	var app := _app()
	_in_run = app != null and app.run_active and app.run_has(problem_id)
	render()
	_probe_modes()
	set_mode(default_mode())


## Modes a problem does not have are left out of the menu: a bug version
## exists only when the judge can plant one.
func _probe_modes() -> void:
	var p := Bank.problem(problem_id)
	var app := _app()
	if p.is_empty() or app == null:
		return
	var found: Dictionary = await app.find_bug(p)
	if not is_inside_tree():
		return
	_bug_found = found
	_render_menu()
	if found.is_empty() and mode == "bug":
		set_mode("order")


func render() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		title.text = "UNKNOWN PROBLEM"
		return
	_loading = true
	var app := _app()
	if _in_run and app:
		var pos: Dictionary = app.run_position(problem_id)
		meta.text = "RUN · %d OF %d" % [pos.at, pos.total]
		_clear(run_bar_host)
		run_bar_host.add_child(UI.bar(pos.at - 1, pos.total, 4))
	else:
		meta.text = "REVIEW" if review else ""
	title.text = str(p.title).to_upper()
	prompt.text = str(p.prompt).replace("`", "")
	expected.text = _expected_line(p)
	_render_status()
	_render_kicker()
	var n := Notes.get_note(problem_id)
	note.text = str(n.get("text", ""))
	resolved.button_pressed = bool(n.get("resolved", false))
	resolved.text = "[x] RESOLVED" if resolved.button_pressed else "[ ] RESOLVED"
	_update_saved()
	_loading = false


func _render_kicker() -> void:
	var p := Bank.problem(problem_id)
	kicker.text = "%s · %s" % [Bank.topic_title(str(p.get("concept", ""))).to_upper(), MODE_NAMES.get(mode, mode).to_upper()]


func _render_status() -> void:
	var when: Variant = Progress.solved().get(problem_id, null)
	var fails := int(Progress.fails().get(problem_id, 0))
	status.visible = when != null or fails > 0
	if when != null:
		status.text = "SOLVED · %s" % Streak.day_key(str(when))
	elif fails > 0:
		status.text = "%d MISS%s SO FAR" % [fails, "" if fails == 1 else "ES"]


## The expected outcome, on one line: the first test's call and answer.
func _expected_line(p: Dictionary) -> String:
	var tests: Array = p.get("tests", [])
	if tests.is_empty():
		return ""
	var t: Dictionary = tests[0]
	if Fmt.print_only(p):
		var lines: Array = t.get("out", [])
		var strings := []
		for line in lines:
			strings.append(str(line))
		return "prints %s" % (" ⏎ ".join(strings) if strings.size() > 0 else "nothing")
	var rtype := Fmt.return_type(str(p.get("signature", "")))
	var value := Fmt.fmt_typed(t.get("expect", null), rtype)
	if Fmt.shows_call(p):
		return "%s → %s" % [Fmt.call_str(p, t.get("args", [])), value]
	return "returns %s" % value


## The other ways into the problem, as rows under "Other ways".
func _render_menu() -> void:
	_clear(other_menu)
	for m in MODES:
		if m == mode:
			continue
		if m == "bug" and _bug_found is Dictionary and _bug_found.is_empty():
			continue
		var row := UI.list_row("", MODE_NAMES[m], {"order": "put the lines in order", "bug": "fix the planted bug", "print": "say what it prints"}[m])
		row.pressed.connect(func() -> void:
			other_menu.visible = false
			other_ways.text = "OTHER WAYS ▾"
			set_mode(m))
		other_menu.add_child(row)
	var typed := UI.list_row("", "Type", "write it yourself")
	typed.pressed.connect(_open_editor)
	other_menu.add_child(typed)
	var reset := UI.list_row("", "Reset", "start this mode over")
	reset.pressed.connect(func() -> void:
		other_menu.visible = false
		other_ways.text = "OTHER WAYS ▾"
		_on_reset())
	other_menu.add_child(reset)
	var n := Notes.get_note(problem_id)
	var note_row := UI.list_row("", "Note", "written" if str(n.get("text", "")).strip_edges() != "" else "what I don't get")
	note_row.pressed.connect(func() -> void:
		other_menu.visible = false
		other_ways.text = "OTHER WAYS ▾"
		_toggle_notes())
	other_menu.add_child(note_row)


# ---- modes ----

## One default per problem: Print for print-style problems, Order for the
## rest. A review alternates like the site: order on odd review steps, bug
## on the others.
func default_mode() -> String:
	if review and Reviews.is_in_review(problem_id):
		return "order" if int(Reviews.rows()[problem_id].get("step", 0)) % 2 == 1 else "bug"
	var p := Bank.problem(problem_id)
	return "print" if Fmt.print_only(p) else "order"


func set_mode(name: String) -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		return
	mode = name
	_switching += 1
	var token := _switching
	verdict.dismiss()
	results.clear()
	instruction_text.visible = true
	instruction_text.text = "Preparing…"
	_render_kicker()
	_render_menu()
	_clear(mode_host)
	_widget = null
	preparing.visible = false
	run_button.disabled = true

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
	widget.instruction_changed.connect(func() -> void:
		if _widget == widget and not results.visible:
			instruction_text.text = widget.instruction())
	var ok := true
	if name == "order":
		widget.setup(p)
	elif name == "bug":
		var app := _app()
		var found: Dictionary = await app.find_bug(p) if app else {}
		if token != _switching or not is_instance_valid(widget):
			return
		ok = not found.is_empty() and await widget.setup(p, found)
	else:
		ok = await widget.setup(p)
	if not is_inside_tree() or token != _switching:
		if is_instance_valid(widget):
			widget.queue_free()
		return
	if not ok:
		# No such version of this problem: order it is.
		widget.queue_free()
		if name == "bug":
			_bug_found = {}
		if name != "order":
			set_mode("order")
		return
	_widget = widget
	widget.visible = true
	instruction_text.text = widget.instruction()
	if name == "print":
		widget.changed.connect(func() -> void: run_button.disabled = widget.selected < 0 or widget.graded)
		run_button.disabled = true
	else:
		run_button.disabled = false


func _open_editor() -> void:
	var app := _app()
	if app:
		app.open_editor(problem_id, review)


## The code the current mode has assembled.
func current_code() -> String:
	if _widget and _widget.has_method("code"):
		return _widget.code()
	var p := Bank.problem(problem_id)
	return Fmt.migrate_draft(str(Progress.draft(problem_id).get("code", p.get("starter", ""))), p)


func _on_reset() -> void:
	if _widget and _widget.has_method("reset"):
		_widget.reset()
	verdict.dismiss()
	results.clear()
	instruction_text.visible = true
	if _widget:
		instruction_text.text = _widget.instruction()
	run_button.disabled = mode == "print"


# ---- running ----

func _on_run() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		return
	if mode == "print":
		_grade_pick()
		return
	run_button.disabled = true
	instruction_text.visible = false
	results.show_running()
	scroll.scroll_vertical = 0
	var reply: Dictionary = await Grader.run(current_code(), p)
	if not is_inside_tree():
		return
	var outcome := Submission.record(p, reply, visit)
	run_button.disabled = false
	var line := ResultsPanel.pass_line(p, reply, outcome) if outcome.pass else ResultsPanel.fail_line(p, reply, outcome)
	_show_verdict(p, reply, outcome, true, line)


## Print mode: the pick is graded and recorded like a run, shown without
## test rows; the answers themselves show right and wrong.
func _grade_pick() -> void:
	var p := Bank.problem(problem_id)
	var graded: Dictionary = _widget.grade() if _widget and _widget.has_method("grade") else {}
	if graded.is_empty():
		return
	run_button.disabled = true
	var outcome := Submission.record(p, graded.reply, visit)
	var extra := ""
	if outcome.verdict.begins_with("All tests pass"):
		outcome.verdict = "Right · solved"
	elif outcome.verdict.begins_with("Not yet"):
		outcome.verdict = "Not that one · " + Submission.miss_text(p)
	else:
		extra = " · " + outcome.verdict    # a review's or a topic's verdict
	if not graded.correct and outcome.note == "":
		outcome.note = "The right answer is marked. Reset to try again."
	var does := "prints" if _widget.print_only() else "returns"
	var line: String
	if graded.correct:
		line = str(outcome.get("xp", "Right · it %s %s" % [does, _widget.right_text()]))
	else:
		line = "It %s %s · you picked %s%s" % [does, _widget.right_text(), _widget.picked_text(), extra]
	_show_verdict(p, graded.reply, outcome, false, line)


## The verdict goes on the panel; the page stays as it was until a button
## on the panel is tapped. A pass puts Next › in the bar for good.
func _show_verdict(p: Dictionary, reply: Dictionary, outcome: Dictionary, with_rows: bool, line: String) -> void:
	_last = {"p": p, "reply": reply, "outcome": outcome, "rows": with_rows}
	results.clear()
	instruction_text.visible = true
	hint_drawer.visible = false
	_render_status()
	var app := _app()
	if app:
		app.buzz(outcome.pass)
	if outcome.pass:
		var label: String = app.next_label(problem_id, review) if app else "NEXT ›"
		next_button.visible = true
		next_button.text = label
		run_button.theme_type_variation = &""
		verdict.show_pass(line, label)
	else:
		verdict.show_fail(line)


## Review: the solved state, your code with the checks and a ✓ on each.
func _show_review() -> void:
	if _last.is_empty():
		return
	instruction_text.visible = false
	results.show_result(_last.p, _last.reply, _last.outcome, _last.rows)
	scroll.scroll_vertical = 0


## Hint from the verdict panel: the checks, and the hint drawer.
func _show_hint() -> void:
	_show_review()
	hint_drawer.visible = true
	_render_hint(true)


func _toggle_hints() -> void:
	hint_drawer.visible = not hint_drawer.visible
	if hint_drawer.visible:
		_render_hint(_hint_at < 0)


## The hint drawer: the next hint that may open at this topic's level.
## Each Next opens one more; a locked one says what opens it.
func _render_hint(advance: bool) -> void:
	var p := Bank.problem(problem_id)
	var list: Array = p.get("hints", [])
	if list.is_empty() and p.has("hint"):
		list = [p.hint]
	if list.is_empty():
		hint_label.text = "NO HINTS FOR THIS ONE"
		hint_text.text = "Type mode shows the reference solution after %d misses." % Submission.unlock_after(p)
		next_hint.visible = false
		return
	var i := mini(_hint_at + (1 if advance else 0), list.size() - 1)
	i = maxi(i, 0)
	var level := Scaffold.level_for(str(p.get("concept", "")))
	var misses := int(Progress.fails().get(problem_id, 0))
	if Scaffold.hint_open(level, i, misses) or Progress.is_solved(problem_id):
		if i != _hint_at:
			Week.log_hint(problem_id, i)
		_hint_at = i
		hint_label.text = "HINT %d OF %d" % [i + 1, list.size()]
		hint_text.text = str(list[i]).replace("`", "")
	else:
		hint_label.text = "HINT %d OF %d · LOCKED" % [i + 1, list.size()]
		hint_text.text = "This hint opens %s. Hints are %s for this topic; change that in Profile." % [Scaffold.hint_lock_text(level), level]
	next_hint.visible = _hint_at < list.size() - 1


## Next ›: inside a run the next stop; else the next review, or the next
## unsolved problem in the topic.
func _go_next() -> void:
	if _save_timer.time_left > 0:
		_save_note()
	var app := _app()
	if app == null:
		return
	if _in_run:
		app.run_next(problem_id)
	else:
		app.open_next(problem_id, review)


# ---- notes ----

func _toggle_notes() -> void:
	notes_drawer.visible = not notes_drawer.visible
	if notes_drawer.visible:
		note.grab_focus()
	elif _save_timer.time_left > 0:
		_save_note()


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
	var app := _app()
	if app and _in_run:
		app.leave_run()
	queue_free()


func _app() -> Node:
	return get_tree().get_first_node_in_group("app")


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
