extends PanelContainer
## Type it instead: a landscape editor with GDScript colouring, line
## numbers, a row of the keys a phone keyboard hides, Run, Reset, the hints,
## the reference solution behind its lock, and the same results panel as
## everywhere else. Drafts save themselves. "Tap mode" goes back.

const KEYS := ["Tab", ":", "=", "==", "(", ")", "[", "]", "\"", "-", "+", "->", "_"]
const KEYWORDS := ["func", "var", "const", "if", "elif", "else", "while", "for", "in", "return", "pass", "break", "continue", "and", "or", "not", "extends", "class_name", "match", "is", "as", "self", "static", "enum", "signal", "await", "true", "false", "null", "PI", "TAU", "INF"]
const TYPES := ["int", "float", "String", "bool", "Array", "Dictionary", "Vector2", "Vector2i", "Rect2", "Rect2i", "Variant", "void"]

var problem_id := ""
var review := false
## Shared with the problem page: misses this visit, whether the review was decided.
var visit: Dictionary = {}

@onready var margin: MarginContainer = $Margin
@onready var back: Button = $Margin/Column/TopBar/Back
@onready var title: Label = $Margin/Column/TopBar/Title
@onready var saved: Label = $Margin/Column/TopBar/Saved
@onready var reset_button: Button = $Margin/Column/TopBar/Reset
@onready var run_button: Button = $Margin/Column/TopBar/Run
@onready var code: CodeEdit = $Margin/Column/Body/Code
@onready var side: VBoxContainer = $Margin/Column/Body/Side/SideColumn
@onready var prompt: Label = $Margin/Column/Body/Side/SideColumn/Prompt
@onready var hints: VBoxContainer = $Margin/Column/Body/Side/SideColumn/Hints
@onready var docs: VBoxContainer = $Margin/Column/Body/Side/SideColumn/Docs
@onready var solution_toggle: Button = $Margin/Column/Body/Side/SideColumn/SolutionToggle
@onready var solution: Label = $Margin/Column/Body/Side/SideColumn/Solution
@onready var keys: HBoxContainer = $Margin/Column/Keys

var results := ResultsPanel.new()
var _save_timer: Timer
var _marked := -1
var _loading := true
var _keyboard := 0


func _ready() -> void:
	var p := Bank.problem(problem_id)
	if visit.is_empty():
		visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	title.text = "%s · %s%s" % [Bank.topic_title(str(p.get("concept", ""))).to_upper(), str(p.get("title", "")).to_upper(), " · REVIEW" if review else ""]
	prompt.text = str(p.get("prompt", ""))
	back.pressed.connect(close)
	run_button.pressed.connect(_on_run)
	reset_button.pressed.connect(_on_reset)
	solution_toggle.pressed.connect(_toggle_solution)
	side.add_child(results)
	results.clear()

	_setup_code()
	_render_hints(p)
	_render_docs(p)
	_render_solution_lock(p)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(_save_draft)
	add_child(_save_timer)
	code.text_changed.connect(func() -> void:
		if _loading or review:
			return
		saved.text = "…"
		_save_timer.start())

	for k in KEYS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.text = "⇥" if k == "Tab" else k
		button.pressed.connect(func() -> void: _insert("\t" if k == "Tab" else k))
		keys.add_child(button)

	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.set_landscape(true)
	_loading = false
	code.grab_focus()


func _exit_tree() -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.set_landscape(false)


## Keep the key row above the phone's keyboard.
func _process(_delta: float) -> void:
	var height := DisplayServer.virtual_keyboard_get_height()
	if height == _keyboard:
		return
	_keyboard = height
	var scale := float(DisplayServer.window_get_size().y) / float(get_window().content_scale_size.y)
	margin.add_theme_constant_override("margin_bottom", 12 + int(height / maxf(scale, 0.01)))


# ---- the code ----

func _setup_code() -> void:
	var p := Bank.problem(problem_id)
	var highlighter := CodeHighlighter.new()
	highlighter.number_color = Color("#a1ffe0")
	highlighter.symbol_color = Color("#e8ecef")
	highlighter.function_color = Color("#57b3ff")
	highlighter.member_variable_color = Color("#e8ecef")
	for word in KEYWORDS:
		highlighter.add_keyword_color(word, Color("#ff7085"))
	for word in TYPES:
		highlighter.add_keyword_color(word, Color("#57b3ff"))
	highlighter.add_color_region("\"", "\"", Color("#ffeda1"), false)
	highlighter.add_color_region("'", "'", Color("#ffeda1"), false)
	highlighter.add_color_region("#", "", Color("#8a8f9d"), true)
	code.syntax_highlighter = highlighter
	code.indent_use_spaces = false
	code.indent_size = 4
	code.text = str(Progress.draft(problem_id).get("code", p.get("starter", "")))


func _insert(text: String) -> void:
	code.insert_text_at_caret(text)
	code.grab_focus()


