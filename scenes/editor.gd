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
## A milestone step instead of a problem: the stage sits beside the code,
## checks replace tests, and a pass marks the step done.
var step_milestone := ""
var step_index := -1

const StagePanel := preload("res://scenes/stage_panel.gd")
var _stage: VBoxContainer
var _stage_timer: Timer


## The problem, or the milestone step, this editor is for.
func _item() -> Dictionary:
	if step_milestone != "":
		var data := Bank.milestone_data(step_milestone)
		if step_index >= 0 and step_index < data.get("steps", []).size():
			return data.steps[step_index]
		return {}
	return Bank.problem(problem_id)

@onready var margin: MarginContainer = $Margin
@onready var prompt_line: Button = $Margin/Column/PromptLine
@onready var drawer: ScrollContainer = $Margin/Column/Drawer
@onready var body: HBoxContainer = $Margin/Column/Body
@onready var side_scroll: ScrollContainer = $Margin/Column/Body/Side
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
@onready var keys: HFlowContainer = $Margin/Column/Keys

var results := ResultsPanel.new()
var _save_timer: Timer
var _marked := -1
var _loading := true
var _keyboard := 0


func _ready() -> void:
	var p := _item()
	if step_milestone != "":
		problem_id = str(p.get("id", ""))
	if visit.is_empty():
		visit = {"review": review, "review_recorded": false, "attempt_fails": 0}
	if step_milestone != "":
		var meta := Bank.milestone(step_milestone)
		title.text = "MILESTONE %02d · STEP %d OF %d · %s" % [int(meta.get("number", 0)), step_index + 1, Bank.milestone_data(step_milestone).get("steps", []).size(), str(p.get("title", "")).to_upper()]
	else:
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
	if step_milestone != "":
		# The stage first in the side column; it follows the code as it is typed.
		solution_toggle.visible = false
		solution.visible = false
		var scene: Dictionary = Bank.milestone_data(step_milestone).get("scene", {})
		_stage = StagePanel.new()
		_stage.setup(str(scene.get("kind", "move")), scene.get("watch", []), func() -> String: return code.text)
		side.add_child(_stage)
		side.move_child(_stage, 0)
		_stage.set_buttons(p.get("scene", {}).get("buttons", []))
		_stage_timer = Timer.new()
		_stage_timer.one_shot = true
		_stage_timer.wait_time = 0.9
		_stage_timer.timeout.connect(func() -> void: _stage.refresh())
		add_child(_stage_timer)
		code.text_changed.connect(func() -> void:
			if not _loading:
				_stage_timer.start())
		_stage.reset()
	else:
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

	prompt_line.pressed.connect(func() -> void:
		drawer.visible = not drawer.visible
		prompt_line.text = ("▾ " if drawer.visible else "▸ ") + prompt_line.text.substr(2))
	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.set_editor_open(true)
	get_window().size_changed.connect(_layout)
	_layout()
	_loading = false
	code.grab_focus()


func _exit_tree() -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.set_editor_open(false)


## The editor follows the phone's rotation. Landscape: the code with the
## side column beside it. Portrait: the prompt collapsed to one line above
## the code (tap to open the drawer with the prompt, hints, stage and
## results), the key row above the keyboard.
func _layout() -> void:
	var size := get_window().content_scale_size
	var portrait := size.y > size.x
	var column: VBoxContainer = side_scroll.get_node("SideColumn")
	if portrait:
		if column.get_parent() != drawer:
			column.get_parent().remove_child(column)
			drawer.add_child(column)
		side_scroll.visible = false
		prompt_line.visible = true
		prompt_line.text = ("▾ " if drawer.visible else "▸ ") + str(_item().get("prompt", "")).replace("`", "").replace("\n", " ")
	else:
		if column.get_parent() != side_scroll:
			column.get_parent().remove_child(column)
			side_scroll.add_child(column)
		side_scroll.visible = true
		prompt_line.visible = false
		drawer.visible = false


## After a run in portrait the drawer opens so the result is seen.
func _show_side() -> void:
	if prompt_line.visible and not drawer.visible:
		prompt_line.pressed.emit()
	drawer.scroll_vertical = 0


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
	var p := _item()
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
	var p := _item()
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
	if not (Progress.is_solved(problem_id) or misses >= Submission.unlock_after(_item())):
		return
	solution.visible = not solution.visible
	_render_solution_lock(_item())


# ---- running ----

func _on_run() -> void:
	var p := _item()
	if p.is_empty():
		return
	run_button.disabled = true
	_mark_error(-1)
	results.show_running()
	var reply: Dictionary = await Grader.run(code.text, p)
	if not is_inside_tree():
		return
	var outcome: Dictionary
	if step_milestone != "":
		outcome = MilestoneStep.record(Bank.milestone(step_milestone), Bank.milestone_data(step_milestone), step_index, reply)
	else:
		outcome = Submission.record(p, reply, visit)
	results.show_result(p, reply, outcome, true)
	_mark_error(results.error_line)
	if step_milestone != "":
		_stage.refresh()
	else:
		_render_solution_lock(p)
		_render_hints(p)
	_show_side()
	run_button.disabled = false


func _on_reset() -> void:
	var p := _item()
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
	if app and step_milestone != "":
		app.open_milestone(step_milestone, step_index)
	elif app:
		app.open_problem(problem_id, review)
