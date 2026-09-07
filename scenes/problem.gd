extends PanelContainer
## One problem, in one of the tap modes: put the lines in order, fix the
## bug, or say what it prints; or typed, in the editor. The instruction area
## above the cards says what to do and, after a run, shows the result. Run,
## Reset and the note live in the bar at the bottom. Opened by
## App.open_problem(); Back closes it.

const OrderMode := preload("res://scenes/modes/order_mode.gd")
const BugMode := preload("res://scenes/modes/bug_mode.gd")
const PrintMode := preload("res://scenes/modes/print_mode.gd")
const MODES := ["order", "bug", "print"]

var problem_id := ""
## Opened from the review slot: the first verdict decides the review.
var review := false
## Shared with the editor: misses this visit, whether the review was decided.
var visit: Dictionary = {}

@onready var back: Button = $Column/TopMargin/TopBar/Back
@onready var meta: Label = $Column/TopMargin/TopBar/Meta
@onready var scroll: ScrollContainer = $Column/Scroll
@onready var title: Label = $Column/Scroll/Margin/Body/Head/Title
@onready var status: Label = $Column/Scroll/Margin/Body/Head/Status
@onready var prompt: Label = $Column/Scroll/Margin/Body/Head/Prompt
@onready var segments: HBoxContainer = $Column/Scroll/Margin/Body/Modes
@onready var instruction_box: PanelContainer = $Column/Scroll/Margin/Body/Work/Instruction
@onready var instruction_column: VBoxContainer = $Column/Scroll/Margin/Body/Work/Instruction/InstructionColumn
@onready var instruction_text: Label = $Column/Scroll/Margin/Body/Work/Instruction/InstructionColumn/InstructionText
@onready var preparing: Label = $Column/Scroll/Margin/Body/Work/Preparing
@onready var mode_host: VBoxContainer = $Column/Scroll/Margin/Body/Work/ModeHost
@onready var notes_drawer: PanelContainer = $Column/NotesDrawer
@onready var note: TextEdit = $Column/NotesDrawer/NotesColumn/Note
@onready var resolved: Button = $Column/NotesDrawer/NotesColumn/NoteRow/Resolved
@onready var saved: Label = $Column/NotesDrawer/NotesColumn/NoteRow/Saved
@onready var close_note: Button = $Column/NotesDrawer/NotesColumn/NoteRow/CloseNote
@onready var run_button: Button = $Column/Bar/BarMargin/Actions/Run
@onready var reset_button: Button = $Column/Bar/BarMargin/Actions/Reset
@onready var note_button: Button = $Column/Bar/BarMargin/Actions/NoteButton

var mode := ""
var results := ResultsPanel.new()
var _widget: Control
var _save_timer: Timer
var _loading := true
var _switching := 0


func _ready() -> void:
	if visit.is_empty():
		visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	instruction_column.add_child(results)
	results.clear()
	back.pressed.connect(close)
	run_button.pressed.connect(_on_run)
	reset_button.pressed.connect(_on_reset)
	note_button.pressed.connect(_toggle_notes)
	close_note.pressed.connect(_toggle_notes)
	for m in MODES:
		var button: Button = segments.get_node(m.capitalize())
		button.pressed.connect(func() -> void:
			if mode != m:
				set_mode(m))
	segments.get_node("Type").pressed.connect(_open_editor)

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
	meta.text = Bank.topic_title(p.concept).to_upper() + (" · REVIEW" if review else "")
	title.text = str(p.title).to_upper()
	prompt.text = str(p.prompt)
	_render_status()
	var n := Notes.get_note(problem_id)
	note.text = str(n.get("text", ""))
	resolved.button_pressed = bool(n.get("resolved", false))
	resolved.text = "[x] RESOLVED" if resolved.button_pressed else "[ ] RESOLVED"
	note_button.text = "NOTE ·" if str(n.get("text", "")).strip_edges() != "" else "NOTE"
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
	segments.get_node(name.capitalize()).button_pressed = true
	results.clear()
	instruction_text.visible = true
	instruction_text.text = "Preparing…"
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
	else:
		ok = await widget.setup(p)
	if not is_inside_tree() or token != _switching:
		if is_instance_valid(widget):
			widget.queue_free()
		return
	if not ok:
		widget.queue_free()
		if name != "order":
			await set_mode("order")
			results.show_note("[!] No %s version of this problem" % ("bug" if name == "bug" else "print"), "Showing it as lines to order instead.")
			instruction_text.visible = false
		return
	_widget = widget
	widget.visible = true
	instruction_text.text = widget.instruction()
	if widget.has_signal("answered"):
		widget.answered.connect(_on_answered)
	run_button.visible = name != "print"
	run_button.disabled = false


func _open_editor() -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.open_editor(problem_id, review)


## The code the current mode has assembled.
func current_code() -> String:
	if _widget and _widget.has_method("code"):
		return _widget.code()
	var p := Bank.problem(problem_id)
	return str(Progress.draft(problem_id).get("code", p.get("starter", "")))


func _on_reset() -> void:
	if _widget and _widget.has_method("reset"):
		_widget.reset()
	results.clear()
	instruction_text.visible = true
	if _widget:
		instruction_text.text = _widget.instruction()


# ---- running ----

func _on_run() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		return
	run_button.disabled = true
	instruction_text.visible = false
	results.show_running()
	scroll.scroll_vertical = 0
	var reply: Dictionary = await Grader.run(current_code(), p)
	if not is_inside_tree():
		return
	var outcome := Submission.record(p, reply, visit)
	results.show_result(p, reply, outcome, true)
	_render_status()
	run_button.disabled = false


## A pick in the print mode: recorded like a run, shown without test rows.
func _on_answered(correct: bool, reply: Dictionary) -> void:
	var p := Bank.problem(problem_id)
	var outcome := Submission.record(p, reply, visit)
	if outcome.verdict.begins_with("All tests pass"):
		outcome.verdict = "Right · solved"
	elif outcome.verdict.begins_with("Not yet"):
		outcome.verdict = "Not that one · " + Submission.miss_text(p)
	if not correct and outcome.note == "":
		outcome.note = "The right answer is marked. Reset to try again."
	instruction_text.visible = false
	results.show_result(p, reply, outcome, false)
	scroll.scroll_vertical = 0
	_render_status()


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
	note_button.text = "NOTE ·" if text.strip_edges() != "" else "NOTE"
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