func _save_draft() -> void:
	var p := Bank.problem(problem_id)
	# Trailing spaces do not make a draft, like the site.
	var re := RegEx.new()
	re.compile("(?m)[ \\t]+$")
	if re.sub(code.text, "", true) == re.sub(str(p.get("starter", "")), "", true):
		Progress.clear_draft(problem_id)
		saved.text = ""
	else:
		Progress.set_draft(problem_id, code.text)
		saved.text = "saved"


func _mark_error(line: int) -> void:
	if _marked >= 0 and _marked < code.get_line_count():
		code.set_line_background_color(_marked, Color(0, 0, 0, 0))
	_marked = line
	if line >= 0 and line < code.get_line_count():
		code.set_line_background_color(line, Color("#ff7085", 0.18))


# ---- hints, docs, the solution ----

## Staged hints. Which may open depends on the topic's hint level and the
## misses on this problem; locked ones say what unlocks them. Opening a
## hint never counts as a miss, but it is logged for the weekly summary.
func _render_hints(p: Dictionary) -> void:
	for child in hints.get_children():
		hints.remove_child(child)
		child.queue_free()
	var list: Array = p.get("hints", [])
	if list.is_empty() and p.has("hint"):
		list = [p.hint]
	var level := Scaffold.level_for(str(p.get("concept", "")))
	var misses := int(Progress.fails().get(problem_id, 0))
	for i in list.size():
		var open := Scaffold.hint_open(level, i, misses) or Progress.is_solved(problem_id)
		var button := Button.new()
		button.theme_type_variation = &"Link"
		button.custom_minimum_size.y = 72
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = "[+] HINT %d OF %d" % [i + 1, list.size()] if open else "[#] HINT %d OF %d — %s" % [i + 1, list.size(), Scaffold.hint_lock_text(level).to_upper()]
		button.disabled = not open
		var text := Label.new()
		text.theme_type_variation = &"Muted"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = str(list[i]).replace("`", "")
		text.visible = false
		button.pressed.connect(func() -> void:
			text.visible = not text.visible
			button.text = ("[-] " if text.visible else "[+] ") + button.text.substr(4)
			if text.visible:
				Week.log_hint(problem_id, i))
		hints.add_child(button)
		hints.add_child(text)
	if list.size() > 0:
		var line := Label.new()
		line.theme_type_variation = &"Small"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "HINTS: %s%s · CHANGE ON THE ROUTE" % [level.to_upper(), " (SET BY HAND)" if Scaffold.override_for(str(p.get("concept", ""))) != "" else ""]
		hints.add_child(line)


func _render_docs(p: Dictionary) -> void:
	var list: Array = p.get("docs", [])
	if list.is_empty():
		return
	var head := Label.new()
	head.theme_type_variation = &"Small"
	head.text = "DOCUMENTATION"
	docs.add_child(head)
	for d in list:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s — %s" % [str(d.get("name", "")), str(d.get("what", ""))]
		docs.add_child(row)


func _render_solution_lock(p: Dictionary) -> void:
	var misses := int(Progress.fails().get(problem_id, 0))
	var after := Submission.unlock_after(p)
	var unlocked := Progress.is_solved(problem_id) or misses >= after
	solution.text = str(p.get("solution", "")).replace("\t", "    ")
	if unlocked:
		solution_toggle.text = ("[-] " if solution.visible else "[+] ") + "REFERENCE SOLUTION"
	else:
		var left := after - misses
		solution.visible = false
		solution_toggle.text = "[#] REFERENCE SOLUTION — LOCKED · %d MORE MISS%s TO UNLOCK" % [left, "" if left == 1 else "ES"]


func _toggle_solution() -> void:
	var misses := int(Progress.fails().get(problem_id, 0))
	if not (Progress.is_solved(problem_id) or misses >= Submission.unlock_after(Bank.problem(problem_id))):
		return
	solution.visible = not solution.visible
	_render_solution_lock(Bank.problem(problem_id))


# ---- running ----

func _on_run() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty() or Grader.busy:
		return
	run_button.disabled = true
	_mark_error(-1)
	results.show_running()
	var reply: Dictionary = await Grader.run(code.text, p)
	if not is_inside_tree():
		return
	var outcome := Submission.record(p, reply, visit)
	results.show_result(p, reply, outcome, true)
	_mark_error(results.error_line)
	_render_solution_lock(p)
	_render_hints(p)
	run_button.disabled = false


func _on_reset() -> void:
	var p := Bank.problem(problem_id)
	_loading = true
	code.text = str(p.get("starter", ""))
	_loading = false
	Progress.clear_draft(problem_id)
	saved.text = ""
	_mark_error(-1)
	results.clear()
	code.grab_focus()


func close() -> void:
	if _save_timer.time_left > 0:
		_save_draft()
	var app := get_tree().get_first_node_in_group("app")
	queue_free()
	if app:
		app.open_problem(problem_id, review)
